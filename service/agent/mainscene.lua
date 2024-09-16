local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")




s.client.MsgGetAchieve = function(msg)
    local respmsg = {}
    respmsg.win = 0
    respmsg.lost = 0

    skynet.error("MsgGetAchieve id：" .. s.id)
    local playerdata = nil
    local success, result = pcall(function()
        playerdata = skynet.call("db", "lua", "getPlayerdata", s.id)
    end)
    if not success then
        skynet.error("MsgGetAchieve fail" .. result)
    end
    if not playerdata then
        skynet.error("MsgGetAchieve fail playerdata nil")
    end

    respmsg.win = playerdata.win
    respmsg.lost = playerdata.lost
    skynet.error("MsgGetAchieve respmsg:" .. respmsg.win .. " " .. respmsg.lost)
    return respmsg
end


s.client.MsgGetRoomList = function(msg)
    skynet.error("MsgGetRoomList id：" .. s.id)
    local rooms = s.client.enterMain()
    if not rooms then
        skynet.error("MsgGetRoomList rooms is nil")
    end

    return rooms
end


s.client.MsgCreateRoom = function(msg)
    local respmsg = {}
    respmsg.result = 1
    if s.player.roomId >= 0 then
        respmsg.result = 1
        return respmsg
    end

    skynet.error("agent MsgCreateRoom")
    if not s.sname then
        skynet.error("不在主场景")
        return
    end


    local isok, roomid = s.call(s.snode, s.sname, "creatRoom", s.player.id)
    if not isok then
        skynet.error("创建房间失败")
        return respmsg
    end

    skynet.error("agent MsgCreateRoom roomid:" .. roomid)
    local isok = s.call(s.snode, s.sname, "enterRoom", s.player.id, roomid)
    if not isok then
        skynet.error("进入房间失败")
        return respmsg
    end


    respmsg.result = 0
    return respmsg
end


s.client.MsgGetRoomInfo = function(msg)
    local respmsg = { players = {} }

    local isok, players = s.call(s.snode, s.sname, "getRoomInfo", s.player.id)
    if not isok then
        skynet.error("获取房间信息失败")
        return respmsg
    end

    if not players then
        skynet.error("获取房间信息失败")
        return respmsg
    end
    respmsg.players = players
    return respmsg
end

s.client.MsgEnterRoom = function(msg)
    local respmsg = {}
    respmsg.id = msg.id
    respmsg.result = 1

    local isok = s.call(s.snode, s.sname, "enterRoom", s.player.id, msg.id)
    if not isok then
        skynet.error("进入房间失败 id" .. s.player.id)
        return respmsg
    end

    respmsg.result = 0
    return respmsg
end



s.client.MsgLeaveRoom = function(msg)
    local respmsg = {}
    respmsg.result = 1

    local isok = s.call(s.snode, s.sname, "leaveRoom", s.player.id)
    if not isok then
        skynet.error("退出房间失败 id" .. s.player.id)
        return respmsg
    end

    respmsg.result = 0
    return respmsg
end


s.client.MsgStartBattle = function(msg)
    local respmsg = {}
    respmsg.result = 1

    local isok = s.call(s.snode, s.sname, "startBattle", s.player)
    if not isok then
        skynet.error("开始战斗失败 id" .. s.player.id)
        return respmsg
    end


    respmsg.result = 0
    return respmsg
end





s.client.MsgSyncTank = function(msg)
    local isok = s.call(s.snode, s.sname, "syncTank", s.player, msg)
    if not isok then
        skynet.error("同步坦克失败  id:" .. s.player.id)
    end
end

s.client.MsgFire = function(msg)
    local isok = s.call(s.snode, s.sname, "msgFire", s.player, msg)
    if not isok then
        skynet.error("同步开火失败  id:" .. s.player.id)
    end
end



s.client.MsgHit = function(msg)
    local isok = s.call(s.snode, s.sname, "msgHit", s.player, msg)
    if not isok then
        skynet.error("同步击中失败  id:" .. s.player.id)
    end
end
