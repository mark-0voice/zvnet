local core = require "zvnet.core"

local new_tab = require "table.new"

local math_floor = math.floor

local tab_remove = table.remove

local coroutine_create = coroutine.create
local coroutine_yield = coroutine.yield
local coroutine_resume = coroutine.resume
local coroutine_running = coroutine.running

local coroutine_pool = setmetatable({}, { __mode = "kv" })

local _M = {}

local function co_create(f)
    assert(f)
    local co = tab_remove(coroutine_pool)
    if co == nil then
        co = coroutine_create(function (...)
            f(...)
            while true do
                f = nil
                coroutine_pool[#coroutine_pool+1] = co
                print("coroutine_pool size", #coroutine_pool)
                f = coroutine_yield()
                f(coroutine_yield())
            end
        end)
    else
        coroutine_resume(co, f)
    end
    return co
end

_M.co_create = co_create
_M.co_yield = coroutine_yield
_M.co_resume = coroutine_resume
_M.co_running = coroutine_running

local caller = {}

local function co_attach(fd)
    local running = coroutine_running()
    caller[running] = fd
end

local function co_detach(fd)
    local running = coroutine_running()
    assert(caller[running] == fd, "please use co_attach first and make sure runfd is right")
    caller[running] = nil
end

local function co_runfd(co)
    return caller[co or coroutine_running()]
end

_M.co_attach = co_attach
_M.co_detach = co_detach
_M.co_runfd = co_runfd

--[[
    minheap = {ele1, ele2, ele3, ...}
    ele = {idx, time, func}
]]
local minheap = {}
local nele = 0

local function min_heap_elem_greater(lht, rht)
    return lht[2] > rht[2]
end

local function min_heap_shift_up(idx)
    local parent = math_floor(idx/2)
    while parent > 0 and min_heap_elem_greater(minheap[parent], minheap[idx]) do
        minheap[parent], minheap[idx] = minheap[idx], minheap[parent]
        minheap[parent][1], minheap[idx][1] = minheap[idx][1], minheap[parent][1]
        idx = parent
        parent = math_floor(idx/2)
    end
    return idx
end

local function min_heap_shift_up_unconditional(idx)
    local parent = math_floor(idx/2)
    repeat
        minheap[parent], minheap[idx] = minheap[idx], minheap[parent]
        minheap[parent][1], minheap[idx][1] = minheap[idx][1], minheap[parent][1]
        idx = parent
        parent = math_floor(idx/2)
    until parent > 0 and min_heap_elem_greater(minheap[parent], minheap[idx])
end

local function min_heap_shift_down(idx)
    local min_child = 2 * idx
    while min_child <= nele do
        if min_child+1 <= nele and min_heap_elem_greater(minheap[min_child], minheap[min_child+1]) then
            min_child = min_child + 1
        end
        if min_heap_elem_greater(minheap[min_child], minheap[idx]) then
            break
        end
        minheap[min_child], minheap[idx] = minheap[idx], minheap[min_child]
        minheap[min_child][1], minheap[idx][1] = minheap[idx][1], minheap[min_child][1]
        idx = min_child
        min_child = 2 * idx
    end
end

local function min_heap_erase(ele)
    local idx = ele[1]
    minheap[idx] = minheap[nele]
    minheap[idx][1] = idx
    minheap[nele] = nil
    if nele == idx then -- delete last element
        nele = nele - 1
        return
    end
    nele = nele - 1
    if nele < 2 then return end
    local parent = math_floor(idx/2)
    if parent > 0 and min_heap_elem_greater(minheap[parent], minheap[idx]) then
        min_heap_shift_up_unconditional(idx)
    else
        min_heap_shift_down(idx)
    end
end

local function min_heap_top()
    return minheap[1]
end

local function min_heap_pop()
    if nele > 0 then
        min_heap_erase(minheap[1])
    end
end

-- local function dump_timer(desc)
--     for i=1, nele do
--         print(("%s=>idx=%d,expire=%d"):format(desc, minheap[i][1], minheap[i][2]))
--     end
-- end
local now_time
local now_tick

function _M.init_timer()
    now_time = core.wall()
    now_tick = core.mono()
end

function _M.time()
    return now_time
end

function _M.real_time()
    return core.wall()
end

local function safe_call_timer(func)
    return function (closed)
        if closed then return end -- recycle coroutine
        local ok, err = xpcall(func, debug.traceback)
        if not ok then
            print(err)
        end
    end
end

local function add_timer(csec, func)
    local ele = new_tab(3, 0)
    nele = nele+1
    ele[1], ele[2], ele[3] = nele, now_tick + csec, co_create(safe_call_timer(func))
    -- print("add timer", csec, ele[2])
    minheap[nele] = ele
    local idx = min_heap_shift_up(nele)
    -- dump_timer("add_timer")
    return minheap[idx]
end

_M.add_timer = add_timer

local function del_timer(ele)
    min_heap_erase(ele)
    coroutine_resume(ele[3], true)
    -- dump_timer("del_timer")
end

_M.del_timer = del_timer

local function update_cache_time()
    local last_tick = now_tick
    now_tick = core.mono()
    local diff = now_tick - last_tick
    now_time = now_time + diff
end

_M.update_cache_time = update_cache_time

local function expire_timer()
    while true do
        if nele == 0 then
            return -1
        end
        local ele = min_heap_top()
        local diff = ele[2] - now_tick
        if diff >= 0 then
            return diff * 10
        end
        -- print("expire timer", now_tick)
        min_heap_pop()
        coroutine_resume(ele[3])
        -- dump_timer("expire_timer")
    end
end

_M.expire_timer = expire_timer

function _M.fork(func)
    add_timer(0, func)
end

function _M.sleep(csec)
    local running = coroutine_running()
    caller[running] = -1
    add_timer(csec, function ()
        coroutine_resume(running)
    end)
    coroutine_yield()
    caller[running] = nil
end

return _M
