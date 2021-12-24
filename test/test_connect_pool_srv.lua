
package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local socket = require "socket"
local evloop = require "evloop"

local function client_loop(fd)
    while true do
        local buf, err = socket.readline(fd, "\n")
        if err then
            print("error", err)
            socket.close(fd)
            return
        end
        print("recv from client:", buf)
        socket.write(fd, buf .. "\n")
    end
end

evloop.start("0.0.0.0:8989", function (fd, ip, port)
    print("accept a connection:", fd, ip, port)
    socket.bind(fd, client_loop)
    print("write buffer size:", socket.getoption(fd, "sndbuf"))
    print("read buffer size:", socket.getoption(fd, "rcvbuf"))
end)

evloop.run()
