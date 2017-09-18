---
--- Created by zhangpei-home.
--- DateTime: 2017/9/17 2:48
---

local socket = require("skynet.socket")
local skynet = require("skynet")

local socket_extend = {}
local writebytes = socket.write

function socket_extend.writefunc(fd)
    return function(content)
        local write_buffer_size = tonumber(skynet.getenv("write_buffer_size"))
        while #content > write_buffer_size do
            local content_chip = string.sub(content, 1, write_buffer_size)
            local ok = writebytes(fd, content_chip)
            print(ok)
            if not ok then
                error(socket_error)
            end
            content = string.sub(content, write_buffer_size - #content)
        end

        local ok = writebytes(fd, content)
        if not ok then
            error(socket_error)
        end
    end
end

return socket_extend