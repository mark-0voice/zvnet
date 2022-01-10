#include <lua.h>
#include <lauxlib.h>
#include "ae.h"

static int 
lcreate(lua_State *L) {
    int aefd = ae_create();
    lua_pushinteger(L, aefd);
    return 1;
}

static int
lclose(lua_State *L) {
    int aefd = luaL_checkinteger(L, 1);
    ae_free(aefd);
    return 0;
}

static int
ladd_read(lua_State *L) {
    int aefd = luaL_checkinteger(L, 1);
    int fd = luaL_checkinteger(L, 2);
    int ret = ae_add_read(aefd, fd);
    if (ret == -1)
        return luaL_error(L, "add event error");
    lua_pushinteger(L, ret);
    return 1;
}

static int
ladd_write(lua_State *L) {
    int aefd = luaL_checkinteger(L, 1);
    int fd = luaL_checkinteger(L, 2);
    int ret = ae_add_write(aefd, fd);
    if (ret == -1)
        return luaL_error(L, "add event error");
    lua_pushinteger(L, ret);
    return 1;
}

static int
lenable(lua_State *L) {
    int aefd = luaL_checkinteger(L, 1);
    int fd = luaL_checkinteger(L, 2);
    bool readable = lua_toboolean(L, 3);
    bool writeable = lua_toboolean(L, 4);
    lua_pushinteger(L, ae_enable_event(aefd, fd, readable, writeable));
    return 1;
}

static int
ldel(lua_State *L) {
    int aefd = luaL_checkinteger(L, 1);
    int fd = luaL_checkinteger(L, 2);
    ae_del_event(aefd, fd);
    return 0;
}

static int
lwait(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    int mask = luaL_checkinteger(L, 2);
    int timeout = luaL_optinteger(L, 3, -1);
    int retmask = ae_wait(fd, mask, timeout);
    lua_getfield(L, LUA_REGISTRYINDEX, "zvnet.update_time");
    lua_call(L, 0, 0);
    if (retmask & mask) {
        lua_pushboolean(L, true);
        return 1;
    } else if (retmask & AE_ERR) {
        lua_pushboolean(L, false);
        lua_pushstring(L, socket_error(fd));
        return 2;
    } 
    lua_pushboolean(L, false);
    return 1;
}

static int
lregister(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_getfield(L, 1, "update_time");
    luaL_checktype(L, -1, LUA_TFUNCTION);
    lua_setfield(L, LUA_REGISTRYINDEX, "zvnet.update_time");
    lua_getfield(L, 1, "ev_handler");
    luaL_checktype(L, -1, LUA_TFUNCTION);
    lua_setfield(L, LUA_REGISTRYINDEX, "zvnet.ev_handler");
    return 0;
}

static int
lpoll(lua_State *L) {
    int aefd = luaL_checkinteger(L, 1);
    int timeout = luaL_checkinteger(L, 2);
    int nfired = luaL_checkinteger(L, 3);
    event_t e[nfired];
    int n = ae_poll(aefd, e, nfired, timeout);
    lua_getfield(L, LUA_REGISTRYINDEX, "zvnet.update_time");
    lua_pushvalue(L, 4);
    lua_call(L, 0, 0);
    lua_getfield(L, LUA_REGISTRYINDEX, "zvnet.ev_handler");
    for(int i = 0; i < n; i++)
    {
        lua_pushvalue(L, 5);
        lua_pushinteger(L, e[i].fd);
        lua_pushboolean(L, e[i].read);
        lua_pushboolean(L, e[i].write);
        if (e[i].error)
            lua_pushstring(L, socket_error(e[i].fd));
        else
            lua_pushnil(L);
        lua_call(L, 4, 0);
        lua_pushvalue(L, 4);
        lua_call(L, 0, 0);
    }
    return 0;
}

static const struct luaL_Reg lib[] =
{
    {"create", lcreate},
    {"close", lclose},
    
    {"add_read", ladd_read},
    {"add_write", ladd_write},
    {"enable", lenable},
    {"del", ldel},
    {"wait", lwait},
    
    {"poll", lpoll},
    {"register", lregister},

    {NULL,NULL}
};

int
luaopen_zvnet_ae(lua_State *L) {
    luaL_newlib(L, lib);
    return 1;
}
