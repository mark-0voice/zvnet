
package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local socket = require "socket"
local evloop = require "evloop"

evloop.start()

local function upstream_loop(upfd)
    while true do
        local buf, err = socket.readline(upfd)
        if err then
            socket.close(upfd)
            print(err)
            evloop.stop()
            return
        end
        print(buf)
    end
end

local clientfd, err = socket.block_connect("127.0.0.1", 8989)
if clientfd ~= -1 then
    socket.bind(clientfd, upstream_loop)
else
    print("block_connect 127.0.0.1:8989 error:", err)
end

local function console_loop(fd)
    while true do
        local cmd = socket.readline(fd)
        socket.write(clientfd, cmd .. "\n")
    end
end

socket.bind(0, console_loop)

evloop.run()
