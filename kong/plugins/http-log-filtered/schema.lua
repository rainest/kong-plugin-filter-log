return {
  fields = {
    http_endpoint = { required = true, type = "url" },
    method = { default = "POST", enum = { "POST", "PUT", "PATCH" } },
    content_type = { default = "application/json", enum = { "application/json" } },
    timeout = { default = 10000, type = "number" },
    request_header_filters = { type = "map",
        keys = { type = "string" },
        values = { type = "string" }
    },
    response_header_filters = { type = "map",
        keys = { type = "string" },
        values = { type = "string" }
    },
    body_filters = { type = "array", elements = { type = "string" } },
    log_body = { type = "boolean", default = false },
    truncate_body = { type = "boolean", default = true },
    read_full_body = { type = "boolean", default = false },
    body_size_limit = { type = "number" },
    keepalive = { default = 60000, type = "number" }
  }
}
