---
--- Created by zhangpei-home.
--- DateTime: 2017/9/25 21:31
---

local skynet = require("skynet")
local httpc = require("http.httpc")
local logger = require("logger")

local auth_host = skynet.getenv("auth_host")
local auth_url = skynet.getenv("auth_url")

local auth = {}

function auth.skynet_todpole(platform, token)
    local uid = nil

    local recvheader ={}
    local postfields = {
        platform = platform,
        token = token
    }

    local ok, status, body = pcall(httpc.post, auth_host, auth_url, postfields, recvheader)
    logger.debug("auth", "auth result", ok, status, body)

    if ok then
        uid = body
    end

    return uid
end

return auth