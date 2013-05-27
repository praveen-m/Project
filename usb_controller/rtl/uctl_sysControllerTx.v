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
// DATE              : Tue, 05 Feb 2013 12:50:40
// AUTHOR            : Darshan Naik
// AUTHOR EMAIL      : darshan.naik@techvulcan.com
// FILE NAME         : uctl_sysControllerTx.v
// VERSION           : 0.6
//-------------------------------------------------------------------

//VERSION            : 0.6
//                      disable fragmentation logic implemented
//VERSION            : 0.5
//                      tstatus bit is set to 2'b00 for full and nearly full condition
//VERSION            : 0.4
//                      sctrlTx2reg_full signal added    
//VERSION            : 0.3
//                      generation of zero lenght packet implemented   
//VERSION            : 0.2 
//                      list protocol implemented,
//VERSION            : 0.1
//                      intial release

/*TODO

  change the name of following signal to wrTrLength
 
  

*/

//-----------------------------------------------------------------
//-----------------------------------------------------------------

module uctl_sysControllerTx #(
                              parameter PKTCNTWD =9
   )(
   input  wire                       sw_rst                          ,//to reset this module
   //--------------------------------------------------------------
   // Global signals
   //---------------------------------------------------------------
   input  wire                       uctl_rst_n                      ,// System Reset
   input  wire                       coreClk                         ,//core clock
   //--------------------------------------------------------------
   // System Endpoint Controller Interface               
   //--------------------------------------------------------------
   input  wire                       sept2sctrlTx_bufFull            ,//endpoint buffer full
   input  wire                       sept2sctrlTx_wrPtrsRecvd        ,//indicates when the endpoint controller has got the pointer
   input  wire                       sept2sctrlTx_transferDn         ,//indicates the assigned data packet trasfer 
   input  wire                       sept2sctrlTx_transferErr        ,//indicates there was a error in thr transfer
   input  wire                       sept2sctrlTx_hdrWrDn            ,//header write completion signal for write
   input  wire                       sept2sctrlTx_bufUpdtDn          ,//buffer update completion signal for write transaction
   input  wire [10               :0] sept2sctrlTx_eptBufSize         ,//buffer size in bytes for the endpoint:
   input  wire [PKTCNTWD-1       :0] sept2sctrlTx_fullPktCnt         ,
   output reg                        sctrlTx2sept_wrAddrEn           ,
   output wire [3                :0] sctrlTx2sept_epNum              ,//endpoint number
   output wire [19               :0] sctrlTx2sept_wrPktLength        ,//length of the current transfer in bytes
   output reg                        sctrlTx2sept_updtWrBuf          ,//update endpoint buffer for current transaction
   output reg                        sctrlTx2sept_inIdle             ,//indicates when in IDLE state
   output reg                        sctrlTx2sept_getWrPtrs          ,//signal used to get the current endpoint attributes 
   output reg                        sctrlTx2sept_wr                 ,// write signal to endpoint controller for writing data to endpoint buffer
   output reg                        sctrlTx2sept_hdrWr              ,//signal to write the header information of the current packet
   //--------------------------------------------------------------
   // Register Interface               
   //--------------------------------------------------------------         
   //TODO: change the name of following signal to wrTrLength
   input  wire [19               :0] reg2sctrlTx_wrPktLength         ,//lenght of the pkt to transfered
   input  wire [3                :0] reg2sctrlTx_epNum               ,// end Point number
   input  wire                       reg2sctrlTx_wr                  ,// signal from syatem to write
   input  wire                       reg2sctrlTx_disFrag             ,//will disable fragmentation 
   input  wire                       reg2sctrlTx_listMode            ,//              
   output wire [4                :0] sctrlTx2reg_fullPktCnt          ,               
   output wire [19               :0] sctrlTx2reg_length              ,//length of the orginal data pending
   output wire [4                :0] sctrlTx2reg_fragCnt             ,//fragmentation count to be updated in register
   output reg  [1                :0] sctrlTx2reg_status              ,//fragmentation count to be updated in register
   output reg                        sctrlTx2reg_full                ,// signal indicating buffer is full
   output reg                        sctrlTx2reg_updt                 //update signal to update the  values
   );

   // --------------------------------------------------------------
   // Localparams
   // --------------------------------------------------------------
   localparam  IDLE       = 3'b000,
               SC_GETPTRS = 3'b001,
               SC_DATA    = 3'b010,
               SC_HEADER  = 3'b011,
               SC_UPDATE  = 3'b100;

   // --------------------------------------------------------------
   // reg/wire declarations
   // --------------------------------------------------------------
   reg  [2              :0] current_state    ;
   reg  [2              :0] next_state       ;
   reg  [19             :0] rem_tr_ln        ;
   reg  [19             :0] rem_tr_ln_last   ;
   reg  [19             :0] pktLn_last       ; 
   wire [19             :0] ept_buf_size     ;
   wire [19             :0] pktLn_fragEn     ;
   wire [19             :0] pktLn_fragDis    ;
   reg  [4              :0] frag_cntr        ;
   reg                      frag_cntr_ld     ;
   reg                      frag_cntr_inc    ;     
   reg                      rem_tr_ln_ld     ;
   reg                      rem_tr_ln_dec    ;
   wire                     rem_tr_ln_isz    ;
   reg                      rem_tr_ln_ld_last;
   reg                      zlp_case         ;
   reg                      pktLn_ld_last    ;
   wire                     tr_ln_nz         ;
   wire                     pkt_ln_nz        ;  
   wire                     set_zlp_case     ;
   reg                      clr_zlp_case     ;
   wire                     tr_ln_pkt_ln_eq  ;
   
 
  
   //----------------------------------------------------------------
   // fragmentation counter               
   //---------------------------------------------------------------  
   always @(posedge coreClk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         frag_cntr <= 5'b0_0000;
      end
      else begin
         if(frag_cntr_ld) begin
            frag_cntr <=5'b0_0001 ;
         end
         else if (frag_cntr_inc) begin
            if( frag_cntr == 5'b1_1111) begin
               frag_cntr <= 5'b1_1111;
            end
            else begin
               frag_cntr <= frag_cntr+1'b1 ;
            end
         end
      end
   end

   //------------------------------------------------------------
   // length decrement logic               
   //-----------------------------------------------------------  
   always @(posedge coreClk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         rem_tr_ln <= {20{1'b0}};
      end
      else begin  
         if(rem_tr_ln_ld) begin
            rem_tr_ln <= reg2sctrlTx_wrPktLength;
         end
         else if (rem_tr_ln_dec) begin
            rem_tr_ln <= rem_tr_ln - sctrlTx2sept_wrPktLength;
         end
      end
   end


   always @(posedge coreClk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         rem_tr_ln_last <= {20{1'b0}};
      end
      else begin  
         if(rem_tr_ln_ld_last) begin
            rem_tr_ln_last <= rem_tr_ln;
         end
         else begin
            rem_tr_ln_last <= {20{1'b0}};
         end
      end
   end

   always @(posedge coreClk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         pktLn_last <= {20{1'b0}};
      end
      else begin  
         if(pktLn_ld_last) begin
            pktLn_last <= ept_buf_size;
         end
         else begin
            pktLn_last <= {20{1'b0}};
         end
      end
   end
      
   always @(posedge coreClk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         zlp_case <= 1'b0;
      end
      else begin  
         if(set_zlp_case) begin
            zlp_case <= 1'b1;
         end
         else if (clr_zlp_case) begin
            zlp_case <= 1'b0;
         end
      end
   end


   assign ept_buf_size              = {{9{1'b0}},sept2sctrlTx_eptBufSize}        ;

   assign rem_tr_ln_isz             = (rem_tr_ln      == {20{1'b0}}) ? 1'b1: 1'b0;

   assign set_zlp_case              = (pkt_ln_nz && tr_ln_nz && tr_ln_pkt_ln_eq) ? 
                                                                       1'b1:1'b0 ; 
   
   assign tr_ln_nz                  = (rem_tr_ln_last != {20{1'b0}}) ? 1'b1:1'b0 ;
   
   assign pkt_ln_nz                 = (pktLn_last     != {20{1'b0}}) ? 1'b1:1'b0 ;
   
   assign tr_ln_pkt_ln_eq           = (rem_tr_ln_last == pktLn_last) ? 1'b1:1'b0 ;

   assign sctrlTx2sept_wrPktLength  = (reg2sctrlTx_disFrag)          ? 
                                       pktLn_fragDis : pktLn_fragEn              ;

   assign pktLn_fragEn              = (rem_tr_ln >= ept_buf_size)    ? 
                                       ept_buf_size : rem_tr_ln                  ;

   assign pktLn_fragDis             = rem_tr_ln                                  ; 

   assign sctrlTx2sept_epNum        = reg2sctrlTx_epNum                          ;           

   assign sctrlTx2reg_length        = rem_tr_ln                                  ;

   assign sctrlTx2reg_fragCnt       = frag_cntr                                  ;

   assign sctrlTx2reg_fullPktCnt    = (sept2sctrlTx_fullPktCnt <= 9'b000011110) ? 
                                       sept2sctrlTx_fullPktCnt[4:0] : 5'b11111   ;   

   //----------------------------------------------
   // State Machine Logic               
   //----------------------------------------------  
   always @(*) begin
      next_state                 = current_state;
      sctrlTx2reg_status         = 2'b00;
      sctrlTx2sept_getWrPtrs     = 1'b0 ;
      sctrlTx2sept_hdrWr         = 1'b0 ;
      sctrlTx2sept_wr            = 1'b0 ;
      sctrlTx2sept_updtWrBuf     = 1'b0 ;
      sctrlTx2sept_inIdle        = 1'b0 ;
      frag_cntr_inc              = 1'b0 ;  
      sctrlTx2reg_updt           = 1'b0 ;
      rem_tr_ln_dec              = 1'b0 ;
      frag_cntr_ld               = 1'b0 ;
      rem_tr_ln_ld               = 1'b0 ;
      sctrlTx2sept_wrAddrEn      = 1'b0 ;
      rem_tr_ln_ld_last          = 1'b0 ;
      pktLn_ld_last              = 1'b0 ;
      clr_zlp_case               = 1'b0 ;
      sctrlTx2reg_full           = 1'b0 ;     
 
      case (current_state)
         IDLE:begin
            if(reg2sctrlTx_wr)begin
               next_state             = SC_GETPTRS;
               sctrlTx2sept_wrAddrEn  = 1'b1 ;   
               sctrlTx2sept_getWrPtrs = 1'b1 ;
               frag_cntr_ld           = 1'b1 ;            
               rem_tr_ln_ld           = 1'b1 ;
               sctrlTx2reg_updt       = 1'b1 ;
               sctrlTx2reg_status     = 2'b10;
            end
            else begin
               next_state=IDLE;
               sctrlTx2sept_inIdle        =1'b1;
            end
         end // case: IDLE

         SC_GETPTRS:begin
            sctrlTx2sept_getWrPtrs =1'b1;
            if((sept2sctrlTx_wrPtrsRecvd) && 
                  (!reg2sctrlTx_listMode))   begin
               if(sept2sctrlTx_bufFull) begin
                  next_state              = IDLE ;
                  sctrlTx2reg_full        = 1'b1 ;
                  sctrlTx2reg_updt        = 1'b1 ;
                  sctrlTx2reg_status      = 2'b00;
               end
               else begin      
                  next_state     =SC_DATA ;
               end
            end
            else if ((sept2sctrlTx_wrPtrsRecvd) && 
                        (reg2sctrlTx_listMode))   begin
               next_state     =SC_UPDATE;
            end
         end // case: SC_GETPTRS

         SC_DATA: begin
            sctrlTx2sept_wr=1'b1;
            if(sept2sctrlTx_transferDn) begin
               next_state     =SC_HEADER;
            end 
            else if (sept2sctrlTx_transferErr) begin
               next_state           = IDLE ;
               sctrlTx2reg_updt     = 1'b1 ;
               sctrlTx2reg_status   = 2'b00;
            end
            else begin
               next_state     = SC_DATA;
            end
            
         end // case: SC_DATA

         SC_HEADER: begin
            sctrlTx2sept_hdrWr=1'b1;
            if(sept2sctrlTx_hdrWrDn==1'b1) begin
               next_state        = SC_UPDATE;
               rem_tr_ln_dec     = 1'b1;
               if(!rem_tr_ln_isz) begin
                  rem_tr_ln_ld_last = 1'b1;
                  pktLn_ld_last     = 1'b1;
               end
            end
            else begin
               next_state  = SC_HEADER;
            end
         end // case: SC_HEADER
         
         SC_UPDATE:begin
            if(!reg2sctrlTx_listMode ) begin   
               sctrlTx2sept_updtWrBuf  = 1'b1;
               if(sept2sctrlTx_bufUpdtDn == 1'b1) begin
                  
                  if(!rem_tr_ln_isz) begin
                     next_state = SC_GETPTRS;
                     frag_cntr_inc           = 1'b1;
                  end
                  else begin
                     if(zlp_case) begin
                        next_state          = SC_GETPTRS;
                        clr_zlp_case        = 1'b1;
                     end
                     else begin
                     next_state             = IDLE ;
                     sctrlTx2reg_updt       = 1'b1 ;
                     sctrlTx2reg_status     = 2'b00;
                     end
                  end
               end
            end
            else begin
               next_state             = IDLE ;
               sctrlTx2reg_updt       = 1'b1 ;
               sctrlTx2reg_status     = 2'b00;
            end 
         end // case: SC_UPDATE
         
         default: next_state = current_state;
         
      endcase
   end // always @ (*)

   always @(posedge coreClk or negedge uctl_rst_n) begin
      if(!uctl_rst_n ) begin
         current_state <= IDLE;
      end
      else if(sw_rst) begin
         current_state <= IDLE;
      end
      else begin
         current_state <= next_state;
      end
   end
   
endmodule 
