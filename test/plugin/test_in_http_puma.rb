require 'helper'
require 'fluent/plugin/in_http_puma'
require 'net/https'

class HttpPumaInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  PORT = unused_port
  CONFIG = %[
    port #{PORT}
    bind "127.0.0.1"
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::HttpPumaInput).configure(conf, true)
  end

  def test_configure
    d = create_driver
    assert_equal PORT, d.instance.port
    assert_equal '127.0.0.1', d.instance.bind
    assert_equal false, d.instance.use_ssl
    assert_equal 0, d.instance.min_threads
    assert_equal 4, d.instance.max_threads
  end

  def test_time
    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    Fluent::Engine.now = time

    d.expect_emit "tag1", time, {"a" => 1}
    d.expect_emit "tag2", time, {"a" => 2}

    d.run do
      d.expected_emits.each { |tag, time, record|
        res = post("/#{tag}", {"json" => record.to_json})
        assert_equal "200", res.code
      }
    end
  end

  def test_json
    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.expect_emit "tag1", time, {"a" => 1}
    d.expect_emit "tag2", time, {"a" => 2}

    d.run do
      d.expected_emits.each { |tag,time,record|
        res = post("/#{tag}", {"json" => record.to_json, "time" => time.to_s})
        assert_equal "200", res.code
      }
    end
  end

  # server.key, server.cert and ca-all.pem are from httpi's repository
  def test_json_over_https
    dir = File.dirname(__FILE__)
    d = create_driver(CONFIG + %[
      use_ssl
      ssl_keys ["#{File.join(dir, 'server.key')}", "#{File.join(dir, 'server.cert')}"]
    ])

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.expect_emit "tag1", time, {"a" => 1}
    d.expect_emit "tag2", time, {"a" => 2}

    d.run do
      d.expected_emits.each { |tag,time,record|
        res = post("/#{tag}", {"json" => record.to_json, "time" => time.to_s}, {}, true)
        assert_equal "200", res.code
      }
    end
  end

  def test_multi_json
    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    events = [{"a" => 1},{"a" => 2}]
    tag = "tag1"

    events.each { |ev|
      d.expect_emit tag, time, ev
    }

    d.run do
      res = post("/#{tag}", {"json" => events.to_json, "time" => time.to_s})
      assert_equal "200", res.code
    end
  end

  def test_application_json
    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.expect_emit "tag1", time, {"a" => 1}
    d.expect_emit "tag2", time, {"a" => 2}

    d.run do
      d.expected_emits.each {|tag,time,record|
        res = post("/#{tag}?time=#{time.to_s}", record.to_json, {"content-type" => "application/json; charset=utf-8"})
        assert_equal "200", res.code
      }
    end
  end

  def test_msgpack
    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.expect_emit "tag1", time, {"a" => 1}
    d.expect_emit "tag2", time, {"a" => 2}

    d.run do
      d.expected_emits.each {|tag,time,record|
        res = post("/#{tag}", {"msgpack" => record.to_msgpack, "time" => time.to_s})
        assert_equal "200", res.code
      }
    end
  end

  def test_multi_msgpack
    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    events = [{"a" => 1},{"a" => 2}]
    tag = "tag1"

    events.each { |ev|
      d.expect_emit tag, time, ev
    }

    d.run do
      res = post("/#{tag}", {"msgpack" => events.to_msgpack, "time" => time.to_s})
      assert_equal "200", res.code
    end

  end

  def test_with_regexp
    d = create_driver(CONFIG + %[
      format /^(?<field_1>\\\\d+):(?<field_2>\\\\w+)$/
      types field_1:integer
    ])

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.expect_emit "tag1", time, {"field_1" => 1, "field_2" => 'str'}
    d.expect_emit "tag2", time, {"field_1" => 2, "field_2" => 'str'}

    d.run do
      d.expected_emits.each { |tag, time, record|
        body = record.map { |k, v|
          v.to_s
        }.join(':')
        res = post("/#{tag}?time=#{time.to_s}", body)
        assert_equal "200", res.code
      }
    end
  end

  def test_with_csv
    require 'csv'

    d = create_driver(CONFIG + %[
      format csv
      keys foo,bar
    ])

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.expect_emit "tag1", time, {"foo" => "1", "bar" => 'st"r'}
    d.expect_emit "tag2", time, {"foo" => "2", "bar" => 'str'}

    d.run do
      d.expected_emits.each { |tag, time, record|
        body = record.map { |k, v| v }.to_csv
        res = post("/#{tag}?time=#{time.to_s}", body)
        assert_equal "200", res.code
      }
    end
  end

  def post(path, params, header = {}, ssl = false)
    http = Net::HTTP.new("127.0.0.1", PORT)
    if ssl
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    req = Net::HTTP::Post.new(path, header)
    if params.is_a?(String)
      req.body = params
    else
      req.set_form_data(params)
    end
    http.request(req)
  end
end
