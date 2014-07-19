module Fluent
  class HttpPumaInput < Input
    Plugin.register_input('http_puma', self)

    def initialize
      require 'puma'
      require 'uri'
      super
    end

    config_param :port, :integer, :default => 9890
    config_param :bind, :string, :default => '0.0.0.0'
    config_param :min_threads, :integer, :default => 0
    config_param :max_threads, :integer, :default => 4
    config_param :use_ssl, :bool, :default => false
    config_param :ssl_keys, :array, :default => nil
    config_param :backlog, :integer, :default => nil
    config_param :format, :string, :default => 'default'

    def configure(conf)
      super

      if @use_ssl && !@ssl_keys
        raise ConfigError, 'ssl_keys parameter is required when use_ssl is true'
      end

      if @format != 'default'
        @parser = TextParser.new
        @parser.configure(conf)
      end
    end

    def start
      super

      # Refer puma's Runner and Rack handler for puma server setup
      @server = ::Puma::Server.new(method(:on_request))
      @server.min_threads = @min_threads
      @server.max_threads = @max_threads
      @server.leak_stack_on_error = false
      if @use_ssl
        setup_https
      else
        setup_http
      end

      @thread = Thread.new(&method(:run))
    end

    def shutdown
      @server.stop(true)
      @thread.join
    end

    def run
      @server.run(false)
    rescue => e
      log.error "unexpected error", :error => e.to_s
      log.error_backtrace e.backtrace
    end

    OK_RESPONSE = [200, {'Content-type'=>'text/plain'}, ["OK"]]

    def on_request(env)
      uri = URI.parse(env['REQUEST_URI'.freeze])
      params = Rack::Utils.parse_query(uri.query)
      path_info = uri.path

      begin
        path = path_info[1..-1]  # remove /
        tag = path.split('/').join('.')
        record_time, record = parse_record(env, params)

        # Skip nil record
        if record.nil?
          return OK_RESPONSE
        end

        time = if param_time = params['time'.freeze]
                 param_time = param_time.to_i
                 param_time.zero? ? Engine.now : param_time
               else
                 record_time.nil? ? Engine.now : record_time
               end
      rescue => e
        return [400, {'Content-type'=>'text/plain'}, ["Bad Request\n#{e}\n"]]
      end

      begin
        # Support batched requests
        if record.is_a?(Array)           
          mes = MultiEventStream.new
          record.each do |single_record|
            single_time = single_record.delete("time".freeze) || time 
            mes.add(single_time, single_record)
          end
          Engine.emit_stream(tag, mes)
	else
          Engine.emit(tag, time, record)
        end
      rescue => e
        return [500, {'Content-type'=>'text/plain'}, ["Internal Server Error\n#{e}\n"]]
      end

      return OK_RESPONSE
    end

    private

    def setup_http
      log.info "listening http on #{@bind}:#{@port}"

      opts = [@bind, @port, true]
      opts << @backlog if @backlog
      @server.add_tcp_listener(*opts)
    end

    def setup_https
      require 'puma/minissl'

      ctx = ::Puma::MiniSSL::Context.new
      key, cert = @ssl_keys
      if defined?(JRUBY_VERSION)
        ctx.keystore = key
        ctx.keystore_pass = cert
      else
        ctx.key = key
        ctx.cert = cert
      end
      ctx.verify_mode = ::Puma::MiniSSL::VERIFY_PEER
      #ctx.verify_mode = ::Puma::MiniSSL::VERIFY_NONE

      log.info "listening https on #{@bind}:#{@port}"

      opts = [@bind, @port, ctx, true]
      opts << @backlog if @backlog
      @server.add_ssl_listener(*opts)
    end

    def parse_record(env, params)
      body = env['rack.input'.freeze]
      content_type = env['CONTENT_TYPE'.freeze]

      case
      when @format != 'default'.freeze
        parse_params_with_parser(body.read)
      when content_type.start_with?('application/json'.freeze)
        return nil, JSON.load(body)
      when content_type.start_with?('application/x-msgpack'.freeze)
        return nil, MessagePack.unpack(body)
      when content_type =~ /^application\/x-www-form-urlencoded/
        params.update(::Rack::Utils.parse_query(body.read))
        parse_params_form(params)
      when content_type =~ /^multipart\/form-data; boundary=(.+)/
        params.update(::Rack::Multipart.parse_multipart(env))
        parse_params_form(params)
      end
    end

    def parse_params_form(params)
      record = if msgpack = params['msgpack'.freeze]
                 MessagePack.unpack(msgpack)
               elsif js = params['json'.freeze]
                 JSON.parse(js)
               else
                 raise "'json' or 'msgpack' parameter is required"
               end
      return nil, record
    end

    def parse_params_with_parser(content)
      @parser.parse(content) { |time, record|
        raise "received event is not #{@format}: #{content}" if record.nil?
        return time, record
      }
    end
  end
end
