#ifndef buffer_h
#define buffer_h
#include <stdint.h>

typedef struct buf_chain_s {
    struct buf_chain_s *next;
    uint32_t buffer_len;
    uint32_t misalign;
    uint32_t off;
    uint8_t *buffer;
} buf_chain_t;

typedef struct buffer_s {
    buf_chain_t *first;
    buf_chain_t *last;
    buf_chain_t **last_with_datap;
    uint32_t total_len;
    uint32_t last_read_pos; // for sep read
} buffer_t;

uint8_t* buffer_available_chunk(buffer_t *buf, uint32_t datlen);

int buffer_add(buffer_t *buf, const void *data, uint32_t datlen);

int buffer_remove(buffer_t *buf, void *data, uint32_t datlen);

int buffer_drain(buffer_t *buf, uint32_t len);

void buf_chain_free_all(buf_chain_t *chain);

int buffer_search(buffer_t *buf, const char* sep, const int seplen);

uint8_t * buffer_write_atmost(buffer_t *p);

#endif
