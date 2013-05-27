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
// DATE		    	: Sun, 03 Mar 2013 17:34:10
// AUTHOR		   : Anuj Pandey
// AUTHOR EMAIL	: anuj.pandey@techvulcan.com
// FILE NAME		: uctl_ctrlAhbTx.v
// VERSION        : 0.3
//-------------------------------------------------------------------

//TODO fixes in 0.2
// dmaTx2ctrl_sRdWr signal is registered now and making it low when transfer is finished. Earlier was assigning. - done

//TODO fixes we have to do in 0.3
//TODO delay in back to back transfers - pending
//TODO make RdWr logic as it was earlier - done
//TODO when Rx part is working..no signal should b driven in this block - done

module uctl_ctrlAhbTx#(
   parameter  CNTR_WD   = 20 ,
              ADDR_SIZE = 32 ,
              DATA_SIZE = 32 ,
              ADD_WIDTH = 4  


)(


   //---------------------------------------------------
   // Global signals
   //---------------------------------------------------

   //---------------------------------------------------
   // System uctl_sysClk and reset
   //---------------------------------------------------
   input  wire                    uctl_sysClk          ,
   input  wire                    uctl_sysRst_n        ,

   //---------------------------------------------------
   // DMA interface
   //---------------------------------------------------
   input  wire [CNTR_WD   -1  :0] dmaTx2ctrl_len       ,
   input  wire                    dmaTx2ctrl_sRdWr     ,// Read or write operation
   input  wire                    dmaTx2ctrl_stransEn  ,
   input  wire [ADDR_SIZE -1  :0] dmaTx2ctrl_sRdAddr   ,

   output reg                     ctrl2dmaTx_dataDn    ,

   //---------------------------------------------------
   // FIFO signals
   //---------------------------------------------------
   input  wire [5           -1:0] words_inFifo         ,

   //---------------------------------------------------
   // AHB i/o
   //---------------------------------------------------
   input  wire                    ahbc2ctrl_ack        ,// ack from ahb to ctrl logic dt info has recvd 
   input  wire                    ahbc2ctrl_addrDn     ,// after trsnfrin burst, done frm ahb 2 ctrl lgic 
   input  wire                    ahbc2ctrl_dataDn     ,// after trsnfrin whole data, done frm ahb 2 ctrl lgic
   input  wire [31           :0]  ahbc2ctrl_sWrAddr     ,

   output reg                     ctrl2ahbc_trEn       ,// enbl signl frm control logic 2 strt the trnsfr
   output wire [4            :0]  ctrl2ahbc_beats      ,// no f beats in a burst ( length f trnsfr )
   output wire [2            :0]  ctrl2ahbc_hSize      ,  // width of transfer
   output wire [ADDR_SIZE -1 :0]  ctrl2ahbc_sRdAddr    ,  
   output reg                     ctrl2ahbc_sRdWr 

   );

   localparam  IDLE           = 3'b000,
               MKBURST        = 3'b001,
               SUBTRREQ       = 3'b010,
               SUBTRANS       = 3'b011,
               WTDDN          = 3'b100,
         
               WORD           = 3'b010 ,
               HWORD          = 3'b001 ,
               BYTES          = 3'b000 ,
         

               INCR16         = 3'b111,                           
               INCR           = 3'b001;  

  localparam   DEPTH     = 2**ADD_WIDTH;
               

   //---------------------------------------------------
   // internal reg or wires
   //---------------------------------------------------
   reg  [2                    :0] nxt_state            ,
                                  cur_state            ;
   reg  [CNTR_WD            -1:0] nBytes               ; // ahb wil store no f bytes in this
   reg                            nBytes_ld            ;
   reg                            nBytes_decr          ;
   reg                            sys_addr_ld          ;
   reg                            ctrl2ahbc_trEn_nxt   ;
   reg  [2                    :0] ctrlHsize            ; // ahb wil store hsize in this reg
   reg  [4                    :0] ctrlBeats            ; // ahb wil store beats in this reg
   reg  [5                  -1:0] nWords_delta         ;
   reg  [7                  -1:0] nBytes_delta         ; //no f bytes sent
   wire                           threshold            ;
   reg [31            :0]         sys_rdAdd            ;
   reg                            RdWr_ld              ;
   reg                            idle_state           ; // signal tells that currently we are in idle state

   always @ (posedge uctl_sysClk , negedge  uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         sys_rdAdd <= {32{1'b0}};
      end
      else if(sys_addr_ld) begin
         sys_rdAdd <= dmaTx2ctrl_sRdAddr;
      end 
      else if(ahbc2ctrl_addrDn && !idle_state) begin
         sys_rdAdd <= ahbc2ctrl_sWrAddr;
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
         ctrl2ahbc_sRdWr    <= dmaTx2ctrl_sRdWr;
      end
   end



   always @ (posedge uctl_sysClk , negedge  uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         nBytes <= {CNTR_WD{1'b0}};             
      end
      // storing incoming byte length into local reg
      else if(nBytes_ld) begin 
         nBytes <= dmaTx2ctrl_len;
      end
      else if(nBytes_decr) begin
         nBytes <=  nBytes - nBytes_delta;
      end
   end

   always@(*) begin
      if(nBytes >= 20'd64) begin
         ctrlHsize    =  WORD  ;
         ctrlBeats    =  5'd16;
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
         //ctrlBeats    =  {2'b00 , nBytes[4:2]};    TODO why we changed it with below line
         ctrlBeats    =   nBytes[6:2];
         nBytes_delta =  {nBytes[6:2], 2'b00};
         nWords_delta =  nBytes[6:2];
      end
   end

   assign threshold        = ((DEPTH - words_inFifo) >= nWords_delta)? 1'b1 : 1'b0; 
   assign ctrl2ahbc_beats  = ctrlBeats   ;// ctrlHsize; 
   assign ctrl2ahbc_hSize  = ctrlHsize   ;//ctrlBeats;
   assign ctrl2ahbc_sRdAddr = sys_rdAdd ;
  // assign ctrl2ahbc_sRdWr  = dmaTx2ctrl_sRdWr;

   // STATE MACHINE
   always @ (*) begin
   nxt_state          = cur_state ;
   nBytes_ld          = 1'b0;
   ctrl2ahbc_trEn_nxt = 1'b0;
   ctrl2dmaTx_dataDn  = 1'b0;
   sys_addr_ld        = 1'b0;
   nBytes_decr        = 1'b0;
   RdWr_ld            = 1'b0;
   idle_state         = 1'b0;

   case(cur_state) 

      IDLE: begin
         idle_state  = 1'b1;
         if(dmaTx2ctrl_stransEn == 1'b1) begin
            nBytes_ld          = 1'b1;
            if(threshold) begin
               ctrl2ahbc_trEn_nxt = 1'b1;
               sys_addr_ld        = 1'b1;
               nxt_state          = SUBTRREQ;
               RdWr_ld            = 1'b1;
            end
            else begin
               ctrl2ahbc_trEn_nxt = 1'b0;
               RdWr_ld            = 1'b0;
               nxt_state          = IDLE;
            end
         end
      end

      MKBURST:begin//{
         RdWr_ld = 1'b0;
         if(nBytes== {CNTR_WD{1'b0}} ) begin
            if(ahbc2ctrl_dataDn) begin
               ctrl2dmaTx_dataDn    =1'b1;
               nxt_state = IDLE;
            end
            else begin
               nxt_state = WTDDN;
            end
         end
         else begin
            if(threshold == 1'b1)begin
               nxt_state = SUBTRREQ;
               ctrl2ahbc_trEn_nxt = 1'b1;
            end
            else begin
               nxt_state = MKBURST;
               ctrl2ahbc_trEn_nxt = 1'b0;
            end
         end
      end//}

      SUBTRREQ: begin 
         RdWr_ld = 1'b0;
         if(ahbc2ctrl_ack) begin
            nBytes_decr = 1'b1;
            if(ahbc2ctrl_addrDn) begin
               nxt_state = MKBURST;

           /*    if(threshold == 1'b1)begin
                  nxt_state = SUBTRREQ;
                  ctrl2ahbc_trEn_nxt = 1'b1;
               end
               else begin
                  nxt_state = MKBURST;
                  ctrl2ahbc_trEn_nxt = 1'b0;
               end
           */
            end
            else begin
               nxt_state = SUBTRANS;
            end
         ctrl2ahbc_trEn_nxt = 1'b0;
         end
      end


      SUBTRANS: begin//{
         RdWr_ld = 1'b0;
         if(ahbc2ctrl_addrDn) begin
            nxt_state = MKBURST;
         end
         else begin
            nxt_state = SUBTRANS;
         end
      end//}


      WTDDN: begin//{
         RdWr_ld = 1'b0;
         if(ahbc2ctrl_dataDn) begin
            ctrl2dmaTx_dataDn   =1'b1;
            nxt_state     = IDLE;
         end
      end//}


   endcase
   end


   always @ (posedge uctl_sysClk or negedge  uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         cur_state <=  IDLE;
      end
      else begin
         cur_state <= nxt_state;
      end
   end 


endmodule





