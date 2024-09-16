local data = {}

data.getPlayerdata = function()
    local m = {
        playerid = 102,
        coin = 100,
        name = "yemo",
        level = 3,
        last_login_time = 5,
    }
    return m
end



-- 连接类
data.conn = function()
    local m = {
        fd = nil,
        playerid = nil,
    }
    return m
end

-- 玩家类
data.gateplayer = function()
    local m = {
        playerid = nil,
        agent = nil,
        conn = nil,
    }
    return m
end

--玩家类
data.mgrplayer = function()
    local m = {
        playerid = nil,
        node = nil,
        agent = nil,
        status = nil,
        gate = nil,
    }
    return m
end


--球
data.ball = function()
    local m = {
        playerid = nil,
        node = nil,
        agent = nil,
        x = math.random(0, 10),
        y = math.random(0, 10),
        size = 1,
        speedx = 0,
        speedy = 0,
    }
    return m
end


--食物
data.food = function()
    local m = {
        fid = nil,
        x = math.random(0, 10),
        y = math.random(0, 10),
    }
    return m
end


return data
