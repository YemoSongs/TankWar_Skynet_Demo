local skynet = require "skynet"
local s = require "service"

s.client = {}
s.resp.client = function(source, fd, cmd, msg)
    local dot_index = string.find(cmd, "%.")         -- 找到 '.' 的位置
    local local_cmd = string.sub(cmd, dot_index + 1) -- 从 '.' 后的下一个字符开始截取

    if s.client[local_cmd] then
        local ret_msg = s.client[local_cmd](fd, msg, source)
        skynet.send(source, "lua", "send_by_fd", fd, cmd, ret_msg)
    else
        skynet.error("s.resp.client fail", cmd)
    end
end


s.client.login = function(fd, msg, source)
    local playerid = msg.id
    local playerpw = msg.pw
    local gate = source
    node = skynet.getenv("node")

    skynet.error("loginId:" .. playerid .. "pw:" .. playerpw)

    local out_msg = {
        id = playerid,
        pw = playerpw,
        result = 1,
    }

    --校验用户名密码
    if playerpw ~= "123" then
        skynet.error("[pw is not] id:" .. playerid)
        return out_msg
    end
    --发给agentmgr
    local isok, agent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gate)
    if not isok then
        skynet.error("[请求mgr失败] id:" .. playerid)
        return out_msg
    end
    --回应gate
    local isok = skynet.call(gate, "lua", "sure_agent", fd, playerid, agent)
    if not isok then
        skynet.error("[gate注册失败] id:" .. playerid)
        return out_msg
    end

    skynet.error("[login succ] id" .. playerid)
    out_msg.result = 0
    return out_msg
end


s.client.MsgLogin = function(fd, msg, source)
    local playerid = msg.id
    local playerpw = msg.pw
    local gate = source
    node = skynet.getenv("node")

    skynet.error("loginId:" .. playerid .. "pw:" .. playerpw)

    local ret_msg = {
        id = playerid,
        pw = playerpw,
        result = 1,
    }

    --校验用户名密码
    local isok = nil
    local success,err = pcall(function()
        isok = skynet.call("db","lua","login_account",playerid,playerpw)
    end)
    -- 检查 pcall 是否成功
    if not success then
        skynet.error("[数据库login出错]:", err)
        return ret_msg
    end
    if not isok then
        skynet.error("[数据库login出错]:", err,"ret_msg"..ret_msg.id..ret_msg.pw..ret_msg.result)
        return ret_msg
    end

    --发给agentmgr
    local isok, agent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gate)
    if not isok then
        skynet.error("[请求mgr失败] id:" .. playerid)
        return ret_msg
    end
    --回应gate
    local isok = skynet.call(gate, "lua", "sure_agent", fd, playerid, agent)
    if not isok then
        skynet.error("[gate注册失败] id:" .. playerid)
        return ret_msg
    end

    skynet.error("[login succ] id" .. playerid)
    ret_msg.result = 0
    return ret_msg
end




s.client.MsgRegister = function(fd,msg,source)

    local ret_msg = {}
    ret_msg.id = msg.id
    ret_msg.pw = msg.pw
    ret_msg.result = 1
    local gate = source
    node = skynet.getenv("node")

    skynet.error("RegisterId:" .. ret_msg.id .. "pw:" .. ret_msg.pw)

    local isok = nil
    local success,err = pcall(function()
        isok = skynet.call("db","lua","register_account",ret_msg.id,ret_msg.pw)
    end)
    -- 检查 pcall 是否成功
    if not success then
        skynet.error("[数据库Register出错]:", err)
        return ret_msg
    end

    if not isok then
        skynet.error("[数据库Register出错]:", err)
        return ret_msg
    end

    ret_msg.result = 0

    return ret_msg

end





s.start(...)
