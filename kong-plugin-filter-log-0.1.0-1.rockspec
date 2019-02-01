package = "kong-plugin-filter-log"
version = "0.1.0-1"

-- TODO: This is the name to set in the Kong configuration `plugins` setting.
-- Here we extract it from the package name.
local pluginName = package:match("^kong%-plugin%-(.+)$")  -- "myPlugin"

supported_platforms = {"linux", "macosx"}
source = {
  url = "https://github.com/rainest/kong-plugin-filter-log.git",
  tag = "0.1.0"
}

description = {
  summary = "Kong Filter Log is a log serializer that can redact strings from logged headers",
  homepage = "https://github.com/rainest/kong-plugin-filter-log",
  license = "All rights reserved"
}

dependencies = {
}

build = {
  type = "builtin",
  modules = {
    -- TODO: add any additional files that the plugin consists of
    ["kong.plugins.file-log-filtered.handler"] = "kong/plugins/file-log-filtered/handler.lua",
    ["kong.plugins.file-log-filtered.schema"] = "kong/plugins/file-log-filtered/schema.lua",
    ["kong.plugins.http-log-filtered.handler"] = "kong/plugins/http-log-filtered/handler.lua",
    ["kong.plugins.http-log-filtered.schema"] = "kong/plugins/http-log-filtered/schema.lua",
    ["kong.plugins.log-serializers.filtered"] = "kong/plugins/log-serializers/filtered.lua",
  }
}