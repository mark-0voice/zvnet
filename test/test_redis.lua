
package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local zv = require "zv"
local socket = require "socket"
local evloop = require "evloop"

local redis = require "db.redis"
require "util"
evloop.start()

local tab_concat = table.concat

local function is_action_allowed(red, userid, action, period, max_count)
    local key = tab_concat({"hist", userid, action}, ":")
    local now = zv.time()
    red:init_pipeline()
    red:multi()
    -- 记录行为
    red:zadd(key, now, now)
    -- 移除时间窗口之前的行为记录，剩下的都是时间窗口内的记录
    red:zremrangebyscore(key, 0, now - period *100)
    -- 获取时间窗口内的行为数量
    red:zcard(key)
    -- 设置过期时间，避免冷用户持续占用内存 时间窗口的长度+1秒
    red:expire(key, period + 1)
    red:exec()
    local res = red:commit_pipeline()
    print(table.dump(res[6][3]))
    return (tonumber(res[6][3]) or 0) <= max_count
end

local function console_loop(_)
    local rds, err = redis.new("127.0.0.1", 6379)
    if not rds then
        print("failed to connect redis:", err)
        return
    end
    local ok
    ok, err = rds:set("name", "zero voice")
    if not ok then
        print("failed to set name: ", err)
        return
    end
    local res
    res, err = rds:get("name")
    if not res then
        print("failed to get name: ", err)
        return
    end
    if res == null then
        print("name not found.")
        return
    end
    print("name:", res)

    for i = 1, 10 do
        local can_reply = is_action_allowed(rds, 10001, "replay", 5, 5)
        if can_reply then
            print("can reply")
        else
            print("cant replay")
        end
        zv.sleep(10)
    end
end

socket.bind(0, console_loop)

evloop.run()