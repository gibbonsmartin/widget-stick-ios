//
//  tcp_client.c
//  widget-stick-ble-app
//

#include "tcp_client.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netdb.h>

int tcp_client_transfer(const char *host,
                        const char *port,
                        const char *buff_tx,
                        size_t buff_tx_sz,
                        char *buff_rx,
                        size_t buff_rx_sz) {
#if 0
    if (host == NULL || host[0] == '\0' || port == NULL || port[0] == '\0') {
        return -1;
    }

    struct addrinfo hints, *res = NULL, *p = NULL;
    int sockfd = -1;
    int status;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    if ((status = getaddrinfo(host, port, &hints, &res)) != 0) {
        fprintf(stderr, "getaddrinfo error: %s\n", gai_strerror(status));
        return -1;
    }

    for (p = res; p != NULL; p = p->ai_next) {
        sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (sockfd == -1) {
            continue;
        }

        // Configure 5 second send/receive timeout
        struct timeval timeout;
        timeout.tv_sec = 5;
        timeout.tv_usec = 0;
        setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

        if (connect(sockfd, p->ai_addr, p->ai_addrlen) == 0) {
            break;
        }

        close(sockfd);
        sockfd = -1;
    }

    freeaddrinfo(res);

    if (sockfd == -1) {
        fprintf(stderr, "Failed to connect to %s:%s (%s)\n", host, port, strerror(errno));
        return -1;
    }

    if (buff_tx != NULL && buff_tx_sz > 0) {
        ssize_t bytes_sent = send(sockfd, buff_tx, buff_tx_sz, 0);
        if (bytes_sent < 0) {
            perror("send failed");
            close(sockfd);
            return -1;
        }
    }

    int result = 0;
    if (buff_rx != NULL && buff_rx_sz > 0) {
        memset(buff_rx, 0, buff_rx_sz);
        ssize_t bytes_received = recv(sockfd, buff_rx, buff_rx_sz - 1, 0);
        if (bytes_received < 0) {
            perror("recv failed");
            close(sockfd);
            return -1;
        }
        buff_rx[bytes_received] = '\0';
        result = (int)bytes_received;
    }

    close(sockfd);
    return result;
#else
    size_t sz = buff_rx_sz > buff_tx_sz ? buff_tx_sz : buff_rx_sz;
    memcpy(buff_rx, buff_tx, sz);
    return sz;
#endif
}
