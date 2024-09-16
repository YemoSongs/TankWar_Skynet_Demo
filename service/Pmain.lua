local skynet = require "skynet"
local cjson = require "cjson"
local pb = require "protobuf"



--编码测试
function test1()
    local msg = {
        _cmd = "balllist",
        balls = {
            [1] = {id=102, x=10, y=20, size=1},
            [2] = {id=103, x=10, y=30, size=2},
        }
    }
    local buff = cjson.encode(msg)
    print(buff)
end


--解码测试
function test2()
    local buff = [[{"_cmd":"enter","playerid":101,"x":10,"y":20,"size":1}]]
    local isok,msg = pcall(cjson.decode,buff)
    if isok then
        print(msg._cmd) --enter
        print(msg.playerid) --101.0
    else
        print("error")
    end
end

--协议测试 
function test3() 
    local msg = { 
        _cmd = "playerinfo", 
        coin = 100, 
        bag = { 
            [1] = {1001,1},  --倚天剑*1 
            [2] = {1005,5}   --草药*5 
        }, 
    } 
    --编码 
    local buff_with_len = json_pack("playerinfo", msg) 
    local len = string.len(buff_with_len) 
    print("len:"..len) 
    print(buff_with_len) 
    --解码 
    local format = string.format(">i2 c%d", len-2) 
    local _, buff = string.unpack(format, buff_with_len) 
    local cmd, umsg = json_unpack(buff) 
    print("cmd:"..cmd) 
    print("coin:"..umsg.coin) 
    print("sword:"..umsg.bag[1][2]) 
end


--protobuf编码解码
function test4()
    pb.register_file("./proto/test.pb")
    --编码
    local msg = {
        id = 101,
        pw = "123456",
        result = 1,
    }
    local buff = pb.encode("test.Test",msg)
    print("len:"..string.len(buff))
    --解码
    local umsg = pb.decode("test.Test",buff)
    if umsg then
        print("id:"..umsg.id)
        print("pw:"..umsg.pw)
        print("result:"..umsg.result)
    else
        print("error")
    end
end


--编码json协议
function json_pack(cmd, msg) 
    msg._cmd = cmd 
    local body = cjson.encode(msg)    --协议体字节流 
    local namelen = string.len(cmd)   --协议名长度 
    local bodylen = string.len(body)  --协议体长度 
    local len = namelen + bodylen + 2 --协议总长度 
    local format = string.format("> i2 i2 c%d c%d", namelen, bodylen) 
    local buff = string.pack(format, len, namelen, cmd, body) 
    return buff 
end

--解码json协议
function json_unpack(buff)
    local len = string.len(buff)
    local namelen_format = string.format("> i2 c%d", len-2)
    local namelen, other = string.unpack(namelen_format, buff)
    local bodylen = len-2-namelen
    local format = string.format("> c%d c%d", namelen, bodylen)
    local cmd, bodybuff = string.unpack(format, other)

    local isok, msg = pcall(cjson.decode, bodybuff)
    if not isok or not msg or not msg._cmd or not cmd == msg._cmd then
        print("error")
        return
	end

    return cmd, msg
end


--[[
local mysql = require "skynet.db.mysql"

local db = nil


local function remove_special_chars(str)
    -- 删除所有特殊字符，如单引号、双引号、分号等
    return str:gsub("[; '\"\\/]", "")
end


local getdata = function()
    local res = db:query("select * from msgs")
    for i,v in pairs(res) do 
        skynet.error(v.id.." "..v.text.."\r\n")
    end
end

local setdata = function(inputdata)
    if not inputdata then
        return
    end

    -- 转义输入数据以防止 SQL 注入
    local escaped_input = remove_special_chars(inputdata)

    -- 查询是否存在相同的消息
    local query = string.format("SELECT * FROM msgs WHERE text = '%s'", escaped_input)
    local result = db:query(query)

    -- 调试输出，检查查询结果
    if not result then
        print("查询失败，result 为空。")
        return
    else
        print("查询结果：")
        for i, row in ipairs(result) do
            for k, v in pairs(row) do
                print(k, v)
            end
        end
    end

    -- 如果没有相同的消息，才执行插入操作
    -- 检查 result[1] 是否存在，并且 `count` 字段应该用于统计行数（这个例子不适用）
    if #result == 0 then
        local insert_query = "INSERT INTO msgs (text) VALUES ('"..inputdata.."')"
        db:query(insert_query)
        print("插入操作已执行。")
    else
        print("相同的消息已存在，插入操作未执行。")
    end
end

local deldate = function(inputdata)
    if not inputdata then
        return
    end

    -- 转义输入数据以防止 SQL 注入
    local escaped_input = remove_special_chars(inputdata)

    -- 执行删除操作
    local delete_query = string.format("DELETE FROM msgs WHERE text = '%s'", escaped_input)
    local result = db:query(delete_query)

    -- 检查结果
    if result then
        print("删除操作已执行。")
    else
        print("删除操作失败。")
    end
end



skynet.start(function()

	--连接数据库
	db = mysql.connect({
		host="47.120.52.179",
		port=3306,
		database="message_board",
		user="yemojack",
		password="Wsygyxkfz1",
		max_packet_size=1024*1024,
		on_connect=nil
	})

    getdata()

    setdata("test1 /")

    deldate("test")

end)
--]]


local db = require "mysqldb"
local protomsg = require "protomsg"




skynet.start(function()
    db.init()
    protomsg.register_protos()
    
    local player = {
        playerid = 101,
        coin = 100,
        name = "yemo",
        level = 3,
        last_login_time = 5,
    }

    db.deldata(101)

    local data =  db.selectdata(101)
    if data ~= nil then
        skynet.error(data.playerid.." "..data.coin.." "..data.name)
    else
        print("data is nil")
    end
end)




