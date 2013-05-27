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
// DATE		   	: Sat, 02 Mar 2013 13:57:34
// AUTHOR	      : MAHMOOD
// AUTHOR EMAIL	: vdn_mahmood@techvulcan.com
// FILE NAME		: uctl_ahbSlave.v
// VERSION        : 0.2
//-------------------------------------------------------------------
//version 0.2
//put condition for htrans_r signal.
//-------------------------------------------------------------------
module uctl_ahbSlave( 
   
   //----------------------------------------------
   // AHB slave interface
   //---------------------------------------------- 
   input  wire                       hClk               ,//system clock
   input  wire                       hReset_n           ,//reset signal for Soc
   input  wire                       swRst              ,//sw reset
   input  wire [31               :0] haddr              ,//sytem address bus
   input  wire [1                :0] htrans             ,//Indicates the type of current transfer
   input  wire                       hwrite             ,//transfer direction Write:1 Read:0
   input  wire [2                :0] hsize              ,//protection control signal
   input  wire [31               :0] hwdata             ,//write data bus
   input  wire                       hsel               ,//slave select signal
   input  wire                       hready_in          ,//
   output wire [31               :0] hrdata             ,//read data bus
   output reg                        hready_out         ,//transfer completion signal
   output wire [1                :0] hresp              ,//transfer response from slave

   //----------------------------------------------
   // cmdInf interface
   //----------------------------------------------
   output reg                        cmdIf_trEn,
   output reg                        cmdIf_req,          
   output wire [31               :0] cmdIf_addr,         
   output wire                       cmdIf_wrRd,         
   input  wire                       cmdIf_ack,          

   output reg                        cmdIf_wrData_req,   
   output wire [31               :0] cmdIf_wrData,       
   input  wire                       cmdIf_wrData_ack,   

   output reg                        cmdIf_rdData_req,   
   input  wire [31               :0] cmdIf_rdData,       
   input  wire                       cmdIf_rdData_ack    
   );


   localparam   IDLE     =2'b00,
                BUSY     =2'b01,
                NSEQ     =2'b10,
                SEQ      =2'b11;

   localparam   OKAY     =2'b00,
                ERROR    =2'b01;

   localparam   CM_IDLE     = 2'b00,
                CM_WAIT     = 2'b01,
                CM_DATA     = 2'b10;
   
   reg  [31                :0] haddr_r             ; 
   reg  [2                 :0] hsize_r             ; 
   reg                         hwrite_r            ;
   reg                         addr_ld             ;
   reg                         cmdIf_wrData_req_nxt;
   reg                         cmdIf_rdData_req_nxt;
   reg                         cmdIf_req_nxt       ;
   reg                         cmdIf_trEn_nxt      ;
   reg  [1                 :0] htrans_r            ;
   reg  [1                 :0] cur_state           ;
   reg  [1                 :0] nxt_state           ;

   wire                        hsel_l              ;
   wire                        cm_write            ;
   wire                        cm_read             ;

   assign   hsel_l         = hsel & hready_in;
   assign   hresp          =  OKAY  ;


   always @(*) begin
      nxt_state               =  cur_state; 
      cmdIf_trEn_nxt          =  cmdIf_trEn;
      cmdIf_req_nxt           =  cmdIf_req;
      cmdIf_wrData_req_nxt    =  cmdIf_wrData_req;
      cmdIf_rdData_req_nxt    =  cmdIf_rdData_req;
      addr_ld                 =  1'b0;
      hready_out              =  1'b1;

      case (cur_state)
         CM_IDLE: begin
            if(htrans == NSEQ && hsel_l == 1'b1) begin
               nxt_state         = CM_WAIT;
               cmdIf_req_nxt     = 1'b1;
               cmdIf_trEn_nxt    = 1'b1;
               addr_ld           = 1'b1;  //write enbl for addr reg
            end   
         end

         CM_DATA: begin
            if(htrans == NSEQ && hsel_l == 1'b1) begin
               nxt_state         = CM_WAIT;
               cmdIf_req_nxt     = 1'b1;
               cmdIf_trEn_nxt    = 1'b1;
               addr_ld           = 1'b1;  //write enbl for addr reg
               cmdIf_wrData_req_nxt  =  1'b0;
               cmdIf_rdData_req_nxt  =  1'b0;
            end
            else if(htrans_r == SEQ || htrans_r == NSEQ) begin
               if(hwrite_r) begin
                  cmdIf_rdData_req_nxt  =  1'b0;
                  if(cmdIf_wrData_ack) begin
                     if (htrans == SEQ) begin
                        cmdIf_wrData_req_nxt  =  1'b1;
                     end
                     else begin
                        cmdIf_trEn_nxt        =  1'b0;
                        cmdIf_wrData_req_nxt  =  1'b0;
                        nxt_state             =  CM_IDLE;
                     end
                     hready_out  =  1'b1;
                  end
                  else begin
                     hready_out  =  1'b0;
                  end
               end
               else begin
                  cmdIf_wrData_req_nxt  =  1'b0;
                  if(cmdIf_rdData_ack) begin
                     if (htrans == SEQ) begin
                        cmdIf_rdData_req_nxt  =  1'b1;
                     end
                     else begin
                        cmdIf_trEn_nxt        =  1'b0;
                        cmdIf_rdData_req_nxt  =  1'b0;
                        nxt_state             =  CM_IDLE;
                     end
                     hready_out     =  1'b1;
                  end
                  else begin
                     hready_out     =  1'b0;
                  end
               end
            end
            else if (htrans_r == BUSY) begin
               nxt_state             =  CM_DATA;
               cmdIf_wrData_req_nxt  =  1'b0;
               cmdIf_rdData_req_nxt  =  1'b0;
            end
            else begin
               cmdIf_wrData_req_nxt  =  1'b0;
               cmdIf_rdData_req_nxt  =  1'b0;
               cmdIf_req_nxt         =  1'b0;
               cmdIf_trEn_nxt        =  1'b0;
               nxt_state             =  CM_IDLE;
            end
         end

         CM_WAIT: begin
            hready_out  =  1'b0;
            if(cmdIf_ack) begin
               nxt_state            = CM_DATA;
               cmdIf_req_nxt        = 1'b0;
               if(cm_write) begin
                  cmdIf_wrData_req_nxt = 1'b1;
               end
               if(cm_read) begin
                  cmdIf_rdData_req_nxt = 1'b1;
               end
            end
         end
      endcase
   end

   always @(posedge hClk or negedge hReset_n) begin   
      if(!hReset_n) begin   
         cur_state <= CM_IDLE;
      end
      else begin
         cur_state <= nxt_state;
      end
   end

   always @(posedge hClk or negedge hReset_n) begin   
      if(!hReset_n) begin   
         cmdIf_trEn <= 1'b0;
      end
      else if(swRst) begin   
         cmdIf_trEn <= 1'b0;
      end
      else begin
         cmdIf_trEn <= cmdIf_trEn_nxt;
      end
   end 

   always @(posedge hClk or negedge hReset_n) begin   
      if(!hReset_n) begin   
         cmdIf_req <= 1'b0;
      end
      else if(swRst) begin   
         cmdIf_req <= 1'b0;
      end
      else begin
         cmdIf_req <= cmdIf_req_nxt;
      end
   end 

   always @(posedge hClk or negedge hReset_n) begin   
      if(!hReset_n) begin   
         cmdIf_wrData_req <= 1'b0;
      end
      else if(swRst) begin   
         cmdIf_wrData_req <= 1'b0;
      end
      else begin
         cmdIf_wrData_req <= cmdIf_wrData_req_nxt;
      end
   end  

   always @(posedge hClk or negedge hReset_n) begin   
      if(!hReset_n) begin   
         cmdIf_rdData_req <= 1'b0;
      end
      else if(swRst) begin   
         cmdIf_rdData_req <= 1'b0;
      end
      else begin
         cmdIf_rdData_req <= cmdIf_rdData_req_nxt;
      end
   end  
   
   always @(posedge hClk or negedge hReset_n) begin   
      if(!hReset_n) begin   
         htrans_r <= IDLE;
      end
      else if(swRst) begin   
         htrans_r <= 1'b0;
      end
      else if(cur_state != CM_WAIT)begin
         htrans_r <= htrans;
      end
   end  
   
   always @(posedge hClk or negedge hReset_n) begin
      if(!hReset_n) begin
         haddr_r   <= {32{1'b0}};     
         hsize_r   <= {2{1'b0}};
         hwrite_r  <= 1'b0;     
        // htrans_r  <= IDLE;
      end
      else if (addr_ld) begin
         haddr_r  <= haddr;
         hsize_r  <= hsize;
         hwrite_r <= hwrite;
        // htrans_r <= htrans;
      end
   end

   assign   cm_write       =  (hwrite_r == 1'b1) ? 1'b1 : 1'b0;
   assign   cm_read        =  (hwrite_r == 1'b0) ? 1'b1 : 1'b0;
   
   assign   cmdIf_wrRd     =  cm_write;
   assign   cmdIf_addr     =  haddr_r;

   assign   cmdIf_wrData   =  hwdata;
   assign   hrdata         =  cmdIf_rdData;    

endmodule 
