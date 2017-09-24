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
package.path =  root .. "skynet/lualib/?.lua;" ..
                root .. "server/lualib/?.lua;" ..
                root .. "server/service/?.lua;" ..
                root .. "client/?.lua;" ..
                root .. "configs/?.lua"

local socket = require("client.socket")
local clientsocket = require("clientsocket")
local protocol = require("protocol")
local sproto = require("sproto")

local host = sproto.new(protocol.s2c):host("package")
local request = host:attach(sproto.new(protocol.c2s))

local loginserver_host
local loginserver_port
local gateserver_host
local gateserver_port
local username
local password

local session = 0
local index = 1
local session_map = {}

local function send_request(name, args)
    session = session + 1
    session_map[session] = name
    local str = request(name, args, session)

    clientsocket.send_package(str)
end

local function mainloop(loginserver_host, loginserver_port, gateserver_host, gateserver_port, username, password)
    clientsocket.set_loginserver(loginserver_host, loginserver_port)
    clientsocket.set_gateserver(gateserver_host, gateserver_port)
    clientsocket.set_credential("gateserver1", username, password)

    local servername
    local secret
    local uid

    local ok, result = pcall(clientsocket.contact_loginserver)
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
