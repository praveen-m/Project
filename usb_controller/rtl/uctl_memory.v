`timescale 1ns / 1ps
//-------------------------------------------------------------------
// Copyright © 2013 TECHVULCAN, Inc. All rights reserved.		   
// TechVulcan Confidential and Proprietary
// Not to be used, copied reprodumem_ced in whole or in part, nor	   
// its contents							   
// revealed in any manner to others without the express written	   
// permission	of TechVulcan 					   
// Limem_censed Material.						   
// Program Property of TECHVULCAN Incorporated.	
// ------------------------------------------------------------------
// DATE		   	: Tue, 26 Feb 2013 11:27:23 
// AUTHOR	      : Lalit Kumar
// AUTHOR EMAIL	: lalit.kumar@techvulcan.com
// FILE NAME		: uctl_memory.v
// VERSION        : 0.1
//-------------------------------------------------------------------

module uctl_memory #(
   parameter			MEM_ADDR_SIZE	= 15,
                     MEM_DATA_SIZE 	= 8
   )(
  input wire 		 		              coreClk   ,		//input clock
  input wire                          mem_ce    ,
  input wire 				              rw_en     ,    //input read/write enable
  input wire  	[MEM_ADDR_SIZE - 1:0]  mem_addr  ,	   //input memory write address
  input wire  	[MEM_DATA_SIZE - 1:0]  mem_dataIn,	   //input data 
  output reg 	[MEM_DATA_SIZE - 1:0]  mem_dataOut
   );

 

   localparam   MEM_SIZE    = 2**MEM_ADDR_SIZE<<2'b10; // 32 kB  
                  

   /////internal variable declaration/////////////////////////
   reg 	[MEM_DATA_SIZE - 1:0]	memory [0:MEM_SIZE-1];

   /////code start here///////////////////////////////////////
   always @ (posedge coreClk ) begin 
      if(mem_ce && rw_en) begin 
   	   mem_dataOut <= memory[mem_addr];	
      end
   end
   always @ (posedge coreClk ) begin 
      if(mem_ce && !rw_en) begin 
   	 memory[mem_addr]  <= mem_dataIn;
   	end		
	end
endmodule
