
#include "ae.h"

#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>

int ae_create() {
    return kqueue();
}

int ae_free(int aefd) {
    return close(aefd);
}

int ae_add_read(int aefd, int fd) {
    struct kevent ke;
    
    EV_SET(&ke, fd, EVFILT_READ, EV_ADD, 0, 0, NULL);
    if (kevent(aefd, &ke, 1, NULL, 0, NULL) == -1 || ke.flags & EV_ERROR) {
        return 1;
    }
    
    EV_SET(&ke, fd, EVFILT_WRITE, EV_ADD, 0, 0, NULL);
    if (kevent(aefd, &ke, 1, NULL, 0, NULL) == -1 || ke.flags & EV_ERROR) {
        EV_SET(&ke, fd, EVFILT_READ, EV_DELETE, 0, 0, NULL);
        kevent(aefd, &ke, 1, NULL, 0, NULL);
        return 1;
    }
    
    EV_SET(&ke, fd, EVFILT_WRITE, EV_DISABLE, 0, 0, NULL);
    if (kevent(aefd, &ke, 1, NULL, 0, NULL) == -1 || ke.flags & EV_ERROR) {
        ae_del_event(aefd, fd);
        return 1;
    }
    return 0;
}

int ae_add_write(int aefd, int fd) {
    struct kevent ke;
    
    EV_SET(&ke, fd, EVFILT_READ, EV_ADD, 0, 0, NULL);
    if (kevent(aefd, &ke, 1, NULL, 0, NULL) == -1 || ke.flags & EV_ERROR) {
        return 1;
    }
    
    EV_SET(&ke, fd, EVFILT_WRITE, EV_ADD, 0, 0, NULL);
    if (kevent(aefd, &ke, 1, NULL, 0, NULL) == -1 || ke.flags & EV_ERROR) {
        EV_SET(&ke, fd, EVFILT_READ, EV_DELETE, 0, 0, NULL);
        kevent(aefd, &ke, 1, NULL, 0, NULL);
        return 1;
    }
    
    EV_SET(&ke, fd, EVFILT_READ, EV_DISABLE, 0, 0, NULL);
    if (kevent(aefd, &ke, 1, NULL, 0, NULL) == -1 || ke.flags & EV_ERROR) {
        ae_del_event(aefd, fd);
        return 1;
    }
    return 0;
}

int ae_del_event(int aefd, int fd) {
    struct kevent ke;
    int ret = 0;
    EV_SET(&ke, fd, EVFILT_READ, EV_DELETE, 0, 0, NULL);
    if (kevent(aefd, &ke, 1, NULL, 0, NULL) == -1 || ke.flags & EV_ERROR) {
        ret |= 1;
    }
    
    EV_SET(&ke, fd, EVFILT_WRITE, EV_DELETE, 0, 0, NULL);
    if (kevent(aefd, &ke, 1, NULL, 0, NULL) == -1 || ke.flags & EV_ERROR) {
        ret |= 1;
    }
    return ret;
}

int ae_enable_event(int aefd, int fd, bool readable, bool writable) {
    struct kevent ke;
    int ret = 0;
    EV_SET(&ke, fd, EVFILT_WRITE, writable ? EV_ENABLE : EV_DISABLE, 0, 0, NULL);
    if (kevent(aefd, &ke, 1, NULL, 0, NULL) == -1 || ke.flags & EV_ERROR) {
        ret |= 1;
    }
    
    EV_SET(&ke, fd, EVFILT_READ, readable ? EV_ENABLE : EV_DISABLE, 0, 0, NULL);
    if (kevent(aefd, &ke, 1, NULL, 0, NULL) == -1 || ke.flags & EV_ERROR) {
        ret |= 1;
    }
    return ret;
}

int ae_poll(int aefd, event_t *fired, int nfire, int timeout) {
    struct kevent ev[nfire];
    int n = 0;
    if (timeout >= 0) {
        struct timespec spec;
        spec.tv_sec = timeout/1000;
        spec.tv_nsec = (timeout % 1000)*1000000;
        n = kevent(aefd, NULL, 0, ev, nfire, &spec);
    } else {
        n = kevent(aefd, NULL, 0, ev, nfire, NULL);
    }
    for (int i = 0; i < n; i++) {
        struct kevent *e = ev + i;
        fired[i].fd = e->ident;
        bool eof = (e->flags & EV_EOF) != 0;
        bool err = (e->flags & EV_ERROR) != 0;
        fired[i].read = (e->filter == EVFILT_READ);
        fired[i].write = (e->filter == EVFILT_WRITE) && (!eof);
        fired[i].error = eof || err;
    }
    return n;
}
