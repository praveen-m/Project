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
// DATE		   	: Fri, 19 Apr 2013 14:32:16
// AUTHOR	      : Sanjeeva
// AUTHOR EMAIL	: sanjeeva.n@techvulcan.com
// FILE NAME		: uctl_fifo_syn_asyn.v
// VERSION        : 0.3
//-------------------------------------------------------------------

//TODO fixes in 0.2
// 1. Generate availSpace for async fifo
// 2. cmdIf2memIn changes have to do --- PENDING
//TODO fixes in 0.3 
// 1. file name changed and numOfFreeLocs signal is added

module uctl_fifo_syn_asyn #(
   parameter BYPASS             = 0 ,
             FIFO_ADDRSIZE      = 4 ,
             FIFO_DATASIZE      = 32,
             NEAR_FULL_TH       = 2
   )(

   input wire                       rClk        ,
   input wire                       wClk        ,
   input wire                       wrst_n      ,
   input wire                       sw_rst      ,
   input wire                       rrst_n      ,
   input wire                       wrEn        ,
   input wire                       rdEn        ,

   input wire [FIFO_DATASIZE-1: 0]  dataIn      ,
   output wire [FIFO_DATASIZE-1: 0] dataOut     ,
   
   output wire                      full        ,
   output wire                      nearly_full ,
   output wire                      empty       ,

   output wire [FIFO_ADDRSIZE  : 0] numOfData   ,
   output wire [FIFO_ADDRSIZE  : 0] numOfFreeLocs

);
   generate begin
      if (BYPASS == 0) begin
         uctl_asyncFifo #(
            .FIFO_ADDRSIZE        ( FIFO_ADDRSIZE), 
            .FIFO_DATASIZE        ( FIFO_DATASIZE), 
            .NEAR_FULL_TH         ( NEAR_FULL_TH )) 
            i_uctl_asyncFifo (
            .wclk         (wClk        ), 
            .rclk         (rClk        ), 
           // .swRst        (sw_rst      ),
            .wrst_n       (wrst_n      ), 
            .rrst_n       (rrst_n      ), 
            .w_en         (wrEn        ), 
            .r_en         (rdEn        ), 
            .fifo_data_in (dataIn      ), 
            .nearly_full  (nearly_full ), 
            .wfull        (full        ), 
            .rempty       (empty       ), 
            .fifo_data_out(dataOut     ),
            .numOfData    (numOfData   ),
            .numOfFreeLocs(numOfFreeLocs)
         );
      end
      else begin
         uctl_syncFifo #(
            .ADD_WIDTH            ( FIFO_ADDRSIZE), 
            .DATA_WIDTH           ( FIFO_DATASIZE), 
            .NEAR_FULL_TH         ( NEAR_FULL_TH ))  
             i_uctl_syncFifo (
            .clk         (wClk         ), 
            .rst_n       (wrst_n       ), 
            .sw_rst      (sw_rst       ), 
              
            .wrEn        (wrEn         ), 
            .rdEn        (rdEn         ), 
            .dataIn      (dataIn       ), 
                
            .full        (full         ), 
            .nearly_full (nearly_full  ), 
            .empty       (empty        ), 
            .dataOut     (dataOut      ), 
            .numOfData   (numOfData    ),
            .numOfFreeLocs(numOfFreeLocs)
        );  
      end
	end
   endgenerate
endmodule
