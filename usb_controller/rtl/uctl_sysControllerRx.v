`timescale 1ns / 1ps
//-------------------------------------------------------------------
// Copyright © 2012 TECHVULCAN, Inc. All rights reserved.   
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, nor 
// its contents  
// revealed in any manner to others without the express written  
// permission of TechVulcan 
// Licensed Material.   
// Program Property of TECHVULCAN Incorporated.
// ------------------------------------------------------------------
// DATE           : Mon, 04 Feb 2013 14:52:12
// AUTHOR         : Sanjeeva
// AUTHOR EMAIL   : sanjeeva.n@techvulcan.com
// FILE NAME      : uctl_sysControllerRx.v
// VERSION        : 0.5
//-------------------------------------------------------------------
/* TODO
* sctrlRx2reg_updtRdBuf -- update signal for register interface.
* sctrlRx2sepr_epNum    -- endpoint number for output.

/*
//Update fix 0.2
// added sctrlRx2sepr_wrAddrEn signal for loading system address
//Update fix 0.3
// list mode is added.
// read count was updating in update state it has to be updated before going to update state.
//Update fix 0.4
// logic mismatch(begin-end) in update state of SM. fixed
// added when read count is 0 it will go to update state and update the register block
// added sctrlRx2reg_empty signal
//update fix 0.5
// read count is updated to N+1(if 0 it will read one packet and if f it will read 16 packets)
*/
module uctl_sysControllerRx
#(   parameter  
   `include "../rtl/uctl_core.vh"
      )
(
   // -------------------------------------------
   // Global Signals
   // -------------------------------------------
   input  wire               uctl_rst_n               ,// Active low reset
   input  wire               coreClk                  ,// The core clock

   input  wire               sw_rst                   ,// software reset
   // -------------------------------------------
   // Register Block Interface
   // -------------------------------------------
   input  wire               reg2sctrlRx_rd           ,// Read enable from register block interface
   input  wire [3       :0]  reg2sctrlRx_epNum        ,// Endpoint number
   input  wire [3       :0]  reg2sctrlRx_rdCount      ,// Number of packets to be read
   input  wire               reg2sctrlRx_listMode     ,
   output reg                sctrlRx2reg_updtRdBuf    ,// Update signal to update the register values
   output wire [3       :0]  sctrlRx2reg_rdCnt        ,// read counter for number of pacckets
   output reg  [1       :0]  sctrlRx2reg_status       ,
   output wire [4       :0]  sctrlRx2reg_fullPktCnt   ,
   output reg                sctrlRx2reg_empty        ,
   // -------------------------------------------
   // System Endpoint Controller interface
   // -------------------------------------------
   input  wire               sepr2sctrlRx_bufEmpty    ,// Endpoint buffer empty
   input  wire               sepr2sctrlRx_rdPtrsRcvd  ,// Endpoint Controller has got the pointer
   input  wire               sepr2sctrlRx_transferDn  ,// Indicates assigned data packet transfer has been done
   input  wire               sepr2sctrlRx_hdrRdDn     ,// Header read completion signal for Read
   input  wire               sepr2sctrlRx_bufUpdtDn   ,// Buffer update completion signal for Read
   input  wire[PKTCNTWD-1:0] sepr2sctrlRx_fullPktCnt  ,

   output reg                sctrlRx2sepr_inIdle      ,// Indicates the System Controller FSM is in IDLE state
   output wire [3        :0] sctrlRx2sepr_epNum       ,// Endpoint number
   output reg                sctrlRx2sepr_getRdPtrs   ,// System Endpoint Controller to get the 
                                                       // current endpoint attributes
   output reg                sctrlRx2sepr_hdrRd       ,// Signal to read the header information from memory
   output reg                sctrlRx2sepr_rd          ,// Read signal for reading out data from the 
                                                       // Endpoint buffer to system endpoint
   output reg                sctrlRx2sepr_updtRdBuf   ,// Update endpoint buffer for the current read transaction
   output reg                sctrlRx2sepr_wrAddrEn     

);
   // -------------------------------------------
   // FSM variables and parameters
   // -------------------------------------------
   localparam [2       :0]  SCTRLRX_IDLE     = 3'b000, 
                            SCTRLRX_RDPTR    = 3'b001,
                            SCTRLRX_RDHDR    = 3'b010,
                            SCTRLRX_RDDATA   = 3'b011,
                            SCTRLRX_UPDT     = 3'b100;

   reg        [2       :0]  current_state    , 
                            next_state       ;
   reg        [3       :0]  reg_rdCount      ;
   reg                      inc_rdCount      ;
   reg                      rst_rdCount      ;

   // -------------------------------------------
   // Next state logic
   // -------------------------------------------
   always @(*)begin
      next_state                         =  current_state;
      sctrlRx2sepr_inIdle                =  1'b0;
      sctrlRx2sepr_getRdPtrs             =  1'b0;
      sctrlRx2sepr_hdrRd                 =  1'b0;
      sctrlRx2sepr_rd                    =  1'b0;
      sctrlRx2sepr_updtRdBuf             =  1'b0;
      sctrlRx2reg_updtRdBuf              =  1'b0;
      inc_rdCount                        =  1'b0;
      sctrlRx2sepr_wrAddrEn              =  1'b0;
      sctrlRx2reg_empty                  =  1'b0;
      rst_rdCount                        =  1'b0;
      sctrlRx2reg_status                 = 2'b00;
      case (current_state) 
         SCTRLRX_IDLE  :  begin
            sctrlRx2sepr_inIdle          =  1'b1;
            rst_rdCount                  =  1'b1;
            if(reg2sctrlRx_rd == 1'b1) begin
               next_state                = SCTRLRX_RDPTR;
               sctrlRx2sepr_wrAddrEn     = 1'b1;
               sctrlRx2sepr_getRdPtrs    = 1'b1;
               sctrlRx2reg_updtRdBuf     = 1'b1;
               sctrlRx2reg_status        = 2'b10;
            end
         end 

         SCTRLRX_RDPTR :  begin 
            sctrlRx2sepr_getRdPtrs       =  1'b1;
            if((sepr2sctrlRx_rdPtrsRcvd   == 1'b1) && (!reg2sctrlRx_listMode)) begin
               next_state                = SCTRLRX_RDHDR;
               if(sepr2sctrlRx_bufEmpty  == 1'b1)  begin
                  next_state             = SCTRLRX_IDLE;
                  sctrlRx2reg_updtRdBuf  = 1'b1;
                  sctrlRx2reg_empty      = 1'b1;
                  sctrlRx2reg_status     = 2'b00; 
               end
            end
            else if((sepr2sctrlRx_rdPtrsRcvd   == 1'b1) && (reg2sctrlRx_listMode)) begin
               next_state                = SCTRLRX_UPDT;
            end
         end

         SCTRLRX_RDHDR :  begin  
            sctrlRx2reg_status           = 2'b10;
            sctrlRx2sepr_hdrRd           =  1'b1;                             
            if(sepr2sctrlRx_hdrRdDn      == 1'b1)  begin
               next_state                = SCTRLRX_RDDATA;
            end
         end

         SCTRLRX_RDDATA :  begin
            sctrlRx2sepr_rd               =  1'b1;
            if(sepr2sctrlRx_transferDn   == 1'b1) begin
               next_state                 = SCTRLRX_UPDT;
            end
         end

         SCTRLRX_UPDT  :  begin
            if(!reg2sctrlRx_listMode)begin
               sctrlRx2sepr_updtRdBuf     =  1'b1;                        
               if(sepr2sctrlRx_bufUpdtDn  == 1) begin
                  if(reg2sctrlRx_rdCount  == reg_rdCount)begin
                     sctrlRx2reg_updtRdBuf=  1'b1;
                     sctrlRx2reg_status   =  2'b00;
                     next_state           =  SCTRLRX_IDLE;
                  end
                  else begin
                     inc_rdCount          =  1'b1;
                     next_state           =  SCTRLRX_RDPTR;
                  end
               end
            end
            else begin
               sctrlRx2reg_updtRdBuf      =  1'b1;
               sctrlRx2reg_status         =  2'b00;
               next_state                 =  SCTRLRX_IDLE;
            end
			end
         default :   next_state           = current_state;

      endcase
   end

   // -------------------------------------------
   // State register
   // -------------------------------------------
   always @( posedge coreClk, negedge uctl_rst_n ) begin
      if(!uctl_rst_n) begin
         current_state                   <= SCTRLRX_IDLE;
      end
      else if (sw_rst) begin
         current_state                   <= SCTRLRX_IDLE;
      end
      else begin
         current_state                   <= next_state;
      end
   end

   // -------------------------------------------
   // increment rdCount
   // -------------------------------------------
   always @( posedge coreClk, negedge uctl_rst_n ) begin
      if(!uctl_rst_n) begin
         reg_rdCount                     <= {4{1'b0}};
      end
      else if(sw_rst == 1'b1)begin
         reg_rdCount                     <= {4{1'b0}};
      end
      else begin
         if(rst_rdCount == 1'b1)begin
            reg_rdCount                  <= {4{1'b0}};
         end
         else if(inc_rdCount == 1'b1)begin
            reg_rdCount                  <= reg_rdCount + 4'b0001;
         end
         else begin
            reg_rdCount                  <= reg_rdCount;
         end
      end
   end

   // -------------------------------------------
   // Continuous assignment
   // -------------------------------------------
   assign sctrlRx2sepr_epNum            = reg2sctrlRx_epNum;
   assign sctrlRx2reg_rdCnt             = reg2sctrlRx_rdCount - reg_rdCount;
   assign sctrlRx2reg_fullPktCnt        = (sepr2sctrlRx_fullPktCnt <= 9'b000011110 )? sepr2sctrlRx_fullPktCnt[4:0] : 5'b11111;

endmodule
