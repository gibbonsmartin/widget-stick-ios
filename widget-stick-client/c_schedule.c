//
//  c_schedule.c
//  widget-stick-client
//

#include "c_schedule.h"
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "socket_client.h"
#include <stdint.h>

static char s_last_input1[256] = "default";
static char s_last_input2[256] = "60";
static int32_t s_run_count = 0;

int32_t c_schedule_execute(const char *input1, const char *input2, char *output_buffer, size_t buffer_size) {
    if (output_buffer == NULL || buffer_size == 0) {
        return -1;
    }

    const char *val1 = (input1 != NULL && input1[0] != '\0') ? input1 : s_last_input1;
    const char *val2 = (input2 != NULL && input2[0] != '\0') ? input2 : s_last_input2;

    strncpy(s_last_input1, val1, sizeof(s_last_input1) - 1);
    s_last_input1[sizeof(s_last_input1) - 1] = '\0';

    strncpy(s_last_input2, val2, sizeof(s_last_input2) - 1);
    s_last_input2[sizeof(s_last_input2) - 1] = '\0';

    s_run_count++;

    if (client_transfer(s_last_input1, s_last_input2, "hello", 6, output_buffer, buffer_size) <= 0)
    {
        snprintf(output_buffer, buffer_size, "No response");
    }

    return 0;
}

int32_t c_schedule_background_tick(char *output_buffer, size_t buffer_size) {
    return c_schedule_execute(s_last_input1, s_last_input2, output_buffer, buffer_size);
}
