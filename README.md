# Puma based HTTP(S) plugin for Fluentd

HTTP input plugin based on [Puma](http://puma.io/).
Almost behaviours are same as in_http plugin. Refer to [in_http official document](http://docs.fluentd.org/articles/in_http).

This input plugin supports HTTPS mode.

## Installation

Use RubyGems:

    fluent-gem install fluent-plugin-http-puma

## Configuration

    <source>
      type http_puma

      # optional parameters(same as in_http)
      bind 127.0.0.1
      port 9890
      backlog 2048
      format json

      # optional Puma parameters
      min_threads 0
      max_threads 4
      use_ssl
      ssl_keys ["/path/to/key", "/path/to/cert"]
    </source>

### HTTPS mode

Use `use_ssl` and `ssl_keys`.

    <source>
      use_ssl
      ssl_keys ["/path/to/key", "/path/to/cert"] # ssl_keys is required when use_ssl is true
    </source>

`ssl_keys` parameter is json array which has two elements, 1st is for key file, 2nd is for cert file.
