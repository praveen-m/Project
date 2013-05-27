
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
// DATE		   	: Mon, 20 May 2013 19:05:52
// AUTHOR	      : Lalit Kumar
// AUTHOR EMAIL   : lalit.kumar@techvulcan.com
// FILE NAME		: uctl_glitchFilter.v
// Version no.    : 0.1
//-------------------------------------------------------------------

module uctl_glitchFilter #(
      parameter GLITCH_CNTR_WD = 4
      )(
      input  wire                       aon_clk      ,// always on clock
      input  wire                       aon_rst_n    ,// reset
      input  wire                       sw_rst       ,// active high software reset
      input  wire                       line_state   ,// state of signal
      input  wire [GLITCH_CNTR_WD -1:0] stable_time  ,// time interval for  signal to be stable
      output reg                        stable_signal // signal on line state is stable
   
   );
      
   reg  [2        -1:0]       gc_state          ;
   reg  [2        -1:0]       gn_state          ;
   reg  [GLITCH_CNTR_WD -1:0] counter           ;
   reg                        run_counter       ; 
   reg                        set_stable_signal ; 
   reg                        clr_stable_signal ; 
   reg                        clr_counter       ; 
   reg                        stable_line       ;
   localparam     IDLE = 2'b00,
                  HL   = 2'b01,
                  LL   = 2'b10;


   assign stable_timeOver  = (counter == stable_time) ? 1'b1 : 1'b0;
   always @(posedge  aon_clk or negedge aon_rst_n) begin
      if(! aon_rst_n) begin
         counter     <= 4'b0;
      end
      else if(sw_rst ) begin
         counter     <= 4'b0;
      end
      else if(clr_counter) begin
         counter     <= 4'b0;
      end
      else if(run_counter) begin 
         counter     <= counter+ 1'b1;  
      end
   end

   always @(posedge  aon_clk or negedge aon_rst_n) begin
      if(! aon_rst_n) begin
         stable_line  <= 1'b0;
      end
      else if(sw_rst) begin
         stable_line    <= 1'b0;
      end
     else if(stable_timeOver ) begin
         stable_line    <= 1'b1;
      end
   end
      
   always @(posedge  aon_clk or negedge aon_rst_n) begin
      if(! aon_rst_n) begin
         stable_signal  <= 1'b0;
      end
      else if(sw_rst) begin
         stable_signal  <= 1'b0;
      end
      else if(clr_stable_signal) begin 
         stable_signal  <=1'b0;
      end
      else if(set_stable_signal) begin
         stable_signal     <= 1'b1;
      end
      else if(clr_stable_signal) begin
         stable_signal     <= 1'b0;
      end
   end
   
         

   always @(posedge  aon_clk or negedge aon_rst_n) begin
      if(! aon_rst_n) begin
         gc_state    <= IDLE;
      end
      else if(sw_rst) begin
         gc_state <=  IDLE;
      end
      else begin
         gc_state    <= gn_state;
      end
   end

   always @(*) begin
      gn_state          = gc_state;
      run_counter       = 1'b0;
      set_stable_signal = 1'b0;
      clr_stable_signal = 1'b0;
      clr_counter       = 1'b0;
      
      case(gc_state)
         IDLE : begin
            if(line_state  == 1'b1) begin 
               gn_state       = HL;
            end
            else begin
               gn_state       = LL;
            end
         end
   
         HL : begin
            run_counter  = 1'b1;
            if(stable_line   && stable_timeOver) begin
               set_stable_signal    = 1'b1;
            end
            if(line_state == 0) begin
               gn_state    = LL;
               clr_stable_signal = 1'b1;
               clr_counter       = 1'b1;
            end
         end

         LL : begin
            run_counter  = 1'b1;
           if(stable_line   && stable_timeOver) begin
               set_stable_signal    = 1'b1;
            end
            if(line_state == 1) begin
               gn_state    = HL;
               clr_stable_signal = 1'b1;
               clr_counter       = 1'b1;
            end
         end   
      endcase 
   end
               
endmodule             
      
