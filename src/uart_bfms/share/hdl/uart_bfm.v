/****************************************************************************
 * uart_bfm.v
 * 
 * This BFM makes use of source from the uart16550 project, which has
 * the following copyright: 
 * 
 * 
////  This file is part of the "UART 16550 compatible" project    ////
////  http://www.opencores.org/cores/uart16550/                   ////
////                                                              ////
////  Documentation related to this project:                      ////
////  - http://www.opencores.org/cores/uart16550/                 ////
////                                                              ////
////  Projects compatibility:                                     ////
////  - WISHBONE                                                  ////
////  RS232 Protocol                                              ////
////  16550D uart (mostly supported)                              ////
////                                                              ////
////  Overview (main Features):                                   ////
////  UART core receiver logic                                    ////
////                                                              ////
////  Known problems (limits):                                    ////
////  None known                                                  ////
////                                                              ////
////  To Do:                                                      ////
////  Thourough testing.                                          ////
////                                                              ////
////  Author(s):                                                  ////
////      - gorban@opencores.org                                  ////
////      - Jacob Gorban                                          ////
////      - Igor Mohor (igorm@opencores.org)                      ////
////                                                              ////
////  Created:        2001/05/12                                  ////
////  Last Updated:   2001/05/17                                  ////
////                  (See log for the revision history)          ////
////                                                              ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2000, 2001 Authors                             ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
 * 
 ****************************************************************************/
module uart_bfm(
		input			clock,
		input			reset,
		input			rx,
		output			tx);
	
	/****************************************************************
	 * Shared configuration
	 ****************************************************************/
	/**
	 * 0: 5
	 * 1: 6
	 * 2: 7
	 * 3: 8
	 */
	reg[1:0]			data_bits = 3;
	reg					parity_en = 0;
	reg					parity_pe = 0;
	reg					parity_sp = 0;
	reg					parity_ep = 0;
	reg					stop_bits = 0;

	/****************************************************************
	 * Clock-divider logic
	 ****************************************************************/
	// Note: enable gates evaluation of the state machine
	reg [15:0] 								dl;   // 32-bit divisor latch
	reg [15:0] 								dl_v = 0; // 32-bit divisor latch
	reg [15:0] 								dlc = 0;  // 32-bit divisor latch counter
	reg [15:0]								dh_v = 0;
	reg 									start_dlc; // activate dlc on writing to UART_DL1
	reg 									start_dlc_v = 0; // activate dlc on writing to UART_DL1
	reg enable;
	
	always @(posedge clock or posedge reset) begin
		if (reset) begin
			dlc <= {16{1'b0}};
			start_dlc <= 1'b0;
			enable <= 1'b0;
		end else begin
			dl <= dl_v;
			start_dlc <= start_dlc_v;
		
			// Handshake with BFM logic
			if (start_dlc) begin
				start_dlc <= 1'b0;
				start_dlc_v = 0;
			end
			
			if (start_dlc | ~ (|dlc)) begin
				dlc <= dl - 1;               // preset counter
			end else begin
				dlc <= dlc - 1;              // decrement counter
			end
		
			// Single-clock pulse when on 16x clock
			if (|dl && !(|dlc)) begin // dl>0 && dlc==0
				enable <= 1'b1;
			end else begin
				enable <= 1'b0;
			end
		end
	end	
	
	/****************************************************************
	 * Receive logic
	 ****************************************************************/
	parameter  sr_idle 					= 4'd0;
	parameter  sr_rec_start 			= 4'd1;
	parameter  sr_rec_bit 				= 4'd2;
	parameter  sr_rec_parity			= 4'd3;
	parameter  sr_rec_stop 				= 4'd4;
	parameter  sr_check_parity 		= 4'd5;
	parameter  sr_rec_prepare 			= 4'd6;
	parameter  sr_end_bit				= 4'd7;
	parameter  sr_ca_lc_parity	      = 4'd8;
	parameter  sr_wait1 					= 4'd9;
	parameter  sr_push 					= 4'd10;	
	
	
	reg	[3:0]	rstate;
	reg	[3:0]	rcounter16;
	reg	[2:0]	rbit_counter;
	reg	[7:0]	rshift;			// receiver shift register
	reg		rparity;		// received parity
	reg		rparity_error;
	reg		rframing_error;		// framing error flag
	reg		rbit_in;
	reg		rparity_xor;
	reg	[7:0]	counter_b;	// counts the 0 (low) signals
	reg   rf_push_q;	
	
	reg	[11-1:0]		rf_data_in;
	wire				rf_error_bit; // an error (parity or framing) is inside the fifo
	wire 				break_error = (counter_b == 0);

	wire 		rcounter16_eq_7 = (rcounter16 == 4'd7);
	wire		rcounter16_eq_0 = (rcounter16 == 4'd0);
	wire		rcounter16_eq_1 = (rcounter16 == 4'd1);

	wire [3:0] rcounter16_minus_1 = rcounter16 - 1'b1;
	
	always @(posedge clock or posedge reset) begin
		if (reset) begin
			rstate 			<= sr_idle;
			rbit_in 		<= 1'b0;
			rcounter16 		<= 0;
			rbit_counter 	<= 0;
			rparity_xor 	<= 1'b0;
			rframing_error 	<= 1'b0;
			rparity_error 	<= 1'b0;
			rparity 		<= 1'b0;
			rshift 			<= 0;
			rf_data_in 		<= 0;
			counter_b		<= 8'd159;
		end else if (enable) begin
			case (rstate)
				sr_idle : begin
					rf_data_in 	  <= 0;
					rcounter16 	  <= 4'b1110;
					if (rx==1'b0 & ~break_error)   // detected a pulse (start bit?)
					begin
						rstate 		  <= sr_rec_start;
					end
				end
				sr_rec_start :	begin
					if (rcounter16_eq_7)    // check the pulse
						if (rx==1'b1)   // no start bit
							rstate <= sr_idle;
						else            // start bit detected
							rstate <= sr_rec_prepare;
					rcounter16 <= rcounter16_minus_1;
				end
				sr_rec_prepare:begin
					case (data_bits)  // number of bits in a word
						2'b00 : rbit_counter <= 3'b100;
						2'b01 : rbit_counter <= 3'b101;
						2'b10 : rbit_counter <= 3'b110;
						2'b11 : rbit_counter <= 3'b111;
					endcase
					if (rcounter16_eq_0)
					begin
						rstate		<= sr_rec_bit;
						rcounter16	<= 4'b1110;
						rshift		<= 0;
					end
					else
						rstate <= sr_rec_prepare;
					rcounter16 <= rcounter16_minus_1;
				end
				sr_rec_bit :	begin
					if (rcounter16_eq_0)
						rstate <= sr_end_bit;
					if (rcounter16_eq_7) // read the bit
						case (data_bits)  // number of bits in a word
							2'b00 : rshift[4:0]  <= {rx, rshift[4:1]};
							2'b01 : rshift[5:0]  <= {rx, rshift[5:1]};
							2'b10 : rshift[6:0]  <= {rx, rshift[6:1]};
							2'b11 : rshift[7:0]  <= {rx, rshift[7:1]};
						endcase
					rcounter16 <= rcounter16_minus_1;
				end
				sr_end_bit :   begin
					if (rbit_counter==3'b0) // no more bits in word
						if (parity_en) // choose state based on parity
							rstate <= sr_rec_parity;
						else
						begin
							rstate <= sr_rec_stop;
							rparity_error <= 1'b0;  // no parity - no error :)
						end
					else		// else we have more bits to read
					begin
						rstate <= sr_rec_bit;
						rbit_counter <= rbit_counter - 1'b1;
					end
					rcounter16 <= 4'b1110;
				end
				sr_rec_parity: begin
					if (rcounter16_eq_7)	// read the parity
					begin
						rparity <= rx;
						rstate <= sr_ca_lc_parity;
					end
					rcounter16 <= rcounter16_minus_1;
				end
				sr_ca_lc_parity : begin    // rcounter equals 6
					rcounter16  <= rcounter16_minus_1;
					rparity_xor <= ^{rshift,rparity}; // calculate parity on all incoming data
					rstate      <= sr_check_parity;
				end
				sr_check_parity: begin	  // rcounter equals 5
					case ({parity_pe,parity_sp})
						2'b00: rparity_error <=  rparity_xor == 0;  // no error if parity 1
						2'b01: rparity_error <= ~rparity;      // parity should sticked to 1
						2'b10: rparity_error <=  rparity_xor == 1;   // error if parity is odd
						2'b11: rparity_error <=  rparity;	  // parity should be sticked to 0
					endcase
					rcounter16 <= rcounter16_minus_1;
					rstate <= sr_wait1;
				end
				sr_wait1 :	if (rcounter16_eq_0)
					begin
						rstate <= sr_rec_stop;
						rcounter16 <= 4'b1110;
					end
					else
						rcounter16 <= rcounter16_minus_1;
				sr_rec_stop :	begin
					if (rcounter16_eq_7)	// read the parity
					begin
						rframing_error <= !rx; // no framing error if input is 1 (stop bit)
						rstate <= sr_push;
					end
					rcounter16 <= rcounter16_minus_1;
				end
				sr_push :	begin
					///////////////////////////////////////
					//				$display($time, ": received: %b", rf_data_in);
					if(rx | break_error) begin
						if(break_error) begin
							rf_data_in 	<= {8'b0, 3'b100}; // break input (empty character) to receiver FIFO
						end else begin
							rf_data_in  <= {rshift, 1'b0, rparity_error, rframing_error};
						end
						
						_recv(rshift);
						
						rstate        <= sr_idle;
					end else if(~rframing_error) begin // There's always a framing before break_error -> wait for break or rx
						rf_data_in  <= {rshift, 1'b0, rparity_error, rframing_error};
						$display("TODO: receive data ready (2)");
						rcounter16 	  <= 4'b1110;
						rstate 		  <= sr_rec_start;
					end
				end
				default : rstate <= sr_idle;
			endcase
		end  // if (enable)
	end // always of receiver	
	
	/****************************************************************
	 * Transmit logic
	 ****************************************************************/
	parameter s_idle        = 3'd0;
	parameter s_send_start  = 3'd1;
	parameter s_send_byte   = 3'd2;
	parameter s_send_parity = 3'd3;
	parameter s_send_stop   = 3'd4;
	parameter s_pop_byte    = 3'd5;
	
	reg [2:0] 									tstate;
	reg [4:0] 									counter;
	reg [2:0] 									bit_counter;   // counts the bits to be sent
	reg [6:0] 									shift_out;	// output shift register
	reg 										stx_o_tmp;
	reg 										parity_xor;  // parity of the word
	reg 										bit_out;	
	
	reg[7:0]									tx_data_v;
	reg											tx_data_valid_v;

	always @(posedge clock or posedge reset) begin
		if (reset) begin
			tstate      <= s_idle;
			stx_o_tmp   <= 1'b1;
			counter   	<= 5'b0;
			shift_out   <= 7'b0;
			bit_out     <= 1'b0;
			parity_xor  <= 1'b0;
			bit_counter <= 3'b0;
			tx_data_v   = {8{1'b0}};
			tx_data_valid_v = 1'b0;
		end else if (enable) begin
			case (tstate)
				s_idle	 :	
					if (tx_data_valid_v == 1) begin // Have data ready
						stx_o_tmp  <= 1'b1;
						tstate  <= s_pop_byte;
						tx_data_valid_v = 0;
					end else begin
						tstate <= s_idle;
						stx_o_tmp <= 1'b1;
					end
				s_pop_byte :	begin
					case (data_bits)  // number of bits in a word
						2'b00 : begin
							bit_counter <= 3'b100;
							parity_xor  <= ^tx_data_v[4:0];
						end
						2'b01 : begin
							bit_counter <= 3'b101;
							parity_xor  <= ^tx_data_v[5:0];
						end
						2'b10 : begin
							bit_counter <= 3'b110;
							parity_xor  <= ^tx_data_v[6:0];
						end
						2'b11 : begin
							bit_counter <= 3'b111;
							parity_xor  <= ^tx_data_v[7:0];
						end
					endcase
					{shift_out[6:0], bit_out} <= tx_data_v;
					tstate <= s_send_start;
				end
				s_send_start :	begin
					if (~|counter)
						counter <= 5'b01111;
					else
					if (counter == 5'b00001)
					begin
						counter <= 0;
						tstate <= s_send_byte;
					end
					else
						counter <= counter - 1'b1;
					stx_o_tmp <= 1'b0;
				end
				s_send_byte :	begin
					if (~|counter)
						counter <= 5'b01111;
					else
					if (counter == 5'b00001)
					begin
						if (bit_counter > 3'b0)
						begin
							bit_counter <= bit_counter - 1'b1;
							{shift_out[5:0],bit_out  } <= {shift_out[6:1], shift_out[0]};
							tstate <= s_send_byte;
						end
						else if (~parity_pe) begin // end of byte
							tstate <= s_send_stop;
						end else begin
							case ({parity_ep,parity_sp})
								2'b00:	bit_out <= ~parity_xor;
								2'b01:	bit_out <= 1'b1;
								2'b10:	bit_out <= parity_xor;
								2'b11:	bit_out <= 1'b0;
							endcase
							tstate <= s_send_parity;
						end
						counter <= 0;
					end
					else
						counter <= counter - 1'b1;
					stx_o_tmp <= bit_out; // set output pin
				end
				s_send_parity :	begin
					if (~|counter)
						counter <= 5'b01111;
					else
					if (counter == 5'b00001)
					begin
						counter <= 4'b0;
						tstate <= s_send_stop;
					end
					else
						counter <= counter - 1'b1;
					stx_o_tmp <= bit_out;
				end
				s_send_stop :  begin
					if (~|counter) begin
						casex ({stop_bits,data_bits})
							3'b0xx:	  counter <= 5'b01101;     // 1 stop bit ok igor
							3'b100:	  counter <= 5'b10101;     // 1.5 stop bit
							default:	  counter <= 5'b11101;     // 2 stop bits
						endcase
					end else if (counter == 5'b00001) begin
						counter <= 0;
						tstate <= s_idle;
						_xmit_ack();
					end else begin
						counter <= counter - 1'b1;
					end
					stx_o_tmp <= 1'b1;
				end

				default : // should never get here
					tstate <= s_idle;
			endcase
		end // end if enable
	end // transmitter logic

	assign tx = stx_o_tmp;
//	assign stx_pad_o = lcr[`UART_LC_BC] ? 1'b0 : stx_o_tmp;    // Break condition	
	
	task init;
	begin
		// TBD
	end
	endtask
	
	task _set_dl(input reg[15:0] dl);
	begin
		dl_v = dl;
		start_dlc_v = 1;
	end
	endtask
	
	task _xmit_req(input reg[7:0] data);
	begin
		tx_data_v = data;
		tx_data_valid_v = 1'b1;
	end
	endtask
	

	// Auto-generated code to implement the BFM API
`ifdef PYBFMS_GEN
${pybfms_api_impl}
`endif
endmodule

