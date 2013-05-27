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
// DATE           : Mon, 04 Feb 2013 14:43:10
// AUTHOR         : Anuj Pandey
// AUTHOR EMAIL   : anuj.pandey@techvulcan.com
// FILE NAME      : uctl_dmaRx.v
// VERSION  No.   : 0.4
//-------------------------------------------------------------------

//TODO fixes in 0.4
// 1. nearlyFull signal is changed now. Now we are seeing available space in fifo and acc to that we are
//    sending read request to memory.

//TODO  fixes in 0.3
// 1. nearlyFull signal is used now, earlier we were using full signal - done
// 2. memRedReq was going low without gettin ack, that bug is closed now.
// 3. now systemWrite address is coming from sepr. earlier it was coming from reg block

//TODO  fixes in 0.2
// 1. code for wrapping of memeory address is corrected now 

module uctl_dmaRx #(
   parameter CNTR_WD         = 20 ,                               
             DMA_RD_FIFO_ADR = 4  ,
             MEM_ADD_WD      = 32 ,
             DATA_SIZE       = 32 ,          
             ADDR_SIZE       = 32
)(
   //---------------------------------------------------------------
   // Global Signals
   //---------------------------------------------------------------
   input  wire                             uctl_rst_n              , 
   input  wire                             core_clk                ,

   //---------------------------------------------------------------
   // Register Interface                       -- reg
   //---------------------------------------------------------------
 //input  wire [1                      :0] reg2dmaRx_sBusIntf      ,// Bus Interface used for transfer --
                                                                    // 00: AHB master, 01: AXI master, 10: rsrvd, 11: rsrvd
   input  wire                             sw_rst                  ,// TODO : from where this signal will come ?

   //---------------------------------------------------------------
   // System Endpoint Controller Rx Interface  -- sepr
   //---------------------------------------------------------------    
   input  wire [ADDR_SIZE -1           :0] sepr2dmaRx_sWrAddr      ,// 32 bit write address in system memory
   input  wire [ADDR_SIZE -1           :0] sepr2dmaRx_laddrIn      ,// Local buffer address
   input  wire                             sepr2dmaRx_dmaStart     ,// Dma start. .high till it didnt receive Done signal from AHB
   input  wire [CNTR_WD   -1           :0] sepr2dmaRx_len          ,// Length of transfer in Bytes
   input  wire [ADDR_SIZE -1           :0] sepr2dmaRx_epStartAddr  ,// Endpoint Buffer Start Address for wrapping the data TODO : dis signals not used
   input  wire [ADDR_SIZE -1           :0] sepr2dmaRx_epEndAddr    ,// Endpoint Buffer End Address for wrapping the data   TODO : dis signals not used
 //input  wire [3                      :0] sepr2dmaRx_rdBE         ,// Byte enable signal used for last data transfer
   input  wire                             sepr2dmaRx_sRdWr        ,
  
   output reg                              dmaRx2sepr_dn           ,// Dma write transfer to system memory completed
    
   //---------------------------------------------------------------
   // Local Memory Rx Interface               -- memrif
   //---------------------------------------------------------------
   input  wire [DATA_SIZE -1           :0] mif2dmaRx_data          ,// read data from local buffer
   input  wire                             mif2dmaRx_ack           ,// acknowledgmnt from local buffer when valid data received
   input  wire                             mif2dmaRx_rdVal         ,// data valid signal from local memory

   output wire [ADDR_SIZE -1           :0] dmaRx2mif_Addr          ,// Read address of memory location in local buffer
   output reg                              dmaRx2mif_rdReq         ,// Read request from dmaRx to local buffer

   //---------------------------------------------------------------
   // ctrl interface                           -- ahbm
   //---------------------------------------------------------------
   output wire [ADDR_SIZE -1           :0] dmaRx2ahbm_sWrAddr      ,//dmaRx2ctrl_sWrAddr : System memory address
   output wire                             dmaRx2ahbm_sRdWr        ,//dmaRx2ctrl_sRdWr : Read or write operation
   output wire [CNTR_WD   -1           :0] dmaRx2ahbm_len          ,//dmaRx2ctrl_len : Length of transfer in Bytes
   output reg                              dmaRx2ahbm_stransEn     ,//dmaRx2ctrl_stransEn
 //output wire [3                      :0] dmaRx2ahbm_BE           ,//dmaRx2ctrl_BE
   input  wire                             ahbm2dmaRx_dn           ,//ctrl2dmaRx_dn


   //---------------------------------------------------------------
   // fifo  interface                           --fifo 
   //---------------------------------------------------------------
   input  wire [DMA_RD_FIFO_ADR        :0] ahbm2dmaRx_availSpace   ,//fifo2dmaRx_full
   output wire [DATA_SIZE -1           :0] dmaRx2ahbm_data         ,//dmaRx2fifo_data
   output wire                             dmaRx2ahbm_wr            //dmaRx2fifo_wr : write request
         
   );    

   localparam    IDLE  = 1'b0;                                      // these are constants
   localparam    TRANS  = 1'b1;                                     // local param means constants

   //---------------------------------------------------------------
   // Local wires and registers
   //---------------------------------------------------------------
   reg  [ADDR_SIZE -1             :0] mem_add_l                    ;// it will take the local address
   reg                                mem_addr_ld                  ;// signal which will indicate load memory address
   reg                                mem_addr_inc                 ;// indicates inc the memory address

 //reg                                smem_addr_ld                 ;

   reg                                mem_bytes_cntr_dec           ;// signal indicates dec the no f bytes
   reg  [CNTR_WD   -1             :0] mem_bytes_cntr               ;// internal reg where no of will b stored
   reg                                mem_bytes_cntr_ld            ;               

   reg                                current_state                ;
   reg                                next_state                   ;             
   wire                               mem_bytes_cntr_iszero        ; 
   reg  [ADDR_SIZE -1             :0] mem_add_l_nxt                ; 
   wire                               ack_reReq_high               ; 
   reg                                hold_req                     ;
   wire                               memRdReq                     ;
   wire                               clear_flag                   ;
   wire                               set_flag                     ;
   wire [DMA_RD_FIFO_ADR          :0] actual_availSpace            ;
   reg                                pendFifoInTrs                ;


   //---------------------------------------------------------------
   // Code Starts From Here
   //---------------------------------------------------------------

   //assign dmaRx2ahbm_BE       = sepr2dmaRx_rdBE        ;
   assign dmaRx2ahbm_sWrAddr    = sepr2dmaRx_sWrAddr     ;
   assign dmaRx2mif_Addr        = mem_add_l              ; 
   assign dmaRx2ahbm_len        = sepr2dmaRx_len         ; 
   assign dmaRx2ahbm_wr         = mif2dmaRx_rdVal        ;
   assign dmaRx2ahbm_data       = mif2dmaRx_data         ;
   assign dmaRx2ahbm_sRdWr      = sepr2dmaRx_sRdWr       ;
   

   always @(*) begin
      if(mem_addr_ld) begin
         mem_add_l_nxt =sepr2dmaRx_laddrIn;           // local reg value on load signal
      end
      else if (mem_addr_inc) begin                    // incrmntin signal to incrmnt the address
         if(mem_add_l >  sepr2dmaRx_epEndAddr) begin
            mem_add_l_nxt  = sepr2dmaRx_epStartAddr;
         end
         else begin
            mem_add_l_nxt = mem_add_l + 3'b100;
         end
      end
      else begin
         mem_add_l_nxt  = mem_add_l;
      end
   end 


   // Local Memory address Counter
   always@(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         mem_add_l <= {ADDR_SIZE{1'b0}};              // local reg value on global rst
      end
      else begin
         mem_add_l <= mem_add_l_nxt;
      end
      
   end


   

   // Byte counter
   always@(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         mem_bytes_cntr <= {CNTR_WD{1'b0}};           // loc reg value on global rst
      end
      else if(mem_bytes_cntr_ld) begin                // on load signl, assign tot no f bytes to locl reg   
         mem_bytes_cntr <= sepr2dmaRx_len;
      end
      else if (mem_bytes_cntr_dec)begin               // on dec signal , dec the countr by 4
         if( mem_bytes_cntr < 3'd4) begin           
            mem_bytes_cntr <= {CNTR_WD{1'b0}};        // if no f bytes < 4 , make value f loc reg is 0
         end 
         else begin 
            mem_bytes_cntr <= mem_bytes_cntr - 3'd4;  // decrsin d no f bytes by 4 if no f bytes are > 0
         end
      end
   end

   //ack-flag
   always@(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         hold_req <= 1'b0;
      end
      else if(clear_flag)begin
         hold_req <= 1'b0;
      end
      else if(set_flag)begin
         hold_req <= 1'b1; 
      end  
   end

   // Track pending Fifo ins
   // ---------------------------------------------------------------------
   assign inc_pendFifoInTrs = dmaRx2mif_rdReq & mif2dmaRx_ack;
   assign dec_pendFifoInTrs = mif2dmaRx_rdVal;

   always@(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         pendFifoInTrs <= 1'b0;
      end
      else if (inc_pendFifoInTrs && dec_pendFifoInTrs) begin
         pendFifoInTrs <= pendFifoInTrs;              // stay at previous value
      end
      else if (inc_pendFifoInTrs) begin
         pendFifoInTrs <= 1'b1;                       // Increment
      end
      else if (dec_pendFifoInTrs) begin
         pendFifoInTrs <= 1'b0;                       // decrement
      end
   end
   
   assign mem_bytes_cntr_iszero   = mem_bytes_cntr == {CNTR_WD{1'b0}};   
   assign actual_availSpace       = ahbm2dmaRx_availSpace - {4'b0, pendFifoInTrs};

   assign memRdReq                = ~mem_bytes_cntr_iszero & (actual_availSpace != {5{1'b0}});
   assign ack_reReq_high          = (mif2dmaRx_ack== 1'b1) && (dmaRx2mif_rdReq == 1'b1) ;
  
   assign clear_flag              = (mif2dmaRx_ack == 1'b1) ? 1'b0 : 1'b1; 
   assign set_flag                = (memRdReq == 1'b1) && (mif2dmaRx_ack == 1'b0) ? 1'b1 : 1'b0;

   always@(*) begin
      next_state           = current_state;
      mem_addr_ld          = 1'b0;
    //smem_addr_ld         = 1'b0;
      mem_bytes_cntr_ld    = 1'b0;
      dmaRx2ahbm_stransEn  = 1'b0;
      dmaRx2sepr_dn        = 1'b0;
      mem_bytes_cntr_dec   = 1'b0;
      mem_addr_inc         = 1'b0; 
      case(current_state)
         IDLE: begin
            if(sepr2dmaRx_dmaStart) begin
               if(sepr2dmaRx_len   == {CNTR_WD{1'b0}}) begin
                  next_state          = IDLE ;
                  dmaRx2sepr_dn       = 1'b1 ;
               end
               else begin
                  dmaRx2ahbm_stransEn = 1'b1 ; 
                  next_state          = TRANS;
                  mem_bytes_cntr_ld   = 1'b1 ;
                  mem_addr_ld         = 1'b1 ;
                  //smem_addr_ld      = 1'b1 ;
               end           
            end
            dmaRx2mif_rdReq = 1'b0;
         end

         TRANS: begin
            dmaRx2mif_rdReq = (hold_req ) | (memRdReq)  ;


            if(ack_reReq_high) begin
               mem_bytes_cntr_dec = 1'b1;
               mem_addr_inc = 1'b1;
            end

            //if(mem_bytes_cntr_iszero)begin
            if(ahbm2dmaRx_dn == 1'b1) begin
               next_state = IDLE;
               dmaRx2sepr_dn = 1'b1;
            end
         end
      endcase
   end

   always@(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         current_state <= IDLE;
      end
      else if (sw_rst) begin
         current_state <=  IDLE;
      end
      else begin
         current_state <= next_state;
      end
   end

endmodule
