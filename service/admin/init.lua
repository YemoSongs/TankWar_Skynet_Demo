local skynet = require "skynet"
local socket = require "skynet.socket"
local s = require "service"
local runconfig = require "runconfig"
require "skynet.manager"

function shutdown_gate()
    for node, _ in pairs(runconfig.cluster) do
        local nodecfg = runconfig[node]
        for i, v in pairs(nodecfg.gateway or {}) do
            local name = "gateway" .. i
            s.call(node, name, "shutdown")
        end
    end
end

function shutdown_agent()
    local anode = runconfig.agentmgr.node
    while true do
        local online_num = s.call(anode, "agentmgr", " shutdown", 1)
        if not online_num or online_num <= 0 then
            skynet.error("agentmgr shutdown ok")
            break
        end
        skynet.error("agentmgr shutdown online:" .. online_num)
        skynet.sleep(100)
    end
end

function stop()
    shutdown_gate()
    shutdown_agent()
    --...
    skynet.abort() --结束skynet进程
    return "ok"
end

function connect(fd, addr)
    socket.start(fd)
    socket.write(fd, "Please enter cmd\r\n")
    local cmd = socket.readline(fd, "\r\n")
    if cmd == "stop" then
        stop()
    else
        --......
    end
end

s.init = function()
    local listenfd = socket.listen("127.0.0.1", 8888)
    skynet.error("admin Listening socket:", listenfd)
    socket.start(listenfd, connect)
end

s.start(...)
