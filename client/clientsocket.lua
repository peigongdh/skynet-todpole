---
--- Created by zhangpei-home.
--- DateTime: 2017/9/24 21:59
---

local socket = require("client.socket")
local crypt = require("client.crypt")

local lib = {}

local loginserver_host
local loginserver_port
local gateserver_host
local gateserver_port
local servername
local username
local password

local last = ""
local fd

local function unpack_package(text)
    local size = #text
    if size < 2 then
        return nil, text
    end
    local s = text:byte(1) * 256 + text:byte(2)
    if size < s + 2 then
        return nil, text
    end

    return text:sub(3, 2 + s), text:sub(3 + s)
end

local function recv_package(last)
    local result
    result, last = unpack_package(last)
    if result then
        return result, last
    end
    local r = socket.recv(fd)
    if not r then
        return nil, last
    end
    if r == "" then
        error "Server closed"
    end
    return unpack_package(last .. r)
end

local function blockread_package()
    while true do
        local result
        result, last = recv_package(last)

        if result then
            print("received:" .. result)
            return result
        end

        socket.usleep(100)
    end
end

function lib.read_package()
    local result
    result, last = recv_package(last)

    if result then
        return result
    end
end

function lib.send_package(pack)
    if fd then
        local package = string.pack(">s2", pack)
        socket.send(fd, package)
    end
end

-- related to loginserver_extend.launch_slave
function lib.contact_loginserver()
    local function encode_token(token)
        return string.format("%s@%s:%s",
        crypt.base64encode(token.platform),
        crypt.base64encode(token.username .. "\t" .. token.password),
        crypt.base64encode(token.servername)
        )
    end

    local gateservername
    local uid
    local token = {
        platform = "skynet_todpole",
        servername = servername,
        username = username,
        password = password
    }

    fd = assert(socket.connect(loginserver_host, loginserver_port))
    local challenge = crypt.base64decode(blockread_package())

    local clientkey = crypt.randomkey()
    lib.send_package(crypt.base64encode(crypt.dhexchange(clientkey)))

    local secret = crypt.dhsecret(crypt.base64decode(blockread_package()), clientkey)
    print("negotiated secret is:", crypt.hexencode(secret))

    local hmac = crypt.hmac64(challenge, secret)
    lib.send_package(crypt.base64encode(hmac))

    local token_encoded = crypt.desencode(secret, encode_token(token))
    token_encoded = crypt.base64encode(token_encoded)
    lib.send_package(token_encoded)

    -- result format: code base64(gateservername) uid
    local result = blockread_package()
    local code = tonumber(string.sub(result, 1, 3))

    local response = {}
    if code ~= 200 then
        response.ok = false
    else
        local arr = {}
        for w in string.gmatch(result, "([^%s]+)") do
            arr[#arr + 1] = w
        end
        gateservername = crypt.base64decode(arr[2])
        uid = tonumber(arr[3])

        response.ok = true
        response.servername = gateservername
        response.uid = uid
        response.secret = secret
    end

    socket.close(fd)

    return response
end

-- auth with gate server
function lib.contact_gateserver(servername, uid, handshake_index, secret)
    fd = assert(socket.connect(gateserver_host, gateserver_port))
    local handshake = string.format("%s@%s#%d", uid, crypt.base64encode(servername), handshake_index)
    local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)
    local text = handshake .. ":" .. crypt.base64encode(hmac)
    lib.send_package(text)

    local resp = blockread_package()
    local code = tonumber(string.sub(resp, 1, 3))
    local result = false

    if code == 200 then
        result = true
    end

    return result
end

function lib.set_loginserver(host, port)
    loginserver_host = host
    loginserver_port = port
end

function lib.set_gateserver(host, port)
    gateserver_host = host
    gateserver_port = port
end

function lib.set_credential(arg1, arg2, arg3)
    servername = arg1
    username = arg2
    password = arg3
end

return lib