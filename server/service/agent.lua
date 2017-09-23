---
--- Created by zhangpei-home.
--- DateTime: 2017/9/24 3:11
---

local skynet = require("skynet")

-- init in CMD.start
local watchdog

-- agent related data
local agentstate = {
    fd = nil,
    ip = nil,
    last_active = skynet.time(),
    userdata = {}
}

-- user for skynet dispatch
local CMD = {}

-- called by watchdog when alloc agent
function CMD.start(conf)
    watchdog = conf.watchdog
end

-- called by watchdog when alloc agent
function CMD.load_user_data(uid)
    agentstate.userdata.uid = uid
    return true
end

function CMD.logout()
    skynet.call(watchdog, "lua", "logout", agentstate.userdata.uid)
end

-- called by watchdog
function CMD.clear()
    agentstate.fd = nil
    agentstate.ip = nil
    agentstate.userdata = nil

    return true
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)
end)