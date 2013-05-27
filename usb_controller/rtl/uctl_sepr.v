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
// DATE           : Mon, 04 Feb 2013 15:42:41
// AUTHOR         : Sanjeeva
// AUTHOR EMAIL   : sanjeeva.n@techvulcan.com
// FILE NAME      : uctl_sepr.v
// VERISON        : 0.5
//------------------------------------------------------------------
/********************************************************************/
/*
// update 0.2 fix
   sepr2dmaRx_sRdWr signal is added and tied to zero.
   cmdif signals added for external dma operation.
// update 0.3 fix
   added dma offset address now on dmaRx will get system address from sepr not from reg block.
// update 0.4 fix
   dma length logic is changed.
   sepr2dmaRx_sWrAddr logic is changed. made word address
// update fix 0.5
   dmaRx2sepr_dn is registered because of comb input
   cmdIf2sepr_dn is registered because of comb input
*/
/* TODO
* eptd2sepr_reqErr
*/
module uctl_sepr #(
   parameter  
    `include "../rtl/uctl_core.vh" 
)(
   // ---------------------------------------------------
   // Global Signals
   // ---------------------------------------------------
   input wire                    uctl_rst_n                     ,//Active low reset
   input wire                    core_clk                       ,//The core clock

   input  wire                   sw_rst                         ,
   // ---------------------------------------------------
   // System Controller interface
   // ---------------------------------------------------
   input wire [3           :0]   sctrlRx2sepr_epNum             ,// Endpoint number
   input wire                    sctrlRx2sepr_inIdle            ,// FSM is in idle state
   input wire                    sctrlRx2sepr_hdrRd             ,// Read the header information from memory
   input wire                    sctrlRx2sepr_getRdPtrs         ,// SEPCR to get the current endpoint attribute
   input wire                    sctrlRx2sepr_rd                ,// reading out data from the EPT buffer to SEPCR
   input wire                    sctrlRx2sepr_updtRdBuf         ,// Update endpoint buffer 
   input wire                    sctrlRx2sepr_wrAddrEn          ,

   output reg                    sepr2sctrlRx_rdPtrsRcvd        ,// Endpoint Controller has got the pointer
   output reg                    sepr2sctrlRx_bufEmpty          ,// Endpoint buffer empty
   output reg                    sepr2sctrlRx_hdrRdDn           ,// Header read completion signal for Read
   output reg                    sepr2sctrlRx_transferDn        ,// Assigned data packet transfer has been done
   output reg                    sepr2sctrlRx_bufUpdtDn         ,// Buffer update completion signal for Read
   output wire[PKTCNTWD-1    :0] sepr2sctrlRx_fullPktCnt        ,

   // ---------------------------------------------------
   // DMA Interface
   // ---------------------------------------------------
   input wire                    dmaRx2sepr_dn                  ,// DMA transfer completed

   output wire [ADDR_SIZE -1 :0] sepr2dmaRx_laddrIn             ,// Local buffer Address
   output reg                    sepr2dmaRx_dmaStart            ,// DMA Read signal      -- sepr2dmaRx_rd
   output wire [19           :0] sepr2dmaRx_len                 ,// Length of transfer in bytes
   output wire [ADDR_SIZE -1 :0] sepr2dmaRx_epStartAddr         ,// Endpoint buffer start address
   output wire [ADDR_SIZE -1 :0] sepr2dmaRx_epEndAddr           ,// Endpoint buffer end address
   output wire                   sepr2dmaRx_sRdWr               ,
   output reg  [ADDR_SIZE -1 :0] sepr2dmaRx_sWrAddr             ,

   // ---------------------------------------------------
   // Memory Interface
   // ---------------------------------------------------
   input wire [DATA_SIZE -1  :0] mif2sepr_rdData                ,// Read data from memory
   input wire                    mif2sepr_ack                   ,// Ready signal from memory
   input wire                    mif2sepr_dVal                  ,// data valid 
   output wire [ADDR_SIZE -1 :0] sepr2mif_addr                  ,// Address of the memory location in local buffer
   output reg                    sepr2mif_rd                    ,// Read request to memory

   // ---------------------------------------------------
   // Register Block Interface
   // ---------------------------------------------------

   input wire [2          :0]    reg2sepr_dmaMode               ,// DMA selector
   input wire [ADDR_SIZE -1 :0]  reg2sepr_sWrAddr               ,// 32 bit write address in system memory for Dma operation
 
   // ---------------------------------------------------
   // Endpoint Data interface
   // ---------------------------------------------------

 //input wire                    eptd2sepr_reqErr               ,// Request error indication
   input wire [ADDR_SIZE -1  :0] eptd2sepr_startAddr            ,// Endpoint Start Address
   input wire [ADDR_SIZE -1  :0] eptd2sepr_endAddr              ,// Endpoint end Address
   input wire [ADDR_SIZE -1  :0] eptd2sepr_rdPtr                ,// Endpoint Read pointer
   input wire [ADDR_SIZE -1  :0] eptd2sepr_wrPtr                ,// Endpoint write pointer
   input wire                    eptd2sepr_lastOp               ,// Last operation for this endpoint
   input wire                    eptd2sepr_updtDn               ,// update is done
   input wire [PKTCNTWD-1    :0] eptd2sepr_fullPktCnt           ,

   output wire[3             :0] sepr2eptd_epNum                ,// Physical Endpoint number
   output reg                    sepr2eptd_reqData              ,// Request signal to get all the endpoint attributes
   output reg                    sepr2eptd_updtReq              ,// Update request for the below Endpoint Attributes
   output wire[ADDR_SIZE -1  :0] sepr2eptd_rdPtr                ,// Read pointer value to be updated


 //---------------------------------------------------
 //CMD Interface
 //--------------------------------------------------
   input  wire                  cmdIf2sepr_dn                   ,
   output wire [2           :0] sepr2cmdIf_dmaMode              ,
   output reg                   sepr2cmdIf_rd                   , 
   output wire [31          :0] sepr2cmdIf_addr                 ,//local buffer address
   output wire [19          :0] sepr2cmdIf_len                  ,
   output wire [31          :0] sepr2cmdIf_epStartAddr          ,
   output wire [31          :0] sepr2cmdIf_epEndAddr           

);
   // --------------------------------------------------
   // Local parameters
   // --------------------------------------------------

   localparam                    LASTOP_READ     =  1'b0;

   // --------------------------------------------------
   // FSM variables and parameters
   // --------------------------------------------------
   localparam [2          :0]    SEPR_IDLE     = 3'b000, 
                                 SEPR_RDPTR    = 3'b001,
                                 SEPR_RDHDR    = 3'b010,
                                 SEPR_RDDATA   = 3'b011,
                                 SEPR_UPDT     = 3'b100;

   reg        [2          :0]    current_state    , 
                                 next_state       ;


   //---------------------------------------------------
   // Local wires and registers
   //---------------------------------------------------
   reg  [ADDR_SIZE       -1:0] startAddr        ;
   reg  [ADDR_SIZE       -1:0] endAddr          ;
   reg  [ADDR_SIZE       -1:0] rdPtr            ;
   reg  [ADDR_SIZE       -1:0] wrPtr            ;
   reg                         lastOp           ;
   reg  [ADDR_SIZE       -1:0] nextRdPtr        ;
   reg                         sepr2eptd_updtReq_nxt ;
   reg                         sepr2sctrlRx_bufUpdtDn_nxt;
   reg                         ld_Ptr           ;
   reg                         ld_hdr           ;      
   reg                         dmaDone          ; 
   reg                         dmaRx2sepr_dn_nxt;
   reg                         cmdIf2sepr_dn_nxt;
   reg                         wrAddrEn         ; 
   wire [2                 :0] memHdr           ;
   wire [32              -1:0] avble_dmaSize    ;
   reg                         sepr2mif_rd_nxt  ;
   wire                        bufEmpty         ;
   wire [2                 :0] byteEn           ;
   reg                         sepr2dmaRx_dmaStart_nxt;
   //---------------------------------------------------
   // Code Starts From Here
   //---------------------------------------------------
   generate begin 
      if(REGISTER_EN ==1)begin 
         always @(posedge core_clk, negedge uctl_rst_n) begin
            if(!uctl_rst_n) begin     
              startAddr          <=       {32{1'b0}}  ;
              endAddr            <=       {32{1'b0}}  ;
              wrPtr              <=       {32{1'b0}}  ;
              lastOp             <=       1'b0        ;
            end
            else if(sw_rst == 1'b1)begin
               startAddr         <=       {32{1'b0}}  ;
               endAddr           <=       {32{1'b0}}  ;
               wrPtr             <=       {32{1'b0}}  ;
               lastOp            <=       1'b0        ;
            end
            else begin
               if(ld_Ptr == 1'b1)begin
                  startAddr      <=      eptd2sepr_startAddr; 
                  endAddr        <=      eptd2sepr_endAddr  ; 
                  wrPtr          <=      eptd2sepr_wrPtr    ; 
                  lastOp         <=      eptd2sepr_lastOp   ;
               end
            end
         end
      end
      else begin
         always @(*) begin
              startAddr          =        eptd2sepr_startAddr; 
              endAddr            =        eptd2sepr_endAddr  ; 
              wrPtr              =        eptd2sepr_wrPtr    ; 
              lastOp             =        eptd2sepr_lastOp   ; 
         end
      end
   end
   endgenerate 
         
   assign sepr2mif_addr                   =   rdPtr;
   assign bufEmpty                        =   (wrPtr == rdPtr) && (lastOp == LASTOP_READ) ;

   always @(*)begin
      next_state                          =   current_state;
      sepr2sctrlRx_bufEmpty               =   1'b0 ;
      sepr2sctrlRx_rdPtrsRcvd             =   1'b0 ;
      sepr2sctrlRx_hdrRdDn                =   1'b0 ;
      sepr2sctrlRx_transferDn             =   1'b0 ;
      sepr2eptd_updtReq_nxt               =   sepr2eptd_updtReq ;
      sepr2sctrlRx_bufUpdtDn_nxt          =   1'b0 ;
      sepr2eptd_reqData                   =   1'b0 ;
      ld_Ptr                              =   1'b0 ;
      ld_hdr                              =   1'b0 ;
      dmaDone                             =   1'b0 ;
      wrAddrEn                            =   1'b0 ;
      sepr2mif_rd_nxt                     =   sepr2mif_rd;
      sepr2cmdIf_rd                       =   1'b0;      
      sepr2dmaRx_dmaStart_nxt             =   sepr2dmaRx_dmaStart;

      case (current_state)
         SEPR_IDLE  :  begin
               sepr2sctrlRx_bufUpdtDn_nxt = 1'b0;
            if(sctrlRx2sepr_getRdPtrs == 1'b1) begin
               wrAddrEn                   =   sctrlRx2sepr_wrAddrEn ;
               sepr2eptd_reqData          =   1'b1 ;
               ld_Ptr                     =   1'b1 ;
               next_state                 =   SEPR_RDPTR;
            end
            else if(sctrlRx2sepr_hdrRd == 1'b1) begin
               sepr2mif_rd_nxt            =   1'b1 ;
               next_state                 =   SEPR_RDHDR;
            end
            else if(sctrlRx2sepr_rd == 1'b1) begin
               if(reg2sepr_dmaMode==3'b010) begin
                  sepr2dmaRx_dmaStart_nxt =   1'b1 ;
               end
               else if(reg2sepr_dmaMode==3'b001 |
                       reg2sepr_dmaMode==3'b000   )begin
                  sepr2cmdIf_rd           =  1'b1;      
               end  
               next_state                 =   SEPR_RDDATA;
            end
            else if(sctrlRx2sepr_updtRdBuf == 1'b1) begin
               sepr2eptd_updtReq_nxt      =   1'b1 ;
               next_state                 =   SEPR_UPDT ;
            end
         end 

         SEPR_RDPTR :  begin
            sepr2sctrlRx_bufEmpty         =   bufEmpty;
            sepr2sctrlRx_rdPtrsRcvd       =   1'b1 ;
            next_state                    =   SEPR_IDLE ;
         end

         SEPR_RDHDR :  begin
            if (mif2sepr_ack == 1'b1) begin  
               sepr2mif_rd_nxt            =   1'b0 ;
               ld_hdr                     =   1'b1 ;
               sepr2sctrlRx_hdrRdDn       =   1'b1 ;
               next_state                 =   SEPR_IDLE ;
            end
         end

         SEPR_RDDATA :  begin
            sepr2dmaRx_dmaStart_nxt       =   1'b0 ; 
            if(dmaRx2sepr_dn_nxt == 1'b1 || cmdIf2sepr_dn_nxt == 1'b1) begin 
               sepr2sctrlRx_transferDn    =   1'b1 ;
               dmaDone                    =   1'b1 ;
               next_state                 =   SEPR_IDLE ;
            end
         end

         SEPR_UPDT  :  begin
            if(eptd2sepr_updtDn == 1'b1) begin
               sepr2eptd_updtReq_nxt      =   1'b0 ;
               sepr2sctrlRx_bufUpdtDn_nxt =   1'b1 ;
            end
            if(sctrlRx2sepr_updtRdBuf == 1'b0) begin
               next_state                 =   SEPR_IDLE ;
            end
         end

         default :   next_state           =   current_state;
      endcase

   end

   // --------------------------------------------------
   // State register
   // --------------------------------------------------
   always @( posedge core_clk, negedge uctl_rst_n ) begin
      if(!uctl_rst_n ) begin
         current_state                   <=  SEPR_IDLE;
      end
      else if(sw_rst == 1'b1) begin
         current_state                   <=  SEPR_IDLE;
      end
      else if(sctrlRx2sepr_inIdle == 1'b1) begin
         current_state                   <=  SEPR_IDLE;
      end
      else begin
         current_state                   <=  next_state;
      end
   end

   // --------------------------------------------------
   // Registered data
   // --------------------------------------------------

   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin    
         rdPtr                           <= {32{1'b0}};
      end
      else if(sw_rst == 1'b1) begin
         rdPtr                           <= {32{1'b0}};
      end
      else begin
         if (ld_Ptr == 1'b1) begin
            rdPtr                        <= eptd2sepr_rdPtr; 
         end
         else if(ld_hdr == 1'b1) begin
            if(rdPtr > endAddr) begin
               rdPtr                     <= startAddr;
            end
            else begin
               rdPtr                     <= rdPtr + 3'b100;
            end
         end
         else begin
            rdPtr                        <= rdPtr;
         end
      end
   end 

   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin   
         sepr2eptd_updtReq               <= 1'b0;
      end
      else if(sw_rst == 1'b1) begin
         sepr2eptd_updtReq               <= 1'b0;
      end
      else begin
         sepr2eptd_updtReq               <= sepr2eptd_updtReq_nxt ;
      end
   end

   //DMA and CMD done register
   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin   
         dmaRx2sepr_dn_nxt               <= 1'b0;
         cmdIf2sepr_dn_nxt               <= 1'b0; 
      end
      else if(sw_rst == 1'b1) begin
         dmaRx2sepr_dn_nxt               <= 1'b0;
         cmdIf2sepr_dn_nxt               <= 1'b0; 
      end
      else begin
         dmaRx2sepr_dn_nxt               <= dmaRx2sepr_dn;
         cmdIf2sepr_dn_nxt               <= cmdIf2sepr_dn; 
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin   
         nextRdPtr                       <=  {32{1'b0}};
      end
      else if(sw_rst == 1'b1) begin
         nextRdPtr                       <=  {32{1'b0}};
      end
      else begin
         if(mif2sepr_dVal == 1'b1) begin
            nextRdPtr                    <=  mif2sepr_rdData; 
         end
         else begin
            nextRdPtr                    <=  nextRdPtr;
         end
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin   
         sepr2mif_rd                     <=  1'b0;
      end
      else if(sw_rst == 1'b1) begin
         sepr2mif_rd                     <=  1'b0;
      end
      else begin
         sepr2mif_rd                     <=  sepr2mif_rd_nxt;
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin   
         sepr2dmaRx_dmaStart             <=  1'b0;
      end
      else if(sw_rst == 1'b1) begin
         sepr2dmaRx_dmaStart             <=  1'b0;
      end
      else begin
         sepr2dmaRx_dmaStart             <=  sepr2dmaRx_dmaStart_nxt;
      end
   end


   always @ (posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         sepr2dmaRx_sWrAddr               <= {32{1'b0}};
      end
      else if(wrAddrEn)begin
         sepr2dmaRx_sWrAddr               <= reg2sepr_sWrAddr;
      end
      else if(dmaDone)begin
         sepr2dmaRx_sWrAddr               <= sepr2dmaRx_sWrAddr +  {avble_dmaSize[19:2] , 2'b00} + byteEn;
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin   
         sepr2sctrlRx_bufUpdtDn               <= 1'b0;
      end
      else if(sw_rst == 1'b1) begin
         sepr2sctrlRx_bufUpdtDn               <= 1'b0;
      end
      else begin
         sepr2sctrlRx_bufUpdtDn               <= sepr2sctrlRx_bufUpdtDn_nxt ;
      end
   end

   // --------------------------------------------------
   // Combinational Logic
   // --------------------------------------------------
   assign  memHdr   = ( nextRdPtr[1:0] == 2'b00 ) ? 3'b000 : 3'b100;
   assign  avble_dmaSize                 =   (rdPtr <= nextRdPtr) ? ({nextRdPtr[31:2],2'b00}- rdPtr) - (memHdr - nextRdPtr[1:0]) : 
                                             ((endAddr + 3'b100 - rdPtr)+({nextRdPtr[31:2],2'b00} - startAddr)) -(memHdr - nextRdPtr[1:0]) ;
   assign  sepr2dmaRx_len                =   avble_dmaSize[19:0]     ;
   assign  byteEn                        =   ((avble_dmaSize[1] || avble_dmaSize[0]) == 1'b1) ? 3'b100 : 3'b000 ;
   assign  sepr2dmaRx_epStartAddr        =   startAddr               ;
   assign  sepr2dmaRx_epEndAddr          =   endAddr                 ;
   assign  sepr2dmaRx_laddrIn            =   rdPtr                   ;
   assign  sepr2eptd_epNum               =   sctrlRx2sepr_epNum      ;
   assign  sepr2eptd_rdPtr               =   {nextRdPtr[31:2], 2'b00};
   assign  sepr2dmaRx_sRdWr              =   1'b0                    ;
   assign  sepr2cmdIf_addr               =   rdPtr                   ; 
   assign  sepr2cmdIf_len                =   avble_dmaSize[19:0]     ; 
   assign  sepr2cmdIf_epStartAddr        =   startAddr               ; 
   assign  sepr2cmdIf_epEndAddr          =   endAddr                 ; 
   assign  sepr2cmdIf_dmaMode            =   reg2sepr_dmaMode        ;
   assign  sepr2sctrlRx_fullPktCnt       =   eptd2sepr_fullPktCnt    ;
endmodule
