
package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local evloop = require "evloop"
local mysql = require "db.mysql_proxy"
local zv = require "zv"
require "util"

evloop.start()

local function test_loop()
    local db, err = mysql.instance("127.0.0.1", 3306, {
        database = "practice",
        user = "debian-sys-maint",
        password = "YjjjR1FWtCEHNZ0Q",
    })
    if not db then
        print("failed to connect mysql:", err)
        return
    end
    local res, _ = db:query("select * from score order by sid limit 10", 10)
    print("=>", table.dump(res))
    -- shell: service mysql restart
    zv.sleep(1000) -- sleep 10 seconds
    res, _ = db:query("select * from score order by sid limit 10", 10)
    print("=>", table.dump(res))
end

zv.fork(test_loop)

evloop.run()