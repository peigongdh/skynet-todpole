---
--- Created by zhangpei-home.
--- DateTime: 2017/9/20 0:50
---

local skynet = require("skynet")
local gateserver = require("snax.gateserver")
-- can not use socket
local socketdriver = require("socketdriver")
local netpack = require("skynet.netpack")
local crypt = require("crypt")
local logger = require("logger")

local base64encode = crypt.base64encode
local base64decode = crypt.base64decode
local hmac_hash = crypt.hmac_hash

--[[
Protocol:
    first package
    client -> server
        uid@base64(server)#index:base64(hmac)
    server -> client

    XXX ErrorCode
        404 user not found
        403 index expired
        401 unauthorized
        400 bad request
        200 ok
API:
    server.set_login(uid, secret)
        update user secret
    server.set_logout(uid)
        user logout
    server.get_ip(uid)
        return ip when connection establish or nil
    server.get_fd(uid)
        return fd when connection establish or nil
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

--skynet.register_protocol {
--    name = "client",
--    id = skynet.PTYPE_CLIENT
--}

local server = {}

-- uid -> user {uid, secret, handshake_index, fd, ip}
local user_online = {}

-- fd -> ip
local handshake = {}

-- fd -> user {uid, secret, handshake_index, fd, ip}
local connection = {}

-- API

function server.set_login(uid, secret)
    assert(user_online[uid] == nil)
    user_online[uid] = {
        uid = uid,
        secret = secret,
        --handshake sequence
        handshake_index = 0,
        fd = nil,
        ip = nil
    }
end

function server.set_logout(uid)
    local user = user_online[uid]
    user_online[uid] = nil
    if user.fd then
        -- close fd
        gateserver.closeclient(user.fd)
        connection[user.fd] = nil
    end
end

function server.get_ip(uid)
    local user = user_online[uid]
    if user and user.ip then
        return user.ip
    end
end

function server.get_fd(uid)
    local user = user_online[uid]
    if user and user.fd then
        return user.fd
    end
end

-- end API

function server.start(handler)

    local CMD = {
        login = assert(handler.login_handler),
        logout = assert(handler.logout_handler),
        kick = assert(handler.kick_handler),
        -- continue register command function here
        othercmd = assert(handler.command_handler)
    }

    local function doauth(fd, message, ipaddr)
        -- format uid@base64(server)#index:base64(hmac)
        local uid, servername, index, hmac = string.match(message, "([^@]*)@([^#]*)#([^:]*):(.*)")
        hmac = base64decode(hmac)

        local user = user_online[tonumber(uid)]
        if user == nil then
            return "404 User Not Found"
        end

        local idx = assert(tonumber(index))
        if idx <= user.handshake_index then
            return "403 Index Expired"
        end

        local text = string.format("%s@%s#%d", uid, servername, index)
        -- equivalent to crypt.hmac64(crypt.hashkey(text), user.secret)
        local v = hmac_hash(user.secret, text)

        if v ~= hmac then
            return "401 Unauthorized"
        end

        user.handshake_index = idx
        user.fd = fd
        user.ip = ipaddr

        connection[fd] = user
    end

    local function auth(fd, ipaddr, message)
        local response
        local ok, result = pcall(doauth, fd, message, ipaddr)
        if not ok then
            logger.warn("gateserver_extend", result, message)
            -- handshake fail
            response = "400 Bad Request"
        end

        if result == nil then
            response = "200 OK"
        end

        -- notify client handshake result
        socketdriver.send(fd, netpack.pack(response))

        if result == nil then
            -- auth success
            local user = connection[fd]
            if user then
                handler.auth_handler(user.uid, user.fd, user.ip)
            else
                logger.error("gateserver_extend", "auth verify success but no user found for fd", fd)
            end
        else
            -- auth failed
            gateserver.closeclient(fd)
        end
    end

    -- register for gateserver
    local gateserver_handler = {}

    function gateserver_handler.connect(fd, ipaddr)
        logger.info("gateserver_extend", "new connection", fd, ipaddr)
        handshake[fd] = ipaddr
        gateserver.openclient(fd)
    end

    function gateserver_handler.disconnect(fd)
        handshake[fd] = nil
        local user = connection[fd]
        if user then
            connection[fd] = nil
            handler.disconnect_handler(user.uid)
        end
    end

    function gateserver_handler.error(fd, msg)
        logger.error("gateserver_extend", "error happened, close connection", fd, msg)
        gateserver_handler.disconnect(fd)
    end

    function gateserver_handler.command(cmd, source, ...)
        local f
        local result
        if CMD[cmd] then
            f = CMD[cmd]
            result = f(source, ...)
        else
            f = CMD.othercmd
            result = f(cmd, source, ...)
        end
        return result
    end

    -- called by watchdog
    function gateserver_handler.open(watchdog, gateconf)
        local servername = assert(gateconf.servername)
        local loginservice = gateconf.loginservice

        -- register self to loginserver
        handler.register_handler(watchdog, loginservice, servername)
    end

    function gateserver_handler.message(fd, msg, sz)
        logger.debug("gatewayserver", fd, msg)
        local ipaddr = handshake[fd]
        local message = netpack.toString(msg, sz)
        if ipaddr then
            handshake[fd] = nil
            auth(fd, ipaddr, message)
        else
            local user = assert(connection[fd], "invalid fd")
            handler.request_handler(user.uid, message)
        end
    end

    function gateserver_handler.warning(fd, size)
        -- callback when fd send socket data exceeded 1MB
        logger.warn("gateserver_extend", "socket data size total exceeded fd", fd, "size", size)
    end
    -- end for gateserver register

    return gateserver.start(gateserver_handler)
end

return server