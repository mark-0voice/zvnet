
package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local socket = require "socket"
local evloop = require "evloop"

local mysql = require "db.mysql"

evloop.start()

local function console_loop(_)
    local db, err = mysql.new("127.0.0.1", 3306, {
        database = "practice",
        user = "debian-sys-maint",
        password = "YjjjR1FWtCEHNZ0Q",
    })
    if not db then
        print("connect mysql err:", err)
        return
    end
    print("begin query")
    local res, err, errno, sqlstate
    res, err, errno, sqlstate = db:query("select * from score order by sid limit 10", 10)
    if not res then
        print("bad result #1: ", err, ": ", errno, ": ", sqlstate, ".")
        return
    end
    for _, row in ipairs(res) do
        local ncols = 0
        for k, v in pairs(row) do
            ncols = ncols + 1
        end
        print("ncols: ", ncols)
    end
end

socket.bind(0, console_loop)

evloop.run()