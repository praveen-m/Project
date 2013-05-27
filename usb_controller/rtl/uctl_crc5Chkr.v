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
// DATE			   : Mon, 07 Jan 2013 15:43:00
// AUTHOR		   : Anuj Pandey
// AUTHOR EMAIL	: anuj.pandey@techvulcan.com
// FILE NAME		: crc5_chkr.v
// VERSION        : 0.2
//-------------------------------------------------------------------
//version 0.2 fix
//signal d is changed

module uctl_crc5Chkr(crc5_error,
                 crc_out,
                 crc_rx_data,
             //    clk,
             //    rst,
                 enbl
                );

  // i/p variables
     // input [0:4] crc_out;
     // input [0:10] crc_rx_data;
      input [4:0] crc_out;
      input [10:0] crc_rx_data;
    //  input clk;
   //   input rst;
      input enbl;

  // o/p variable
      output crc5_error;

 // i/p variables declared as wires
     // wire [4:0] crc_out;
     // wire [10:0] crc_rx_data;
  //    wire clk;
  //    wire rst;
      wire enbl;

 // o/p variable declared as wire coz we are using it in assign statement
      wire crc5_error;

  /* internal registers */

 // 16 bit internal reg = 5 bit crc_out + 11 bit crc_rx_data
     // wire [15:0] d;
      reg [0:15] d;
 // 5 bit internal reg .. initial values of flip flops
      reg [4:0] c= 5'b11111;
 // 5 bit internal reg for storing the value of residual
      reg [4:0] res_const;
   //always @(*) begin
   //   for(int i=0; i<11; i=i+1) begin
   //      d[15-i]  =  crc_rx_data[10-i];
   //      d[4-i]   =  crc_out[i];
   //   end     
   //end
 //assign  d  = {crc_rx_data[3],crc_rx_data[4],crc_rx_data[5],crc_rx_data[6],crc_rx_data[7],
 //              crc_rx_data[8],crc_rx_data[9],crc_rx_data[10],crc_rx_data[0],crc_rx_data[1],crc_rx_data[2], 
 //              crc_out[4],crc_out[3],crc_out[2],crc_out[1],crc_out[0]};    //TODO crc5 enter from MSB to LSB , rest enter from lsb to msb
  always @ ( * )
    begin
     //d =  { crc_rx_data, crc_out[0],crc_out[1],crc_out[2],crc_out[3],crc_out[4]};
    // d =  { crc_rx_data, crc_out};
     d =  {crc_out, crc_rx_data };
   //if(enbl) begin
    res_const[0] = d[13] ^ d[12] ^ d[11] ^ d[10] ^ d[9] ^ d[6] ^ d[5] ^ d[3] ^ d[0] ^ c[0] ^ c[1] ^ c[2];
    res_const[1] = d[14] ^ d[13] ^ d[12] ^ d[11] ^ d[10] ^ d[7] ^ d[6] ^ d[4] ^ d[1] ^ c[0] ^ c[1] ^ c[2] ^ c[3];
    res_const[2] = d[15] ^ d[14] ^ d[10] ^ d[9] ^ d[8] ^ d[7] ^ d[6] ^ d[3] ^ d[2] ^ d[0] ^ c[3] ^ c[4];
    res_const[3] = d[15] ^ d[11] ^ d[10] ^ d[9] ^ d[8] ^ d[7] ^ d[4] ^ d[3] ^ d[1] ^ c[0] ^ c[4];
    res_const[4] = d[12] ^ d[11] ^ d[10] ^ d[9] ^ d[8] ^ d[5] ^ d[4] ^ d[2] ^ c[0] ^ c[1];
    //  end
    end

   assign crc5_error = ((res_const != 5'b01100) && enbl) ? 1'b1 : 1'b0;  // 0 - no crc5 crror and 1 - crc5 error //c
 endmodule  
