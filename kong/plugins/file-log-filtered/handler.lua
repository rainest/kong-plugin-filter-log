-- Copyright (C) Kong Inc.
local ffi = require "ffi"
local cjson = require "cjson"
local system_constants = require "lua_system_constants"
local filtered_serializer = require "kong.plugins.log-serializers.filtered"
local singletons =  require "kong.singletons"
local BasePlugin = require "kong.plugins.base_plugin"

local ngx_timer = ngx.timer.at
local O_CREAT = system_constants.O_CREAT()
local O_WRONLY = system_constants.O_WRONLY()
local O_APPEND = system_constants.O_APPEND()
local S_IRUSR = system_constants.S_IRUSR()
local S_IWUSR = system_constants.S_IWUSR()
local S_IRGRP = system_constants.S_IRGRP()
local S_IROTH = system_constants.S_IROTH()

local oflags = bit.bor(O_WRONLY, O_CREAT, O_APPEND)
local mode = bit.bor(S_IRUSR, S_IWUSR, S_IRGRP, S_IROTH)

ffi.cdef[[
int write(int fd, const void * ptr, int numbytes);
]]

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

  local limit = conf.body_size_limit or calculate_bytes(singletons.configuration.client_body_buffer_size)

  if conf.log_body then
    ngx.req.read_body()
    body = ngx.req.get_body_data()
    local body_filepath = ngx.req.get_body_file()
    if not body and body_filepath and conf.read_full_body then
      local file = io.open(body_filepath, "rb")
      if conf.truncate_body then
        body = file:read(limit)
      else
        body = file:read("*all")
      end
      file:close()
    end
  end

  ngx.ctx.request_body = body
end

-- fd tracking utility functions
local file_descriptors = {}

-- Log to a file. Function used as callback from an nginx timer.
-- @param `premature` see OpenResty `ngx.timer.at()`
-- @param `conf`     Configuration table, holds http endpoint details
-- @param `message`  Message to be logged
local function log(premature, conf, message)
  if premature then
    return
  end

  local msg = cjson.encode(message) .. "\n"

  local fd = file_descriptors[conf.path]

  if fd and conf.reopen then
    -- close fd, we do this here, to make sure a previously cached fd also
    -- gets closed upon dynamic changes of the configuration
    ffi.C.close(fd)
    file_descriptors[conf.path] = nil
    fd = nil
  end

  if not fd then
    fd = ffi.C.open(conf.path, oflags, mode)
    if fd < 0 then
      local errno = ffi.errno()
      ngx.log(ngx.ERR, "[file-log] failed to open the file: ", ffi.string(ffi.C.strerror(errno)))
    else
      file_descriptors[conf.path] = fd
    end
  end

  ffi.C.write(fd, msg, #msg)
end

local FileLogFilteredHandler = BasePlugin:extend()

FileLogFilteredHandler.PRIORITY = 9
FileLogFilteredHandler.VERSION = "0.1.0"

function FileLogFilteredHandler:new()
  FileLogFilteredHandler.super.new(self, "file-log")
end

function FileLogFilteredHandler:access(conf)
  FileLogFilteredHandler.super.access(self)
  access(conf)
end

function FileLogFilteredHandler:log(conf)
  FileLogFilteredHandler.super.log(self)
  local message = filtered_serializer.serialize(ngx, conf)

  local ok, err = ngx_timer(0, log, conf, message)
  if not ok then
    ngx.log(ngx.ERR, "[file-log] failed to create timer: ", err)
  end

end

return FileLogFilteredHandler
