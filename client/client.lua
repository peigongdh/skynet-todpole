---
--- Created by zhangpei-home.
--- DateTime: 2017/9/24 21:17
---

if _VERSION ~= "Lua 5.3" then
    error "Use lua 5.3"
end

local root = "../../../"

package.cpath = root .. "skynet/luaclib/?.so;" ..
root .. "server/luaclib/?.so"
package.path = root .. "skynet/lualib/?.lua;" ..
root .. "client/?.lua;" ..
root .. "config/?.lua;" ..
root .. "shared_lib/?.lua"

local socket = require("client.socket")
local clientsocket = require("clientsocket")
local protocol = require("protocol")
local sproto = require("sproto")
local string_utils = require("string_utils")

local host = sproto.new(protocol.s2c):host("package")
local request = host:attach(sproto.new(protocol.c2s))

local loginserver_host
local loginserver_port
local gateserver_host
local gateserver_port
local username
local password

local REQ_FROM_SERVER = {}
local RESP_FROM_SERVER = {}

-- increment index when send_request
local session = 0

-- session -> command name
local session_map = {}

-- use for gate server login
local handshake_index = 1

local function send_request(name, args)
    session = session + 1
    session_map[session] = name
    local str = request(name, args, session)

    clientsocket.send_package(str)
end

local function handle_package(t, ...)
    local arr = { ... }
    if t == "REQUEST" then
        local name = arr[1]
        local args = arr[2]
        assert(REQ_FROM_SERVER[name], "no REQ_FROM_SERVER handler found for: " .. name)
        local f = REQ_FROM_SERVER[name]
        f(args)
    elseif t == "RESPONSE" then
        local s = arr[1]
        local args = arr[2]

        local name = session_map[s]
        if name then
            session_map[s] = nil
            assert(RESP_FROM_SERVER[name], "no RESP_FROM_SERVER handler found for: " .. name)
            local f = RESP_FROM_SERVER[name]
            f(args)
        end
    end
end

local function dispatch_package()
    while true do
        local v = clientsocket.read_package()
        if not v then
            break
        end

        handle_package(host:dispatch(v))
    end
end

function RESP_FROM_SERVER.enter_room(args)
    local result = args.result
    if result then
        print("enter room success")
    else
        print("enter room failed")
    end
end

function RESP_FROM_SERVER.list_rooms(args)
    local room_infos = args.room_infos
    for _, room_info in pairs(room_infos) do
        print(room_info.id .. "  " .. room_info.name)
    end
end

function RESP_FROM_SERVER.list_members(args)
    local members = args.members
    for _, member in pairs(members) do
        print(member.uid .. "  " .. member.name .. "  " .. member.exp)
    end
end

function REQ_FROM_SERVER.enter_room_message(args)
    local user_info = args.user_info
    local room_id = args.room_id
    print(user_info.uid .. "  " .. user_info.name .. "  " .. user_info.exp .. " enter room " .. room_id)
end

local function mainloop(loginserver_host, loginserver_port, gateserver_host, gateserver_port, username, password)
    clientsocket.set_loginserver(loginserver_host, loginserver_port)
    clientsocket.set_gateserver(gateserver_host, gateserver_port)
    clientsocket.set_credential("gateserver1", username, password)

    local servername
    local secret
    local uid

    -- auth with login server
    print("try to login with login server")
    local ok, result = pcall(clientsocket.contact_loginserver)
    if not ok or not result or not result.ok then
        print("connect to login server failed" .. (result or ""))
        os.exit()
    else
        servername = result.servername
        uid = result.uid
        secret = result.secret
    end

    -- auth with gate srever
    local ok, result = pcall(clientsocket.contact_gateserver, servername, uid, handshake_index, secret)
    if not ok or not result then
        print("auth with gate server failed")
        os.exist()
    end

    -- login finish
    print("login finish")
    while true do
        dispatch_package()
        local stdin = socket.readstdin()
        if stdin then
            local arr = string_utils.split_string(stdin)
            local cmd = arr[1]

            if cmd == "enter_room" then
                local room_id = arr[2]
                if not room_id then
                    print("usage: enter_room room_id")
                else
                    room_id = tonumber(room_id)
                    send_request("enter_room", {
                        room_id = room_id
                    })
                end
            elseif cmd == "list_rooms" then
                send_request("list_rooms", {})
            elseif cmd == "list_members" then
                send_request("list_members", {})
            elseif cmd == "logout" then
                send_request("logout", {})
            end
        else
            socket.usleep(100)
        end
    end

end

local args_len = #arg

if args_len == 6 then
    loginserver_host = arg[1]
    loginserver_port = tonumber(arg[2])
    gateserver_host = arg[3]
    gateserver_port = tonumber(arg[4])
    username = arg[5]
    password = arg[6]
else
    print("usage:lua main.lua loginserver_host loginserver_port gateserver_host gateserver_port username password")
    os.exit()
end

mainloop(loginserver_host, loginserver_port, gateserver_host, gateserver_port, username, password)
