#include "_serial.h"
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <poll.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

bool
helium_serial_readable(void * param)
{
    struct pollfd pollfd = {
        .fd = (int)(intptr_t)param, .events = POLLIN,
    };
    if (poll(&pollfd, 1, -1) == 1)
    {
        return pollfd.revents & POLLIN;
    }
    return false;
}

bool
helium_serial_getc(void * param, uint8_t * ch)
{
    return read((int)(intptr_t)param, ch, 1) > 0;
}

bool
helium_serial_putc(void * param, uint8_t ch)
{
    return write((int)(intptr_t)param, &ch, 1) == 1;
}

void
helium_wait_us(void * param, uint32_t us)
{
    (void)param;
    usleep(us);
}

static int
_set_interface_attribs(int fd, int speed)
{
    struct termios tty;

    if (tcgetattr(fd, &tty) < 0)
    {
        return -1;
    }

    cfsetospeed(&tty, (speed_t)speed);
    cfsetispeed(&tty, (speed_t)speed);

    tty.c_cflag |= (CLOCAL | CREAD); /* ignore modem controls */
    tty.c_cflag &= ~CSIZE;
    tty.c_cflag |= CS8;      /* 8-bit characters */
    tty.c_cflag &= ~PARENB;  /* no parity bit */
    tty.c_cflag &= ~CSTOPB;  /* only need 1 stop bit */
    tty.c_cflag &= ~CRTSCTS; /* no hardware flowcontrol */

    /* setup for non-canonical mode */
    tty.c_iflag &=
        ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
    tty.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    tty.c_oflag &= ~OPOST;

    /* fetch bytes as they become available */
    tty.c_cc[VMIN]  = 1;
    tty.c_cc[VTIME] = 1;

    if (tcsetattr(fd, TCSANOW, &tty) != 0)
    {
        return -1;
    }
    return 0;
}

int
open_serial_port(const char * portname, enum helium_baud baud)
{
    int fd;
    fd = open(portname, O_RDWR | O_NOCTTY | O_NONBLOCK);

    if (fd < 0)
    {
        return -1;
    }

    if (ioctl(fd, TIOCEXCL) < 0)
    {
        return -1;
    }

    if (fcntl(fd, F_SETFL, 0) < 0)
    {
        return -1;
    }

    speed_t baud_rate = B9600;
    switch (baud)
    {
    case helium_baud_b9600:
        baud_rate = B9600;
        break;
    case helium_baud_b14400:
    // B14400 does not exist on linux, default to a higher speed
    case helium_baud_b19200:
        baud_rate = B19200;
        break;
    case helium_baud_b38400:
        baud_rate = B38400;
        break;
    case helium_baud_b57600:
        baud_rate = B57600;
        break;
    case helium_baud_b115200:
        baud_rate = B115200;
        break;
    }

    /* Set baud rate,  8 bits, no parity, 1 stop bit */
    if (_set_interface_attribs(fd, baud_rate) != 0)
    {
        return -1;
    }

    return fd;
}

void
close_serial_port(int fd)
{
    close(fd);
}
