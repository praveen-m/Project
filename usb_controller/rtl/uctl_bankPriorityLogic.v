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
// DATE		   	: Fri, 22 Feb 2013 16:34:03
// AUTHOR	      : Lalit Kumar
// AUTHOR EMAIL	: lalit.kumar@techvulcan.com
// FILE NAME		: uctl_bankPriorityLogic .v
// VERSION        : 0.1
//-------------------------------------------------------------------

module uctl_bankPriorityLogic  (
   input  wire  [4        -1:0] uctl_bankReq   ,
   output wire                  uctl_memCe     ,
   output reg                   uctl_mem_rw    ,   
   output reg   [4        -1:0] uctl_chipSel    //use as ack to bankSeq block
   );

   
   assign uctl_memCe     = |uctl_chipSel;  

   always @(*) begin
      if(uctl_bankReq[0]) begin
         uctl_chipSel     = 4'b0001; 
         uctl_mem_rw      = uctl_bankReq[0];
      end                        
      else if(uctl_bankReq[1]) begin  
         uctl_chipSel     = 4'b0010;  
         uctl_mem_rw      = ~uctl_bankReq[1];
      end                        
      else if(uctl_bankReq[2]) begin  
         uctl_chipSel     = 4'b0100;  
         uctl_mem_rw      = uctl_bankReq[2];
      end                        
      else if(uctl_bankReq[3]) begin  
         uctl_chipSel     = 4'b1000;  
         uctl_mem_rw      = ~uctl_bankReq[3];
      end
      else begin
         uctl_chipSel     = 4'b0000; 
         uctl_mem_rw       = 1'b0;
      end
	end
endmodule 
   
         
 
         
