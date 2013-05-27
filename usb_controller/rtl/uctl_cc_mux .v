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
// DATE		   	: Thu, 07 Mar 2013 11:31:50
// AUTHOR	      : Lalit Kumar
// AUTHOR EMAIL	: lalit.kumar@techvulcan.com
// FILE NAME		: uctl_cc_mux.v
// VERSION        : 0.1
//-------------------------------------------------------------------

module uctl_cc_mux #(
   parameter   MEM_ADDR_SIZE  = 15,
               MEM_DATA_SIZE  = 32
   )(
   // *************************************************************************
   // Global signals
   // *************************************************************************
      input  wire                     uctl_clk       ,
      input wire                      uctl_core_rst_n,

   // *************************************************************************
   //client0 data and adress
   // *************************************************************************
      input  wire [MEM_ADDR_SIZE    -1:0] uctl_cl0Addr,
      input  wire [MEM_DATA_SIZE    -1:0] uctl_cl0DOut,
      output reg  [MEM_DATA_SIZE    -1:0] uctl_cl0DIn ,

   // *************************************************************************
   //client1 data and adress
   // *************************************************************************
      input  wire [MEM_ADDR_SIZE    -1:0] uctl_cl1Addr,
      input  wire [MEM_DATA_SIZE    -1:0] uctl_cl1DOut,
      output reg  [MEM_DATA_SIZE    -1:0] uctl_cl1DIn ,

   // *************************************************************************
   //client2 data and adress
   // *************************************************************************
      input  wire [MEM_ADDR_SIZE    -1:0] uctl_cl2Addr,
      input  wire [MEM_DATA_SIZE    -1:0] uctl_cl2DOut,
      output reg  [MEM_DATA_SIZE    -1:0] uctl_cl2DIn ,

   // *************************************************************************
   //client3 data and adress
   // *************************************************************************
      input  wire [MEM_ADDR_SIZE    -1:0] uctl_cl3Addr,
      input  wire [MEM_DATA_SIZE    -1:0] uctl_cl3DOut,
      output reg  [MEM_DATA_SIZE    -1:0] uctl_cl3DIn ,
   
   // *************************************************************************
   // select signal from bank select block
   // *************************************************************************
      input  wire [4                -1:0] uctl_chipsel,

   // *************************************************************************
   // memory signals
   // *************************************************************************
      output reg  [MEM_ADDR_SIZE    -1:0] mem_addr    ,
      output reg  [MEM_DATA_SIZE    -1:0] mem_dIn ,
      input  wire [MEM_DATA_SIZE    -1:0] mem_dOut,
   
   // *************************************************************************
   // ack to bankreq block
   // *************************************************************************
      output wire  [4         -1:0]   uctl_rdDVl 
   );
   
   localparam  MEM_DEPTH      = 2**MEM_ADDR_SIZE;
               

    reg [4         -1:0] ack_reg; 
    assign uctl_rdDVl    = ack_reg                ; 

    always @(posedge  uctl_clk) begin 
      if(!uctl_core_rst_n) begin 
         ack_reg  <= 1'b0     ;
      end
      else begin 
         ack_reg  <= uctl_chipsel;
      end
   end

   // select data and address for memory
   always @(*) begin
      case(uctl_chipsel)
         4'b0001: begin
            mem_addr    = uctl_cl0Addr             ;
            mem_dIn     = uctl_cl0DOut             ;
         end
         4'b0010: begin
            mem_addr    = uctl_cl1Addr             ;
            mem_dIn     = uctl_cl1DOut             ;
         end
         4'b0100: begin
            mem_addr    = uctl_cl2Addr             ;
            mem_dIn     = uctl_cl2DOut             ;
         end
         4'b1000: begin
            mem_addr    = uctl_cl3Addr             ;
            mem_dIn     = uctl_cl3DOut             ;
         end
         default: begin
            mem_addr    = {MEM_ADDR_SIZE{1'b0}}    ;
            mem_dIn     = {MEM_DATA_SIZE{1'b0}}    ;
         end
      endcase
   end
   
   //select data for input to clients
   always @(*) begin
      case(ack_reg)
         4'b0001: begin
            uctl_cl0DIn = mem_dOut                     ;
            uctl_cl1DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl2DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl3DIn = {MEM_DATA_SIZE{1'b0}}        ;          
         end
         4'b0010: begin
            uctl_cl0DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl1DIn = mem_dOut                     ;
            uctl_cl2DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl3DIn = {MEM_DATA_SIZE{1'b0}}        ;          
         end
         4'b0100: begin
            uctl_cl0DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl1DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl2DIn = mem_dOut                     ;
            uctl_cl3DIn = {MEM_DATA_SIZE{1'b0}}        ;          
         end
         4'b1000: begin
            uctl_cl0DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl1DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl2DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl3DIn = mem_dOut                     ;
         end
         default: begin
            uctl_cl0DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl1DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl2DIn = {MEM_DATA_SIZE{1'b0}}        ;          
            uctl_cl3DIn = {MEM_DATA_SIZE{1'b0}}        ;          
         end
      endcase
   end
endmodule  
      



















