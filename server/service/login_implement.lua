---
--- Created by zhangpei-home.
--- DateTime: 2017/9/19 21:44
---

local skynet = require("skynet")
local loginserver_extend = require("loginserver_extend")
local crypt = require("skynet.crypt")
local auth = require("auth")
local logger = require("logger")

-- load config
local host = skynet.getenv("loginserver_host")
local port = skynet.getenv("loginserver_port")
local instance = skynet.getenv("loginserver_slave_instance") or 8

assert(host ~= nil, "loginserver_host must specified in config file")
assert(port ~= nil, "loginserver_port must specified in config file")

local handler = {
    host = host,
    port = tonumber(port),
    multilogin = false,
    name = "login_master",
    instance = tonumber(instance)
}

-- init in CMD.register_gate
-- servername -> address
local gateserver_list = {}

-- init in login_handler
-- uid -> {uid, servername, address}
local onlineuser_list = {}

-- authenticate token and try to get uid
local function authenticate(platform, token)
    local uid

    if auth[platform] then
        local func = auth[platform]
        uid = func(platform, token)

        if not uid then
            logger.error("login_implement", "auth failed", platform, token)
            error(string.format("platform: %s unexpected error verify token: %s", platform, token))
        end
    else
        logger.error("login_implement", "invalid platform", platform)
        error("invalid platform" .. platform)
    end

    return uid
end

-- use for command_handler
local CMD = {}

-- called by gateserver, gateserver register itself to loginserver
function CMD.register_gate(servername, address)
    gateserver_list[servername] = address
end

-- called by gate server
function CMD.logout(uid)
    local user = onlineuser_list[uid]

    if user then
        logger.info("login_implement", "user uid", uid, "logout server", user.servername)

        onlineuser_list[uid] = nil
    end
end

-- register for loginserver

-- verify token and return servername, uid for user
function handler.auth_handler(token)
    -- the token is base64(platform)@base64(platform_token):base64(servername)
    logger.info("login_implement", "login auth token", token)
    local platform, platform_token, servername = token:match("([^@]+)@([^:]+):(.+)")

    platform = crypt.base64decode(platform)
    platform_token = crypt.base64decode(platform_token)
    servername = crypt.base64decode(servername)

    local ok, uid = pcall(authenticate, platform, platform_token)
    if not ok then
        logger.info("login_implement", "authenticate failed, token", token)
        error("authentication failed")
    end

    return servername, uid
end

-- notify gateserver to login this user
function handler.login_handler(servername, uid, secret)
    if not gateserver_list[servername] then
        logger.error("login_implement", "user", "uid", "want login to unknown server:", servername)
        error("unknown server")
    end

    local serveraddr = gateserver_list[servername]
    local last = onlineuser_list[uid]

    -- kick repeat login user
    if last then
        logger.warn("login_implement", "user", uid, "is already online, notify gateserver to kick this user")
        skynet.call(last.address, "lua", "kick", uid)
    end

    -- we disable multilogin so that login_handler should not called twice
    if last then
        error(string.format("user %d is already online", uid))
    end

    -- notify gateserver to login this user
    skynet.call(serveraddr, "lua", "login", uid, secret)

    onlineuser_list[uid] = {
        uid = uid,
        servername = servername,
        address = serveraddr
    }

    return uid
end

function handler.command_handler(command, ...)
    local f = assert(CMD[command])
    return f(...)
end

-- end for loginserver register

loginserver_extend(handler)