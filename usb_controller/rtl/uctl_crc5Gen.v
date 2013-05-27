`timescale 1ns / 1ps
//-------------------------------------------------------------------
// Copyright © 2012 TECHVULCAN, Inc. All rights reserved.		   
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, nor	   
// its contents							   
// revealed in any manner to others without the express written	   
// permission	of TechVulcan 					   
// Licensed Material.						   
// Program Property of TECHVULCAN Incorporated.	
// ------------------------------------------------------------------
// DATE			   : Mon, 07 Jan 2013 14:29:56
// AUTHOR		   : Anuj Pandey
// AUTHOR EMAIL	: anuj.pandey@techvulcan.com
// FILE NAME		:uctl_crc5Gen .v
// VERSION        : 0.1
//-------------------------------------------------------------------



module uctl_crc5Gen(
  input [10:0] data_in,
  output [4:0] crc_out);

  reg [4:0] lfsr_c;
  wire   [4:0] lfsr_q = 5'b11111;

  assign crc_out = lfsr_c;

  always @(*) begin
    lfsr_c[0] = lfsr_q[0] ^ lfsr_q[3] ^ lfsr_q[4] ^ data_in[0] ^ 
                data_in[3] ^ data_in[5] ^ data_in[6] ^ data_in[9] ^
                data_in[10];
    lfsr_c[1] = lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[4] ^ data_in[1] ^
                data_in[4] ^ data_in[6] ^ data_in[7] ^ data_in[10];
    lfsr_c[2] = lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[2] ^ lfsr_q[3] ^
                lfsr_q[4] ^ data_in[0] ^ data_in[2] ^ data_in[3] ^
                data_in[6] ^ data_in[7] ^ data_in[8] ^ data_in[9] ^
                data_in[10];
    lfsr_c[3] = lfsr_q[1] ^ lfsr_q[2] ^ lfsr_q[3] ^ lfsr_q[4] ^
                data_in[1] ^ data_in[3] ^ data_in[4] ^ data_in[7] ^
                data_in[8] ^ data_in[9] ^ data_in[10];
    lfsr_c[4] = lfsr_q[2] ^ lfsr_q[3] ^ lfsr_q[4] ^ data_in[2] ^
                data_in[4] ^ data_in[5] ^ data_in[8] ^ data_in[9] ^
                data_in[10];

  end 
endmodule
