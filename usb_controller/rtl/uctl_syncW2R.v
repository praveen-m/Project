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
// DATE			   : Mon, 29 Apr 2013 14:00:00
// AUTHOR		   : MAHMOOD
// AUTHOR EMAIL	: vdn_mahmood@techvulcan.com
// FILE NAME		: uctl_syncW2R.v
//-------------------------------------------------------------------
module sync_w2r #(parameter FIFO_ADDRSIZE = 2)(
   input wire                 rclk, 
   input wire                 rrst_n,
   output reg  [FIFO_ADDRSIZE:0]   rq2_wptr,
   input wire  [FIFO_ADDRSIZE:0]   wptr);

   reg [FIFO_ADDRSIZE:0] rq1_wptr;
  
   always @(posedge rclk or negedge rrst_n) begin
      if (!rrst_n) begin 
         {rq2_wptr,rq1_wptr} <= 0;
      end
      else begin
         {rq2_wptr,rq1_wptr} <= {rq1_wptr,wptr};
      end
   end
endmodule

