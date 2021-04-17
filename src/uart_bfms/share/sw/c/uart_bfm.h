/*
 * uart_bfm.h
 *
 *  Created on: Apr 15, 2021
 *      Author: mballance
 */

#ifndef INCLUDED_UART_BFM_H
#define INCLUDED_UART_BFM_H
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void uart_bfm_config(
		uint8_t			bfm_id,
		uint16_t		baud_div,
		uint8_t			data_size);

void uart_bfm_tx_bytes_incr(
		uint8_t			bfm_id,
		uint8_t			sval,
		uint8_t			nbytes);

void uart_bfm_rx_bytes_incr(
		uint8_t			bfm_id,
		uint8_t			sval,
		uint8_t			nbytes);

#ifdef __cplusplus
}
#endif




#endif /* INCLUDED_UART_BFM_H */
