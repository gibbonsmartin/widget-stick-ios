//
//  tcp_client.h
//  widget-stick-ble-app
//

#ifndef tcp_client_h
#define tcp_client_h

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Connects to a TCP server at host:port, transmits buff_tx, and reads the response into buff_rx.
 *
 * @param host        Server hostname or IPv4/IPv6 address string.
 * @param port        Server TCP port string (e.g. "8080").
 * @param buff_tx     Data buffer to send to the server.
 * @param buff_tx_sz  Number of bytes to send from buff_tx.
 * @param buff_rx     Buffer to store response received from the server.
 * @param buff_rx_sz  Size of buff_rx in bytes.
 * @return Number of bytes received (>= 0) on success, or -1 on error.
 */
int tcp_client_transfer(const char *host,
                        const char *port,
                        const char *buff_tx,
                        size_t buff_tx_sz,
                        char *buff_rx,
                        size_t buff_rx_sz);

#ifdef __cplusplus
}
#endif

#endif /* tcp_client_h */
