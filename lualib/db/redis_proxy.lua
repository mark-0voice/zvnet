
local zv = require "zv"

local redis = require "db.redis"

local socket = require "socket"

local db = false

local disconnected = false

local proxy = {}

local backlog = {}

local _M = {}

local tab_remove = table.remove

local function redis_eventloop()
    assert(db)
    local res, err
    local fd = rawget(db, "_sock")
    socket.rebind(fd)
    while true do
        res, err = db:read_result()
        if disconnected then return end
        assert(#backlog > 0)
        local co = tab_remove(backlog, 1)
        zv.co_resume(co, res, err)
    end
end

local function instance(host, port)
    if not db then
        local err
        db, err = redis.new(host, port, {proxy = true})
        assert(db, err)
        local fd = rawget(db, "_sock")
        disconnected = false
        socket.onclose(fd, function ()
            disconnected = true
            socket.close(fd)
            for _, co in ipairs(backlog) do
                zv.co_resume(co, nil, "closed")
            end
            backlog = {}
            setmetatable(proxy, {
                __index = function (_, cmd)
                    return function (_, ...)
                        print("try reconnect redis ...")
                        db = false
                        proxy = instance(host, port)
                    end
                end
            })
        end)
        proxy = setmetatable({db}, {
            __index = function (_, cmd)
                return function (self, ...)
                    local res, err = self[1][cmd](self[1], ...)
                    if res then
                        backlog[#backlog+1] = zv.co_running()
                        local fd = rawget(db, "_sock")
                        zv.co_attach(fd)
                        res, err = zv.co_yield()
                        zv.co_detach(fd)
                    end
                    return res, err
                end
            end
        })
        zv.fork(redis_eventloop)
    end
    return proxy
end

_M.instance = instance

function proxy.new(...)
    assert(false, "please use instance interface in proxy mode")
end

function proxy.set_keepalive(...)
    assert(false, "cant use set_keepalive in proxy mode")
end

function proxy.read_result(...)
    assert(false, "cant use `read_result`")
end

return _M
