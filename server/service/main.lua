local skynet = require "skynet"
local logger = require "logger"

skynet.start(function()
    logger.info("main", "Server start")

    local debug_console_port = skynet.getenv("debug_console_port") or 8000
    if debug_console_port then
        skynet.newservice("debug_console", tonumber(debug_console_port))
    end

    skynet.newservice("simpleweb")
    skynet.newservice("events")
    --skynet.newservice("testsocket", "", 0)

    local loginservice = skynet.uniqueservice("login_implement")
    local gateservice = skynet.uniqueservice("gate_implement")
    local watchdog = skynet.uniqueservice("watchdog")

    local gateconf = {
        servername = "gateserver1",
        loginservice = loginservice,
        gateservice = gateservice
    }

    skynet.call(watchdog, "lua", "start", gateconf)

    skynet.exit()
end)
