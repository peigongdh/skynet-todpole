---
--- Created by zhangpei-home.
--- DateTime: 2017/9/20 0:50
---

local gateserver = require "snax.gateserver"

--[[
Protocol:
    first package
    client -> server
        uid@base64(server)#index:base64(hmac)
    server -> client
        404 user not found
        403 index expired
        401 unauthorized
        400 bad request
        200 ok
API:
    server.login(uid, secret)
        update user secret
    server.logout(uid)
        user logout
    server.ip(uid)
        return ip when connection establish or nil
    server.start(conf)
        start server

Supported skynet command:
    login uid secret (used by loginserver)
    logout uid (used by watchdog/agent)
    kick uid

Config for server.start
    handler.login_handler(uid, secret) -> subid : the function when a new user login, alloc a subid for it. (may call by login server)
    handler.logout_handler(uid, subid) : the function when a user logout. (may call by agent)
    handler.request_handler(uid, session, msg) : the function when recv a new request.
    handler.register_handler(source, loginsrv, servername) : called when gate open
    handler.disconnect_handler(uid) : called when a connection disconnected(afk)
]]

local server = {}

-- API

function server.set_login(uid, secret)
end

function server.set_logout(uid)
end

function server.ip(uid)
end

function server.fd(uid)
end

-- end API

function server.start(handler)

    local CMD = {
        login = assert(handler.login_handler),
        logout = assert(handler.logout_handler),
        kick = assert(handler.kick_handler),
    }

    local gateserver_handler = {}

    -- register for gateserver
    function gateserver_handler.connect(fd, ipaddr)
    end

    function gateserver_handler.disconnect(fd)
    end

    function gateserver_handler.error(fd, msg)
    end

    function gateserver_handler.command(cmd, source, ...)
    end

    function gateserver_handler.open(source, conf)
    end

    function gateserver_handler.message(fd, msg, sz)
    end

    function gateserver_handler.warning(fd, size)
    end
    -- end for gateserver register

    return gateserver.start(gateserver_handler)
end

return server