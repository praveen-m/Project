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
// DATE		   	: Fri, 19 Apr 2013 18:47:17
// AUTHOR		   : Anuj Pandey
// AUTHOR EMAIL	: anuj.pandey@techvulcan.com
// FILE NAME		: uctl_synchronizer.v
//-------------------------------------------------------------------
module uctl_synchronizer #(
   parameter BYPASS      = 0

)(
   input  wire clk    ,
   input  wire reset  ,
   input  wire dataIn ,

   output wire dataOut
   );


   reg  flop1Out;
   reg  flop2Out;

   generate begin
      if (BYPASS == 0) begin
         always@(posedge clk or negedge reset)begin
            if(!reset)begin
               flop1Out <= 1'b0;
               flop2Out <= 1'b0;
            end
            else begin
               flop1Out <= dataIn;
               flop2Out <= flop1Out;
            end
         end
         assign dataOut =  flop2Out; 
      end
      else begin
         assign dataOut =  dataIn; 
      end
   end
   endgenerate

endmodule
