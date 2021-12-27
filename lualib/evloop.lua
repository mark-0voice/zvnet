
local socket = require "socket"
local zv = require "zv"

local _M = {}

local aefd, stop
function _M.start(endpoint, on_accept)
    aefd = socket.new_poll()
    zv.init_timer()
    if not endpoint and not on_accept then
        print("just to be a client")
        return
    end
    assert(type(endpoint) == "string", "your need provide `host:port`(string type) for listennig")
    assert(type(on_accept) == "function", "your need provide a function to accept a client")
    socket.listen(endpoint, on_accept)
end

function _M.stop()
    stop = true
end

function _M.run()
    assert(aefd, "please call evloop.start first!")
    while not stop do
        socket.event_wait(zv.expire_timer())
    end
    socket.free_poll()
end

return _M
