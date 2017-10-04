---
--- Created by zhangpei-home.
--- DateTime: 2017/10/4 21:48
---

local skynet = require("skynet")
local redis = require("skynet.db.redis")
local datetime_utils = require("datetime_utils")
local bson = require("bson")
local logger = require("logger")
local string_utils = require("string_utils")

local redis_host = skynet.getenv("redis_host") or "127.0.0.1"
local redis_port = tonumber(skynet.getenv("redis_port") or 6379)
local redis_db = tonumber(skynet.getenv("redis_db") or 0)
local redis_logging_queue_name = skynet.getenv("redis_logging_queue_name") or "TODPOLE_LOG"

local redis_conf = {
    host = redis_host,
    port = redis_port,
    db = redis_db
}

local LOG_TABLES = {
    LOG_LOGIN = "log_login",
    LOG_LOGOUT = "log_logout"
}

-- init as redis connection
local db

local save_queue = {}

local function push(key, val)
    local encoded = bson.encode(val)
    db:rpush(key, encoded)
end

local function persistent(table_name, operation, log_data, primary_key)
    local data = {
        table_name = table_name,
        operation = operation,
        log_data = log_data,
        primary_key = primary_key
    }

    local ok = pcall(push, redis_logging_queue_name, data)
    if not ok then
        save_queue[#save_queue + 1] = data
    end
end

local CMD = {}

function CMD.log_user_login(uid, ip)
    local datetime = datetime_utils.get_current_datetime()

    local table_name = LOG_TABLES.LOG_LOGIN
    local operation = "insert"

    local log_data = {
        uid = uid,
        login_ip = ip,
        login_datetime = datetime
    }

    persistent(table_name, operation, log_data)
end

function CMD.log_user_logout(uid, ip)
    local datetime = datetime_utils.get_current_datetime()

    local table_name = LOG_TABLES.LOG_LOGOUT
    local operation = "insert"

    local log_data = {
        uid = uid,
        login_ip = ip,
        login_datetime = datetime
    }

    persistent(table_name, operation, log_data)
end

local function retry_queued_logs()
    while true do

    end
end

local function statelogging_init()
    -- logger.debug("statelogging_implement", "statelogging_init", string_utils.dump(redis_conf))
    -- db = redis:connect(redis_conf)
    -- redis:connect may have a bug that read port as nil

    local ok
    ok, db = pcall(redis.connect, redis_conf)
    if not ok or not db then
        logger.error("statelogging_implement", "connect to redis failed")
    end
end

skynet.start(function()
    statelogging_init()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(CMD[cmd])
        local result = f(...)
        skynet.ret(skynet.pack(result))
    end)
end)
