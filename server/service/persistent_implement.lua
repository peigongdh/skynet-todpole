---
--- Created by zhangpei-home.
--- DateTime: 2017/10/3 1:09
---

local skynet = require("skynet")
local datetime_utils = require("datetime_utils")
local mysql = require("mysql")
local logger = require("logger")
local string_utils = require("string_utils")

local mysql_host = skynet.getenv "mysql_host" or ""
local mysql_port = tonumber(skynet.getenv "mysql_port" or 3306)
local mysql_username = skynet.getenv "mysql_username" or ""
local mysql_password = skynet.getenv "mysql_password" or ""
local mysql_database = skynet.getenv "mysql_database" or ""

local PERSISTENT_TYPES = {
    SAVE_USER_DATA = 'save_user_data'
}

local model = ...

if model == "slave" then
    local db
    local master

    local function dbquery(sql, multirows)
        local res = db:query(sql)
        local results = {}

        if res['errcode'] then
            --error happen
            logger.error("persistent_implement", "mysql error", sql)
            return nil
        end

        if multirows then
            --need return multiple rows
            if #res >= 1 then
                for k, v in pairs(res) do
                    results[#results + 1] = v
                end
            else
                results = false
            end
        else
            --need exact one row
            if res[1] then
                results = res[1]
            else
                results = false
            end
        end

        -- nil means error, false means empty data
        return results
    end

    local PERSISTENT_HANDLER = {}

    function PERSISTENT_HANDLER.save_user_data(task)
        local uid = task.uid
        local userdata = task.data
        local now = datetime_utils.get_current_datetime()

        local sql = string.format("UPDATE `todpole`.`users` SET `name` = '%s', `exp` = '%d', `updated_at` = '%s' WHERE `uid` = %d", userdata.name, userdata.exp, now, uid)
        dbquery(sql)
        logger.debug("persistent_implement_slave", "save user data success")

        return true
    end


    local CMD = {}

    function CMD.start(persistent_master)
        master = persistent_master
        return true
    end

    function CMD.create_user_data(uid, name)
        uid = tonumber(uid)
        local now = datetime_utils.get_current_datetime()

        local sql = string.format("INSERT INTO `todpole`.`users` (`uid`, `name`, `exp`, `created_at`, `updated_at`) VALUES ('%d', '%s', '%d', '%s', '%s')", uid, name, 0, now, now)
        dbquery(sql)
        logger.debug("persistent_implement_slave", "create user data success")

        local userdata = {
            uid = uid,
            name = name,
            exp = 0,
            created_at = now,
            updated_at = now
        }

        return userdata
    end

    function CMD.load_user_data(uid)
        uid = tonumber(uid)

        local sql = string.format("SELECT * FROM `todpole`.`users` WHERE `uid` = '%d' LIMIT 1", uid)
        local row = dbquery(sql)
        logger.debug("persistent_implement_slave", "load user data success")

        if row == false then
            logger.error("persistent_implement_slave", "user not exist, uid", uid)
            return false
        end

        local userdata = {
            uid = uid,
            name = row['name'],
            exp = row['exp'],
            created_at = row['created_at'],
            updated_at = row['updated_at']
        }

        return userdata
    end

    function CMD.do_persistent(taskid, task)
        local tasktype = task.type
        local f = PERSISTENT_HANDLER[tasktype]
        if f then
            local result = f(task)
            if result then
                skynet.send(master, "lua", "finish_task", taskid)
            end
        end
    end

    local function init_mysql()
        local function on_connected(db)
            db:query("set names utf8")
        end

        local ok
        ok, db = pcall(mysql.connect, {
            host = mysql_host,
            port = mysql_port,
            database = mysql_database,
            user = mysql_username,
            password = mysql_password,
            max_packet_size = 1024 * 1024,
            on_connect = on_connected
        })

        if not ok or not db then
            logger.error("persistent_implement_slave", "connect to mysql failed")
        end
    end

    skynet.start(function()
        skynet.dispatch("lua", function(_, _, cmd, ...)
            local f = assert(CMD[cmd])
            local result = f(...)
            skynet.ret(skynet.pack(result))
        end)

        init_mysql()
    end)

else
    local slaves = {}

    local balance = 1

    -- taskid -> taskdata
    local save_queue = {}

    --[[
        taskdata defination:
        {
            taskid = xx,
            sended_to_slave = bool,
            type = tasktype,
            uid = xx,
            data = xx
        }
    ]]

    -- use for gen_taskid
    local taskid = 1

    -- uid -> taskid
    local save_queue_uid2taskid = {}

    -- taskid -> uid
    local save_queue_taskid2uid = {}

    local function is_userdata_pending_persistent(uid)
        local id = save_queue_uid2taskid[uid]
        if id then
            return id
        else
            return false
        end
    end

    -- auto increment
    local function gen_taskid()
        local id = taskid
        taskid = taskid + 1
        return id
    end

    local function getslave()
        local slave = slaves[balance]
        balance = balance + 1
        if balance > #slaves then
            balance = 1
        end
        return slave
    end

    -- timer
    local function process_task_queue()
        logger.debug("persistent_implement", "process_task_queue")
        for taskid, task in pairs(save_queue) do
            if not task.sended_to_slave then
                local slave = getslave()
                skynet.send(slave, "lua", "do_persistent", taskid, task)
                task.sended_to_slave = true
            end
        end
        skynet.timeout(100, process_task_queue)
    end

    local CMD = {}

    function CMD.create_user_data(uid, name)
        local slave = getslave()
        local result = skynet.call(slave, "lua", "create_user_data", uid, name)
        return result
    end

    -- called by agent when user login
    function CMD.load_user_data(uid)
        local result

        local id = is_userdata_pending_persistent(uid)
        logger.debug("persistent_implement", "is_userdata_pending_persistent", id)
        if id then
            local data = save_queue[id]
            result = data.data
        else
            local slave = getslave()
            result = skynet.call(slave, "lua", "load_user_data", uid)
        end

        return result
    end

    -- add task to queue to save user data
    function CMD.save_user_data(userdata)
        local uid = userdata.uid

        local id = save_queue_uid2taskid[uid]
        -- if taskid is exist, clean it from queue
        if id then
            save_queue_uid2taskid[id] = nil
            save_queue_taskid2uid[id] = nil
        end

        local newtaskid = gen_taskid()
        local task = {
            taskid = newtaskid,
            sended_to_slave = false,
            type = PERSISTENT_TYPES.SAVE_USER_DATA,
            uid = uid,
            data = userdata
        }

        save_queue[newtaskid] = task
        save_queue_uid2taskid[uid] = newtaskid
        save_queue_taskid2uid[newtaskid] = uid

        return true
    end

    -- called by persistent slave when finish task, clear task from all queue
    function CMD.finish_task(taskid)
        local task = save_queue[taskid]
        if task then
            save_queue[taskid] = nil
            local uid = save_queue_taskid2uid[taskid]
            if uid then
                save_queue_taskid2uid[taskid] = nil
                save_queue_uid2taskid[uid] = nil
                return true
            end
        end
        return false
    end

    local function init_slaves()
        local slavesize = tonumber(skynet.getenv("persistent_slave_poolsize")) or 8
        for i = 1, slavesize do
            local slave = skynet.newservice(SERVICE_NAME, "slave")
            skynet.call(slave, "lua", "start", skynet.self())
            slaves[#slaves + 1] = slave
        end
        skynet.timeout(100, process_task_queue)
        return true
    end

    skynet.start(function()
        init_slaves()
        skynet.dispatch("lua", function(_, _, cmd, ...)
            local f = assert(CMD[cmd])
            local result = f(...)
            skynet.ret(skynet.pack(result))
        end)
        skynet.timeout(100, process_task_queue)
    end)
end