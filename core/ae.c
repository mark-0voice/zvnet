#include "ae.h"
#include "poll.h"

const char * socket_error(int fd) {
    int error;
    socklen_t len = sizeof(error);
    int code = getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &len);
    const char * err = NULL;
    if (code < 0) {
        err = strerror(errno);
    } else if (error != 0) {
        err = strerror(error);
    } else {
        err = "Unknown error";
    }
    return err;
}

#if (defined(__APPLE__) && defined(MAC_OS_X_VERSION_10_6)) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined (__NetBSD__)
#include "ae_kqueue.c"
#endif

#ifdef __linux__
#include "ae_epoll.c"
#endif

int ae_wait(int fd, int mask, int timeout) {
    struct pollfd pfd;
    int retmask = 0, retval;

    memset(&pfd, 0, sizeof(pfd));
    pfd.fd = fd;
    if (mask & AE_READABLE) pfd.events |= POLLIN;
    if (mask & AE_WRITABLE) pfd.events |= POLLOUT;

    if ((retval = poll(&pfd, 1, timeout)) == 1) {
        if (pfd.revents & (POLLERR | POLLHUP)) {
            retmask |= AE_ERR;
        } else {
            if (pfd.revents & POLLIN) retmask |= AE_READABLE;
            if (pfd.revents & POLLOUT) retmask |= AE_WRITABLE;
        }
        return retmask;
    } else {
        return retval;
    }
}
