local skynet = require "skynet"
local socket = require "socket"
local string = require "string"
local websocket = require "websocket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"

local cjson = require("cjson")
local connection = {}

local handler = {}
function handler.on_open(ws)
    print(string.format("%d::open", ws.id))
    connection[ws.id] = ws
end

function handler.on_message(ws, message)
    print(string.format("%d receive:%s", ws.id, message))
    local messageObj = cjson.decode(message);
    if messageObj.type == "authorize" then
        print(string.format("%d receive:%s", ws.id, message))
    elseif messageObj.type == "update" then
        local sendMessage = {
            type = "update",
            id = ws.id,
            angle = messageObj.angle + 0,
            momentum = messageObj.momentum + 0,
            x = messageObj.x + 0,
            y = messageObj.y + 0,
            life = 1,
            name = "Guest." .. ws.id,
            authorized = false
        }
        sendToAll(sendMessage)
    elseif messageObj.type == "message" then
        local sendMessage = {
            type = "message",
            id = ws.id,
            message = messageObj.message
        }
        sendToAll(sendMessage)
    elseif messageObj.type == "shoot" then
        local sendMessage = {
            type = "shoot",
            id = ws.id,
            x = messageObj.x + 0,
            y = messageObj.y + 0,
            angle = messageObj.angle + 0
        }
        sendToAll(sendMessage)
    end
end

function handler.on_close(ws, code, reason)
    print(string.format("%d close:%s  %s", ws.id, code, reason))
    local sendMessage = {
        type = "closed",
        id = ws.id
    }
    sendToAll(sendMessage)
    connection[ws.id] = nil
end

function welcome(ws)
    local sendMessage = {
        type = "welcome",
        id = ws.id
    }
    ws:send_text(cjson.encode(sendMessage))
end

function sendToAll(sendMessage)
    for k, v in pairs(connection) do
        v:send_text(cjson.encode(sendMessage))
    end
end

local function handle_socket(id)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
    if code then
        if url == "/ws" then
            local ws = websocket.new(id, header, handler)
            welcome(ws)
            ws:start()
        end
    end
end

skynet.start(function()
    local address = "0.0.0.0:8002"
    skynet.error("Listening " .. address)
    local id = assert(socket.listen(address))
    socket.start(id, function(id, addr)
        socket.start(id)
        pcall(handle_socket, id)
    end)
end)
