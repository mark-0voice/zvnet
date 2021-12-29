
package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local socket = require "socket"
local evloop = require "evloop"
local zv = require "zv"

local function client_loop(fd)
    local i = 1
    while true do
        local buf, err = socket.readline(fd, "\n")
        if err then
            print("error", err)
            socket.close(fd)
            return
        end
        print("recv from client:", buf)
        socket.write(fd, buf .. "\n")
        if i == 2 then
            local connfd, err1 = socket.connect("127.0.0.1", 6379, {backlog = 1, pool_size = 1})
            if not err1 then
                print("now use coonection fd:", connfd)
                socket.write(connfd, "PING\r\n")
                local buf1 = socket.readline(connfd, "\r\n")
                print("recv from upstream:", buf1)
                socket.setkeepalive(connfd)
                -- socket.close(connfd)
            else
                print("connect 127.0.0.1:6379 error:", err1)
            end
        end
        i = i+1
    end
end

evloop.start("0.0.0.0:8989", function (fd, ip, port)
    print("accept a connection:", fd, ip, port)
    socket.bind(fd, client_loop)
end)

local function upstream_loop(upfd)
    socket.write(upfd, "PING\r\n")
    local buf = socket.readline(upfd, "\r\n")
    print("upstream_loop:recv from upstream:", buf)
    socket.close(upfd)
end

local fd, err = socket.block_connect("127.0.0.1", 6379)
if fd ~= -1 then
    socket.bind(fd, upstream_loop)
else
    print("block_connect 127.0.0.1:6379 error:", err)
end

zv.add_timer(400, function ()
    print("hello world 400", zv.time())
end)
local ele = zv.add_timer(600, function ()
    print("hello world 600", zv.time())
end)
zv.add_timer(700, function ()
    print("hello world 700", zv.time())
end)
zv.add_timer(800, function ()
    print("hello world 800", zv.time())
end)
zv.del_timer(ele)
zv.add_timer(900, function ()
    print("hello world 900", zv.time())
end)

evloop.run()
