from libcpp cimport bool
from libc.stdint cimport (
    uint64_t,
    uint32_t,
    uint16_t,
    uint8_t,
    int8_t
)


cdef extern from "helium-client.h":
    cdef:
         struct ctx "helium_ctx":
             void * param
         struct connection:
             pass
         struct info "helium_info":
             uint64_t mac
             uint32_t uptime
             uint32_t time
             uint32_t fw_version
             uint8_t  radio_count
         struct connection:
             uint64_t long_addr

    uint32_t _POLL_RETRIES_5S "HELIUM_POLL_RETRIES_5S"

    enum helium_baud:
      baud_9600     "helium_baud_b9600",
      baud_14400    "helium_baud_b14400",
      baud_19200    "helium_baud_b19200",
      baud_38400    "helium_baud_b38400",
      baud_57600    "helium_baud_b57600",
      baud_115200   "helium_baud_b115200"

    enum helium_status:
        OK                  "helium_status_OK"
        OK_NO_DATA          "helium_status_OK_NO_DATA"
        ERR_COMMUNICATION   "helium_status_ERR_COMMUNICATION"
        ERR_NOT_CONNECTED   "helium_status_ERR_NOT_CONNECTED"
        ERR_DROPPED         "helium_status_ERR_DROPPED"
        ERR_KEEP_AWAKE      "helium_status_ERR_KEEP_AWAKE"

    void init "helium_init"(ctx *, void *)
    bool needs_reset "helium_needs_reset"(ctx *)
    int _info "helium_info"(ctx *, info *)
    int connect "helium_connect"(ctx *, connection *, uint32_t)
    int connected "helium_connected"(ctx *)
    int sleep "helium_sleep"(ctx *, connection *)

    int channel_create "helium_channel_create"(ctx *, const char *, size_t, uint16_t *)
    int channel_send "helium_channel_send"(ctx *, uint8_t, void *, size_t, uint16_t *)
    int channel_poll_result "helium_channel_poll_result"(ctx *, uint16_t, int8_t *, uint32_t)

cdef extern from "_serial.h":
  int open_serial_port(const char *, helium_baud)
  void close_serial_port(int)
