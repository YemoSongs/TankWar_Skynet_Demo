local skynet = require "skynet"
require "skynet.manager"

local s = require "service"
local runconfig = require "runconfig"
local socketdriver = require "skynet.socketdriver"
local netpack = require "skynet.netpack"

local protomsg = require "protomsg"

local mkdata = require "makedata"

local queue -- message queue


conns = {}   --[socket_id] = conn
players = {} --[playerid] = gateplayer


local closing = false --不再接收新连接

local listenfd = nil


s.resp.shutdown = function()
    --skynet.error("  id" .. s.id .. s.name)
    closing = true
end




-- 清理队列
local function clear_queue()
    if queue then
        netpack.clear(queue)
        queue = nil
    end
end




--有新连接时
local connect = function(fd, addr)
    if closing then --不接收新连接
        return
    end
    skynet.error("new conn fd:" .. fd .. " addr:" .. addr)
    socketdriver.start(fd)

    local c = mkdata.conn()
    conns[fd] = c
    c.fd = fd
end



-- 断开连接
local disconnect = function(fd)
    local c = conns[fd]
    if not c then
        return
    end

    local playerid = c.playerid
    if not playerid then
        return
    else
        players[playerid] = nil
        local reason = "断线"
        skynet.call("agentmgr", "lua", "reqkick", playerid, reason)
    end
end




-- 有新连接
function process_connect(fd, addr)
    connect(fd, addr) -- 调用 connect 函数以处理新连接
end

-- 关闭连接
function process_close(fd)
    skynet.error("close fd:" .. fd)
    disconnect(fd)
end

-- 发生错误
function process_error(fd, error)
    skynet.error("error fd:" .. fd .. " error:" .. error)
end

-- 发生警告
function process_warning(fd, size)
    skynet.error("warning fd:" .. fd .. " size:" .. size)
end

-- 处理单条消息
function process_msg(fd, msg, sz)
    local str = netpack.tostring(msg, sz)
    --skynet.error("recv from fd:" .. fd .. "size:" .. sz)

    -- 继续处理解包后的字符串消息
    local cmd, msg_tbl = protomsg.msg_unpack(str)
    skynet.error("[process_msg] recv " .. fd .. " [" .. cmd .. "]")



    local conn = conns[fd]
    local playerid = conn.playerid
    if not playerid then
        -- 尚未完成登录流程
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1, #nodecfg.login)
        local login = "login" .. loginid
        skynet.error("未完成登录流程，尝试登录 " .. login)
        skynet.send(login, "lua", "client", fd, cmd, msg_tbl)
    else
        -- 已完成登录流程
        local gplayer = players[playerid]
        local agent = gplayer.agent
        skynet.error("已登录，转发消息 " .. fd .. " [" .. cmd .. "]")
        skynet.send(agent, "lua", "client", cmd, msg_tbl)
    end
end

-- 处理多个消息
function process_more()
    for fd, msg, sz in netpack.pop, queue do
        skynet.fork(process_msg, fd, msg, sz)
    end
end

-- 解码底层传来的 SOCKET 类型消息
function socket_unpack(msg, sz)
    return netpack.filter(queue, msg, sz)
end

-- 处理底层传来的 SOCKET 类型消息
function socket_dispatch(_, _, q, type, ...)
    queue = q
    if type == "open" then
        process_connect(...)
    elseif type == "data" then
        process_msg(...)
    elseif type == "more" then
        process_more(...)
    elseif type == "close" then
        process_close(...)
    elseif type == "error" then
        process_error(...)
    elseif type == "warning" then
        process_warning(...)
    end
end

-- 发送消息
--用于login服务的消息转发，功能是将消息发送到指定fd的客户端。
s.resp.send_by_fd = function(source, fd, cmd, msg)
    if not conns[fd] then
        skynet.error("send_by_fd fail fd")
        return
    end
    --skynet.error("send_by_fd CMD:" .. cmd)

    local buff = protomsg.msg_pack(cmd, msg)
    skynet.error("send " .. fd .. " cmd:" .. cmd)
    socketdriver.send(fd, buff)
end




--用于agent的消息转发，功能是将消息发送给指定玩家id的客户端。
s.resp.send = function(source, playerid, cmd, msg)
    --skynet.error("send CMD:" .. cmd .. "id:" .. playerid .. type(playerid))
    local pid = tostring(playerid)
    local gplayer = players[pid]
    if gplayer == nil then
        skynet.error("gplayer nil" .. cmd)
        return
    end
    local c = gplayer.conn
    if c == nil then
        skynet.error("gplayer conn nil" .. cmd)
        return
    end

    s.resp.send_by_fd(nil, c.fd, cmd, msg)
end

-- 确认 agent
s.resp.sure_agent = function(source, fd, playerid, agent)
    local conn = conns[fd]
    if not conn then -- 登陆过程中已经下线
        skynet.call("agentmgr", "lua", "reqkick", playerid, "未完成登陆即下线")
        return false
    end
    skynet.error("sure_agent playerid:" .. playerid)
    conn.playerid = playerid

    local gplayer = mkdata.gateplayer()
    gplayer.playerid = playerid

    gplayer.agent = agent
    gplayer.conn = conn
    players[playerid] = gplayer
    if not players[playerid] then
        skynet.error("sure_agent gplayer nil" .. gplayer.playerid)
    end

    return true
end



-- 踢出玩家
s.resp.kick = function(source, playerid)
    local gplayer = players[playerid]
    if not gplayer then
        return
    end

    local c = gplayer.conn
    players[playerid] = nil

    if not c then
        return
    end
    conns[c.fd] = nil

    disconnect(c.fd)
    socketdriver.close(c.fd)
end

-- 初始化服务
function s.init()
    local node = skynet.getenv("node")
    local nodecfg = runconfig[node]
    local port = nodecfg.gateway[s.id].port

    protomsg.register_protos() -- 注册所有协议文件


    --注册SOCKET类型消息
    skynet.register_protocol({
        name = "socket",
        id = skynet.PTYPE_SOCKET,
        unpack = socket_unpack,
        dispatch = socket_dispatch,
    })


    listenfd = socketdriver.listen("0.0.0.0", port)
    skynet.error("Listen socket:", "0.0.0.0", port, listenfd)
    socketdriver.start(listenfd)
end

s.start(...)
