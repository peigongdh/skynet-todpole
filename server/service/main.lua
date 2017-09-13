local skynet = require "skynet"

skynet.start(function()
    skynet.error("Server start")
    if not skynet.getenv "daemon" then
        local console = skynet.newservice("console")
    end
    -- skynet.newservice("debug_console", 8000)
    skynet.newservice("simpleweb")
    skynet.newservice("events")
    skynet.exit()
end)
