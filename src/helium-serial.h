#include "helium-client/helium-client.h"

#ifndef HELIUM_SERIAL_H
#define HELIUM_SERIAL_H

#ifdef __cplusplus
extern "C" {
#endif

int
open_serial_port(const char * portname, enum helium_baud baud);

void
close_serial_port(int fd);

#ifdef __cplusplus
}
#endif

#endif // HELIUM_SERIAL_H
