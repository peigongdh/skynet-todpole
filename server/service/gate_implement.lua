---
--- Created by zhangpei-home.
--- DateTime: 2017/9/20 1:10
---

local skynet = require("skynet")
local gateserver_extend = require("gateserver_extend")
local logger = require("logger")

-- init in handler.register_handler
local watchdog
local loginservice
local servername

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
        logger.error("gate_implement", "uid", "authed success, but login failed")
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
        user[uid] = nil

        -- inform login server to logout
        skynet.call(loginservice, "lua", "logout", uid)
    end
end

-- called by loginserver when user login repeat
function handler.kick_handler(uid)

end

--
function handler.authed_handler(uid, fd, ip)

end

-- the function when recv a new request.
function handler.request_handler(uid, session, msg)

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

end

--
function handler.command_handler(cmd, source, ...)
    local f = assert(CMD[cmd])
    return f(source, ...)
end

-- end for gateserver_extend register

gateserver_extend.start(handler)