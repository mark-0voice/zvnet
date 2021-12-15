
#include "anet.h"
#include <lua.h>
#include <lauxlib.h>
#include <arpa/inet.h>
#include <stdlib.h>

static int
llisten(lua_State *L) {
    const char * host = luaL_checkstring(L, 1);
    int port = luaL_checkinteger(L, 2);
    int backlog = luaL_optinteger(L, 3, 32);
    int fd = anet_tcp_listen(host, port, backlog);
    if (fd < 0)
        return luaL_error(L, strerror(errno));
    lua_pushinteger(L, fd);
    return 1;
}

static int
ltcp_accept(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    char ip[INET_ADDRSTRLEN] = {0};
    int port = -1;
    int clientfd = anet_tcp_accept(fd, ip, &port);
    if (clientfd < 0)
        return luaL_error(L, strerror(errno));
    lua_pushinteger(L, clientfd);
    lua_pushstring(L, ip);
    lua_pushinteger(L, port);
    return 3;
}

static int
ltcp_connect(lua_State* L) {
    const char * addr = luaL_checkstring(L, 1);
    int port = luaL_checkinteger(L, 2);
    int fd = anet_tcp_connect(addr, port);
    lua_pushinteger(L, fd);
    return 1;
}

static int
ltcp_close(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    int ret = anet_tcp_close(fd);
    lua_pushinteger(L, ret);
    return 1;
}

static int
ltcp_nodelay(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    int ret = anet_tcp_set_nodelay(fd);
    lua_pushinteger(L, ret);
    return 1;
}

static const struct luaL_Reg lib[] = {
    {"listen", llisten},

    {"accept", ltcp_accept},
    {"connect", ltcp_connect},
    {"close", ltcp_close},

    {"nodelay", ltcp_nodelay},
    {NULL, NULL}
};

int luaopen_zvnet_anet(lua_State *L) {
    luaL_newlib(L, lib);
    return 1;
}
