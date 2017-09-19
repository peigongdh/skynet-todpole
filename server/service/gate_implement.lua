---
--- Created by zhangpei-home.
--- DateTime: 2017/9/20 1:10
---

local gateserver_extend = require("gateserver_extend")

-- register for gateserver_extend

local handler = {}

-- notify from login server
function handler.login_handler(uid, secret)

end

-- the function when a user logout. (may call by agent)
function handler.logout_handler(uid, subid)

end

--
function handler.kick_handler(uid)

end

--
function handler.authed_handler(uid, fd, ip)

end

-- the function when recv a new request.
function handler.request_handler(uid, session, msg)

end

-- called when gate open
function handler.register_handler(source, loginsrv, servername)

end

-- called when a connection disconnected(afk)
function handler.disconnect_handler(uid)

end

--
function handler.command_handler()

end

-- end for gateserver_extend register

gateserver_extend.start(handler)