# Puma based HTTP(S) plugin for Fluentd

HTTP input plugin based on [Puma](http://puma.io/).
Almost behaviours are same as in_http plugin. Refer to [in_http official document](http://docs.fluentd.org/articles/in_http).

This input plugin supports HTTPS mode.
If you can't use Nginx or other proxy server on front of Fluentd for HTTPS, this plugin is useful.

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
      type http_puma

      use_ssl
      ssl_keys ["/path/to/key", "/path/to/cert"] # ssl_keys is required when use_ssl is true
    </source>

`ssl_keys` parameter is json array which has two elements, 1st is for key file, 2nd is for cert file.

## Performance

Tested on my MBP, CPU: 2.6 GHz Intel Core i7 and Memory: 16GB 1600MHz DDR3. Sending small json with `application/json` content-type.

- in_http

Ave 2400 events/sec.

    2014-07-20 19:02:30 +0900 [info]: plugin:out_flowcounter_simple count:2318      indicator:num   unit:second
    2014-07-20 19:02:31 +0900 [info]: plugin:out_flowcounter_simple count:2420      indicator:num   unit:second
    2014-07-20 19:02:32 +0900 [info]: plugin:out_flowcounter_simple count:2383      indicator:num   unit:second
    2014-07-20 19:02:33 +0900 [info]: plugin:out_flowcounter_simple count:2399      indicator:num   unit:second
    2014-07-20 19:02:34 +0900 [info]: plugin:out_flowcounter_simple count:2382      indicator:num   unit:second

- in_http_puma

Ave 2500 events/sec.

    2014-07-20 19:01:12 +0900 [info]: plugin:out_flowcounter_simple count:2472      indicator:num   unit:second
    2014-07-20 19:01:13 +0900 [info]: plugin:out_flowcounter_simple count:2550      indicator:num   unit:second
    2014-07-20 19:01:14 +0900 [info]: plugin:out_flowcounter_simple count:2294      indicator:num   unit:second
    2014-07-20 19:01:15 +0900 [info]: plugin:out_flowcounter_simple count:2537      indicator:num   unit:second
    2014-07-20 19:01:16 +0900 [info]: plugin:out_flowcounter_simple count:2538      indicator:num   unit:second

- in_http_puma with VERIFY_PEER client

Ave 320 events/sec.

    2014-07-20 19:05:18 +0900 [info]: plugin:out_flowcounter_simple count:329       indicator:num   unit:second
    2014-07-20 19:05:19 +0900 [info]: plugin:out_flowcounter_simple count:327       indicator:num   unit:second
    2014-07-20 19:05:20 +0900 [info]: plugin:out_flowcounter_simple count:327       indicator:num   unit:second
    2014-07-20 19:05:21 +0900 [info]: plugin:out_flowcounter_simple count:325       indicator:num   unit:second
    2014-07-20 19:05:22 +0900 [info]: plugin:out_flowcounter_simple count:326       indicator:num   unit:second

- in_http_puma with VERIFY_NONE client

Ave 400 events/sec.

    2014-07-20 19:04:06 +0900 [info]: plugin:out_flowcounter_simple count:406       indicator:num   unit:second
    2014-07-20 19:04:07 +0900 [info]: plugin:out_flowcounter_simple count:365       indicator:num   unit:second
    2014-07-20 19:04:08 +0900 [info]: plugin:out_flowcounter_simple count:400       indicator:num   unit:second
    2014-07-20 19:04:09 +0900 [info]: plugin:out_flowcounter_simple count:399       indicator:num   unit:second
    2014-07-20 19:04:10 +0900 [info]: plugin:out_flowcounter_simple count:400       indicator:num   unit:second
