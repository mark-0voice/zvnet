#ifndef async_event_h
#define async_event_h

#include <unistd.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>

#define AE_NONE 0       /* No events registered. */
#define AE_READABLE 1   /* Fire when descriptor is readable. */
#define AE_WRITABLE 2   /* Fire when descriptor is writable. */
#define AE_ERR  4

#define AE_MAXEVENT 64

typedef struct {
    int fd;
    bool read;
    bool write;
    bool error;
} event_t;

// typedef struct {
//     int aefd;
//     event_t *fired;
//     int nfire;
// } ae_t;

int ae_create();
int ae_free(int aefd);
int ae_add_read(int aefd, int fd);
int ae_add_write(int aefd, int fd);
int ae_del_event(int aefd, int fd);
int ae_enable_event(int aefd, int fd, bool readable, bool writable);
int ae_wait(int fd, int mask, int timeout);
int ae_poll(int aefd, event_t *fired, int nfire, int timeout);
const char * socket_error(int fd);

#endif