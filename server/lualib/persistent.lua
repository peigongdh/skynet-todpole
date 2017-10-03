---
--- Created by zhangpei-home.
--- DateTime: 2017/10/3 2:23
---

local skynet = require("skynet")
local logger = require("logger")

local persistent = {}

local persistent_implement

function persistent.save_user_data(userdata)
    return skynet.call(persistent_implement, "lua", "save_user_data", userdata)
end

function persistent.create_user_data(uid, name)
    return skynet.call(persistent_implement, "lua", "create_user_data", uid, name)
end

function persistent.load_user_data(uid)
    return skynet.call(persistent_implement, "lua", "load_user_data", uid)
end

local function start()
    persistent_implement = skynet.uniqueservice("persistent_implement")
end

skynet.init(start)

return persistent
