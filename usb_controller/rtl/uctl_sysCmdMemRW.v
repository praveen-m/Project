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
// DATE		   	: Mon, 11 Mar 2013 12:16:16
// AUTHOR	      : Lalit Kumar
// AUTHOR EMAIL	: lalit.kumar@techvulcan.com
// FILE NAME		: uctl_sysCmdMemRW.v
// VERSION        : 0.1
//-------------------------------------------------------------------

   module uctl_sysCmdMemRW#(
      parameter   DATA_SIZE = 32,
                  ADDR_SIZE = 32
      )(
    input wire                      coreRst_n             ,
    input wire                      coreClk               ,
   //----------------------------------------------
   //cmd2-memory interface
   //----------------------------------------------
   input wire                       mem_req               ,        
   input wire                       mem_wrRd              ,
   input wire  [ADDR_SIZE-1 :0]     mem_addr              ,                          
   input wire  [DATA_SIZE-1 :0]     mem_wrData            ,
   output wire                      mem_ack               ,
   output reg                       mem_rdVal             ,
   output  reg [DATA_SIZE-1 :0]     mem_rdData            ,
   // ---------------------------------------------------
   //  sepr Interface
   // ---------------------------------------------------
   output reg [DATA_SIZE-1  :0]     mif2sepr_rdData       ,// Read data from memory
   output reg		                  mif2sepr_ack          ,// Ready signal from memory
   output reg                       mif2sepr_rdVal        , 
   input wire [ADDR_SIZE-1  :0]     sepr2mif_addr         ,// Address of the memory location in local buffer
   input wire	       	            sepr2mif_rd           ,// Read request to memory

   //-----------------------------------------------
   // sept Interface
   //-----------------------------------------------   
   output reg                       mif2sept_ack           ,// ack signal for the sys endpoint controller
   input wire                       sept2mif_wr            ,//write enable
   input wire  [ADDR_SIZE -1:0]     sept2mif_addr          ,// address of the memory location in thlocal buffer
   input wire  [DATA_SIZE -1:0]     sept2mif_wrData        ,// write data
   //-----------------------------------------------------------
   // Local Memory Tx Interface         -- mif
   //-----------------------------------------------------------
   output  reg                      mif2dmaTx_ack          ,// ack from local buffer
   input wire  [ADDR_SIZE -1:0]     dmaTx2mif_wrAddr       ,// write address of memory location in local buffer
   input wire                       dmaTx2mif_wrReq        ,// write request from dma to local buffer
   input wire [DATA_SIZE -1:0]      dmaTx2mif_wrData       ,// write data to local buffer

   //---------------------------------------------------------------
   // Local Memory Rx Interface               -- memrif
   //---------------------------------------------------------------
   output  reg [DATA_SIZE -1:0]     mif2dmaRx_data         ,// read data from local buffer
   output  reg                      mif2dmaRx_ack          ,// acknowledgmnt from local buffer when valid data received
   output  reg                      mif2dmaRx_rdVal        ,// data valid signal from local memory
   input wire [ADDR_SIZE -1:0]      dmaRx2mif_Addr         ,// Read address of memory location in local buffer
   input wire                       dmaRx2mif_rdReq        ,// Read request from dmaRx to local buffer
    
   //---------------------------------------------------------------
   //memory0 signals
   //---------------------------------------------------------------
   output  reg [ADDR_SIZE -1:0]     mem0_addr              ,       
   output  reg [DATA_SIZE -1:0]     mem0_dataIn            ,
   input wire                       mem0_ackOut            , 
   output  reg                      mem0_wr                , 
   //output  reg                      mem0_rd                , 
   //---------------------------------------------------------------
   //memory1 signals
   //---------------------------------------------------------------
   output  reg [ADDR_SIZE -1:0]     mem1_addr              ,       
   input wire                       mem1_ackOut            , 
   //output  reg                      mem1_wr                , 
   output  reg                      mem1_rd                , 
   input wire  [DATA_SIZE -1:0]     mem1_dataOut           ,
   input wire                       mem1_dataVld         
  );

   reg         mem0_ack          ,
               mem1_ack          ,
               mem_req_r         ,          
               dmaRx2mif_rdReq_r ,
               sepr2mif_rd_r     ; 


   assign mem_ack  = mem0_ack | mem1_ack;                            
   
   always @(*) begin
      if(sepr2mif_rd_r) begin
         mif2sepr_rdVal    = mem1_dataVld     ;
         mif2dmaRx_rdVal   = 1'b0             ;
         mem_rdVal         = 1'b0             ;
         mif2sepr_rdData   = mem1_dataOut      ;   
         mem_rdData        = {DATA_SIZE{1'b0}};       
         mif2dmaRx_data    = {DATA_SIZE{1'b0}};          
      end
      else if(mem_req_r ) begin 
         mif2sepr_rdVal     = 1'b0            ;
         mif2dmaRx_rdVal   = 1'b0             ;
        mif2sepr_rdData    = {DATA_SIZE{1'b0}};      
         mem_rdVal         = mem1_dataVld     ;
         mem_rdData         = mem1_dataOut     ;
         mif2dmaRx_data    = {DATA_SIZE{1'b0}};          
      end
      else if(dmaRx2mif_rdReq_r ) begin 
         mif2sepr_rdVal     = 1'b0            ;
         mif2sepr_rdData    = {DATA_SIZE{1'b0}};      
         mif2dmaRx_rdVal   = mem1_dataVld     ;
         mem_rdVal         = 1'b0             ; 
         mif2dmaRx_data    = mem1_dataOut     ;    
         mem_rdData        = {DATA_SIZE{1'b0}};      
      end
      else  begin 
         mif2sepr_rdVal     = 1'b0            ;
         mif2dmaRx_rdVal   = 1'b0             ;
         mem_rdVal         = 1'b0             ; 
         mem_rdData        = {DATA_SIZE{1'b0}};   
        mif2sepr_rdData    = {DATA_SIZE{1'b0}};      
         mif2dmaRx_data    = {DATA_SIZE{1'b0}};          
    end
  end

   always @(posedge  coreClk) begin
      if(!coreRst_n) begin 
         mem_req_r         <= 1'b0  ;         
         sepr2mif_rd_r     <= 1'b0  ;
         dmaRx2mif_rdReq_r <= 1'b0  ;
      end
      else begin 
         mem_req_r         <= mem_req		;
         sepr2mif_rd_r     <= sepr2mif_rd	;
         dmaRx2mif_rdReq_r <= dmaRx2mif_rdReq;
      end
   end
   
   always @(*) begin
      if(sept2mif_wr) begin
         mem0_addr         = sept2mif_addr    ;      
         mem0_dataIn       = sept2mif_wrData  ;      
         mif2sept_ack      = mem0_ackOut      ;      
         mem0_wr           = 1'b1             ;      
         mif2dmaTx_ack       = 1'b0             ;
         mem0_ack           = 1'b0             ;
      end
      else if(dmaTx2mif_wrReq  ) begin
         mem0_addr         = dmaTx2mif_wrAddr ;      
         mem0_dataIn       = dmaTx2mif_wrData ;      
         mif2sept_ack      = 1'b0             ; 
         mif2dmaTx_ack     = mem0_ackOut      ;      
         mem0_wr           = 1'b1             ;      
        mem0_ack           = 1'b0             ;
      end
      else if(mem_req) begin
        mem0_addr          = mem_addr         ;
        mem0_dataIn        = mem_wrData       ;
        mem0_ack           = mem0_ackOut      ;
        mem0_wr            = mem_wrRd         ;      
        mif2sept_ack        = 1'b0             ; 
        mif2dmaTx_ack       = 1'b0             ;
      end
      else begin
        mem0_addr          = {ADDR_SIZE{1'b0}};       
        mem0_dataIn        = {DATA_SIZE{1'b0}};
        mem0_ack           = 1'b0             ;
        mem0_wr            = 1'b0             ;
        mif2sept_ack        = 1'b0             ; 
        mif2dmaTx_ack       = 1'b0             ;
      end
   end

   

   always @(*) begin
      if(sepr2mif_rd) begin
         mem1_addr         = sepr2mif_addr    ;      
         mif2sepr_ack      = mem1_ackOut      ;      
         mem1_rd           = 1'b1             ;
         mif2dmaRx_ack     = 1'b0             ;
         mem1_ack           = 1'b0             ;
      end
     else if(dmaRx2mif_rdReq) begin
         mem1_addr         = dmaRx2mif_Addr   ;      
         mif2dmaRx_ack     = mem1_ackOut      ;      
         mem1_rd           = 1'b1             ;
        mif2sepr_ack       = 1'b0             ;
        mem1_ack           = 1'b0             ;
      end
     else if(mem_req) begin
        mem1_addr          = mem_addr        ;
        mem1_ack           = mem1_ackOut      ;
        mem1_rd            = ~mem_wrRd        ;
        mif2sepr_ack       = 1'b0             ;
         mif2dmaRx_ack     = 1'b0             ;
		end
      else begin
        mem1_addr          = {ADDR_SIZE{1'b0}};       
        mif2sepr_ack       = 1'b0             ;
        mem1_rd            = 1'b0             ;
        mif2dmaRx_ack     = 1'b0             ;
        mem1_ack           = 1'b0             ;
      end
   end    

endmodule
