
local zv = require "zv"
local redis = require "db.redis_proxy"
local mysql = require "db.mysql_proxy"
require "util"

local tab_concat = table.concat
local unpack = unpack

local hots = {}
local checks = {}

local _M = {}
local rds,mydb

--[[
    {field, auto_inc, default, type}
]]

local remember_insert_into = Remember(function (t, table)
    local schema = assert(hots[table])
    local sql = {"insert into ", table, "("}
    local auto_inc = schema[1][2] == "ai" -- whether auto_increment
    local fields = {}
    for i=auto_inc and 2 or 1, #schema do
        fields[#fields+1] = schema[i][1]
    end
    sql[#sql+1] = tab_concat(fields, ",")
    sql[#sql+1] = ")";
    local sqlstr = tab_concat(sql)
    t[table] = sqlstr
    return sqlstr
end)

local remember_select_all_on_one_line = Remember(function (t, table)
    local schema = assert(hots[table])
    local sql = {"select * from ", table, " where ", schema[1][1], "="}
    local sqlstr = tab_concat(sql)
    t[table] = sqlstr
    return sqlstr
end)

local function to_string(col, obj)
    if col[4] == "string" then
        return "'" .. (obj[col[1]] or col[3]) .. "'"
    end
    return obj[col[1]] or col[3]
end

local function values(table, obj)
    local schema = assert(hots[table])
    local auto_inc = schema[1][2] == "ai" -- whether auto_increment
    local sql = {"values("}
    local data = {}
    for i=auto_inc and 2 or 1, #schema do
        data[#data+1] = to_string(schema[i], obj)
    end
    sql[#sql+1] = tab_concat(data, ',')
    sql[#sql+1] = ")"
    return tab_concat(sql)
end

local function select_some_on_one_line(table, pk_value, ...)
    local schema = assert(hots[table])
    local sql = {"select "}
    local fields = {...}
    sql[#sql+1] = tab_concat(fields, ",")
    sql[#sql+1] = " from "
    sql[#sql+1] = table
    sql[#sql+1] = " where "
    sql[#sql+1] = schema[1][1]
    sql[#sql+1] = "="
    sql[#sql+1] = pk_value
    return mydb:query(tab_concat(sql))
end

local function to_string_by_type(typ, val)
    if type == "string" then
        return "'" .. val .. "'"
    end
    return val
end

local function update_some_on_one_line(table, pk_value, kvs, inc)
    local chk = assert(checks[table])
    local schema = assert(hots[table])
    local sql = {"update ", table, " set "}
    local sets = {}
    for k, v in pairs(kvs) do
        local typ = assert(chk[k])
        if inc then
            local set = {k,"=",k}
            if v > 0 then
                set[#set+1] = '+'
            end
            set[#set+1] = v
            sets[#sets+1] = tab_concat(set)
        else
            sets[#sets+1] = k .. "=" .. to_string_by_type(typ, v)
        end
    end
    sql[#sql+1] = tab_concat(sets, " ")
    sql[#sql+1] = " where "
    sql[#sql+1] = schema[1][1]
    sql[#sql+1] = "="
    sql[#sql+1] = pk_value
    local sqlstr = tab_concat(sql)
    print(sqlstr)
    return mydb:query(sqlstr)
end

local function hmget_some_field_on_one_key(table, pk_value, ...)
    local chk = assert(checks[table])
    local key = table .. ":" .. pk_value
    for _, field in ipairs({...}) do
        assert(chk[field])
    end
    return rds:hmget(key, ...)
end

function _M.init()
    local err
    rds, err = redis.instance("127.0.0.1", 6379)
    if not rds then
        print("failed to connect redis:", err)
        return
    end
    mydb, err = mysql.instance("127.0.0.1", 3306, {
        database = "practice",
        user = "debian-sys-maint",
        password = "YjjjR1FWtCEHNZ0Q",
    })
    if not mydb then
        print("failed to connect mysql:", err)
        return
    end
end

function _M.get_redis()
    return assert(rds)
end

function _M.get_mysql()
    return assert(mydb)
end

function _M.register(table, schema)
    if hots[table] then
        print("repeat register hots schema:", table)
    end
    hots[table] = schema
    local chk = {}
    for _, col in ipairs(schema) do
        chk[col[1]] = col[4]
    end
    checks[table] = chk
end

function _M.new_obj(table, obj)
    assert(mydb)
    local sqlstr = remember_insert_into[table] .. values(table, obj)
    print(sqlstr)
    return mydb:query(sqlstr)
end

function _M.get_obj(table, pk_value, ...)
    assert(rds and mydb, "please call init first")
    local n = select("#", ...)
    local res, err
    local exist = true
    local rds_key = table .. ":" .. pk_value
    if n == 0 then
        res, err = rds:hgetall(rds_key)
        exist = next(res) ~= nil
        print("try get data from redis ... ")
        if not res or not exist then
            print("try get data from mysql ... ")
            local sqlstr = remember_select_all_on_one_line[table] .. pk_value
            res, err = mydb:query(sqlstr)
            assert(res, err) -- mysql get error
        end
    else
        res, err = hmget_some_field_on_one_key(table, pk_value, ...)
        exist = next(res) ~= nil
        print("try get data from redis ... ")
        if not res or not exist then
            print("try get data from mysql ... ")
            res, err = select_some_on_one_line(table, pk_value, ...)
            assert(res, err) -- mysql get error
        end
    end
    if not exist then
        -- async write to redis
        zv.fork(function ()
            local kvs = {}
            for k,v in pairs(res[1]) do
                kvs[#kvs+1] = k
                kvs[#kvs+1] = v
            end
            rds:hmset(rds_key, unpack(kvs))
        end)
    end
    return res
end

function _M.set_obj(table, pk_value, kvs)
    assert(rds and mydb, "please call init first")
    --[[
        -- option one：delete key
        -- option two: update key set expire
    ]]
    local rds_key = table .. ":" .. pk_value

    local res, err = rds:del(rds_key)
    print("try set data to mysql ... ")
    res, err = update_some_on_one_line(table, pk_value, kvs, false)
    assert(res, err)
    return res
end

function _M.inc_obj(table, pk_value, kvs)
    assert(rds and mydb, "please call init first")
    local rds_key = table .. ":" .. pk_value
    local res, err = rds:del(rds_key)
    res, err = update_some_on_one_line(table, pk_value, kvs, true)
    assert(res, err)
    return res
end

function _M.del_obj(table, pk_value)
    assert(rds and mydb, "please call init first")
    local schema = assert(hots[table])
    local rds_key = table .. ":" .. pk_value
    local res, err = rds:del(rds_key)
    local sql = {"delete from ", table, " where ", schema[1][1], "=", pk_value}
    res, err = mydb:query(tab_concat(sql))
    assert(res, err)
    return res
end

return _M
