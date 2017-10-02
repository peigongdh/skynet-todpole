---
--- Created by zhangpei-home.
--- DateTime: 2017/9/24 3:11
---

local skynet = require("skynet")
local socket = require("socket")
local sproto = require("sproto")
local sprotoloader = require("sprotoloader")
local logger = require("logger")

-- use for sproto, init when CMD.start
local host

-- use for sproto, init when CMD.start
local make_request

-- init in CMD.start
local watchdog

-- agent related data
local agentstate = {
    fd = nil,
    ip = nil,
    afk = false,
    last_active = skynet.time(),
    userdata = {}
}

-- use for check idle
local agent_session_expire = skynet.getenv("agent_session_expire") or 3

-- use for handle client request
local REQUEST = {}

function REQUEST.logout(args)
    skynet.call(watchdog, "lua", "logout", agentstate.userdata.uid)
end



local function clear_agentstate()
    agentstate.fd = nil
    agentstate.ip = nil
    agentstate.afk = false
    agentstate.last_active = 0
    agentstate.userdata = {}
end

-- user for skynet dispatch
local CMD = {}

-- called by watchdog when alloc agent
function CMD.start(conf)
    watchdog = conf.watchdog

    -- init sproto and use dispatch
    host = sprotoloader.load(1):host("package")
    make_request = host:attach(sprotoloader.load(2))
end

-- called by watchdog when alloc agent
function CMD.load_user_data(uid)
    local userdata = {
        uid = tonumber(uid)
    }
    agentstate.userdata = userdata
    return true
end

-- called by watchdog when auth completed
function CMD.associate_fd_ip(fd, ip)
    logger.info("agent", "associate fd & ip", fd, ip)

    local s, e = string.find(ip, ":")
    if s and e then
        ip = string.sub(ip, 1, s - 1)
    end

    agentstate.fd = fd
    agentstate.ip = ip
    agentstate.afk = false
end

-- called by watchdog
function CMD.logout()
    clear_agentstate()
    return true
end

-- called by watchdog
function CMD.check_idle()
    local now = skynet.time()
    local timepassed = now - agentstate.last_active
    if timepassed >= agent_session_expire then
        skynet.call(watchdog, "lua", "recycle_agent", agentstate.userdata.uid)
    end
end

-- called by watchdog
function CMD.persisent()
    logger.debug("agent", "persisent")
    -- todo
end

-- called by watchdog to logout user
function CMD.recycle()
    logger.debug("agent", "recycle")
    clear_agentstate()
end



local function handle_client_request(name, args, response)
    local f = assert(REQUEST[name])
    local result = f(args)

    if response then
        return response(result)
    end
end

local function send_package(pack)
    if not agentstate.fd then
        return
    end

    local package = string.pack(">s2", pack)
    socket.write(agentstate.fd, package)
end

-- message from gate server, through unpack and dispatch, handle by REQUEST
skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = function(msg, sz)
        return host:dispatch(msg, sz)
    end,
    dispatch = function(_, _, type, ...)
        if type == "REQUEST" then
            local ok, result = pcall(handle_client_request, ...)
            if ok then
                if result then
                    send_package(result)
                end
            else
                logger.error("agent", "error when handle request", result)
            end
        else
            -- type == RESPONSE
            assert(type == "RESPONSE")
            error "This example doesn't support request client"
        end
        -- keep_alive()
    end,
}

skynet.start(function()
    skynet.dispatch("lua", function(_, _, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)
end)