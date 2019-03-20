# kong-plugin-filter-log

This plugin is similar to the standard Kong HTTP Log plugin, but with the
ability to filter request and response values.

## Header filtering

Two new configuration options, `response_header_filters` and 
`request_header_filters`, add header-filtering capabilities. These are maps that accept header
name+filter regular expression pairs. For example:

```
$ http post admin.kong.example/plugins name=http-log-filtered config.http_endpoint="http://localhost:8999" \
    config.request_header_filters.X-Example-Request="\w* secret content \w*" \
    config.response_header_filters.X-Example-Response=".*" \
    config.request_header_filters.X-Example-Other-Request="\w*@\w*\.\w*"                 

HTTP/1.1 201 Created
Connection: keep-alive
Content-Type: application/json; charset=utf-8
Date: Sat, 26 Jan 2019 01:07:23 GMT
Server: kong/0.34-1-enterprise-edition
Transfer-Encoding: chunked
Vary: Origin
X-Kong-Admin-Request-ID: 1JPRXcKzrncxvF9AcJO9HRodR54A7yVk

{
    "config": {
        "content_type": "application/json",
        "http_endpoint": "http://localhost:8999",
        "keepalive": 60000,
        "method": "POST",
        "request_header_filters": {
            "X-Example-Other-Request": "\\w*@\\w*\\.\\w*",
            "X-Example-Request": "\\w* secret content \\w*"
        },
        "response_header_filters": {
            "X-Example-Response": ".*"
        },
        "timeout": 10000
    },
    "created_at": 1548464844000,
    "enabled": true,
    "id": "cdeca9f7-cb62-4211-b4f3-00169f910d08",
    "name": "http-log-filtered"
}
```

This configuration adds a phrase filter for `X-Example-Request` in the request
headers, a filter for any content in the `X-Example-Response` response header,
and a filter for email addresses in the `X-Example-Other-Request` request
header (note that the regular expression used to match email addresses is a
simplified example for demonstration only). With this configuration in place,
we can send a test request that includes headers matching those filters:

```
$ http localhost:8000/logme/response-headers?X-Example-Response=whatever X-Example-Request:"this is some secret content ignore it" X-Example-Other-Request:"send mail to admin@example.com please"
HTTP/1.1 200 OK                                                                                                                                                                                                        
Access-Control-Allow-Credentials: true
Access-Control-Allow-Origin: *
Connection: keep-alive
Content-Length: 106
Content-Type: application/json
Date: Sat, 26 Jan 2019 01:14:17 GMT
Server: gunicorn/19.9.0
Via: kong/0.34-1-enterprise-edition
X-Example-Response: whatever
X-Kong-Proxy-Latency: 42
X-Kong-Upstream-Latency: 175

{
    "Content-Length": "106",
    "Content-Type": "application/json",
    "X-Example-Response": "whatever"
}
```

This results in a log entry that has content matching the filter expressions
replaced with `XX REDACTED XX`:

```
{"latencies":{"request":218,"kong":43,"proxy":175},"service":{"host":"httpbin.org","created_at":1545243827,"connect_timeout":60000,"id":"537a12a9-3fcd-4a17-a09d-726eb86e860b","protocol":"http","name":"httpbin","read_timeout":60000,"port":80,"path":"\/","updated_at":1545243827,"retries":5,"write_timeout":60000},"request":{"querystring":{"X-Example-Response":"whatever"},"size":"307","uri":"\/logme\/response-headers?X-Example-Response=whatever","url":"http:\/\/localhost:8000\/logme\/response-headers?X-Example-Response=whatever","headers":{"host":"localhost:8000","x-example-request":"this is somXX REDACTED XXgnore it","accept-encoding":"gzip, deflate","user-agent":"HTTPie\/1.0.2","accept":"*\/*","x-example-other-request":"send mail to XX REDACTED XX please","connection":"keep-alive"},"method":"GET"},"client_ip":"10.0.2.2","api":{},"upstream_uri":"\/response-headers?X-Example-Response=whatever","response":{"headers":{"content-type":"application\/json","date":"Sat, 26 Jan 2019 01:14:17 GMT","connection":"close","access-control-allow-credentials":"true","content-length":"106","x-kong-proxy-latency":"42","server":"gunicorn\/19.9.0","x-kong-upstream-latency":"175","via":"kong\/0.34-1-enterprise-edition","access-control-allow-origin":"*","x-example-response":"XX REDACTED XXXX REDACTED XX"},"status":200,"size":"459"},"route":{"created_at":1545938532,"strip_path":true,"hosts":[],"preserve_host":false,"regex_priority":0,"updated_at":1545938532,"paths":["\/logme"],"service":{"id":"537a12a9-3fcd-4a17-a09d-726eb86e860b"},"methods":[],"protocols":["http","https"],"id":"58d48d2a-acf3-40f6-866b-1376a8e79934"},"started_at":1548465257244}
```

## Body filtering

These plugins add the ability to log the request body and apply filters similar to the above. `body_filters` is an array of regular expression strings, which replace any matching content in the logged body with `XX REDACTED XX`.

There are several tuning options to control how and when the body is logged:

* `log_body` defaults to `false`, which will disable body logging altogether. Setting it to `true` will enable body logging.
* `read_full_body` defaults to `false`, which will not attempt to read bodies larger than `client_body_buffer_size` at all. Setting it to `true` will read all request bodies, including those that have been buffered to disk.
* `truncate_body` defaults to `true`, and truncates the body at either `body_size_limit` or `client_body_buffer_size` from kong.conf.
* `body_size_limit` sets the size (in bytes) of body data that will be logged.

It is *highly* recommended that `read_full_body` is always set to `false`. When set to `true`, reading larger files requires reading from disk, which has serious performance implications within Lua code. Users can expect an order of magnitude increase in latency if this is enabled. It should ideally only be used temporarily with a very specific set of matching criteria (e.g. only for a single route/consumer combo).

If it is necessary to log larger bodies consistently, increasing `client_body_buffer_size` is preferable: it will lead to increased RAM usage, but does not incur disk read performance hits.

Note that `truncate_body` and `body_size_limit` do not have a meaningful effect on the performance hit incurred by disk reads. They do have some impact on redaction performance after, but the time needed for that is typically much smaller than disk read time. In general, their main usage is to limit the amount of data sent to a logging service.
