local skynet = require("skynet")
local sprotoparser = require("sprotoparser")
local sprotoloader = require("sprotoloader")
local protocol = require("protocol")

skynet.start(function()
    sprotoloader.save(protocol.c2s, 1)
    sprotoloader.save(protocol.s2c, 2)
    -- don't call skynet.exit() , because sproto.core may unload and the global slot become invalid
end)
