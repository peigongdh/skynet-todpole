---
--- Created by zhangpei-home.
--- DateTime: 2017/9/19 21:44
---

local skynet = require("skynet")
local login = require("loginserver")
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
    -- the token is base64(user)@base64(server):base64(password)
    logger.info("login_implement", "login auth token", token)
    local user, servername, password = token:match("([^@]+)@([^:]+):(.+)")
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

login(handler)