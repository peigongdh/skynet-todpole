---
--- Created by zhangpei-home.
--- DateTime: 2017/10/4 21:45
---

local skynet = require("skynet")

local statelogging_implement

local statelogging = {}

function statelogging.log_user_login(uid, ip)
    return skynet.call(statelogging_implement, "lua", "log_user_login", uid, ip)
end

function statelogging.log_user_logout(uid, ip)
    return skynet.call(statelogging_implement, "lua", "log_user_logout", uid, ip)
end

local function start()
    statelogging_implement = skynet.uniqueservice("statelogging_implement")
end

skynet.init(start)

return statelogging
