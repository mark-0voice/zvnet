local core = require "zvnet.core"

local new_tab = require "table.new"

local math_floor = math.floor

local _M = {}

--[[
    minheap = {ele1, ele2, ele3, ...}
    ele = {idx, time, func}
]]
local minheap = {}
local n = 0

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
    while min_child <= n do
        if min_child+1 <= n and min_heap_elem_greater(minheap[min_child], minheap[min_child+1]) then
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
    minheap[idx] = minheap[n]
    minheap[idx][1] = idx
    minheap[n] = nil
    n = n - 1
    if n < 2 then return end
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
    if n > 0 then
        min_heap_erase(minheap[1])
    end
end

-- local function dump_timer(desc)
--     for i=1, n do
--         print(("%s=>idx=%d,expire=%d"):format(desc, minheap[i][1], minheap[i][2]))
--     end
-- end
local now_time
local now_tick

function _M.init_timer()
    now_time = core.wall()
    now_tick = 0
end

function _M.cache_time()
    return now_time
end

function _M.real_time()
    return core.wall()
end

local function add_timer(csec, func)
    local ele = new_tab(3, 0)
    n = n+1
    ele[1], ele[2], ele[3] = n, now_tick + csec, func
    -- print("add timer", csec, ele[2])
    minheap[n] = ele
    local idx = min_heap_shift_up(n)
    -- dump_timer("add_timer")
    return minheap[idx]
end

_M.add_timer = add_timer

local function del_timer(ele)
    min_heap_erase(ele)
    -- dump_timer("del_timer")
end

_M.del_timer = del_timer

local function update_cache_time()
    local last_time = now_time
    now_time = core.wall()
    local diff = now_time - last_time
    now_tick = now_tick + diff
end

_M.update_cache_time = update_cache_time

local function expire_timer()
    while true do
        if n == 0 then
            return -1
        end
        local ele = min_heap_top()
        local diff = ele[2] - now_tick
        if diff >= 0 then
            return diff * 10
        end
        -- print("expire timer", now_tick)
        local _, err = xpcall(ele[3], debug.traceback)
        if err then
            print(err)
        end
        -- dump_timer("expire_timer")
        min_heap_pop()
    end
end

_M.expire_timer = expire_timer

return _M
