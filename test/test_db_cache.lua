
package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local evloop = require "evloop"
local cache = require "db.dbcache"
local zv = require "zv"
require "util"

evloop.start()

-- first line use to desc primary key
cache.register("user", {
    {"id", "", 0, "number"},
    {"nick", "", "", "string"},
    {"height", "", 175, "number"},
    {"sex", "", '1', "string"},
    {"age", "", 30, "number"},
})

local function test_loop()
    cache.init()
    -- local res, err = cache.new_obj("user", {
    --     id = 10002,
    --     nick = "darren",
    --     height = 180,
    --     -- sex = '1',
    --     age = 30,
    -- })
    -- print(table.dump(res), table.dump(err))

    -- local res, err = cache.get_obj("user", 10001, "age")
    -- print(table.dump(res), err)

    -- local res, err = cache.set_obj("user", 10001, {age = 31})
    -- print(table.dump(res), table.dump(err))

    -- local res, err = cache.inc_obj("user", 10001, {age = -1})
    -- print(table.dump(res), table.dump(err))

    -- local res, err = cache.del_obj("user", 10001)
    -- print(table.dump(res), table.dump(err))
end

zv.fork(test_loop)

evloop.run()