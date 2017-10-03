---
--- Created by zhangpei-home.
--- DateTime: 2017/9/23 15:38
---

local skynet = require("skynet")
local logger = require("logger")

-- init in CMD.start
local gateservice
local loginservice

-- use for dispatch
local CMD = {}
local SOCKET = {}

-- agent list
local agentpool = {}

-- use for agent pool
local agentpool_min_size = tonumber(skynet.getenv("agentpool_min_size")) or 10

-- use for agent recycle & persistent
local check_idle_agent_time = tonumber(skynet.getenv("check_idle_agent_time")) or 5
local check_recycle_agent_time = tonumber(skynet.getenv("check_recycle_agent_time")) or 5
local check_persistent_agent_time = tonumber(skynet.getenv("check_persistent_agent_time")) or 10
-- uid -> agent
local user_agent = {}
-- [uid]
local recycle_agent_queue = {}

-- precreate agents
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

local function check_idle_agent()
    logger.debug("watchdog", "check_idle_agent")

    for _, agent in pairs(user_agent) do
        skynet.call(agent, "lua", "check_idle")
    end
end

local function check_recycle_agent()
    logger.debug("watchdog", "check_recycle_agent start")

    if #recycle_agent_queue > 0 then
        for _, uid in pairs(recycle_agent_queue) do
            local agent = user_agent[uid]
            if agent then
                skynet.call(gateservice, "lua", "logout", uid)
                local can_recycle = skynet.call(agent, "lua", "logout")
                if can_recycle then
                    skynet.call(agent, "lua", "persistent")
                    skynet.call(agent, "lua", "recycle")

                    user_agent[uid] = nil
                    agentpool[#agentpool + 1] = agent
                end
            end
        end
        recycle_agent_queue = {}
    end
end

local function check_persistent_agent()
    logger.debug("watchdog", "check_persistent_agent")

    for _, agent in pairs(user_agent) do
        skynet.call(agent, "lua", "persistent")
    end
end

-- do agent recycle & persistent
local function watchdog_timer(idle_count, recycle_count, persistent_count)
    logger.debug("watchdog", "watchdog_timer")
    precreate_agents_to_freepool()

    idle_count = idle_count + 1
    recycle_count = recycle_count + 1
    persistent_count = persistent_count + 1

    if idle_count >= check_idle_agent_time then
        idle_count = 0
        check_idle_agent()
    end
    if recycle_count >= check_recycle_agent_time then
        recycle_count = 0
        check_recycle_agent()
    end
    if persistent_count >= check_persistent_agent_time then
        persistent_count = 0
        check_persistent_agent()
    end

    skynet.timeout(100, function()
        watchdog_timer(idle_count, recycle_count, persistent_count)
    end)
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
    skynet.timeout(100, function()
        watchdog_timer(0, 0, 0)
    end)
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

-- called by gate server when auth completed
function CMD.client_auth_completed(agent, fd, ip)
    skynet.call(agent, "lua", "associate_fd_ip", fd, ip)
end

-- called by agent when user logout or gateserver when kick user
function CMD.logout(uid)
    logger.info("watchdog", "user uid", uid, "logout")
    do_logout(uid)
    return true
end

-- called by watchdog after agent check idle
function CMD.recycle_agent(uid)
    recycle_agent_queue[#recycle_agent_queue + 1] = uid
end

function CMD.close(fd)

end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
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