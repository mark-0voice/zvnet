# $@ 目标文件 $^ 所有的依赖文件 $< 第一个依赖文件
# = 是最基本的赋值
# := 是覆盖之前的值
# ?= 是如果没有被赋值过就赋予等号后面的值
PLAT ?= linux
CC ?= gcc

.PHONY : clean zvnet linux macosx all
.PHONY : default

default :
	$(MAKE) $(PLAT)

LUA_CLIB_PATH ?= luaclib
LUA_CLIB_SRC ?= lualib-src
LUA_CLIB ?= zvnet
LUA_INC_PATH ?= /usr/local/include/luajit-2.1
LUA_LIB_PATH ?= /usr/local/lib
LUA_LIB ?= -lluajit-5.1 -ldl -lm
CORE_PATH ?= ./core

linux : PLAT := linux
macosx : PLAT := macosx

SHARED = -fPIC --shared
EXPORT = -Wl,-E

macosx : SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
macosx : EXPORT :=

LUA_CLIB_ZVNET = \
	lua-ae.c \
	lua-anet.c \
	lua-core.c \
	lua-buffer.c

CFLAGS = -g -O2 -Wall -I$(LUA_INC_PATH)

NET_SRC = ae.c anet.c systime.c buffer.c zvnet.c

linux macosx:
	$(MAKE) all EXPORT="$(EXPORT)" SHARED="$(SHARED)"

all : \
	zvnet \
	$(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)

clean:
	rm -f zvnet && \
	rm -rf $(LUA_CLIB_PATH)

zvnet : $(foreach v, $(NET_SRC), $(CORE_PATH)/$(v))
	$(CC) $(CFLAGS) $^ -o $@ -I$(LUA_INC_PATH) -L$(LUA_LIB_PATH) $(EXPORT) $(LUA_LIB)

$(LUA_CLIB_PATH) :
	mkdir -p $(LUA_CLIB_PATH)

$(LUA_CLIB_PATH)/zvnet.so : $(addprefix lualib-src/,$(LUA_CLIB_ZVNET)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I$(LUA_INC_PATH) -I$(CORE_PATH) -I$(LUA_CLIB_SRC)
