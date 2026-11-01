//
//  socket_client.c
//  widget-stick-client
//
//  Created by Martin Gibbons on 31/10/2026.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#define BUFFER_SIZE 4096

int client_transfer(const char *host, const char *port, const char *buff_tx, size_t buff_tx_sz, char *buff_rx, size_t buff_rx_sz) {
    struct addrinfo hints, *res, *p;
    int sockfd = -1;
    int status;

    // 1. Configure address resolution hints
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;     // Allow IPv4 or IPv6
    hints.ai_socktype = SOCK_STREAM; // TCP stream sockets

    // 2. Resolve hostname and port
    if ((status = getaddrinfo(host, port, &hints, &res)) != 0) {
        fprintf(stderr, "getaddrinfo error: %s\n", gai_strerror(status));
        return EXIT_FAILURE;
    }

    // 3. Loop through results and connect to the first reachable address
    for (p = res; p != NULL; p = p->ai_next) {
        sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (sockfd == -1) {
            continue; // Try next address if socket creation fails
        }

        if (connect(sockfd, p->ai_addr, p->ai_addrlen) == 0) {
            break; // Successfully connected
        }

        close(sockfd);
        sockfd = -1;
    }

    freeaddrinfo(res); // Free linked list allocated by getaddrinfo

    if (sockfd == -1) {
        fprintf(stderr, "Failed to connect to %s:%s (%s)\n", host, port, strerror(errno));
        return EXIT_FAILURE;
    }

    printf("Connected to %s:%s\n", host, port);

    // 4. Send data to the server
    ssize_t bytes_sent = send(sockfd, buff_tx, buff_tx_sz, 0);
    if (bytes_sent == -1) {
        perror("send failed");
        close(sockfd);
        return EXIT_FAILURE;
    }

    // 5. Receive response from the server
    ssize_t bytes_received = recv(sockfd, buff_rx, buff_rx_sz, 0);
    if (bytes_received < 0) {
        perror("recv failed");
    } else if (bytes_received == 0) {
        printf("Server closed the connection.\n");
    } else {
        printf("Received (%zd bytes): %.64s", bytes_received, buff_rx);
    }

    // 6. Clean up
    close(sockfd);
    return EXIT_SUCCESS;
}
