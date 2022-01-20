local ae = require "zvnet.ae"
local anet = require "zvnet.anet"
local buffer = require "zvnet.buffer"
local zv = require "zv"

local tab_isempty = require "table.isempty"
local tab_isarray = require "table.isarray"
local tab_remove = table.remove
local tab_concat = table.concat
local traceback = debug.traceback

local _M = {}
local AE_READABLE = 1
local AE_WRITABLE = 2

local socket_pool = setmetatable({},{
    __gc = function(tab)
        for fd, _ in pairs(tab) do
            ae.close(fd)
        end
    end
})

local connection_pool = {}

local aefd

local function close(fd)
    local s = socket_pool[fd]
    if s then
        if s.rbuffer then
            s.rbuffer:clear()
        end
        if s.wbuffer then
            s.wbuffer:clear()
        end
        socket_pool[fd] = nil
        if s.pool_name then
            local spool = connection_pool[s.pool_name]
            if s.status and spool[s.status] then
                spool[s.status][fd] = nil
            end
        end
        ae.del(aefd, fd)
        anet.close(fd)
    end
end

_M.close = close

local option_idx = {
    ["keepalive"]   = 1,
    ["reuseaddr"]   = 2,
    ["tcp-nodelay"] = 3,
    ["sndbuf"]      = 4,
    ["rcvbuf"]      = 5,
}

local function setoption(fd, option, value)
    if option == nil then
        return false, 'missing the "option" argument'
    end

    if value == nil then
        return false, 'missing the "value" argument'
    end

    if option_idx[option] == nil then
        return false, "unsupported option " .. tostring(option)
    end

    return anet.setoption(fd, option_idx[option], value)
end
_M.setoption = setoption

local function getoption(fd, option)
    if option == nil then
        return nil, 'missing the "option" argument'
    end

    if option_idx[option] == nil then
        return nil, "unsupported option " .. tostring(option)
    end
    return anet.getoption(fd, option_idx[option])
end
_M.getoption = getoption

local function ev_base_handler(fd, readable, writable, errevent)
    local s = assert(socket_pool[fd])
    local ok, err = xpcall(s.ev_handler, traceback, s, readable, writable, errevent)
    if not ok then
        print(err)
        close(fd)
    end
end

local function ev_listen_handler(s, readable, writable, _)
    if readable and not writable then
        zv.co_resume(s.co)
    end
end

local function ev_client_handler(s, readable, writable, _)
    assert(s)
    local runfd = assert(zv.co_runfd(s.co))
    if readable then
        local sz = s.read_step
        local n, err = s.rbuffer:read(s.fd, sz)
        if not n then
            if s.close_cb then
                s.close_cb()
            end
            if s.fd == runfd then
                return zv.co_resume(s.co, n, err)
            else
                s.errmsg = err
                return
            end
        end
        if n > 0 then
            if s.fd == runfd then
                local tp = type(s.read_need)
                if tp == "string" then
                    local buf = s.rbuffer:readline(s.read_need)
                    if buf ~= nil then
                        zv.co_resume(s.co, buf)
                    end
                elseif tp == "number" then
                    local buf = s.rbuffer:readn(s.read_need)
                    if #buf >= s.read_need then
                        zv.co_resume(s.co, buf)
                    end
                end
            end
            if n == sz and sz < 2048 then
                s.read_step = s.read_step * 2;
            elseif n > 64 and n*2 < sz then
                s.read_step = s.read_step / 2;
            end
        end
    end
    if writable then
        local ok = s.wbuffer:flush(s.fd)
        if s.writable and ok then
            s.writable = false
            ae.enable(aefd, s.fd, true, false)
        end
    end
end

local function ev_connect_handler(s, readable, writable, errevent)
    if errevent then
        zv.co_resume(s.co, nil, errevent)
        return
    end
    if not readable and writable then
        zv.co_resume(s.co, true)
    end
end

local function ev_pool_connect_handler(s, _, _, errevent)
    if errevent then
        local spool = connection_pool[s.pool_name]
        spool.connections = spool.connections - 1
        close(s.fd)
    end
end

local event_handler = {
    base = ev_base_handler,
    listen = ev_listen_handler,
    client = ev_client_handler,
    connect = ev_connect_handler,
    pool_connect = ev_pool_connect_handler,
}

function _M.new_poll()
    aefd = ae.create()
    ae.register({
        update_time = zv.update_cache_time,
        ev_handler = event_handler.base,
    })
    return aefd
end

function _M.free_poll()
    return ae.close(aefd)
end

function _M.listen(endpoint, on_accept)
    local host, port = endpoint:match("([^:]+):(.+)$")
    print("listen:", host, port)
    port = tonumber(port)
    local fd = anet.listen(host, port, 32)
    local co = zv.co_create(function ()
        while true do
            local clientfd, ip, clientport = anet.accept(fd)
            if clientfd == 0 then
                zv.co_yield()
            else
                on_accept(clientfd, ip, clientport)
            end
        end
    end)
    local s = {
        fd = fd,
        co = co,
        ev_handler = event_handler.listen,
    }
    socket_pool[fd] = s
    setoption(fd, "tcp-nodelay", 1)
    ae.add_read(aefd, fd)
    return fd
end

local function bind(fd, logic)
    local co = zv.co_running()
    local s = socket_pool[fd]
    if s ~= nil then
        ae.enable(aefd, fd, true, false)
        s.co = co
        s.read_need = false
        s.read_step = 64
        s.rbuffer = buffer.new()
        s.wbuffer = buffer.new()
        s.writeable = false
        s.ev_handler = ev_client_handler
    else
        assert(logic and type(logic) == "function")
        co = zv.co_create(function ()
            local ok, err = xpcall(logic, traceback, fd)
            if not ok then
                print(err)
                close(fd)
            end
        end)
        ae.add_read(aefd, fd)
        socket_pool[fd] = {
            fd = fd,
            co = co,
            read_need = false,
            read_step = 64,
            rbuffer = buffer.new(),
            wbuffer = buffer.new(),
            writable = false,
            ev_handler = event_handler.client,
            errmsg = nil,
        }
        zv.co_resume(co)
    end
end

_M.bind = bind

function _M.rebind(fd)
    local s = assert(socket_pool[fd])
    s.co = zv.co_running()
end

function _M.readline(fd, sep)
    sep = sep or "\n"
    local s = assert(socket_pool[fd])
    if s.errmsg then
        return nil, s.errmsg
    end
    local buf = s.rbuffer:readline(sep)
    if buf then
        return buf
    end
    local err
    s.read_need = sep
    zv.co_attach(fd)
    buf, err = zv.co_yield(s.co)
    zv.co_detach(fd)
    s.read_need = false
    return buf, err
end

function _M.read(fd, sz)
    assert(sz > 0, "read sz must > 0")
    local s = assert(socket_pool[fd])
    if s.errmsg then
        return nil, s.errmsg
    end
    local buf = s.rbuffer:readn(sz);
    if buf then
        return buf
    end
    s.read_need = sz
    zv.co_attach(fd)
    local ok, err = zv.co_yield()
    zv.co_detach(fd)
    s.read_need = false
    return ok, err
end

local function concat_tab_buf(tab)
    local tmp = {}
    for _, v in ipairs(tab) do
        if type(v) == "table" then
            assert(tab_isarray(v))
            tmp[#tmp+1] = concat_tab_buf(v)
        else
            tmp[#tmp+1] = v
        end
    end
    return tab_concat(tmp)
end

function _M.write(fd, buf)
    local typ = type(buf)
    if typ == "table" then
        assert(tab_isarray(buf))
        buf = concat_tab_buf(buf)
    end
    if #buf == 0 then
        return true
    end
    local s = assert(socket_pool[fd])
    local ok = s.wbuffer:write(fd, buf)
    if not ok then
        s.writable = true
        ae.enable(aefd, fd, true, true)
    end
    return ok
end

function _M.block_connect(ip, port)
    local fd = anet.connect(ip, port)
    local ok, err = ae.wait(fd, AE_WRITABLE)
    if not ok then
        close(fd)
        return nil, err
    end
    return fd
end

local function create_pool(opts, host)
    local default_pool = {
        cache = {}, -- 可用连接
        free = {}, -- 正用连接
        wait = {},
        wait_timer = {},
        wait_timeout = 500, -- 5秒
        connections = 0,
        backlog = opts.backlog or -1,
        pool_size = opts.pool_size or 30,
        pool_name = opts.pool or host,
    }
    local spool = setmetatable(default_pool, {
        __gc = function (tab)
            for fd,_ in pairs(tab.free) do
                close(fd)
            end
            for fd,_ in pairs(tab.cache) do
                close(fd)
            end
        end
    })
    connection_pool[spool.pool_name] = spool
    return spool
end

local function get_alive_peer(spool)
    if not tab_isempty(spool.cache) then
        local min, ele = 65535, nil
        for fd, s in pairs(spool.cache) do
            if fd < min then
                min = fd
                ele = s
            end
        end
        spool.free[min] = ele
        spool.cache[min] = nil
        ele.status = "free"
        ele.co = zv.co_running()
        ele.ev_handler = event_handler.client
        return ele
    end
end

local function simple_connect(ip, port)
    local running = zv.co_running()
    local fd = anet.connect(ip, port)
    ae.add_write(aefd, fd)
    socket_pool[fd] = {
        fd = fd,
        co = running,
        ev_handler = event_handler.connect,
    }
    zv.co_attach(fd)
    local ok, err = zv.co_yield()
    zv.co_detach(fd)
    if not ok then
        close(fd)
        return nil, err
    end
    bind(fd)
    return fd
end

local function pool_connect(ip, port, spool)
    local running = zv.co_running()
    local fd = anet.connect(ip, port)
    ae.add_write(aefd, fd)
    local sock = {
        fd = fd,
        co = running,
        pool_name = spool.pool_name,
        ev_handler = ev_connect_handler,
    }
    socket_pool[fd] = sock
    zv.co_attach(fd)
    -- print("pool_connect begin yield", fd)
    local ok, err = zv.co_yield()
    zv.co_detach(fd)
    if not ok then
        spool.connections = spool.connections - 1
        close(fd)
        return nil, err
    end
    if spool.connections <= spool.pool_size then
        spool.free[fd] = sock
        sock.status = "free"
    end
    bind(fd)
    return fd
end

function _M.connect(ip, port, opts)
    if not opts or (not opts.pool_size and not opts.backlog) then
        return simple_connect(ip, port)
    end
    local running = zv.co_running()
    local host = ip .. ":" .. port
    local spool = connection_pool[opts.pool or host]
    if not spool then
        spool = create_pool(opts, host)
    else
        local ele = get_alive_peer(spool)
        if ele then
            spool.connections = spool.connections + 1
            return ele.fd
        end
    end
    spool.connections = spool.connections + 1
    if spool.backlog >= 0 then
        if spool.connections > spool.pool_size + spool.backlog then
            spool.connections = spool.connections - 1
            return nil, "too many connect operations"
        end
        if spool.connections > spool.pool_size then
            spool.wait[#spool.wait+1] = running
            spool.wait_timer[running] = zv.add_timer(spool.wait_timeout, function ()
                local runco = tab_remove(spool.wait, 1)
                zv.co_resume(runco, nil, "timeout")
            end)
            zv.co_attach(-1)
            local fd, err = zv.co_yield()
            zv.co_detach(-1)
            if err then
                spool.connections = spool.connections - 1
            else
                local s = socket_pool[fd]
                s.co = running
            end
            return fd, err
        end
    end
    return pool_connect(ip, port, spool)
end

function _M.setkeepalive(fd)
    local s = assert(socket_pool[fd])
    if not s.pool_name then
        return
    end
    local spool = assert(connection_pool[s.pool_name])
    spool.connections = spool.connections - 1
    -- print("setkeepalive", fd, spool.pool_name, s.status)
    if s.status ~= "free" then
        close(fd)
        return
    end
    if #spool.wait > 0 then
        local co = tab_remove(spool.wait, 1)
        local tele = spool.wait_timer[co]
        zv.del_timer(tele)
        zv.co_resume(co, fd)
        return
    end
    s.status = "cache"
    s.co = nil
    s.ev_handler = event_handler.pool_connect
    spool.cache[s.fd] = s
    spool.free[s.fd] = nil
end

function _M.event_wait(timeout)
    ae.poll(aefd, timeout or -1, 64)
end

function _M.onclose(fd, callback)
    if socket_pool[fd] then
        socket_pool[fd].close_cb = callback
    end
end

return _M
