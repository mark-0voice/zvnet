#ifndef zvmalloc_h
#define zvmalloc_h

#ifndef NOUSE_JEMALLOC

#include <jemalloc.h>
#define malloc je_malloc
#define calloc je_calloc
#define realloc je_realloc
#define free je_free

#else

    #include <stdlib.h>

#endif

#endif
