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
// DATE		   	: Sun, 12 May 2013 17:41:04
// AUTHOR	      : Lalit Kumar
// AUTHOR EMAIL	: lalit.kumar@techvulcan.com
// FILE NAME		: uctl_frameCounter.v
// Version no.    : 0.1
//-------------------------------------------------------------------

module uctl_frameCounter#(
   parameter      SOF_DNCOUNTER_WD = 16,  
                  SOF_UPCOUNTER_WD = 20   
   )(
   input   wire                  clk                       , 
   input   wire                  phy_rst_n                 ,
   input   wire                  sw_rst                    ,
   input   wire                  pd2frmCntrr_frmNumValid   ,
   input   wire [11       -1:0]  pd2frmCntrr_FrameNum      ,
   output  reg                   frmCntr2pe_frmBndry       ,
   input   wire [20       -1:0]  reg2frmCntr_upCntMax      ,
   input   wire [4        -1:0]  reg2frmCntr_timerCorr     ,
   output  wire [11       -1:0]  frmCntr2reg_frameCount    ,   //Local fram number
   output  wire                  frmCntr2reg_frameCntVl    ,
   output  wire                  frmCntr2reg_sofSent       , 
   output  wire                  frmCntr2reg_sofRcvd       , 
   input   wire [10       -1:0]  reg2frmCntr_eof1          ,
   input   wire [8        -1:0]  reg2frmCntr_eof2          ,
   input   wire                  reg2frmCntr_enAutoSof     ,
   input   wire                  reg2frmCntr_autoLd        ,
   input   wire [20       -1:0]  reg2frmCntr_timerStVal    ,  
   input   wire                  reg2frmCntr_ldTimerStVal  ,    //pulse
   output wire                   frmCntr2reg_eof1Hit       ,      
   output wire                   frmCntr2reg_babble         //hit of eof2
);
   
   reg [SOF_UPCOUNTER_WD  -1:0]  upCounter            ;
   reg [SOF_DNCOUNTER_WD  -1:0]  dnCounter            ;
   reg [SOF_DNCOUNTER_WD  -1:0]  nxt_frameCount       ;
   wire[SOF_DNCOUNTER_WD  -1:0]  timer_correction     ;
   reg [2             -1:0]      current_state        ;
   reg [2             -1:0]      next_state           ;
   reg                           clr_up_cntr          ;            
   reg                           run_up_counter       ;
   reg                           load_dn_counter      ;
   reg                           load_next_frame_reg  ;
   reg [SOF_DNCOUNTER_WD  -1:0]  mid_thresold         ;
   wire                          mid_thresold_crossed ;
   wire                          up_counter_roll_over ;
   reg [11            -1:0]      frame_num            ;
   wire                          dnCounter_zero       ; 





   localparam    IDLE         = 2'b00,
                 WT4SOF       = 2'b01,
                 WT4ROLL_OVER = 2'b10;


   // ---------------------------------------------------------------
   // Code starts here
   // ---------------------------------------------------------------
   assign mid_thresold_crossed   = (dnCounter< mid_thresold) ? 1'b1 : 1'b0;
   assign frmCntr2reg_sofRcvd    = frmCntr2pe_frmBndry ;
   assign up_counter_roll_over   = (upCounter == reg2frmCntr_upCntMax) ? 1'b1 : 1'b0;
   assign frmCntr2reg_frameCount = frame_num;
   assign timer_correction       = {{16{reg2frmCntr_timerCorr[3]}}, reg2frmCntr_timerCorr}; // sign bit extension     
   assign dnCounter_zero         = dnCounter == {SOF_DNCOUNTER_WD{1'b0}} ? 1'b1 : 1'b0;
   assign frmCntr2reg_eof1Hit    = (upCounter == reg2frmCntr_eof1 ) ? 1'b1 : 1'b0 ;  //TODO
   assign frmCntr2reg_frameCntVl = frmCntr2pe_frmBndry ;
      
   // run down counter 
   // ---------------------------------------------------------------
   always @(posedge clk, negedge phy_rst_n) begin 
      if(! phy_rst_n) begin
         dnCounter   <= {SOF_DNCOUNTER_WD{1'b0}};            
      end
      else if(sw_rst) begin
         dnCounter   <= {SOF_DNCOUNTER_WD{1'b0}};            
      end
      else if(load_dn_counter) begin
         dnCounter   <= upCounter;
      end
      else if(dnCounter_zero | pd2frmCntrr_frmNumValid) begin 
         dnCounter   <= nxt_frameCount + timer_correction;       
      end
      else begin
         dnCounter   <= dnCounter -1'b1;
      end
   end

   // run up   counter 
   // ---------------------------------------------------------------
   always @(posedge clk, negedge phy_rst_n) begin 
      if(! phy_rst_n) begin
         upCounter   <= {SOF_UPCOUNTER_WD{1'b0}};            
      end
      else if(sw_rst) begin
         upCounter   <= {SOF_UPCOUNTER_WD{1'b0}};            
      end
      else if(up_counter_roll_over | clr_up_cntr) begin
         upCounter   <= {SOF_UPCOUNTER_WD{1'b0}};            
      end
      else if(run_up_counter) begin
         upCounter   <= upCounter + 1'b1;
      end
   end
         
      
   // load next frame register
   // ---------------------------------------------------------------

   always @(posedge clk, negedge phy_rst_n) begin 
      if(! phy_rst_n) begin
         nxt_frameCount <= {SOF_DNCOUNTER_WD{1'b1}};            
      end
      else if(sw_rst) begin
         nxt_frameCount <= {SOF_DNCOUNTER_WD{1'b1}};            
      end
      else if(!reg2frmCntr_autoLd && reg2frmCntr_ldTimerStVal) begin
         nxt_frameCount <= reg2frmCntr_timerStVal;
      end
      else if(load_next_frame_reg) begin
         nxt_frameCount <= upCounter;
      end
   end
         
         
   // calculate mid-threshold value for generating local sof interrupt
   // ---------------------------------------------------------------

   always @(posedge clk, negedge phy_rst_n) begin 
      if(! phy_rst_n) begin
         mid_thresold   <= {SOF_DNCOUNTER_WD{1'b0}};
      end
      else if(sw_rst) begin
         mid_thresold   <= {SOF_DNCOUNTER_WD{1'b0}};
      end
      else if(load_next_frame_reg) begin //TODO can msb be used for midthreshold
         mid_thresold   <= upCounter>> 1'b1;
      end
      else begin
         mid_thresold   <= mid_thresold  ;
      end
   end
         
   // generate local frame boundary signal
   // ---------------------------------------------------------------
   always @(posedge clk, negedge phy_rst_n) begin 
      if(! phy_rst_n) begin
         frmCntr2pe_frmBndry <= 1'b0;
      end   
      else if(sw_rst) begin
         frmCntr2pe_frmBndry <= 1'b0;
      end   
      else if(dnCounter_zero) begin
         frmCntr2pe_frmBndry <= 1'b1;
      end
      else if(mid_thresold_crossed && 
            pd2frmCntrr_frmNumValid) begin
         frmCntr2pe_frmBndry <= 1'b1;
      end
      else begin
         frmCntr2pe_frmBndry <= 1'b0;
      end   
   end
         
      
   // generate local frame number 
   // ---------------------------------------------------------------
   always @(posedge clk, negedge phy_rst_n) begin 
      if(! phy_rst_n) begin
         frame_num   <= {11{1'b0}};
      end
      else if(sw_rst) begin
         frame_num   <= {11{1'b0}};
      end
      else if(pd2frmCntrr_frmNumValid) begin
         frame_num   <= pd2frmCntrr_FrameNum;
      end
      else if(dnCounter_zero) begin
         frame_num   <= frame_num + 1'b1;
      end
   end
/*
   always @(posedge clk, negedge phy_rst_n) begin 
      if(! phy_rst_n) begin
         frmCntr2reg_frameCntVl  <= 1'b0;
      end
      else if(sw_rst   ) begin
         frmCntr2reg_frameCntVl  <= 1'b0;
      end
      else if(pd2frmCntrr_frmNumValid | dnCounter_zero) begin
         frmCntr2reg_frameCntVl  <= 1'b1;
      end
      else begin 
         frmCntr2reg_frameCntVl  <= 1'b0;
      end
   end
*/
   // FSM sequential block
   // ---------------------------------------------------------------
 always @(posedge clk, negedge phy_rst_n) begin 
      if(! phy_rst_n) begin
         current_state  <= IDLE     ;
      end
      else if(sw_rst) begin
         current_state  <= IDLE     ;
      end
      else begin
		   current_state <= next_state;
      end
   end

   // FSM combinational block
   // ---------------------------------------------------------------
   always @ * begin
   	next_state              = current_state;
      clr_up_cntr             = 1'b0  ;
      run_up_counter          = 1'b0;
      load_dn_counter         = 1'b0;
      load_next_frame_reg     = 1'b0;

      case(current_state)
         IDLE: begin 
            next_state  = WT4SOF;
            clr_up_cntr = 1'b1  ;
         end
         
         WT4SOF: begin
            run_up_counter = 1'b1;
            if(pd2frmCntrr_frmNumValid) begin
               clr_up_cntr = 1'b1  ;
               load_dn_counter      = 1'b1;
               next_state  = WT4ROLL_OVER;
            end
            else if(up_counter_roll_over) begin 
               next_state  = IDLE;
            end
         end
      
         WT4ROLL_OVER: begin
            run_up_counter = 1'b1;
            if(pd2frmCntrr_frmNumValid) begin // 2 or more consecutive SOFs are received 
               load_next_frame_reg  = 1'b1;
               clr_up_cntr = 1'b1  ;
            end
            else if(up_counter_roll_over) begin 
               next_state  = IDLE;
            end
         end
      endcase
    end
endmodule 
