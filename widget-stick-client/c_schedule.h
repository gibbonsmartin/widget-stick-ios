//
//  c_schedule.h
//  widget-stick-client
//

#ifndef c_schedule_h
#define c_schedule_h

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Runs or updates the C schedule module with two string inputs and writes the status/result int32_to output_buffer.
 *
 * @param input1 First input parameter from text field 1.
 * @param input2 Second input parameter from text field 2.
 * @param output_buffer Buffer to receive the formatted result string.
 * @param buffer_size Size of the output buffer in bytes.
 * @return 0 on success, non-zero on error.
 */
int32_t c_schedule_execute(const char *input1, const char *input2, char *output_buffer, size_t buffer_size);

/**
 * Performs a periodic/background tick for the C schedule module.
 *
 * @param output_buffer Buffer to receive the formatted status string.
 * @param buffer_size Size of the output buffer in bytes.
 * @return 0 on success, non-zero on error.
 */
int32_t c_schedule_background_tick(char *output_buffer, size_t buffer_size);

#ifdef __cplusplus
}
#endif

#endif /* c_schedule_h */
