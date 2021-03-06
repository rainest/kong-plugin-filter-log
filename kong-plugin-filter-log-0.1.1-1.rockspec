package = "kong-plugin-filter-log"
version = "0.1.1-1"

supported_platforms = {"linux", "macosx"}
source = {
  url = "git+https://github.com/rainest/kong-plugin-filter-log.git",
  tag = "0.1.1"
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
    ["kong.plugins.file-log-filtered.handler"] = "kong/plugins/file-log-filtered/handler.lua",
    ["kong.plugins.file-log-filtered.schema"] = "kong/plugins/file-log-filtered/schema.lua",
    ["kong.plugins.http-log-filtered.handler"] = "kong/plugins/http-log-filtered/handler.lua",
    ["kong.plugins.http-log-filtered.schema"] = "kong/plugins/http-log-filtered/schema.lua",
    ["kong.plugins.log-serializers.filtered"] = "kong/plugins/log-serializers/filtered.lua",
  }
}
