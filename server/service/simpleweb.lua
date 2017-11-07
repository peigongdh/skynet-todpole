local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local logger = require "logger"

local table = table
local string = string

local mode = ...

if mode == "agent" then

    local function response(id, ...)
        local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
        if not ok then
            -- if err == sockethelper.socket_error , that means socket closed.
            logger.info("simpleweb", string.format("fd = %d, %s", id, err))
        end
    end

    local function read_file(filename)
        -- security problem
        -- todo
        local f = assert(io.open("web" .. filename, "r"))
        local content = f:read("*all")
        f:close()
        return content
    end

    skynet.start(function()
        skynet.dispatch("lua", function(_, _, id)
            socket.start(id)
            -- limit request body size to 8192 (you can pass nil to unlimit)
            local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
            if code then
                if code ~= 200 then
                    response(id, code)
                else
                    local path, query = urllib.parse(url)
                    local response_body = read_file(path)
                    response(id, code, response_body)
                end
            else
                if url == sockethelper.socket_error then
                    skynet.error("socket closed")
                else
                    skynet.error(url)
                end
            end
            socket.close(id)
        end)
    end)

else

    skynet.start(function()
        local simpleweb_agentpool = skynet.getenv("simpleweb_agentpool") or 10
        local agent = {}
        for i = 1, simpleweb_agentpool do
            agent[i] = skynet.newservice(SERVICE_NAME, "agent")
        end
        local balance = 1
        local simpleweb_port = skynet.getenv("simpleweb_port") or 8001
        local id = socket.listen("0.0.0.0", simpleweb_port)
        logger.info("simpleweb", "Listen web port: ", simpleweb_port)
        socket.start(id, function(id, addr)
            logger.info("simpleweb", string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
            skynet.send(agent[balance], "lua", id)
            balance = balance + 1
            if balance > #agent then
                balance = 1
            end
        end)
    end)
end
