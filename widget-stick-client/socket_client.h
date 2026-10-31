//
//  socket_client.h
//  widget-stick-ios
//
//  Created by Martin Gibbons on 31/10/2026.
//

#ifndef socket_client_h
#define socket_client_h

extern int client_transfer(const char *host, const char *port, const char *buff_tx, int buff_rx_sz, const char *buff_rx, int buff_rx_sz);
#endif /* socket_client_h */
