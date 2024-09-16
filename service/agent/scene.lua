local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

s.snode = nil --scene_node
s.sname = nil --scene_id

local function random_scene()
    --选择node
    local nodes = {}
    for i, v in pairs(runconfig.scene) do
        table.insert(nodes, i)
        if runconfig.scene[mynode] then
            table.insert(nodes, mynode)
        end
    end
    local idx = math.random(1, #nodes)
    local scenenode = nodes[idx]
    --具体场景
    local scenelist = runconfig.scene[scenenode]
    local idx = math.random(1, #scenelist)
    local sceneid = scenelist[idx]
    return scenenode, sceneid
end

s.client.enterMain = function()
    skynet.error("agent scene enterMain")
    if s.sname then
        skynet.error("已在场景")
        local isok, ret = s.call(s.snode, s.sname, "getRoomlist", s.player)
        if not isok then
            skynet.error("获取房间列表失败")
            return nil
        end
        if not ret then
            skynet.error("ret rooms is nil")
            return nil
        end
        return ret
    end

    local snode, sid = random_scene()
    local sname = "scene" .. sid
    local isok, ret = s.call(snode, sname, "enterMain", s.player, mynode, skynet.self())
    if not isok then
        skynet.error("进入失败")
        return
    end
    s.snode = snode
    s.sname = sname

    if not ret then
        skynet.error("ret rooms is nil")
    end
    return ret
end

s.client.enter = function(msg)
    local respmsg = {}
    if s.sname then
        respmsg.result = 1
        respmsg.resaon = "已在场景"

        return respmsg
    end
    local snode, sid = random_scene()
    local sname = "scene" .. sid
    local isok = s.call(snode, sname, "enter", s.id, mynode, skynet.self())
    if not isok then
        respmsg.result = 1
        respmsg.resaon = "进入失败"
        return respmsg
    end
    s.snode = snode
    s.sname = sname

    return nil
end

--改变方向
s.client.shift = function(msg)
    if not s.sname then
        return
    end
    local x = msg.x or 0
    local y = msg.y or 0

    s.call(s.snode, s.sname, "shift", s.id, x, y)
end

s.client.leave = function()
    --不在场景
    if not s.sname then
        return
    end
    s.call(s.snode, s.sname, "leave", s.id)
    s.snode = nil
    s.sname = nil
end
