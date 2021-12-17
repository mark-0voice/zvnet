// #include "reactor.h"
#include <stdio.h>
#include <stdlib.h>

#include <luajit.h>
#include <lualib.h>
#include <lauxlib.h>

// cd luajit && make && sudo make install
// sudo ldconfig

static int
traceback (lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg)
        luaL_traceback(L, L, msg, 1);
    else {
        lua_pushliteral(L, "no error message");
    }
    return 1;
}

int main(int argc, char** argv) {
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    if (argc > 1) {
        lua_pushcfunction(L, traceback);
        int r = luaL_loadfile(L, argv[1]);
        if (LUA_OK != r) {
            const char* err = lua_tostring(L, -1);
            fprintf(stderr, "can't load %s err:%s\n", argv[1], err);
            return 1;
        }
        r = lua_pcall(L, 0, LUA_MULTRET, 1);
        if (LUA_OK != r) {
            const char* err = lua_tostring(L, -1);
            fprintf(stderr, "lua file %s launch err:%s\n", argv[1], err);
            return 1;
        }
    } else {
        fprintf(stderr, "please provide main lua file\n");
    }
    return 0;
}
