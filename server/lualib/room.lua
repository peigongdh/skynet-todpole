---
--- Created by zhangpei-home.
--- DateTime: 2017/10/3 19:28
---

local skynet = require("skynet")

local room_implement

local room = {}

function room.enter_room(room_id, userdata, agent)
    return skynet.call(room_implement, "lua", "enter_room", room_id, userdata, agent)
end

function room.leave_room(uid)
    return skynet.call(room_implement, "lua", "leave_room", uid)
end

function room.list_members(uid)
    return skynet.call(room_implement, "lua", "list_members", uid)
end

function room.list_rooms()
    return skynet.call(room_implement, "lua", "list_rooms")
end

function room.say_public(uid, content)
    return skynet.call(room_implement, "lua", "say_public", uid, content)
end

function room.say_private(from_uid, to_uid, content)
    return skynet.call(room_implement, "lua", "say_private", from_uid, to_uid, content)
end

local function start()
    room_implement = skynet.uniqueservice("room_implement")
end

skynet.init(start)

return room