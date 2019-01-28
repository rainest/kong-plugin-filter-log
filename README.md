# kong-plugin-filter-log

This plugin is similar to the standard Kong HTTP Log plugin, but with the
ability to filter request and response header values.

Two new configuration options, `response_header_filters` and 
`request_header_filters`, are present. These are maps that accept header
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
