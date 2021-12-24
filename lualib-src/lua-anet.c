
#include "anet.h"
#include <lua.h>
#include <lauxlib.h>
#include <arpa/inet.h>
#include <stdbool.h>

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
ltcp_getopt(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    int option = luaL_checkinteger(L, 2);
    int val = 0;
    int ret = anet_tcp_getoption(fd, option, &val);
    switch (ret) {
    case -1:
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        break;
    case -2:
        lua_pushnil(L);
        lua_pushfstring(L, "unsupported option %d", option);
        break;
    default:
        lua_pushinteger(L, val);
        return 1;
    }
    return 2;
}

static int
ltcp_setopt(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    int option = luaL_checkinteger(L, 2);
    int val = luaL_optinteger(L, 3, 1);
    int ret = anet_tcp_setoption(fd, option, val);
    switch (ret) {
    case -1:
        lua_pushboolean(L, false);
        lua_pushstring(L, strerror(errno));
        break;
    case -2:
        lua_pushboolean(L, false);
        lua_pushfstring(L, "unsupported option %d", option);
        break;
    default:
        lua_pushboolean(L, true);
        return 1;
    }
    return 2;
}

static const struct luaL_Reg lib[] = {
    {"listen", llisten},

    {"accept", ltcp_accept},
    {"connect", ltcp_connect},
    {"close", ltcp_close},

    {"getoption", ltcp_getopt},
    {"setoption", ltcp_setopt},
    {NULL, NULL}
};

int luaopen_zvnet_anet(lua_State *L) {
    luaL_newlib(L, lib);
    return 1;
}
