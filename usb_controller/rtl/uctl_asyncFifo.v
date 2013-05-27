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
// DATE			   : Mon, 29 Apr 2013 12:46:20
// AUTHOR		   : MAHMOOD
// AUTHOR EMAIL	: vdn_mahmood@techvulcan.com
// FILE NAME		: uctl_asyncFifo.v
// VERSION        : 0.3
//-------------------------------------------------------------------
/*updates
version 0.3
numOfFreeLocs is added
swrst is added

version 0.2
seperate sync for both read and write pointers
numOfData cond is changed
*/
module uctl_asyncFifo #(
      parameter FIFO_DATASIZE = 25, 
      parameter FIFO_ADDRSIZE = 2,
      parameter NEAR_FULL_TH  = 2)(

      input wire                       swRst,
      input wire                       wclk, 
      input wire                       wrst_n,
      input wire                       w_en, 
      input wire [FIFO_DATASIZE-1:0]   fifo_data_in,
      output reg                       wfull,
         
      input wire                       rclk,
      input wire                       rrst_n,
      input wire                       r_en, 
      output wire [FIFO_DATASIZE-1:0]  fifo_data_out,
      output reg                       rempty,
      output wire [FIFO_ADDRSIZE   :0] numOfData,
      output wire                      nearly_full,
      output wire [FIFO_ADDRSIZE   :0] numOfFreeLocs);  
      
      localparam DEPTH = 1<<FIFO_ADDRSIZE; 

      wire [FIFO_ADDRSIZE-1: 0]    waddr; 
      wire [FIFO_ADDRSIZE-1: 0]    raddr;
      reg  [FIFO_ADDRSIZE:   0]    wptr; 
      reg  [FIFO_ADDRSIZE:   0]    rptr; 
      wire [FIFO_ADDRSIZE:   0]    wq2_rptr; 
      wire [FIFO_ADDRSIZE:   0]    rq2_wptr;

      reg [FIFO_DATASIZE-1:0] mem [0:DEPTH-1];
      reg [FIFO_ADDRSIZE:0]  rbin;
      wire [FIFO_ADDRSIZE:0] rgraynext;
      wire [FIFO_ADDRSIZE:0] rbinnext;

      reg  [FIFO_ADDRSIZE :0] wbin;
      wire [FIFO_ADDRSIZE :0] wgraynext; 
      wire [FIFO_ADDRSIZE :0] wbinnext;
      
    sync_r2w #(.FIFO_ADDRSIZE (FIFO_ADDRSIZE))i_sync_r2w (.wq2_rptr(wq2_rptr), .rptr(rptr),
                        .wclk(wclk), .wrst_n(wrst_n));
   
    sync_w2r #(.FIFO_ADDRSIZE (FIFO_ADDRSIZE)) i_sync_w2r (.rq2_wptr(rq2_wptr), .wptr(wptr),
                        .rclk(rclk), .rrst_n(rrst_n));

   assign raddr      = rbin[FIFO_ADDRSIZE-1:0];
   assign rbinnext   = rbin + (r_en & ~rempty);
   assign rgraynext  = (rbinnext>>1) ^ rbinnext;
   assign rempty_val = (rgraynext == rq2_wptr); 

   assign waddr      = wbin[FIFO_ADDRSIZE-1:0];
   assign wbinnext   = wbin + (w_en & ~wfull);
   assign wgraynext  = (wbinnext>>1) ^ wbinnext;
   assign wfull_val  = (wgraynext=={~wq2_rptr[FIFO_ADDRSIZE:FIFO_ADDRSIZE-1],
                        wq2_rptr[FIFO_ADDRSIZE-2:0]});
   
   //----------------------------------------------------------------
   //read logic
   //----------------------------------------------------------------
   assign fifo_data_out = mem[raddr];

   //----------------------------------------------------------------
   //write logic
   //----------------------------------------------------------------
   always @(posedge wclk) begin
      if (w_en) begin      //TODO
         mem[waddr] <= fifo_data_in;
      end
   end

   //----------------------------------------------------------------
   //
   //----------------------------------------------------------------
   always @(posedge rclk or negedge rrst_n) begin
      if (!rrst_n) begin
         {rbin, rptr} <= 0;
      end
      else if (swRst) begin
         {rbin, rptr} <= 0;
      end
      else begin
         {rbin, rptr} <= {rbinnext, rgraynext};
      end
   end

   always @(posedge rclk or negedge rrst_n)  begin
      if (!rrst_n) begin
         rempty <= 1'b1;
      end
      else if (swRst) begin
         rempty <= 1'b1;
      end
      else begin 
         rempty <= rempty_val;
      end
   end

   //--------------------------------------------------------------------
   //
   //--------------------------------------------------------------------
   always @(posedge wclk or negedge wrst_n) begin
      if (!wrst_n) begin
         {wbin, wptr} <= 0;
      end
      else if (swRst) begin
         {wbin, wptr} <= 0;
      end
      else  begin 
         {wbin, wptr} <= {wbinnext, wgraynext};
      end
   end

   always @(posedge wclk or negedge wrst_n) begin
      if (!wrst_n) begin
         wfull <= 1'b0;
      end
      else if (swRst) begin
         wfull <= 1'b0;
      end
      else  begin
         wfull <= wfull_val;
      end
   end

   assign   numOfData   =  (wbin[FIFO_ADDRSIZE] != rbin[FIFO_ADDRSIZE]) ? (DEPTH-(rbin[FIFO_ADDRSIZE-1:0] - wbin[FIFO_ADDRSIZE-1:0])):
                              (wbin[FIFO_ADDRSIZE-1:0] - rbin[FIFO_ADDRSIZE-1:0]);
   assign   nearly_full =  (DEPTH - numOfData) <= NEAR_FULL_TH ? 1'b1 : 1'b0;
   assign   numOfFreeLocs = (DEPTH - numOfData);

endmodule
 
  // assign   numOfData   =  ((wbin[FIFO_ADDRSIZE] == rbin[FIFO_ADDRSIZE]) && !wfull) ? (wbin[FIFO_ADDRSIZE-1:0] - rbin[FIFO_ADDRSIZE-1:0]):
  //                            (DEPTH-(rbin[FIFO_ADDRSIZE-1:0] - wbin[FIFO_ADDRSIZE-1:0]));

   
   
   
   

