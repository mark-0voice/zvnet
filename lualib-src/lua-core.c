#include <lua.h>
#include <lauxlib.h>
#include "systime.h"

static int
lmono(lua_State *L) {
    lua_pushinteger(L, systime_mono());
    return 1;
}

static int
lwall(lua_State *L) {
    lua_pushinteger(L, systime_wall());
    return 1;
}

static const struct luaL_Reg lib[] = {
    {"mono", lmono},
    {"wall", lwall},
    {NULL, NULL}
};

int luaopen_zvnet_core(lua_State *L) {
    luaL_newlib(L, lib);
    return 1;
}

