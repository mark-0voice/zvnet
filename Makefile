
PLAT ?= linux
CC ?= gcc

.PHONY : clean zvnet linux macosx all luajit jemalloc cleanall
.PHONY : default

default :
	$(MAKE) $(PLAT)

LUA_CLIB_PATH ?= luaclib
LUA_CLIB_SRC ?= lualib-src
LUA_CLIB ?= zvnet
LUA_INC_PATH ?= deps/luajit2/src
ZVNET_LIBS ?= -ldl -lm
CORE_PATH ?= ./core

linux : PLAT := linux
macosx : PLAT := macosx

SHARED = -fPIC --shared
EXPORT = -Wl,-E

macosx : SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
macosx : EXPORT :=

JEMALLOC_STATICLIB := deps/jemalloc/lib/libjemalloc_pic.a
JEMALLOC_INC := deps/jemalloc/include/jemalloc

LUAJIT_STATICLIB := deps/luajit2/src/libluajit.a

# dont use jemalloc in macosx
macosx : JEMALLOC_STATICLIB :=
macosx : ZVNET_DEFINE :=-DNOUSE_JEMALLOC

# append pthread when use jemalloc
linux : ZVNET_LIBS += -lpthread

deps/jemalloc/Makefile : | deps/jemalloc/autogen.sh
	cd deps/jemalloc && ./autogen.sh --with-jemalloc-prefix=je_ --enable-prof

$(JEMALLOC_STATICLIB) : deps/jemalloc/Makefile
	cd deps/jemalloc && $(MAKE) CC=$(CC)

jemalloc : $(JEMALLOC_STATICLIB)

MACOSX_DEPLOYMENT_TARGET := '12.0'
linux : MACOSX_DEPLOYMENT_TARGET :=

XCFLAGS := '-DLUAJIT_ENABLE_LUA52COMPAT -fno-stack-check'

luajit :
	cd deps/luajit2 && \
	$(MAKE) CC=$(CC) XCFLAGS=$(XCFLAGS) MACOSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET)

LUA_CLIB_ZVNET = \
	lua-ae.c \
	lua-anet.c \
	lua-core.c lsha1.c\
	lua-buffer.c

CFLAGS = -g -O2 -Wall -I$(LUA_INC_PATH)

NET_SRC = ae.c anet.c systime.c buffer.c zvnet.c

linux macosx:
	$(MAKE) all EXPORT="$(EXPORT)" SHARED="$(SHARED)" JEMALLOC_STATICLIB="$(JEMALLOC_STATICLIB)" ZVNET_LIBS="$(ZVNET_LIBS)" ZVNET_DEFINE="$(ZVNET_DEFINE)" MACOSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET)

all : \
	luajit \
	jemalloc \
	zvnet \
	$(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)

zvnet : $(foreach v, $(NET_SRC), $(CORE_PATH)/$(v)) $(LUAJIT_STATICLIB) $(JEMALLOC_STATICLIB)
	$(CC) $(CFLAGS) $^ -o $@ -I$(LUA_INC_PATH) -I$(JEMALLOC_INC) $(EXPORT) $(ZVNET_LIBS) $(ZVNET_DEFINE)

$(LUA_CLIB_PATH) :
	mkdir -p $(LUA_CLIB_PATH)

$(LUA_CLIB_PATH)/zvnet.so : $(addprefix lualib-src/,$(LUA_CLIB_ZVNET)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I$(LUA_INC_PATH) -I$(CORE_PATH) -I$(LUA_CLIB_SRC)

clean:
	rm -f zvnet && \
    rm -rf $(LUA_CLIB_PATH)

cleanall: clean
ifneq (,$(wildcard deps/jemalloc/Makefile))
	cd deps/jemalloc && $(MAKE) clean && rm Makefile
endif
	cd deps/luajit2 && $(MAKE) clean MACOSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET)
	rm -f $(LUAJIT_STATICLIB)
