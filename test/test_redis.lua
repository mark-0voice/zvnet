
package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local socket = require "socket"
local evloop = require "evloop"

local redis = require "db.redis"

evloop.start()

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
end

socket.bind(0, console_loop)

evloop.run()