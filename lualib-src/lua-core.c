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

// defined in lsha1.c
int lsha1(lua_State *L);
int lhmac_sha1(lua_State *L);

static const struct luaL_Reg lib[] = {
    {"mono", lmono},
    {"wall", lwall},
    {"sha1", lsha1},
    {"hmac_sha1", lhmac_sha1},
    {NULL, NULL}
};

int luaopen_zvnet_core(lua_State *L) {
    luaL_newlib(L, lib);
    return 1;
}

