local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"

skynet.start(function()
    --初始化
    local mynode = skynet.getenv("node")
    local nodecfg = runconfig[mynode]

    --节点管理
    local nodemgr = skynet.newservice("nodemgr", "nodemgr", 0)
    skynet.name("nodemgr", nodemgr)
    --集群
    cluster.reload(runconfig.cluster)
    cluster.open(mynode)
    --gate
    for i, v in pairs(nodecfg.gateway or {}) do
        local srv = skynet.newservice("gateway", "gateway", i)
        skynet.name("gateway" .. i, srv)
    end
    --login
    for i, v in pairs(nodecfg.login or {}) do
        local srv = skynet.newservice("login", "login", i)
        skynet.name("login" .. i, srv)
    end
    --agentmgr
    local anode = runconfig.agentmgr.node
    if mynode == anode then
        local srv = skynet.newservice("agentmgr", "agentmgr", 0)
        skynet.name("agentmgr", srv)
    else
        local proxy = cluster.proxy(anode, "agentmgr")
        skynet.name("agentmgr", proxy)
    end
    --数据库服务
    local dbnode = runconfig.db.node
    if mynode == dbnode then
        local srv = skynet.newservice("db", "db", 0)
        skynet.name("db", srv)
    else
        local proxy = cluster.proxy(dbnode, "db")
        skynet.name("db", proxy)
    end


    --admin
    local adnode = runconfig.admin.node
    if mynode == adnode then
        local admin = skynet.newservice("admin", "admin", 0)
        skynet.name("admin", admin)
    else
        local proxy = cluster.proxy(adnode, "admin")
        skynet.name("admin", proxy)
    end


    --scene(sid->sceneid)
    for _, sid in pairs(runconfig.scene[mynode] or {}) do
        local srv = skynet.newservice("scene", "scene", sid)
        skynet.name("scene" .. sid, srv)
    end


    --test


    --[[local isok, player = skynet.call("db", "lua", "selectdata", 102)
    if not isok then
        skynet.error("[数据库查询测试失败]")
    else
        skynet.error("[数据库查询测试] :" .. player.playerid .. " " .. player.name)
    end]]




    --[[
    local isok = skynet.call("db", "lua", "deldata", 102)
    if isok then
        skynet.error("[数据库删除测试成功] ")
    end]]


    --退出自身
    skynet.exit()
end)
