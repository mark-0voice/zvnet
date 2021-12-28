
package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local socket = require "socket"
local evloop = require "evloop"
local zv = require "zv"

evloop.start()

local function test_loop()
    local strs = {}
    for i=0,9 do
        local tab = {}
        for j=1, 1026 do
            tab[#tab+1] = i
        end
        strs[#strs+1] = table.concat(tab)
    end
    local i = 0
    while true do
        -- local cmd = socket.readline(fd)
        -- socket.write(fd, cmd .. "\n")
        local clientfd, err = socket.connect("127.0.0.1", 8989, {backlog = 1, pool_size = 2})
        print(clientfd, err)
        if not err then
            socket.write(clientfd, strs[i%10+1] .. "\n")
            local buf, errmsg = socket.readline(clientfd, "\n")
            if errmsg then
                print("err:", errmsg)
                socket.close(clientfd)
            else
                print("recv", clientfd, buf, #buf)
                socket.setkeepalive(clientfd)
            end
        end
        i = i+1
        zv.sleep(i<5 and 10 or 100)
    end
end

zv.fork(test_loop)
zv.fork(test_loop)
zv.fork(test_loop)
zv.fork(test_loop)

evloop.run()
