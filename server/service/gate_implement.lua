---
--- Created by zhangpei-home.
--- DateTime: 2017/9/20 1:10
---

local skynet = require("skynet")
local gateserver_extend = require("gateserver_extend")
local string_utils = require("string_utils")
local logger = require("logger")

-- init in handler.register_handler
local watchdog
local loginservice
local servername

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT
}

-- uid -> {agent, uid}
local users = {}

-- use for command_handler
local CMD = {}

-- register for gateserver_extend
local handler = {}

-- called by login server after login complete
function handler.login_handler(uid, secret)
    if users[uid] then
        error(string.format("%s is already login", uid))
    end

    local agent = skynet.call(watchdog, "lua", "alloc_agent", uid)
    if not agent then
        logger.error("gate_implement", uid, "authed success, but login failed")
        error("init agent failed")
    end

    local user = {
        agent = agent,
        uid = uid
    }
    users[uid] = user

    gateserver_extend.set_login(uid, secret)
    return true
end

-- called by watchdog when user logout
function handler.logout_handler(uid)
    local user = users[uid]
    if user then
        gateserver_extend.set_logout(uid)
        users[uid] = nil
        logger.info("gate_implement", "user uid", uid, "logout server")

        -- inform login server to logout
        skynet.call(loginservice, "lua", "logout", uid)
    end
end

-- called by loginserver when user login repeat
function handler.kick_handler(uid)
    local user = users[uid]
    if user then
        skynet.call(watchdog, "lua", "logout", uid)
        logger.info("gate_implement", "kick user", uid)
    else
        logger.warn("gate_implement", "kick failed, user not exist", uid)
    end
end

-- auth completed, notify watchdog
function handler.authed_handler(uid, fd, ip)
    local user = users[uid]
    local agent = user.agent
    if agent then
        skynet.call(watchdog, "lua", "client_auth_completed", agent, fd, ip)
    else
        logger.error("gated", "fd", fd, "auth success but not found associated agent, ip", ip)
    end
end

-- the function when recv a new request.
function handler.request_handler(uid, message)
    local user = users[uid]
    local agent = user.agent
    if agent then
        skynet.redirect(agent, 0, "client", 0, message)
    else
        -- todo
    end
end

-- called when gate open, register self to loginserver
function handler.register_handler(source, loginsrv, name)
    watchdog = source
    loginservice = loginsrv
    servername = name

    skynet.call(loginservice, "lua", "register_gate", servername, skynet.self())
end

-- called when a connection disconnected(afk)
function handler.disconnect_handler(uid)
    local user = users[uid]
    local agent = user.agent

    logger.info("gate_implement", "disconnect_handler", uid)
    skynet.call(watchdog, "lua", "afk", agent, uid)
end

--
function handler.command_handler(cmd, source, ...)
    local f = assert(CMD[cmd])
    return f(source, ...)
end

-- end for gateserver_extend register

gateserver_extend.start(handler)