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
// DATE		   	: Mon, 25 Feb 2013 10:38:58
// AUTHOR		   : Anuj Pandey
// AUTHOR EMAIL	: anuj.pandey@techvulcan.com
// FILE NAME		: uctl_ctrlAhbRx.v
// VERSION        : 0.4
//-------------------------------------------------------------------

// TODO changes in version 0.4
// TODO threshold condition has changed..earlier i was checking for == now i am checking for >=

// TODO changes in version 0.3
// TODO delay in back to back transfers - pending
// TODO when tx part is working..no signal should b driven in this block - done

// TODO changes in version 0.2
// dmaRx2ctrl_sRdWr signal is registered now - done

module uctl_ctrlAhbRx#(
   parameter CNTR_WD     = 20                           ,                               
             ADDR_SIZE   = 32                           ,
             DATA_SIZE   = 32 
)(

   //----------------------------------------------------
   // Global signals
   //----------------------------------------------------

   //----------------------------------------------------
   // System uctl_sysClk
   //----------------------------------------------------
   input  wire                    uctl_sysClk           ,
   input  wire                    uctl_sysRst_n         ,

   //----------------------------------------------------
   // DMA interface
   //----------------------------------------------------
   input  wire [CNTR_WD     -1:0] dmaRx2ctrl_len        ,
   input  wire                    dmaRx2ctrl_sRdWr      ,// Read or write operation
   input  wire                    dmaRx2ctrl_stransEn   ,
   input  wire [ADDR_SIZE   -1:0] dmaRx2ctrl_sWrAddr    ,//TODO this signal wil directly go to the ahb or thru ctrl logic

   output reg                     ctrl2dmaRx_dn         ,


   

   //----------------------------------------------------
   // FIFO signals
   //----------------------------------------------------
   input  wire [5           -1:0] words_inFifo          ,

   //----------------------------------------------------
   // AHB i/o
   //----------------------------------------------------
   input  wire                    ahbc2ctrl_ack         ,// ack from ahb to ctrl logic dt info has recvd 
   input  wire                    ahbc2ctrl_addrDn      ,// after trsnfrin burst, done frm ahb 2 ctrl lgic 
   input  wire                    ahbc2ctrl_dataDn      ,// after trsnfrin whole data, done frm ahb 2 ctrl lgic
   input  wire [31           :0]  ahbc2ctrl_sWrAddr     ,

   output reg                     ctrl2ahbc_trEn        ,// enbl signl frm control logic 2 strt the trnsfr
   output wire [4            :0]  ctrl2ahbc_beats       ,// no f beats in a burst ( length f trnsfr )
   output wire [2            :0]  ctrl2ahbc_hSize       ,// width of transfer
   output wire [ADDR_SIZE  -1:0]  ctrl2ahbc_sWrAddr     , 
   output reg                    ctrl2ahbc_sRdWr 
               
      

   );   

   //----------------------------------------------------
   // internal reg / wires
   //----------------------------------------------------

   reg [CNTR_WD     -1:0]         nBytes               ;
   reg [4             :0]         ctrlBeats            ;
   reg [2             :0]         ctrlHsize            ;
   reg                            nBytes_ld            ;
   reg                            sys_addr_ld          ;
   reg [5           -1:0]         nWords_delta         ;
   reg [7           -1:0]         nBytes_delta         ;//no f bytes sent
   reg                            nBytes_decr          ;
   reg                            ctrl2ahbc_trEn_nxt   ;
   reg [3           -1:0]         cur_state            ,
                                  nxt_state            ;
   wire                           threshold            ;
   reg [31            :0]         sys_wrAdd            ;
   reg                            RdWr_ld              ;
   reg                            idle_state           ;

   //----------------------------------------------------
   // local params
   //----------------------------------------------------
   localparam  WORD           = 3'b010                  ;
   localparam  HWORD          = 3'b001                  ;
   localparam  BYTES          = 3'b000                  ; 

   localparam  INCR16         = 3'b111                  ; // 16 beat transfer
   localparam  INCR           = 3'b001                  ; // undefined length transfr
   localparam  STRANS         = 3'b000                  ; // single transfer

   localparam  IDLE           = 3'b000,
               FIFOTHRESHLD   = 3'b001,
               SUBTRREQ       = 3'b010,
               SUBTRANS       = 3'b011,
               WTDDN          = 3'b100;


   //----------------------------------------------------
   // code starts here
   //----------------------------------------------------


   assign threshold         = (words_inFifo >= nWords_delta) ? 1'b1 : 1'b0;
   assign ctrl2ahbc_beats   = ctrlBeats ; // ctrlHsize; 
   assign ctrl2ahbc_hSize   = ctrlHsize ; //ctrlBeats;
   assign ctrl2ahbc_sWrAddr = sys_wrAdd ;
   //assign ctrl2ahbc_sRdWr   = dmaRx2ctrl_sRdWr;  TODO : now we are registering this signal..and will send with ctrl2ahbc_trEn

   always @ (posedge uctl_sysClk , negedge  uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         sys_wrAdd <= {32{1'b0}};
      end
      else if(sys_addr_ld) begin
         sys_wrAdd <= dmaRx2ctrl_sWrAddr;
      end 
      else if(ahbc2ctrl_addrDn && !idle_state) begin
         sys_wrAdd <= ahbc2ctrl_sWrAddr;
      end
   end

   always @ (posedge uctl_sysClk , negedge  uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         ctrl2ahbc_trEn    <= 1'b0;
      end
      else begin 
         ctrl2ahbc_trEn    <= ctrl2ahbc_trEn_nxt;
      end
   end

   always @ (posedge uctl_sysClk , negedge  uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         ctrl2ahbc_sRdWr    <= 1'b0;
      end
      else if(RdWr_ld == 1'b1) begin 
         ctrl2ahbc_sRdWr    <= dmaRx2ctrl_sRdWr;
      end
   end


   always @ (posedge uctl_sysClk , negedge  uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         nBytes <= {CNTR_WD{1'b0}};             
      end
      // storing incoming byte length into local reg
      else if(nBytes_ld) begin 
         nBytes <= dmaRx2ctrl_len;
      end
      else if(nBytes_decr) begin
         nBytes <=  nBytes - nBytes_delta;
      end
   end


   always@(*) begin
      if(nBytes >= 20'd64) begin
         ctrlHsize    =  WORD  ;
         ctrlBeats    =  5'd16 ;
         nBytes_delta =  7'd64;
         nWords_delta =  5'd16;
      end
      else if (nBytes < 4) begin
         ctrlHsize    =  BYTES;
         ctrlBeats    =  nBytes[4:0];
         nBytes_delta =  nBytes[6:0];
         nWords_delta =  5'd1;
      end
      else begin 
         ctrlHsize    =  WORD;
         //ctrlBeats    =  {2'b00 , nBytes[4:2]};    TODO why we changed it
         ctrlBeats    =   nBytes[6:2];
         nBytes_delta =  {nBytes[6:2], 2'b00};
         nWords_delta =   nBytes[6:2];
      end
   end


   //----------------------------------------------------
   // state machine
   //----------------------------------------------------
   always@(*) begin//{
      ctrl2ahbc_trEn_nxt   = ctrl2ahbc_trEn;
      nBytes_decr          = 1'b0;
      nxt_state            = cur_state;
      nBytes_ld            = 1'b0;
      sys_addr_ld          = 1'b0;
      ctrl2dmaRx_dn        = 1'b0;
      RdWr_ld              = 1'b0;
      idle_state           = 1'b0;

      case(cur_state) //{
         // default state
         IDLE : begin//{
            idle_state  = 1'b1;
            if(dmaRx2ctrl_stransEn == 1'b1) begin//{
               nBytes_ld = 1'b1;
               sys_addr_ld = 1'b1;
               nxt_state = FIFOTHRESHLD ;
               RdWr_ld = 1'b1; // TODO new signal added
            end//}
         end//}

         FIFOTHRESHLD : begin//{
               RdWr_ld = 1'b0; // TODO new signal added
            if (nBytes=={CNTR_WD{1'b0}}) begin
               if(ahbc2ctrl_dataDn) begin
                  ctrl2dmaRx_dn    =1'b1;
                  nxt_state = IDLE;
               end
               else begin
                  nxt_state = WTDDN;
               end
            end
            else begin
               if(threshold == 1'b1) begin//{
                  nxt_state = SUBTRREQ ;
                  ctrl2ahbc_trEn_nxt = 1'b1; //signl wil go on clock only..
               end//}
            end
         end//}
         
         SUBTRREQ : begin//{
               RdWr_ld = 1'b0; // TODO new signal added
            if(ahbc2ctrl_ack) begin
               nBytes_decr = 1'b1;
               if (ahbc2ctrl_addrDn) begin
                  nxt_state = FIFOTHRESHLD;
               end
               else begin
                  nxt_state = SUBTRANS;
               end
               ctrl2ahbc_trEn_nxt = 1'b0;
            end
         end //}

         SUBTRANS: begin//{
               RdWr_ld = 1'b0; // TODO new signal added
            if (ahbc2ctrl_addrDn) begin
               nxt_state = FIFOTHRESHLD;
            end
            else begin
               nxt_state = SUBTRANS;
            end
         end//}

         WTDDN: begin//{
               RdWr_ld = 1'b0; // TODO new signal added
            if(ahbc2ctrl_dataDn) begin
               ctrl2dmaRx_dn   =1'b1;
               nxt_state     = IDLE;
            end

         end//}

      endcase//}
   end//}

   always @ (posedge uctl_sysClk or negedge  uctl_sysRst_n) begin
      if (!uctl_sysRst_n) begin
         cur_state <=  IDLE;
      end
      else begin
         cur_state <= nxt_state;
      end
   end 


endmodule


