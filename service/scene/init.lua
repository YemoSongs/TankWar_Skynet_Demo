local skynet = require "skynet"
local s = require "service"

local mkdata = require "makedata"


local balls = {} --[playerid] = ball
local foods = {} --[id] = food
local food_maxid = 0
local food_count = 0

rooms = {}
local room_maxid = 0
mainPlayers = {}



local function getTankInfo()
    local m = {
        id = 1,
        camp = 1,
        hp = 100,
        x = 0,
        y = 0,
        z = 0,
        ex = 0,
        ey = 0,
        ez = 0,
    }
    return m
end


local function getroom()
    room_maxid = room_maxid + 1
    local m = {
        id = room_maxid,
        playerIds = {},
        ownerId = "",
        status = 0,
        count = 0,
        birthCofig = {
            --阵营1 出生点
            {
                { -43.3, 1.5, -64.9, 0, 0, 0 }, --出生点1
                { -17.6, 1.5, -64.9, 0, 0, 0 }, --出生点2
                { -8.5, 1.5, -64.9, 0, 0, 0 }   --出生点3
            },
            --阵营2 出生点
            {
                { 2.8, 1.5, 50.9, 0, 180, 0 },   --出生点1
                { -23.3, 1.5, 50.9, 0, 180, 0 }, --出生点2
                { -49, 1.5, 50.9, 0, 180, 0 }    --出生点3
            },
        },
        lastJudgeTime = 0,
    }
    return m
end


--广播
function roomBroadMsg(cmd, msg, roomId)
    if next(rooms[roomId].playerIds) == nil then
        return
    end

    for i, v in pairs(rooms[roomId].playerIds) do
        s.send(mainPlayers[i].node, mainPlayers[i].agent, "send", cmd, msg)
    end
end

s.resp.getRoomlist = function(source, player)
    if not mainPlayers[player.id] then
        skynet.error("mainPlayers[player.id] is nil")
        return false, nil
    end

    local msg = { rooms = {} }
    for _, v in pairs(rooms) do
        local room = {}
        room.id = v.id
        room.count = v.count
        room.status = v.status

        table.insert(msg.rooms, room)
    end

    skynet.error("scene getRoomlist :" .. #msg.rooms)
    return true, msg
end


s.resp.enterMain = function(source, player, node, agent)
    skynet.error("scene enterMain")
    --[[
    if mainPlayers[player.id] then
        return false, nil
    end
    ]]

    local b = {}
    b.playerid = player.id
    b.node = node
    b.agent = agent
    b.roomId = player.roomId
    b.camp = player.camp
    b.win = player.win
    b.lost = player.lost
    b.isOwner = 0
    b.x = player.x
    b.y = player.y
    b.z = player.z
    b.ex = player.ex
    b.ey = player.ey
    b.ez = player.ez
    b.hp = player.hp
    b.turretY = 0

    mainPlayers[player.id] = b
    if not mainPlayers[player.id] then
        skynet.error("mainPlayers[player.id] is nil")
    end



    local msg = { rooms = {} }
    for _, v in ipairs(rooms) do
        local room = {}
        room.id = v.id
        room.count = v.count
        room.status = v.status

        table.insert(msg.rooms, room)
    end

    return true, msg
end



s.resp.creatRoom = function(source, id)
    if not mainPlayers[id] then
        return false, nil
    end
    local room = getroom()
    room.ownerId = id
    mainPlayers[id].isOwner = 1

    rooms[room.id] = room

    if not rooms[room.id] then
        return false, nil
    end

    skynet.error(id .. " scene creatRoom :" .. rooms[room.id].id)

    return true, room.id
end


local switchCamp = function()
    local count1 = 0
    local count2 = 0

    for _, v in pairs(mainPlayers) do
        if v.camp == 1 then
            count1 = count1 + 1
        else
            count2 = count2 + 1
        end
    end

    if count1 <= count2 then
        return 1
    else
        return 2
    end
end



s.resp.getRoomInfo = function(source, id)
    skynet.error("scene getRoomInfo" .. id)
    if not mainPlayers[id] then
        return false, nil
    end
    local roomid = mainPlayers[id].roomId
    skynet.error("getRoomInfo roomid" .. roomid)
    if not rooms[roomid] then
        return false, nil
    end

    skynet.error("getRoomInfo room :" .. rooms[roomid].id)

    local players = {}
    for i, v in pairs(rooms[roomid].playerIds) do
        local mainPlayer = mainPlayers[i]
        if mainPlayer then
            skynet.error("mainPlayers 表中找到玩家: " .. i)
            local player = {
                id = mainPlayer.playerid,
                camp = mainPlayer.camp,
                win = mainPlayer.win,
                lost = mainPlayer.lost,
                isOwner = 0,
            }
            if i == rooms[roomid].ownerId then
                player.isOwner = 1
            end
            table.insert(players, player)
        else
            skynet.error("mainPlayers 表中找不到玩家: " .. i)
        end
    end
    -- 检查玩家是否为空
    if next(players) == nil then
        skynet.error("getRoomInfo: 房间内没有玩家，房间ID: " .. roomid)
        return false, nil
    end

    return true, players
end



s.resp.enterRoom = function(source, id, roomId)
    local respmsg = { players = {} }
    skynet.error("scene enterRoom" .. id .. " " .. roomId)
    if not mainPlayers[id] then
        return false
    end
    if not rooms[roomId] then
        return false
    end
    if rooms[roomId].status == 1 then
        return false
    end

    mainPlayers[id].roomId = roomId
    if next(rooms[roomId].playerIds) == nil then
        rooms[roomId].playerIds = {}
    end
    rooms[roomId].playerIds[id] = true
    if not rooms[roomId].playerIds[id] then
        return false
    end


    mainPlayers[id].camp = switchCamp()


    local isok, players = s.resp.getRoomInfo(source, id)
    if not isok then
        return false
    end
    respmsg.players = players
    roomBroadMsg("RoomMsg.MsgGetRoomInfo", respmsg, roomId)
    return true
end



s.resp.leaveRoom = function(source, id)
    local player = mainPlayers[id]
    if not player then
        return false
    end

    local roomid = player.roomId
    local room = rooms[roomid]
    if not room then
        return false
    end

    if not room.playerIds[id] then
        return false
    end
    player.roomId = -1
    player.camp = 0
    room.playerIds[id] = nil


    if next(rooms[roomid].playerIds) == nil then
        -- 如果房间为空，移除房间
        rooms[roomid] = nil
    else
        if player.isOwner == 1 then
            player.isOwner = 0
            -- 从剩余的玩家中选择新的房主
            for newId, _ in pairs(room.playerIds) do
                room.ownerId = newId           -- 设置新的房主
                mainPlayers[newId].isOwner = 1 -- 更新新房主的 isOwner 状态
                skynet.error("新房主为玩家: " .. newId)
                break                          -- 找到一个新房主后，退出循环
            end
        end
        if room.status == 1 then
            player.lost = player.lost + 1
            local leavemsg = {}
            leavemsg.id = player.playerid
            roomBroadMsg("RoomMsg.MsgLeaveRoom", leavemsg, room.id)
        end
        local msg = {
            players = {}
        }
        local isok, ps = s.resp.getRoomInfo(source, next(room.playerIds))
        msg.players = ps
        roomBroadMsg("RoomMsg.MsgGetRoomInfo", msg, room.id)
    end


    return true
end



local checkCampCount = function(room)
    local count1 = 0
    local count2 = 0
    for i, _ in pairs(room.playerIds) do
        if mainPlayers[i].camp == 1 then
            count1 = count1 + 1
        else
            count2 = count2 + 1
        end
    end

    if count1 < 1 or count2 < 1 then
        return false
    end
    return true
end


local setBirthPos = function(player, count, room)
    local birthCofig = room.birthCofig
    local camp = player.camp
    -- 确保 camp 和 count 有效
    if birthCofig[camp] and birthCofig[camp][count] then
        player.x, player.y, player.z, player.ex, player.ey, player.ez = table.unpack(birthCofig[camp][count])
    else
        print("Error: Invalid camp or count for player", player.id, "camp:", camp, "count:", count)
    end
end



local resetPlayers = function(room)
    local count1 = 1
    local count2 = 1
    for i, _ in pairs(room.playerIds) do
        local player = mainPlayers[i]
        if player.camp == 1 then
            setBirthPos(player, count1, room)
            count1 = count1 + 1
        else
            setBirthPos(player, count2, room)
            count2 = count2 + 1
        end
    end
end


local judagement = function(room)
    local count1 = 0
    local count2 = 0

    for i, _ in pairs(room.playerIds) do
        local player = mainPlayers[i]
        if player.hp > 0 then
            if player.camp == 1 then
                count1 = count1 + 1
            else
                count2 = count2 + 1
            end
        end
    end

    skynet.error("judagement roomid:" .. room.id)
    if count1 <= 0 then
        return 2
    elseif count2 <= 0 then
        return 1
    end

    return 0
end




s.resp.startBattle = function(source, player)
    local player = mainPlayers[player.id]
    local room = rooms[player.roomId]

    if not room then
        skynet.error("房间不存在")
        return false
    end

    if player.isOwner ~= 1 then
        skynet.error("不是房主")
        return false
    end

    if room.status == 1 then
        skynet.error("正在战斗中")
        return false
    end

    skynet.error("1 scene startBattle roomid:" .. room.id)

    local isok = checkCampCount(room)
    if not isok then
        return false
    end

    room.status = 1

    skynet.error("2 scene startBattle roomid:" .. room.id)

    resetPlayers(room)

    skynet.error("3 scene startBattle roomid:" .. room.id)

    local enterbattlemsg = {
        tanks = {},
        mapId = 1,
    }
    for i, _ in pairs(room.playerIds) do
        local player = mainPlayers[i]
        local tankinfo = getTankInfo()
        tankinfo.camp = player.camp
        tankinfo.id = player.playerid
        tankinfo.hp = player.hp
        tankinfo.x = player.x
        tankinfo.y = player.y
        tankinfo.z = player.z
        tankinfo.ex = player.ex
        tankinfo.ey = player.ey
        tankinfo.ez = player.ez
        table.insert(enterbattlemsg.tanks, tankinfo)
    end

    roomBroadMsg("BattleMsg.MsgEnterBattle", enterbattlemsg, room.id)


    return true
end


s.resp.syncTank = function(source, splayer, msg)
    local player = mainPlayers[splayer.id]
    local room = rooms[player.roomId]

    if not player or not room then
        skynet.error("玩家不存在" .. splayer.id)
        return false
    end
    if room.status == 0 then
        skynet.error("房间不存在" .. player.roomId)
        return false
    end

    player.x = msg.x
    player.y = msg.y
    player.z = msg.z
    player.ex = msg.ex
    player.ey = msg.ey
    player.ez = msg.ez
    player.turretY = msg.turretY

    msg.id = splayer.id

    roomBroadMsg("SyncMsg.MsgSyncTank", msg, room.id)
    return true
end

s.resp.msgFire = function(source, splayer, msg)
    local player = mainPlayers[splayer.id]
    local room = rooms[player.roomId]
    if not player or not room then
        skynet.error("玩家不存在 或者 房间不存在" .. splayer.id)
        return false
    end
    if room.status == 0 then
        skynet.error("room非对战状态" .. player.roomId)
        return false
    end
    msg.id = splayer.id

    roomBroadMsg("SyncMsg.MsgFire", msg, room.id)
    return true
end


s.resp.msgHit = function(source, splayer, msg)
    local player = mainPlayers[splayer.id]
    local targetPlayer = mainPlayers[msg.targetId]
    local room = rooms[player.roomId]
    if not player or not targetPlayer or not room then
        skynet.error("玩家不存在 或者 房间不存在" .. splayer.id)
        return false
    end
    if room.status == 0 then
        skynet.error("room非对战状态" .. player.roomId)
        return false
    end

    if splayer.id ~= msg.id then
        skynet.error("玩家id不一致" .. splayer.id .. " " .. msg.id)
        return false
    end

    local damage = 35
    targetPlayer.hp = targetPlayer.hp - damage
    msg.id = splayer.id
    msg.hp = targetPlayer.hp
    msg.damage = damage

    roomBroadMsg("SyncMsg.MsgHit", msg, room.id)
    return true
end




local roomUpdate = function(room)
    if room.status == 0 then
        return
    end

    local timestamp = os.time()
    if timestamp - room.lastJudgeTime < 10 then
        return
    end
    room.lastJudgeTime = timestamp
    local winCamp = judagement(room)
    if winCamp == 0 then
        return
    end
    room.status = 0

    for i, _ in pairs(room.playerIds) do
        local player = mainPlayers[i]
        if player.camp == winCamp then
            player.win = player.win + 1
        else
            player.lost = player.lost + 1
        end
    end

    local battleresultmsg = {}
    battleresultmsg.winCamp = winCamp
    roomBroadMsg("BattleMsg.MsgBattleResult", battleresultmsg, room.id)
end
















--******************************************


--球列表
local function balllist_msg()
    local msg = { players = {} } -- 创建一个包含 players 数组的消息表

    for _, v in ipairs(balls) do
        -- 创建一个新的 playerinfo 消息
        local player = mkdata.ball()
        player.playerid = v.playerid
        player.x = v.x
        player.y = v.y
        player.size = v.size
        table.insert(msg.players, player) -- 将 playerinfo 添加到 players 数组中
    end

    return msg -- 返回 balllist 格式的消息
end

--食物列表
local function foodlist_msg()
    local msg = { foods = {} } -- 创建一个包含 foods 数组的消息表

    for _, v in ipairs(foods) do
        -- 创建一个新的 foodinfo 消息
        local food = mkdata.food()
        food.fid = v.fid
        food.x = v.x
        food.y = v.y
        table.insert(msg.foods, food) -- 将 foodinfo 添加到 foods 数组中
    end

    return msg -- 返回 foodlist 格式的消息
end

--广播
function broadcast(cmd, msg)
    for i, v in pairs(balls) do
        s.send(v.node, v.agent, "send", cmd, msg)
    end
end

--进入
s.resp.enter = function(source, playerid, node, agent)
    if balls[playerid] then
        return false
    end
    local resmsg = {}

    local b = mkdata.ball()
    b.playerid = playerid
    b.node = node
    b.agent = agent
    --广播
    resmsg.player = {
        id = playerid,
        x = b.x,
        y = b.y,
        size = b.size
    }
    resmsg.result = 0
    resmsg.reason = "进入成功"
    broadcast("Battle.enter", resmsg)
    --记录
    balls[playerid] = b
    --回应
    s.send(b.node, b.agent, "send", "Battle.enter", resmsg)
    --发战场信息
    s.send(b.node, b.agent, "send", "Battle.balllist", balllist_msg())
    s.send(b.node, b.agent, "send", "Battle.foodlist", foodlist_msg())
    return true
end

--退出
s.resp.leave = function(source, playerid)
    if not balls[playerid] then
        return false
    end
    balls[playerid] = nil

    local leavemsg = {}
    leavemsg.id = playerid
    broadcast("Battle.leave", leavemsg)
end

--改变速度
s.resp.shift = function(source, playerid, x, y)
    local b = balls[playerid]
    if not b then
        return false
    end
    b.speedx = x
    b.speedy = y
end


function food_update()
    if food_count > 10 then
        return
    end

    if math.random(1, 100) < 98 then
        return
    end

    food_maxid = food_maxid + 1
    food_count = food_count + 1
    local f = mkdata.food()
    f.fid = food_maxid
    foods[f.fid] = f

    local msg = {}
    msg.fid = f.fid
    msg.x = f.x
    msg.y = f.y
    broadcast("Battle.addfood", msg)
end

function move_update()
    for i, v in pairs(balls) do
        v.x = v.x + v.speedx * 0.2
        v.y = v.y + v.speedy * 0.2
        if math.abs(v.speedx) > 1e-6 or math.abs(v.speedy) > 1e-6 then
            local msg = {}
            msg.id = v.playerid
            msg.x = v.x
            msg.y = v.y
            broadcast("Battle.move", msg)
        end
    end
end

function eat_update()
    for pid, b in pairs(balls) do
        for fid, f in pairs(foods) do
            if (b.x - f.x) ^ 2 + (b.y - f.y) ^ 2 < b.size ^ 2 then
                b.size = b.size + 1
                food_count = food_count - 1
                local msg = {}
                msg.id = b.playerid
                msg.fid = fid
                msg.size = b.size
                broadcast("Battle.eat", msg)
                foods[fid] = nil --warm
            end
        end
    end
end

function update(frame)
    for i, v in pairs(rooms) do
        --房间更新
        roomUpdate(v)
    end



    --food_update()
    --move_update()
    --eat_update()
    --碰撞略
    --分裂略
end

s.init = function()
    skynet.fork(function()
        --保持帧率执行
        local stime = skynet.now()
        local frame = 0
        while true do
            frame = frame + 1
            local isok, err = pcall(update, frame)
            if not isok then
                skynet.error(err)
            end
            local etime = skynet.now()
            local waittime = frame * 20 - (etime - stime)
            if waittime <= 0 then
                waittime = 2
            end
            skynet.sleep(waittime)
        end
    end)
end

s.start(...)
