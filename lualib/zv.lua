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

return _M
