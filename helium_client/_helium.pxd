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
         struct helium "helium_ctx":
             void * param
         struct channel "helium_channel":
             void * param
         struct config "helium_config":
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

    void helium_init "helium_init"(helium *, void *)
    bool needs_reset "helium_needs_reset"(helium *)
    int _info "helium_info"(helium *, info *)
    int connect "helium_connect"(helium *, connection *, uint32_t)
    int connected "helium_connected"(helium *)
    int sleep "helium_sleep"(helium *, connection *)
    int reset "helium_reset"(helium *)
    int poll_result "helium_poll_result"(helium *, uint16_t, int8_t *, uint32_t)

    int create_channel "helium_create_channel"(helium *, const char *, size_t, uint16_t *)

    void channel_init "helium_channel_init"(channel *, helium *, uint8_t)
    int channel_send "helium_channel_send"(channel *, void *, size_t, uint16_t *)
    int channel_ping "helium_channel_ping"(channel *, uint16_t * t)

    enum helium_config_type:
        I32  "helium_config_i32"
        F32  "helium_config_f32"
        STR  "helium_config_str"
        BOOL "helium_config_bool"
        NIL  "helium_config_null"

    void config_init "helium_config_init"(config * config, channel *)
    ctypedef bool (*_config_handler)(void *       handler_ctx,
                                     const char * key,
                                     helium_config_type value_type,
                                     void *                  value);
    int config_get "helium_config_get"(config *, const char *, uint16_t *)
    int config_get_poll_result "helium_config_get_poll_result"(config *,
                                                               uint16_t,
                                                               _config_handler,
                                                               void *,
                                                               int8_t *,
                                                               uint32_t)
    int config_set "helium_config_set"(config *,
                                       const char *config_key,
                                       helium_config_type,
                                       void *value,
                                       uint16_t *token)

    int config_set_poll_result "helium_config_set_poll_result"(config *,
                                                               uint16_t,
                                                               int8_t *,
                                                               uint32_t)

    int config_poll_invalidate "helium_config_poll_invalidate"(config *,
                                                               bool *,
                                                               uint32_t)

cdef extern from "_serial.h":
  int open_serial_port(const char *, helium_baud)
  void close_serial_port(int)
