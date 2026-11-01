//
//  socket_client.h
//  widget-stick-ios
//
//  Created by Martin Gibbons on 31/10/2026.
//

#ifndef socket_client_h
#define socket_client_h

extern int client_transfer(const char *host, const char *port, const char *buff_tx, size_t buff_tx_sz, char *buff_rx, size_t buff_rx_sz);
#endif /* socket_client_h */
