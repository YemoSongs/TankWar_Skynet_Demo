local mysql = require "skynet.db.mysql"
local skynet = require "skynet"
local pb = require "protomsg"
local s = require "service"


local db = nil

--[[ 删除特殊字符，防止 SQL 注入
local remove_special_chars = function(str)
    return str:gsub("[; '\"\\/]", "")
end
--]]

s.resp.creatdata = function(source, id, inputdata)
    if not id or not inputdata or type(inputdata) ~= "table" then
        return false
    end


    local success, data = pcall(pb.jsonpack, inputdata)
    if not success then
        skynet.error("序列化失败: " .. data)
        return false
    end

    -- 查询是否存在相同的记录
    local query = string.format("SELECT * FROM msgs WHERE id = %d", id)
    local result = db:query(query)

    if not result then
        skynet.error("查询失败，result 为空。")
        return false
    end

    -- 如果没有相同的记录，执行插入操作
    if #result == 0 then
        local insert_query = string.format(
            "INSERT INTO msgs (id, data) VALUES (%d, '%s') ON DUPLICATE KEY UPDATE data = VALUES(data)",
            id, data
        )
        db:query(insert_query)
        skynet.error("插入操作已执行。")
    else
        skynet.error("相同的消息已存在，插入操作未执行。")
    end
    return true
end

s.resp.updatedata = function(source, id, new_data)
    if not id or not new_data then
        skynet.error("Invalid parameters for update_data")
        return false
    end

    -- 查询是否存在对应的记录
    local query = string.format("SELECT COUNT(*) as count FROM msgs WHERE id = %d", id)
    local result = db:query(query)

    if not result or result[1].count == 0 then
        skynet.error("Record with ID " .. id .. " does not exist")
        return false
    end

    local success, data = pcall(pb.jsonpack, new_data)
    if not success then
        skynet.error("序列化失败: " .. data)
        return false
    end

    -- 更新数据
    local update_query = string.format("UPDATE msgs SET data = '%s' WHERE id = %d", data, id)
    local ok, err = pcall(function()
        db:query(update_query)
    end)

    if not ok then
        skynet.error("Failed to update record: " .. err)
        return false
    end

    skynet.error("Successfully updated record with ID " .. id)
    return true
end

s.resp.selectdata = function(source, id)
    if not id then
        return false
    end

    --skynet.error("准备执行查询，ID：" .. tostring(id))

    -- 查询数据
    local query = string.format("SELECT * FROM msgs WHERE id = %d", id)
    local result = db:query(query)

    if not result or #result == 0 then
        skynet.error("查询失败或没有找到记录。")
        return false
    end

    -- 解析查询结果
    local row = result[1]
    local serialized_data = row.data
    --skynet.error("Serialized data from database: " .. tostring(serialized_data))

    -- 反序列化数据
    local isok, ret_data = pcall(function()
        return pb.jsonunpack(serialized_data)
    end)

    if not isok or not ret_data then
        skynet.error("反序列化失败")
        return false
    end

    --skynet.error("查询成功，返回数据：")
    return isok, ret_data
end

s.resp.deldata = function(source, id)
    if not id then
        return
    end

    -- 删除数据
    local delete_query = string.format("DELETE FROM msgs WHERE id = %d", id)
    local result = db:query(delete_query)

    if result then
        skynet.error("删除操作已执行。")
    else
        skynet.error("删除操作失败。")
        return false
    end
    return true
end



local creatplayerdata = function(id)
    -- 查询是否存在相同的记录
    local query = string.format("SELECT * FROM playerdata WHERE id = '%s'", id)
    local result = db:query(query)

    if not result then
        skynet.error("查询失败，result 为空。")
        return false
    end

    local playerdata = {
        coin = 0,
        text = "new text",
        win = 0,
        lost = 0,
    }

    local success, data = pcall(pb.jsonpack, playerdata)
    if not success then
        skynet.error("序列化失败: " .. data)
        return false
    end

    -- 如果没有相同的记录，执行插入操作
    if #result == 0 then
        local insert_query = string.format(
            "INSERT INTO playerdata (id, data) VALUES ('%s', '%s')",
            id, data
        )
        local success, err = db:query(insert_query)
        if not success then
            skynet.error("插入操作失败: " .. err)
            return false
        end
        skynet.error("插入操作已执行。")
    else
        skynet.error("相同的消息已存在，插入操作未执行。")
    end
end



-- 注册账号
s.resp.register_account = function(source, id, pw)
    if not id or not pw then
        skynet.error("无效的注册参数")
        return false
    end

    -- 查询是否存在相同的账号
    local query = string.format("SELECT * FROM account WHERE id = '%s'", id)
    local result = db:query(query)

    if not result then
        skynet.error("查询失败，result 为空。")
        return false
    end

    -- 如果没有相同的账号，执行插入操作
    if #result == 0 then
        local insert_query = string.format(
            "INSERT INTO account (id, pw) VALUES ('%s', '%s')",
            id, pw
        )
        local insert_result = db:query(insert_query)
        if insert_result then
            skynet.error("注册操作已执行。")
            creatplayerdata(id)
            return true
        else
            skynet.error("注册操作失败。")
            return false
        end
    else
        skynet.error("相同的账号已存在，注册操作未执行。")
        return false
    end
end



s.resp.login_account = function(source, id, pw)
    if not id or not pw then
        skynet.error("无效的登录参数")
        return false
    end

    -- 查询账号密码
    local query = string.format("SELECT pw FROM account WHERE id = '%s'", id)
    local result = db:query(query)

    if not result or #result == 0 then
        skynet.error("查询失败或账号不存在。")
        return false
    end

    local stored_pw = result[1].pw

    -- 验证密码是否匹配
    if stored_pw == pw then
        skynet.error("登录成功。")
        return true
    else
        skynet.error("密码错误，登录失败。")
        return false
    end
end

s.resp.getPlayerdata = function(source, id)
    -- 查询账号密码
    local query = string.format("SELECT data FROM playerdata WHERE id = '%s'", id)


    local result = db:query(query)

    if not result or #result == 0 then
        skynet.error("查询失败或账号不存在。id: " .. id)
        return false
    end

    local stored_data = result[1].data

    if not stored_data or stored_data == "" then
        skynet.error("没有存储的玩家数据。")
        return false
    end

    local success, playerdata = pcall(pb.jsonunpack, stored_data)
    if not success then
        skynet.error("数据解码失败: " .. playerdata)
        return false
    end
    return playerdata
end






s.init = function()
    if not db then
        db = mysql.connect({
            host = "47.120.52.179",
            port = 3306,
            database = "message_board",
            user = "yemojack",
            password = "Wsygyxkfz1",
            max_packet_size = 1024 * 1024,
            on_connect = nil
        })
        assert(db, "Failed to connect to MySQL database")
        skynet.error("[Database] connection established")
    else
        skynet.error("[Database] connection already exists")
    end
end


s.start(...)
