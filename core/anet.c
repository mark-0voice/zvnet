#include "anet.h"

enum TCP_SOCK_OPTION {
    SOCK_OPT_KEEPALIVE = 1,
    SOCK_OPT_REUSEADDR,
    SOCK_OPT_TCP_NODELAY,
    SOCK_OPT_SNDBUF,
    SOCK_OPT_RCVBUF,
};

int
anet_tcp_listen(const char *bindaddr, int port, int backlog) {
    char _port[6];  /* strlen("65535") */
    struct addrinfo hints, *servinfo, *p;
    snprintf(_port,6,"%d",port);
    memset(&hints,0,sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;    /* No effect if bindaddr != NULL */
    if (bindaddr && !strcmp("*", bindaddr))
        bindaddr = NULL;

    int rv;
    if ((rv = getaddrinfo(bindaddr,_port,&hints,&servinfo)) != 0) {
        return -1;
    }

    int s = -1;
    for (p = servinfo; p != NULL; p = p->ai_next) {
        if ((s = socket(p->ai_family,p->ai_socktype,p->ai_protocol)) == -1)
            continue;
        if (anet_tcp_setoption(s, SOCK_OPT_REUSEADDR, 1) == -1) goto error;
        if (bind(s, p->ai_addr, p->ai_addrlen) == -1) goto error;
        if (listen(s, backlog) == -1) goto error;
        if (_anet_tcp_set_nonblock(s) == -1) goto error;
        goto end;
    }
    if (p == NULL) {
        printf("unable to bind socket, errno: %s\n", strerror(errno));
    }
error:
    close(s);
    s=-1;
end:
    freeaddrinfo(servinfo);
    return s;
}

int anet_tcp_accept(int fd, char* ip, int *port) {
    int clientfd;
    struct sockaddr_storage sa;
    socklen_t salen = sizeof(sa);
    while (1) {
        clientfd = accept(fd, (struct sockaddr*)&sa, &salen);
        if (clientfd == -1) {
            if (errno == EINTR)
                continue;
            else if (errno == EWOULDBLOCK)
                return 0;
            else {
                return -1;
            }
        }
        break;
    }
    struct sockaddr_in *s = (struct sockaddr_in *)&sa;
    if (ip) inet_ntop(AF_INET, (void*)&(s->sin_addr), ip, INET_ADDRSTRLEN);
    if (port) *port = ntohs(s->sin_port);
    return clientfd;
}

int anet_tcp_connect(const char *addr, int port) {
    char portstr[6];  /* strlen("65535") + 1; */
    struct addrinfo hints, *servinfo, *p;
    
    snprintf(portstr, sizeof(portstr), "%d", port);
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    int rv;
    
    if ((rv = getaddrinfo(addr, portstr, &hints, &servinfo)) != 0) {
        return -1;
    }
    
    int s;
    for (p = servinfo; p != NULL; p = p->ai_next) {
        if ((s = socket(p->ai_family,p->ai_socktype,p->ai_protocol)) == -1)
            continue;

        if (anet_tcp_setoption(s, SOCK_OPT_REUSEADDR, 1) == -1) goto error;
        if (anet_tcp_setoption(s, SOCK_OPT_KEEPALIVE, 1) == -1) goto error;
        if (_anet_tcp_set_nonblock(s) == -1) goto error;

        if (connect(s, p->ai_addr, p->ai_addrlen) == -1 && errno != EINPROGRESS) {
            close(s);
            s = -1;
            continue;
        }
        goto end;
    }

error:
    close(s);
    s = -1;
end:
    freeaddrinfo(servinfo);
    return s;
}

int anet_tcp_close(int fd) {
    return close(fd);
}

int anet_tcp_read(int fd, void* buf, int sz) {
    while (1) {
        int n = read(fd, buf, sz);
        if (n == 0) return 0;
        if (n == -1) {
            if (errno == EINTR)
                continue;
            if (errno == EWOULDBLOCK)
                return -2;
            return -1;
        }
        return n;
    }
    return 0;
}

int anet_tcp_write(int fd, const void *buf, int sz) {
    while (1) {
        int n = write(fd, buf, sz);
        if (n == -1) {
            if (errno == EINTR)
                continue;
            if (errno == EWOULDBLOCK)
                return -2;
            return -1;
        }
        return n;
    }
    return 0;
}

int _anet_tcp_set_nonblock(int fd) {
    int flag = fcntl(fd, F_GETFL, 0);
	if (-1 == flag) {
		return -1;
	}
	return fcntl(fd, F_SETFL, flag | O_NONBLOCK);
}

int anet_tcp_getoption(int fd, int option, int *val) {
    socklen_t len = sizeof(int);
    switch (option) {
    case SOCK_OPT_KEEPALIVE:
        return getsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, (void *) val, &len);
    case SOCK_OPT_REUSEADDR:
        return getsockopt(fd, SOL_SOCKET, SO_REUSEADDR, (void *) val, &len);
    case SOCK_OPT_TCP_NODELAY:
        return getsockopt(fd, IPPROTO_TCP, TCP_NODELAY, (void *) val, &len);
    case SOCK_OPT_SNDBUF:
        return getsockopt(fd, SOL_SOCKET, SO_RCVBUF, (void *) val, &len);
    case SOCK_OPT_RCVBUF:
        return getsockopt(fd, SOL_SOCKET, SO_SNDBUF, (void *) val, &len);
    default:
        return -2;
    }
    return 0;
}

int anet_tcp_setoption(int fd, int option, int val) {
    socklen_t len = sizeof(int);
    switch (option) {
    case SOCK_OPT_KEEPALIVE:
        return setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, (const void *) &val, len);
    case SOCK_OPT_REUSEADDR:
        return setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, (const void *) &val, len);
    case SOCK_OPT_TCP_NODELAY:
        return setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, (const void *) &val, len);
    case SOCK_OPT_SNDBUF:
        return setsockopt(fd, SOL_SOCKET, SO_RCVBUF, (const void *) &val, len);
    case SOCK_OPT_RCVBUF:
        return setsockopt(fd, SOL_SOCKET, SO_SNDBUF, (const void *) &val, len);
    default:
        return -2;
    }
    return 0;
}
