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
// DATE			   : Mon, 29 Apr 2013 13:55:52
// AUTHOR		   : MAHMOOD
// AUTHOR EMAIL	: vdn_mahmood@techvulcan.com
// FILE NAME		: uctl_syncR2W.v
//------------------------------------------------------------------
module sync_r2w #(parameter FIFO_ADDRSIZE = 2)(
   output reg [FIFO_ADDRSIZE:0] wq2_rptr,
   input wire [FIFO_ADDRSIZE:0] rptr,
   input                   wclk, 
   input                   wrst_n);
   
   reg [FIFO_ADDRSIZE:0] wq1_rptr;
   
   always @(posedge wclk or negedge wrst_n)  begin
      if (!wrst_n) begin
         {wq2_rptr,wq1_rptr} <= 0;
      end
      else  begin 
         {wq2_rptr,wq1_rptr} <= {wq1_rptr,rptr};
      end
   end
endmodule

