package.cpath = "luaclib/?.so;" .. "/usr/local/share/lua/5.4/?.lua;" .. package.cpath --.."../../luaclib/?.so"
package.path = "lualib/?.lua;" .. "/usr/local/lib/lua/5.4/?.so;" .. package.path      --.."../../lualib/?.lua"




local socket = require("socket")
local tcp = socket.tcp()

local pb = require "protobuf"


tcp:connect("127.0.0.1", 8001)



-- 注册 Protobuf 文件
local login_file = "./proto/login.pb"
local battle_file = "./proto/battle.pb"

local success, err = pcall(function() pb.register_file(login_file) end)
if not success then
    print("Failed to register " .. login_file .. ": " .. err)
end


success, err = pcall(function() pb.register_file(battle_file) end)
if not success then
    print("Failed to register " .. battle_file .. ": " .. err)
end

-- 定义所有的协议及其对应的消息内容
local predefined_messages = {
    ["Login.login"] = { id = 103, pw = "123", result = 1 },
    ["Battle.work"] = { coin = 10, result = 1, reason = "Initial work setup" },
    ["Battle.enter"] = { player = { id = 101, x = 50, y = 60, size = 20 }, result = 1, reason = "Player entry successful" },
    ["Battle.balllist"] = { players = { { id = 101, x = 50, y = 60, size = 20 }, { id = 102, x = 70, y = 80, size = 30 } } },
    ["Battle.foodlist"] = { foods = { { fid = 1, x = 20, y = 30 }, { fid = 2, x = 40, y = 50 } } },
    ["Battle.addfood"] = { fid = 1, x = 25, y = 35 },
    ["Battle.shift"] = { x = 5, y = -5 },
    ["Battle.move"] = { id = 101, x = 60, y = 70 },
    ["Battle.eat"] = { id = 101, fid = 1, size = 25 },
    ["Battle.leave"] = { id = 101 },
    -- 继续添加更多预定义的协议及其消息内容...
}
local function send_protobuf_message(cmd, msg)
    -- 使用 Protobuf 编码消息
    local body = pb.encode(cmd, msg)
    if not body then
        print("Error encoding message for protocol:", cmd)
        return
    end

    -- 计算长度和格式
    local namelen = string.len(cmd)
    local bodylen = string.len(body)
    local len = namelen + bodylen + 2
    print("Sending message:", cmd, "with length:", len)

    -- 打包消息
    local format = string.format("> i2 i2 c%d c%d", namelen, bodylen)
    local buff = string.pack(format, len, namelen, cmd, body)

    -- 发送消息
    local sent = tcp:send(buff)
    if sent then
        print("Message sent successfully for protocol:", cmd)
    else
        print("Failed to send message for protocol:", cmd)
    end
end



local function getinput()
    print("请输入一些内容 (输入 'exit' 退出):")
    local input = io.read("*l")

    print("你输入的是: " .. input)
    return input
end




-- 发送消息函数
local function test_protobuf_send()
    while true do
        local input = getinput()
        if input == "exit" then
            print("退出...")
            break
        elseif input ~= "" or input ~= nil then
            if input == "stop" then
                -- 使用预定义的消息内容
                local msg = predefined_messages["Battle.shift"]
                msg.x = 0
                msg.y = 0
                -- 发送消息
                send_protobuf_message("Battle.shift", msg)
            end
            -- 使用预定义的消息内容
            local msg = predefined_messages[input]
            if not msg then
                print("Unknown message:", input)
            else
                -- 发送消息
                send_protobuf_message(input, msg)
            end
        end
    end

    -- 关闭连接
    tcp:close()
end


-- 执行测试
test_protobuf_send()
