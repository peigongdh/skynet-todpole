---
--- Created by zhangpei-home.
--- DateTime: 2017/10/3 21:07
---

local skynet = require("skynet")
local room_conf = require("room_conf")
local logger = require("logger")

-- room_id -> {members -> [uid -> {agent, userdata}], info -> {room_id, room_name}}
local room_list = {}

-- uid -> room_id
local uid2roomid = {}

-- use for dispatch
local CMD = {}

function CMD.enter_room(room_id, userdata, agent)
    local member = {
        agent = agent,
        userdata = userdata
    }

    local room = room_list[room_id]
    if room then
        room.members[userdata.uid] = member
        room_list[room_id] = room
        uid2roomid[userdata.uid] = room_id

        -- send notify to each member in room
        -- todo

        return {
            result = true
        }
    else
        logger.error("room_implement", "invalid room_id", room_id)
        return {
            result = false
        }
    end
end

function CMD.list_members(uid)
    local room_id = uid2roomid[uid]
    if not room_id then
        return {
            result = false,
            members = nil
        }
    end

    local room = room_list[room_id]
    if room then
        local members = {}
        for uid, v in pairs(room.members) do
            local member = {
                uid = v.userdata.uid,
                name = v.userdata.name,
                exp = v.userdata.exp
            }
            members[#members + 1] = member
        end
        return {
            result = true,
            members = members
        }
    else
        logger.error("room_implement", "invalid room_id", room_id)
        return {
            result = false,
            members = nil
        }
    end
end

local function room_init()
    for _, v in pairs(room_conf) do
        local room = {
            members = {},
            info = {
                id = v.id,
                name = v.name
            }
        }
        room_list[v.id] = room
        logger.info("room_implement", "create_room", v.id, v.name)
    end
end

skynet.start(function()
    room_init()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(...)))
    end)
end)
