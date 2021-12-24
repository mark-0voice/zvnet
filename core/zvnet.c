#include <stdio.h>
#include "zvmalloc.h"
#include <luajit.h>
#include <lualib.h>
#include <lauxlib.h>

typedef struct {
    size_t mem;
    size_t mem_level;
} lstate_t;

const size_t MEMLVL = 2097152; // 2M
const size_t MEM_1MB = 1048576; // 1M

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

void *
lua_alloc(void *ud, void *ptr, size_t osize, size_t nsize) {
    lstate_t *s = (lstate_t*)ud;
    s->mem += nsize;
    if (ptr) s->mem -= osize;
    if (s->mem > s->mem_level) {
        do {
            s->mem_level += MEMLVL;
        } while (s->mem > s->mem_level);
        
        printf("luajit vm now use %.2f M's memory up\n", (float)s->mem / MEM_1MB);
    } else if (s->mem < s->mem_level - MEMLVL) {
        do {
            s->mem_level -= MEMLVL;
        } while (s->mem < s->mem_level);
        
        printf("luajit vm now use %.2f M's memory down\n", (float)s->mem / MEM_1MB);
    }
	if (nsize == 0) {
		free(ptr);
		return NULL;
	} else {
		return realloc(ptr, nsize);
	}
}

int main(int argc, char** argv) {
    lstate_t ud = {0, MEMLVL};
    lua_State *L = lua_newstate(lua_alloc, &ud);
    luaL_openlibs(L);
    if (argc > 1) {
        lua_pushcfunction(L, traceback);
        int r = luaL_loadfile(L, argv[1]);
        lua_pushlightuserdata(L, NULL);
        lua_setglobal(L, "null");
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
