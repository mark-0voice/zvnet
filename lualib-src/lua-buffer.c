
#include <stdbool.h>
#include <arpa/inet.h>
#include <lua.h>
#include <lauxlib.h>
#include "buffer.h"
#include "anet.h"

static int
lread(lua_State *L) {
    buffer_t *p = (buffer_t *)luaL_checkudata(L, 1, "zvnet.buffer");
    // printf("lread:%p\n", p);
    int fd = luaL_checkinteger(L, 2);
    int sz = luaL_checkinteger(L, 3);
    char buf[sz];
    int n = anet_tcp_read(fd, buf, sz);
    switch (n) {
    case 0:
        lua_pushnil(L);
        lua_pushstring(L, "closed (read return zero)");
        break;
    case -1:
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        break;
    case -2:
        lua_pushinteger(L, 0);
        break;
    default:
        lua_pushinteger(L, n);
        buffer_add(p, buf, n);
        break;
    }
    return 2;
}

static int
lwrite(lua_State *L) {
    buffer_t *p = (buffer_t *)luaL_checkudata(L, 1, "zvnet.buffer");
    // printf("lwrite:%p\n", p);
    int fd = luaL_checkinteger(L, 2);
    size_t len = 0;
    const char *buf = luaL_checklstring(L, 3, &len);
    if (p->total_len > 0) {
        buffer_add(p, buf, len);
        lua_pushboolean(L, true);
    } else {
        int n = anet_tcp_write(fd, buf, len);
        switch (n)
        {
        case -1:
            lua_pushboolean(L, true);
            break;
        case -2:
            buffer_add(p, buf, len);
            lua_pushboolean(L, false);
            break;
        default:
            if (n < len) {
                buffer_add(p, buf+n, len-n);
                lua_pushboolean(L, false);
            } else {
                lua_pushboolean(L, true);
            }
            break;
        }
    }
    return 1;
}

static int
lflush(lua_State *L) {
    buffer_t *p = (buffer_t *)luaL_checkudata(L, 1, "zvnet.buffer");
    int fd = luaL_checkinteger(L, 2);
    if (p->total_len <= 0) {
        lua_pushboolean(L, true);
        return 1;
    }
    buf_chain_t *chain;
    for (chain = p->first; chain; chain = chain->next)
    {
        int n = anet_tcp_write(fd, chain->buffer+chain->misalign, chain->off);
        if (n <= 0) {
            lua_pushboolean(L, false);
            return 1;
        }
        buffer_drain(p, n);
        if (n < chain->off) {
            lua_pushboolean(L, false);
            return 1;
        }
    }
    lua_pushboolean(L, true);
    return 1;
}

static int
lreadn(lua_State *L) {
    buffer_t *p = (buffer_t *)luaL_checkudata(L, 1, "zvnet.buffer");
    int sz = luaL_checkinteger(L, 2);
    if (sz <= 0) {
        return luaL_error(L, "lreadn(sz) sz need > 0");
    }
    if (p->total_len >= sz) {
        char buf[sz+1];
        buffer_remove(p, buf, sz);
        lua_pushlstring(L, buf, sz);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int
lreadline(lua_State *L) {
    buffer_t *p = (buffer_t *)luaL_checkudata(L, 1, "zvnet.buffer");
	size_t seplen = 0;
	const char *sep = luaL_checklstring(L, 2, &seplen);
    int n = buffer_search(p, sep, seplen);
    if (n > 0) {
        char buf[n+1];
        buffer_remove(p, buf, n);
        lua_pushlstring(L, buf, n-seplen);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int
lclear(lua_State *L) {
    buffer_t *p = (buffer_t *)luaL_checkudata(L, 1, "zvnet.buffer");
    // printf("%p free chain\n", p);
    buf_chain_free_all(p->first);
    return 0;
}

static int
lnew (lua_State *L) {
    buffer_t *q = (buffer_t*)lua_newuserdata(L, sizeof(buffer_t));
    memset(q, 0, sizeof(*q));
    q->last_with_datap = &q->first;
	if (luaL_newmetatable(L, "zvnet.buffer")) {
        luaL_Reg m[] = {
			{"read", lread},
            {"write", lwrite},
            {"readline", lreadline},
            {"readn", lreadn},
            {"flush", lflush},
            {"clear", lclear},
			{NULL, NULL},
		};
		luaL_newlib(L, m);
        lua_setfield(L, -2, "__index");
    }
    lua_setmetatable(L, -2);
    return 1;
}

static const luaL_Reg lib[] = {
	{"new", lnew},
	{NULL, NULL},
};

int luaopen_zvnet_buffer(lua_State *L) {
    luaL_newlib(L, lib);
    return 1;
}
