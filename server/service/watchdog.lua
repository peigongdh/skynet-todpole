---
--- Created by zhangpei-home.
--- DateTime: 2017/9/23 15:38
---

local skynet = require("skynet")
local logger = require("logger")

-- uid -> agent
local user_agent = {}

-- init in CMD.start
local gateservice
local loginservice

-- use for dispatch
local CMD = {}
local SOCKET = {}

-- agent list
local agentpool = {}

local agentpool_min_size = tonumber(skynet.getenv("agentpool_min_size")) or 10

--
local function precreate_agents_to_freepool()
    if #agentpool < agentpool_min_size then
        local need_create = agentpool_min_size - #agentpool
        logger.info("watchdog", "create agent for agentpool", need_create)
        for i = 1, need_create do
            local agent = skynet.newservice("agent")
            local conf = {
                watchdog = skynet.self()
            }
            skynet.call(agent, "lua", "start", conf)

            agentpool[#agentpool + 1] = agent
        end
    end
end

-- called in CMD.logout
local function do_logout(uid)
    local agent = user_agent[uid]
    if agent then
        -- logout from gate server, gate server then informs login server to logout
        skynet.call(gateservice, "lua", "logout", uid)

        local can_recycle = skynet.call(agent, "lua", "logout")
        if can_recycle then
            user_agent[uid] = nil
            agentpool[#agentpool + 1] = agent
        end
    end
end

function SOCKET.close(fd)

end

function SOCKET.error(fd, msg)

end

function SOCKET.warning(fd, size)

end

function SOCKET.data(fd, msg)

end

-- called by main
function CMD.start(conf)
    gateservice = conf.gateservice
    loginservice = conf.loginservice

    skynet.call(gateservice, "lua", "open", conf)
    precreate_agents_to_freepool()
end

-- called by gate server when login complete
function CMD.alloc_agent(uid)
    local agent
    if user_agent[uid] then
        logger.info("watchdog", "user uid", uid, "in online, ignore realloc")
        agent = user_agent[uid]
    else
        logger.info("watchdog", "alloc agent for user uid", uid)
        if #agentpool > 0 then
            agent = table.remove(agentpool)
        else
            agent = skynet.newservice("agent")
            local conf = {
                watchdog = skynet.self()
            }
            skynet.call(agent, "lua", "start", conf)
        end

        user_agent[uid] = agent

        local init = skynet.call(agent, "lua", "load_user_data", uid)
        if not init then
            logger.warn("watchdog", "agent load_user_data failed, add to free pool")
            agentpool[#agentpool + 1] = agent

            agent = nil
            user_agent[uid] = nil
        end
    end
    return agent
end

function CMD.client_auth_completed(agent, fd, ip)
    skynet.call(agent, "lua", "associate_fd_ip", fd, ip)
end

-- called by agent when user logout or gateserver when kick user
function CMD.logout(uid)
    logger.info("watchdog", "user uid", uid, "logout")
    do_logout(uid)
    return true
end

function CMD.close(fd)

end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd,...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            f(...)
            -- socket api don't need return
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)
end)