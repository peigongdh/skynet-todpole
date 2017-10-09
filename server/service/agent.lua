---
--- Created by zhangpei-home.
--- DateTime: 2017/9/24 3:11
---

local skynet = require("skynet")
local socket = require("socket")
local persistent = require("persistent")
local sproto = require("sproto")
local sprotoloader = require("sprotoloader")
local string_utils = require("string_utils")
local logger = require("logger")
local room = require("room")
local statelogging = require("statelogging")

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
local agent_session_expire = tonumber(skynet.getenv("agent_session_expire")) or 3

-- use for handle client request
local REQUEST = {}

function REQUEST.logout(args)
    statelogging.log_user_logout( agentstate.userdata.uid, agentstate.ip)
    skynet.call(watchdog, "lua", "logout", agentstate.userdata.uid)
end

function REQUEST.list_rooms(args)
    local reponse = room.list_rooms()
    return reponse
end

function REQUEST.enter_room(args)
    assert(args.room_id)
    local room_id = args.room_id
    local response = room.enter_room(room_id, agentstate.userdata, skynet.self())
    return response
end

function REQUEST.list_members()
    assert(agentstate.userdata.uid)
    local uid = agentstate.userdata.uid
    local response = room.list_members(uid)
    return response
end

-- do not clear userdata here
local function clear_agentstate()
    agentstate.fd = nil
    agentstate.ip = nil
    agentstate.afk = true
    agentstate.last_active = 0
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
    local userdata = persistent.load_user_data(uid)
    if userdata then
        logger.debug("agent", "load user data success", string_utils.dump(userdata))
        agentstate.userdata = userdata
        return true
    else
        logger.debug("agent", "load user data failed, try craete user data, uid", uid)
        userdata = persistent.create_user_data(uid, "GUEST-" .. uid)
        if userdata then
            logger.debug("agent", "craete user data success", string_utils.dump(userdata))
            agentstate.userdata = userdata
            return true
        else
            logger.error("agent", "craete user data failed, uid", uid)
            return false
        end
    end
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
function CMD.persistent()
    persistent.save_user_data(agentstate.userdata)
end

-- called by watchdog, last step to reset agent
function CMD.recycle()
    clear_agentstate()
    agentstate.userdata = {}
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