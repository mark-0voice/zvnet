
#include "ae.h"
#include <unistd.h>
#include <sys/epoll.h>

int ae_create() {
    return epoll_create(1);
}

int ae_free(int aefd) {
    return close(aefd);
}

int ae_add_read(int aefd, int fd) {
    struct epoll_event e;
    e.events = EPOLLIN;
    e.data.fd = fd;
    return epoll_ctl(aefd, EPOLL_CTL_ADD, fd, &e) != -1;
}

int ae_add_write(int aefd, int fd) {
    struct epoll_event e;
    e.events = EPOLLOUT;
    e.data.fd = fd;
    return epoll_ctl(aefd, EPOLL_CTL_ADD, fd, &e) != -1;
}

int ae_del_event(int aefd, int fd) {
    return epoll_ctl(aefd, EPOLL_CTL_DEL, fd, NULL) != -1;
}

int ae_enable_event(int aefd, int fd, bool readable, bool writable) {
    struct epoll_event e;
    e.data.fd = fd;
    e.events = (readable ? EPOLLIN : 0) | (writable ? EPOLLOUT : 0); 
    return epoll_ctl(aefd, EPOLL_CTL_MOD, fd, &e) != -1;
}

int ae_poll(int aefd, event_t *fired, int nfire, int timeout) {
    struct epoll_event events[nfire];
    int n = epoll_wait(aefd, events, nfire, timeout);
    for (int i = 0; i < n; i++) {
        struct epoll_event *e = events + i;
        fired[i].fd = e->data.fd;
        int mask = e->events;
        if (mask & EPOLLHUP) 
            mask |= (EPOLLIN | EPOLLOUT);
        fired[i].read = (mask & EPOLLIN) != 0;
        fired[i].write = (mask & EPOLLOUT) != 0;
        fired[i].error = (mask & (EPOLLERR|EPOLLHUP)) != 0;
    }
    return n;
}
