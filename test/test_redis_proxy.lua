
package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local evloop = require "evloop"
local redis = require "db.redis_proxy"
local zv = require "zv"

evloop.start()

local function test_loop()
    local rds, err = redis.instance("127.0.0.1", 6379)
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
    print("name:", res, #res)
    -- shell: restart redis
    zv.sleep(1000) -- sleep 10 seconds
    res, err = rds:get("name")
    print("name:", res, err)
end

zv.fork(test_loop)

evloop.run()