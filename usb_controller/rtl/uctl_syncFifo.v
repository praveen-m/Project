`timescale 1ns / 1ps

//-------------------------------------------------------------------
// Copyright © 2012 TECHVULCAN, Inc. All rights reserved.		   
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, nor	   
// its contents		                  
// revealed in any manner to others without the express written      
// permission   of TechVulcan                   
// Licensed Material.                     
// Program Property of TECHVULCAN Incorporated.   
// ------------------------------------------------------------------
// DATE           : thu, 28 Feb 2013 
// AUTHOR         : Sanjeeva
// AUTHOR EMAIL   : sanjeeva.n@techvulcan.com
// FILE NAME      : uctl_syncFifo.v
// VERSION        : 0.3
//-------------------------------------------------------------------

// TODO fixes in 0.3 
// one more signal is added now numOfFreeLocs.

/********************************************************************/
// Update 0.2 fix
// numOfData logic is fixed for wrptr = rdptr and fifo full condition
//
/********************************************************************/
module uctl_syncFifo #(
   parameter   ADD_WIDTH          = 4,
               DATA_WIDTH         = 32,
               NEAR_FULL_TH       = 2 // Near full threshold                 
)
(
   input  wire                      clk     ,
   input  wire                      rst_n   ,
   input  wire                      sw_rst  ,

   input  wire                      wrEn    ,
   input  wire                      rdEn    ,
   input  wire [DATA_WIDTH-1   : 0] dataIn  ,

   output wire                      full    ,
   output wire                      nearly_full ,
   output wire                      empty   ,
   output wire [DATA_WIDTH-1   : 0] dataOut ,
   output wire [ADD_WIDTH      : 0] numOfData,
   output wire [ADD_WIDTH      : 0] numOfFreeLocs
);

   localparam   DEPTH     = 2**ADD_WIDTH;

   //--------------------------------------
   // reg and wire declaration
   //--------------------------------------
   reg       [ADD_WIDTH     : 0] rd_ptr    ;
   reg       [ADD_WIDTH     : 0] wr_ptr    ;
   reg       [DATA_WIDTH-1  : 0] mem [0 : DEPTH - 1];

   //--------------------------------------
   // increment read/write pointer
   //--------------------------------------
   always @(posedge clk , negedge rst_n) begin
      if(!rst_n) begin
         wr_ptr <= {ADD_WIDTH+1{1'b0}};
         rd_ptr <= {ADD_WIDTH+1{1'b0}};
      end
      else if(sw_rst)begin
         wr_ptr <= {ADD_WIDTH+1{1'b0}};
         rd_ptr <= {ADD_WIDTH+1{1'b0}};
      end
      else begin
         if(wrEn && !full)begin
            wr_ptr <= wr_ptr+1'b1;
         end
         if(rdEn && !empty)begin            
            rd_ptr <= rd_ptr+1'b1;
         end 
      end
   end

   //--------------------------------------
   // output unregistered
   //--------------------------------------
   assign dataOut =  mem[rd_ptr[ADD_WIDTH-1:0]];
   assign numOfData = ( rd_ptr[ADD_WIDTH] != wr_ptr[ADD_WIDTH]) ? (DEPTH-(rd_ptr[ADD_WIDTH-1:0] - wr_ptr[ADD_WIDTH-1:0])) :
                      (wr_ptr[ADD_WIDTH-1:0] - rd_ptr[ADD_WIDTH-1:0]);
   assign numOfFreeLocs = (DEPTH - numOfData);

   //--------------------------------------
   // writing data into memory
   //--------------------------------------
   always @(posedge clk) begin  
      if(wrEn && !full)begin   
         mem[wr_ptr[ADD_WIDTH-1:0]] <= dataIn;
      end
   end

   //--------------------------------------
   // full and empty condition
   //--------------------------------------
   assign full          = ({rd_ptr[ADD_WIDTH],rd_ptr[ADD_WIDTH-1:0]}=={!wr_ptr[ADD_WIDTH],wr_ptr[ADD_WIDTH-1:0]}) ? 1'b1:1'b0;
   assign nearly_full   = (DEPTH - numOfData) <= NEAR_FULL_TH ? 1'b1 : 1'b0;
   assign empty         = ( rd_ptr==wr_ptr) ? 1'b1:1'b0;

endmodule
