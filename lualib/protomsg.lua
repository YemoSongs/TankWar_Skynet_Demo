local skynet = require "skynet"
local pb = require "protobuf"
local cjson = require "cjson"



local protomsg = {}
local proto_files = {
    "./proto/login.pb",
    "./proto/battle.pb",
    "./proto/BattleMsg.pb",
    "./proto/LoginMsg.pb",
    "./proto/RoomMsg.pb",
    "./proto/SyncMsg.pb",
    "./proto/SysMsg.pb",
   
    -- 在这里添加其他的协议文件路径
}



-- 函数：注册所有协议文件
function protomsg.register_protos()
    for _, file in ipairs(proto_files) do
        local success, err = pcall(pb.register_file, file)
        if not success then
            skynet.error("[Protobuf] Failed to register file: " .. file .. " Error: " .. err)
        else
            skynet.error("[Protobuf] Registered protobuf file: " .. file)
        end
    end
end

-- 序列化方法
protomsg.jsonpack = function(body)
    --[[
    local encoded, err = pcall(function()
        return pb.encode(cmd, body)
    end)]]

    local success, result = pcall(function()
        return cjson.encode(body)
    end)
    if not success then
        skynet.error("Data JsonPack fail " .. result)
        return false
    end
    --skynet.error("Data: " .. tostring(result))
    return result
end



-- 反序列化方法
protomsg.jsonunpack = function(body)
    local success, result = pcall(function()
        return cjson.decode(body)
    end)

    if not success then
        skynet.error("Data JsonUnPack fail " .. result)
        return
    end

    return result
end



-- 编码
protomsg.msg_pack = function(cmd, msg)
    -- 编码消息
    local body = pb.encode(cmd, msg)

    -- 协议名长度
    local namelen = string.len(cmd)
    -- 协议体长度
    local bodylen = string.len(body)
    -- 协议总长度
    local len = namelen + bodylen + 2

    -- 构造数据格式
    local format = string.format("> i2 i2 c%d c%d", namelen, bodylen)

    -- 打包协议
    local buff = string.pack(format, len, namelen, cmd, body)
    return buff
end


-- 解码
protomsg.msg_unpack = function(buff)
    local len = string.len(buff)
    local namelen_format = string.format("> i2 c%d", len - 2)
    local namelen, other = string.unpack(namelen_format, buff)
    skynet.error(namelen .. " " .. other)
    local bodylen = len - 2 - namelen
    local format = string.format("> c%d c%d", namelen, bodylen)
    local cmd, bodybuff = string.unpack(format, other)
    skynet.error(cmd .. " " .. bodybuff)
    -- Ensure command is extracted correctly
    local isok, msg = pcall(function()
        return pb.decode(cmd, bodybuff)
    end)

    if not isok or not msg then
        skynet.error("[decode error] msg unpack failed")
        return
    end

    return cmd, msg
end


return protomsg
