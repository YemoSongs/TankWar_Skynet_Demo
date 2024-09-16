local skynet = require "skynet"
local s = require "service"
local mkdata = require "makedata"

s.client = {}
s.gate = nil

require "scene" --引入战斗场景
require "mainscene"

s.resp.client = function(source, cmd, msg)
    s.gate = source

    local dot_index = string.find(cmd, "%.")         -- 找到 '.' 的位置
    local local_cmd = string.sub(cmd, dot_index + 1) -- 从 '.' 后的下一个字符开始截取
    if s.client[local_cmd] then
        --skynet.error("[s.resp.client] agent:", cmd)
        local ret_msg = s.client[local_cmd](msg, source)
        if ret_msg then
            skynet.error("[s.resp.client] agent resp:", cmd)
            skynet.send(source, "lua", "send", s.id, cmd, ret_msg)
        end
    else
        skynet.error("s.resp.client fail", cmd)
    end
end


s.client.work = function(msg)
    s.data.coin = s.data.coin + 1
    local respmsg = {
        coin = s.data.coin,
        result = 1,
        reason = "",
    }

    respmsg.result = 0
    respmsg.reason = "工作，金币++"

    local playerdata = mkdata.getPlayerdata()
    playerdata.playerid = s.data.playerid
    playerdata.coin = s.data.coin
    playerdata.name = s.data.name
    playerdata.level = s.data.level
    playerdata.last_login_time = s.data.last_login_time

    local isok = skynet.call("db", "lua", "updatedata", playerdata.playerid, playerdata)
    if not isok then
        skynet.error("[数据库update测试失败]")
    else
        skynet.error("[数据库update测试成功] ")
    end



    return respmsg
end




s.resp.kick = function(source)
    s.client.leave()

    --在此处保存角色数据
    skynet.sleep(200)
end

s.resp.exit = function(source)
    skynet.exit()
end

--，scene调用了agent的远程调用方法send给客户端发送消息
s.resp.send = function(source, cmd, msg)
    skynet.send(s.gate, "lua", "send", s.id, cmd, msg)
end

s.init = function()
    local playerid = s.id
    --在此处加载角色数据
    -- 使用 pcall 来捕获可能的错误
    local getP
    local success, err = pcall(function()
        getP = skynet.call("db", "lua", "getPlayerdata", playerid)
    end)

    -- 检查 pcall 是否成功
    if not success then
        skynet.error("[数据库select出错]:", err)
        return
    end

    if not getP then
        skynet.error("[数据库select失败]")
    else
        skynet.error("[数据库select] " ..
            " coin:" .. getP.coin .. "text" .. getP.text .. "win" .. getP.win .. "lost" .. getP.lost)
        s.data = {
            playerid = playerid,
            coin = getP.coin,
            text = getP.text,
            win = getP.win,
            lost = getP.lost,
        }
        local name = tostring(playerid)
        s.player = {
            id = name,
            x = 0,
            y = 0,
            z = 0,
            ex = 0,
            ey = 0,
            ez = 0,
            roomId = -1,
            camp = 1,
            hp = 100,
            win = s.data.win,
            lost = s.data.lost,
            data = s.data,
        }
    end
end


s.start(...)
