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
// DATE           : Sat, 02 Mar 2013 11:43:36
// AUTHOR         : Anuj Pandey
// AUTHOR EMAIL   : anuj.pandey@techvulcan.com
// FILE NAME      : uctl_dmaTx.v
// VERSION No.    : 0.4
//-------------------------------------------------------------------

//TODO fixes in 0.4
// 1. have put some extra code in WTTRDN state...

//TODO  fixes in 0.3
// 1.   now systemRead address is coming from sept. earlier it was coming from reg block

//TODO  fixes in 0.2
// 1. code for wrapping of memeory address is corrected now 




module uctl_dmaTx #(
   parameter CNTR_WD     = 20 ,                               
             DATA_SIZE   = 32 ,          
             ADDR_SIZE   = 32
   )(
   //-----------------------------------------------------------
   // Global SIgnals
   //-----------------------------------------------------------
   input  wire                         uctl_reset_n            ,
   input  wire                         core_Clk                ,
   input  wire                         sw_rst                  ,
   
   //-----------------------------------------------------------
   // Register interface                   (reg)
   //-----------------------------------------------------------
 //input  wire [1                  :0] reg2dmaTx_sBusIntf      ,// Bus Interface used for transfer -- TODO : not assignd anywhr in code
                                                                // 00: AHB master, 01: AXI master, 10: rsrvd, 11: rsrvd 

   //-----------------------------------------------------------
   // Sys Endpoint Controller Tx Interface (sept)
   //-----------------------------------------------------------
   input  wire [ADDR_SIZE -1       :0] sept2dmaTx_sRdAddr       ,// 32 bit read address in system memory
   input  wire [ADDR_SIZE -1       :0] sept2dmaTx_addrIn      ,// Local buffer address
   input  wire                         sept2dmaTx_dmaStart     ,// Dma start signal
   input  wire [CNTR_WD   -1       :0] sept2dmaTx_len          ,// Length of transfer in bytes
   input  wire [ADDR_SIZE -1       :0] sept2dmaTx_epStartAddr  ,// Endpoint Buffer Start Address for wrapping the data
   input  wire [ADDR_SIZE -1       :0] sept2dmaTx_epEndAddr    ,// Endpoint Buffer End Address for wrapping the data
 //input  wire [31                 :0] sept2dmaTx_offsetAddr   ,// Dma offset address during fragmentation otherwise zero TODO : not assignd
   input  wire                         sept2dmaTx_sRdWr        ,
    
   output reg                          dmaTx2sept_dn           ,// Dma write transfer to system memory completed

   //-----------------------------------------------------------
   // Local Memory Tx Interface         -- mif
   //-----------------------------------------------------------
   input  wire                         mif2dmaTx_ack           ,// ack from local buffer
   
   output wire [ADDR_SIZE -1       :0] dmaTx2mif_wrAddr        ,// write address of memory location in local buffer
   output reg                          dmaTx2mif_wrReq         ,// write request from dma to local buffer
   output wire [DATA_SIZE -1       :0] dmaTx2mif_wrData        ,// write data to local buffer

  
   //-----------------------------------------------------------
   // ctrl interface
   //-----------------------------------------------------------      
   output wire [ADDR_SIZE -1       :0] dmaTx2ahbm_sRdAddr      ,//dmaTx2ctrl_sRdAddr : name of d signal wd wch it wil b connected
   output wire [CNTR_WD   -1       :0] dmaTx2ahbm_len          ,//dmaTx2ctrl_len : same as above
   output reg                          dmaTx2ahbm_stransEn     ,//dmaTx2ctrl_stransEn : same as above
   output wire                         dmaTx2ahbm_sRdWr        ,//dmaTx2ctrl_sRdWr : same as above
   input  wire                         ahbm2dmaTx_dataDn       ,//ctrl2dmaTx_dataDn : same as above



   //-----------------------------------------------------------
   // Fifo  interface
   //-----------------------------------------------------------
   input  wire                         ahbm2dmaTx_ready        ,//fifo2dmaTx_fifoEmpty : same as above
   input  wire [DATA_SIZE -1       :0] ahbm2dmaTx_wrData       ,//fifo2dmaTx_wrData : same as above     
   output reg                          dmaTx2ahbm_rd            //dmaTx2fifo_rdEn : same as above
   );

   //-----------------------------------------------------------
   // local wires and registers
   //-----------------------------------------------------------
   reg  [ADDR_SIZE  -1             :0] mem_addr_l              ;// it will take the local address
   reg                                 mem_addr_ld             ;// signal which will indicate load memory address
   reg                                 mem_addr_inc            ;// indicates inc the memory address


   reg  [CNTR_WD    -1             :0] mem_bytes_cntr_t          ;// internal reg where no of bytes will b stored
   reg                                 mem_bytes_cntr_ld       ;// signal which will indicate load no f bytes 
   reg                                 mem_bytes_cntr_dec      ;// signal indicates decrease the no f bytes

   reg  [ADDR_SIZE  -1             :0] mem_addr_l_nxt          ;// mem addr in case of wrapping

   reg  [1                         :0] cur_state               ;
   reg  [1                         :0] nxt_state               ;
   wire                                fifoNotEmpty_byteNotZero;
   wire                                wrReq_Ack_high          ;
   wire                                mem_bytes_cntr_t_is_0   ;

   localparam IDLE  = 2'd0;
   localparam TRANS = 2'd1;
   localparam WTTRDN= 2'd2;

   // wrapping of address is done here
   always @(*) begin
      if(mem_addr_ld)begin
         mem_addr_l_nxt = sept2dmaTx_addrIn ;
      end
      else if(mem_addr_inc) begin
         if(mem_addr_l >  sept2dmaTx_epEndAddr) begin
            mem_addr_l_nxt  = sept2dmaTx_epStartAddr ;
			end	
         else begin
            mem_addr_l_nxt = mem_addr_l + 3'b100;
         end
      end
      else begin
         mem_addr_l_nxt  = mem_addr_l;
      end
   end 
   
  

   //storing local  addr and incrementing it
   always @ (posedge core_Clk or negedge uctl_reset_n) begin//{
      if(!uctl_reset_n) begin
         mem_addr_l <= {ADDR_SIZE{1'b0}}  ;
      end
      else begin
         mem_addr_l <= mem_addr_l_nxt     ;
      end
   end//}

   


   // storing bytes and decrementing it
   always @ (posedge core_Clk or negedge uctl_reset_n) begin
      if(!uctl_reset_n) begin
         mem_bytes_cntr_t <= {CNTR_WD{1'b0}};            // loc reg value on global rst
      end

      else if(mem_bytes_cntr_ld) begin                 // on load signl, assign tot no f bytes to locl reg   
         mem_bytes_cntr_t <= sept2dmaTx_len;             // length of transfer in bytes
      end

      else if (mem_bytes_cntr_dec) begin               // on dec signal , dec the countr by 4
         if( mem_bytes_cntr_t < 3'd4) begin           
            mem_bytes_cntr_t <= {CNTR_WD{1'b0}};         // if no f bytes < 4 , make value f loc reg is 0
         end 
         else begin
            mem_bytes_cntr_t <= mem_bytes_cntr_t - 3'd4;   // decrsin d no f bytes by 4 if no f bytes are > 0
         end
      end
      
   end
   assign mem_bytes_cntr_t_is_0 =(mem_bytes_cntr_t == {CNTR_WD{1'b0}});

   assign dmaTx2mif_wrData     = ahbm2dmaTx_wrData ;   // passing data from fifo to local mem.
   assign dmaTx2ahbm_sRdAddr   = sept2dmaTx_sRdAddr ;   // passing system add to ctrl logic
   assign dmaTx2ahbm_len       = sept2dmaTx_len    ;   // passing tot. bytes to ctrl logic
   assign dmaTx2mif_wrAddr     = mem_addr_l        ;   // passing mem address whr data is to put
   assign dmaTx2ahbm_sRdWr     = sept2dmaTx_sRdWr  ;


   assign fifoNotEmpty_byteNotZero = (ahbm2dmaTx_ready == 1'b1) && !mem_bytes_cntr_t_is_0;
   assign wrReq_Ack_high           = dmaTx2mif_wrReq == 1'b1 && mif2dmaTx_ack == 1'b1;
   
   //state machine
   always @ (*) begin
      nxt_state            = cur_state             ;
      mem_addr_ld          = 1'b0                  ;
      mem_bytes_cntr_ld    = 1'b0                  ;
      dmaTx2ahbm_stransEn  = 1'b0                  ;
      dmaTx2sept_dn        = 1'b0                  ;
      mem_addr_inc         = 1'b0                  ;
      mem_bytes_cntr_dec   = 1'b0                  ; 
      dmaTx2ahbm_rd        = 1'b0                  ;
      dmaTx2mif_wrReq      = 1'b0                  ;

      case(cur_state) 
         IDLE :  begin
            if(sept2dmaTx_dmaStart==1'b1) begin
               if(sept2dmaTx_len == {CNTR_WD{1'b0}}) begin
                  nxt_state            =  IDLE     ;
                  dmaTx2sept_dn        =  1'b1     ;
               end
               else begin
                  dmaTx2ahbm_stransEn  = 1'b1      ;
                  mem_addr_ld          = 1'b1      ;
                  mem_bytes_cntr_ld    = 1'b1      ; 
                  nxt_state            = TRANS     ;
               end
            end
            dmaTx2mif_wrReq = 1'b0                 ;
         end//end of idle state

         TRANS : begin
            if(fifoNotEmpty_byteNotZero) begin
               dmaTx2mif_wrReq        = 1'b1       ;
            end
            else begin
               dmaTx2mif_wrReq        = 1'b0       ;
            end

            if(wrReq_Ack_high) begin
               mem_addr_inc           = 1'b1       ;
               mem_bytes_cntr_dec     = 1'b1       ;
               dmaTx2ahbm_rd          = 1'b1       ;
            end
      
            if (ahbm2dmaTx_dataDn) begin
               if (mem_bytes_cntr_t_is_0) begin
                  nxt_state               = IDLE;
                  dmaTx2sept_dn           = 1'b1; 
               end
               else begin
                  nxt_state               = WTTRDN;
               end
            end
         end//end of trans state

         WTTRDN: begin
            if(fifoNotEmpty_byteNotZero) begin
               dmaTx2mif_wrReq        = 1'b1       ;
            end
            else begin
               dmaTx2mif_wrReq        = 1'b0       ;
            end

            if(wrReq_Ack_high) begin
               mem_addr_inc           = 1'b1       ;
               mem_bytes_cntr_dec     = 1'b1       ;
               dmaTx2ahbm_rd          = 1'b1       ;
            end

            if(mem_bytes_cntr_t_is_0) begin
               nxt_state               = IDLE;
               dmaTx2sept_dn           = 1'b1; 
            end
         end

      endcase


   
   end//end of state machine

   
   always @ (posedge core_Clk or negedge uctl_reset_n) begin
      if(!uctl_reset_n) begin
         cur_state <= IDLE;
      end
      else if (sw_rst) begin
         cur_state <= IDLE;
      end
      else begin
         cur_state <= nxt_state;
      end
   
   end


endmodule
