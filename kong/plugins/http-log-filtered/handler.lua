local filtered_serializer = require "kong.plugins.log-serializers.filtered"
local singletons =  require "kong.singletons"
local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local url = require "socket.url"

local string_format = string.format
local cjson_encode = cjson.encode

local HttpLogFilteredHandler = BasePlugin:extend()

HttpLogFilteredHandler.PRIORITY = 12
HttpLogFilteredHandler.VERSION = "0.1.0"

local HTTP = "http"
local HTTPS = "https"

-- Generates the raw http message.
-- @param `method` http method to be used to send data
-- @param `content_type` the type to set in the header
-- @param `parsed_url` contains the host details
-- @param `body`  Body of the message as a string (must be encoded according to the `content_type` parameter)
-- @return raw http message
local function generate_post_payload(method, content_type, parsed_url, body)
  local url
  if parsed_url.query then
    url = parsed_url.path .. "?" .. parsed_url.query
  else
    url = parsed_url.path
  end
  local headers = string_format(
    "%s %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\nContent-Type: %s\r\nContent-Length: %s\r\n",
    method:upper(), url, parsed_url.host, content_type, #body)

  if parsed_url.userinfo then
    local auth_header = string_format(
      "Authorization: Basic %s\r\n",
      ngx.encode_base64(parsed_url.userinfo)
    )
    headers = headers .. auth_header
  end

  return string_format("%s\r\n%s", headers, body)
end

-- Parse host url.
-- @param `url` host url
-- @return `parsed_url` a table with host details like domain name, port, path etc
local function parse_url(host_url)
  local parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == HTTP then
      parsed_url.port = 80
     elseif parsed_url.scheme == HTTPS then
      parsed_url.port = 443
     end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end
  return parsed_url
end

-- Convert NGINX-style byte notation to raw byte count
-- @param `bytestring` NGINX-style bytestring
local function calculate_bytes(bytestring)
  local conversions = {k = 2^10, m = 2^20, g = 2^30}
  local suffix = string.sub(bytestring, -1)
  local count = tonumber(string.sub(bytestring, 1, -2))
  return count * conversions[suffix]
end

-- Make the request body always available for later
-- @param `conf` plugin configuration table
local function access(conf)
  local body
  -- there does not appear to be a way to retrieve body length alone,
  -- only body + headers. Content-Length is not reliable. As such,
  -- this always attempts to read the body
  -- future work: limiters to prevent this from DoSing nginx by
  -- effectively circumventing the request size buffer

  -- depending on preference, one of these may be a better alternative
  -- for now, simplest limit is to cut off at the standard buffer limit
  -- local length = ngx.var.content_length
  -- local bytes = ngx.var.bytes_received

  local limit = calculate_bytes(singletons.configuration.client_body_buffer_size)

  if conf.log_body then
    ngx.req.read_body()
    body = ngx.req.get_body_data()
    local body_filepath = ngx.req.get_body_file()
    if not body and body_filepath then
      local file = io.open(body_filepath, "rb")
      if conf.limit_body_size then
        body = file:read(limit)
      else
        body = file:read("*all")
      end
      file:close()
    end
  end

  ngx.ctx.request_body = body
end


-- Log to a Http end point.
-- This basically is structured as a timer callback.
-- @param `premature` see openresty ngx.timer.at function
-- @param `conf` plugin configuration table, holds http endpoint details
-- @param `body` raw http body to be logged
-- @param `name` the plugin name (used for logging purposes in case of errors etc.)
local function log(premature, conf, body, name)
  if premature then
    return
  end
  name = "[" .. name .. "] "

  local ok, err
  local parsed_url = parse_url(conf.http_endpoint)
  local host = parsed_url.host
  local port = tonumber(parsed_url.port)

  local sock = ngx.socket.tcp()
  sock:settimeout(conf.timeout)

  ok, err = sock:connect(host, port)
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  if parsed_url.scheme == HTTPS then
    local _, err = sock:sslhandshake(true, host, false)
    if err then
      ngx.log(ngx.ERR, name .. "failed to do SSL handshake with " .. host .. ":" .. tostring(port) .. ": ", err)
    end
  end

  ok, err = sock:send(generate_post_payload(conf.method, conf.content_type, parsed_url, body))
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to send data to " .. host .. ":" .. tostring(port) .. ": ", err)
  end

  ok, err = sock:setkeepalive(conf.keepalive)
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to keepalive to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end
end

-- Only provide `name` when deriving from this class. Not when initializing an instance.
function HttpLogFilteredHandler:new(name)
  HttpLogFilteredHandler.super.new(self, name or "http-log-filtered")
end

-- serializes context data into an html message body.
-- @param `ngx` The context table for the request being logged
-- @param `conf` plugin configuration table, holds http endpoint details
-- @return html body as string
function HttpLogFilteredHandler:serialize(ngx, conf)
  return cjson_encode(filtered_serializer.serialize(ngx, conf))
end

function HttpLogFilteredHandler:access(conf)
  HttpLogFilteredHandler.super.access(self)
  access(conf)
end

function HttpLogFilteredHandler:log(conf)
  HttpLogFilteredHandler.super.log(self)

  local ok, err = ngx.timer.at(0, log, conf, self:serialize(ngx, conf), self._name)
  if not ok then
    ngx.log(ngx.ERR, "[" .. self._name .. "] failed to create timer: ", err)
  end
end

return HttpLogFilteredHandler
