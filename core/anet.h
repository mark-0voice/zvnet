#ifndef async_net_h
#define async_net_h

#include <netdb.h>
#include <errno.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <stdio.h>

//-- bind and listen
int anet_tcp_listen(const char *bindaddr, int port, int backlog);

//-- connection
int anet_tcp_accept(int fd, char* ip, int *port);
int anet_tcp_connect(const char *addr, int port);
int anet_tcp_close(int fd);
int anet_tcp_read(int fd, void* buf, int sz);
int anet_tcp_write(int fd, const void* buf, int sz);

//-- utils
int _anet_tcp_set_nonblock(int fd);
int anet_tcp_getoption(int fd, int option, int *val);
int anet_tcp_setoption(int fd, int option, int val);

#endif