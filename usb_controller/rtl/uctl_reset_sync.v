`timescale 1ns / 1ps
//-------------------------------------------------------------------
// Copyright © 2013 TECHVULCAN, Inc. All rights reserved.		   
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, nor	   
// its contents							   
// revealed in any manner to others without the express written	   
// permission	of TechVulcan 					   
// Licensed Material.						   
// Program Property of TECHVULCAN Incorporated.	
// ------------------------------------------------------------------
// DATE		   	: Wed, 06 Mar 2013 19:10:47
// AUTHOR	      : Lalit Kumar
// AUTHOR EMAIL	: lalit.kumar@techvulcan.com
// FILE NAME		: uctl_reset_sync.v
// VERSION        : 0.1
//-------------------------------------------------------------------

   module uctl_reset_sync(
      input  wire        clk         ,
      input  wire        uctl_PoRst_n,
      output reg         rst_out_n   
   );
      reg                q;
   
   always @( posedge  clk or negedge uctl_PoRst_n) begin
      if(!uctl_PoRst_n) begin 
         q           <= 1'b0;
         rst_out_n   <= 1'b0;
      end
      else begin
         q              <= 1'b1;
         rst_out_n      <= q   ;
      end
   end
endmodule


      
