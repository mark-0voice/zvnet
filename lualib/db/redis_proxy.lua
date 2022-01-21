
local zv = require "zv"

local redis = require "db.redis"

local socket = require "socket"

local db = false

local disconnected = true

local proxy = {}

local backlog = {}

local pipeline_reqs = {}
local pipeline_resp = {}

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
        local nreqs = pipeline_resp[co]
        if nreqs then
            local nvals = 0
            local vals = {}
            while true do
                if res then
                    nvals = nvals + 1
                    vals[nvals] = res
                elseif res == nil then
                    db:close()
                    vals = nil
                    pipeline_resp[co] = nil
                    break
                else
                    nvals = nvals + 1
                    vals[nvals] = {false, err}
                end
                if nvals >= nreqs then
                    pipeline_resp[co] = nil
                    res = vals
                    break
                end
                res, err = db:read_result()
            end
        end
        zv.co_resume(co, res, err)
    end
end

local function proxy_metafunc(tab, cmd)
    local function wait_for_response(self, ...)
        local running = zv.co_running()
        if cmd == "commit_pipeline" then
            pipeline_resp[running] = #pipeline_reqs[running]
            pipeline_reqs[running] = nil
        end
        local res, err = self[1][cmd](self[1], ...)
        if pipeline_reqs[running] then
            return
        end
        if res then
            backlog[#backlog+1] = zv.co_running()
            local fd = rawget(db, "_sock")
            zv.co_attach(fd)
            res, err = zv.co_yield()
            zv.co_detach(fd)
        end
        return res, err
    end
    tab[cmd] = wait_for_response
    return wait_for_response
end

local function init_pipeline(_)
    assert(db)
    local running = zv.co_running()
    if pipeline_reqs[running] then
        return
    end
    db:init_pipeline()
    pipeline_reqs[running] = rawget(db, "_reqs")
end

local function cancel_pipeline(_)
    assert(db)
    local running = zv.co_running()
    db:cancel_pipeline()
    pipeline_reqs[running] = nil
end

local function new(...)
    assert(false, "please use instance interface in proxy mode")
end

local function set_keepalive(...)
    assert(false, "cant use set_keepalive in proxy mode")
end

local function read_result(...)
    assert(false, "cant use `read_result`")
end

local function instance(host, port)
    if not db then
        local connecting = true
        local err
        db, err = redis.new(host, port, {proxy = true})
        assert(db, err)
        connecting = false
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
                        if disconnected and connecting then
                            return nil, "db is connecting"
                        end
                        print("try reconnect redis ...")
                        db = false
                        proxy = instance(host, port)
                        return proxy[cmd](proxy, ...)
                    end
                end
            })
        end)
        proxy = setmetatable({db,
                init_pipeline = init_pipeline,
                cancel_pipeline = cancel_pipeline,
                new = new,
                set_keepalive = set_keepalive,
                read_result = read_result,
            }, {__index = proxy_metafunc})
        zv.fork(redis_eventloop)
    end
    return proxy
end

_M.instance = instance

return _M
