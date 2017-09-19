---
--- Created by zhangpei-home.
--- DateTime: 2017/9/19 21:44
---

local login = require("loginserver")

local handler = {
    host = '',
    port = '',
    multilogin = false,
    name = 'login_master',
    instance = 0
}

local CMD = {}


-- register for loginserver

function handler.auth_handler(token)
    -- the token is base64(user)@base64(server):base64(password)
end

function handler.login_handler(server, uid, secret)

end

function handler.command_handler(command, ...)
    local f = assert(CMD[command])
    return f(...)
end

-- end for loginserver register

login(handler)