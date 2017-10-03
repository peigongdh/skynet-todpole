local skynet = require("skynet")
local logger = require("logger")
local sprotoloader = require("sprotoloader")

skynet.start(function()
    logger.info("main", "Server start")

    local debug_console_port = skynet.getenv("debug_console_port") or 8000
    if debug_console_port then
        skynet.newservice("debug_console", tonumber(debug_console_port))
    end

    skynet.newservice("simpleweb")
    skynet.newservice("events")
    -- skynet.newservice("testsocket", "", 0)

    skynet.uniqueservice("protoloader")

    skynet.uniqueservice("room_implement")
    skynet.uniqueservice("persistent_implement")

    local loginservice = skynet.uniqueservice("login_implement")
    local gateservice = skynet.uniqueservice("gate_implement")
    local watchdog = skynet.uniqueservice("watchdog")

    local gateserver_host = skynet.getenv("gateserver_host")
    local gateserver_port = tonumber(skynet.getenv("gateserver_port"))

    local gateconf = {
        address = gateserver_host,
        port = gateserver_port,
        nodelay = true,
        maxclient = 1024,
        servername = "gateserver1",
        loginservice = loginservice,
        gateservice = gateservice
    }

    skynet.call(watchdog, "lua", "start", gateconf)

    skynet.exit()
end)
