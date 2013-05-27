
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
// DATE		   	: Mon, 20 May 2013 19:57:14
// AUTHOR	      : Lalit Kumar
// AUTHOR EMAIL   : lalit.kumar@techvulcan.com
// FILE NAME		: uctl_aon.v
// Version no.    : 0.1
//-------------------------------------------------------------------
module uctl_aon#(
      parameter GLITCH_CNTR_WD = 4
      )(
      input  wire                        aon_clk           ,// always on clock
      input  wire                        aon_rst_n         ,// reset
      input  wire                        sw_rst            ,// active high software reset
      input  wire  [GLITCH_CNTR_WD -1:0] ss_count          ,// signal stable for ss_count aon_clk cycle
      input  wire [2               -1:0] line_state        ,// line state 
      input  wire                        power_down        ,//High if device is in power down state core clock signal
      output reg                         bus_activityIrq   // activity on the bus has been detected
      );
   
   reg                      dm_lineSt1    ;
   reg                      dm_lineSt0    ;
   reg                      dp_lineSt1    ;
   reg                      dp_lineSt0    ;
   reg                      bus_active    ;
   wire                     dp_status     ;  // DM
   wire                     dm_status     ;  // DP
   reg                      syn_power_down;
   reg                      syn_power_down1;


//   assign bus_activityIrq  = (dp_status || dm_status) ? 1'b1 : 1'b0 ;

   //check activity on line state
   //---------------------------------------------------------------
   always @(*) begin
      case ({syn_power_down,dp_status , dm_status})
         3'b100 : bus_active =  1'b1;  //SE0
         3'b101 : bus_active =  1'b1;  //K
         3'b110 : bus_active =  1'b0;  //J
         3'b111 : bus_active =  1'b0;  //SE1
         default: bus_active =  1'b0;  //invalid
      endcase
   end

   //register ativity on line state
   //---------------------------------------------------------------
   always @(posedge  aon_clk, negedge aon_rst_n) begin
      if(! aon_rst_n) begin 
         bus_activityIrq      <= 1'b0;
      end
      else if( sw_rst    ) begin 
         bus_activityIrq      <= 1'b0;
      end
      else begin
         bus_activityIrq      <= bus_active;
      end
   end 

   //synchronize the phy domain line state to aon clok domain
   //---------------------------------------------------------------
   always @(posedge  aon_clk, negedge aon_rst_n) begin
      if(! aon_rst_n) begin 
         dm_lineSt0       <= 1'b0;
         dm_lineSt1      <= 1'b0;
      end 
      else  if( sw_rst    ) begin 
         dm_lineSt0      <= 1'b0;
         dm_lineSt1   <= 1'b0;
      end 
      else begin
         dm_lineSt0   <= line_state[0]  ;
         dm_lineSt1   <= dm_lineSt0;
      end
   end
   
   always @(posedge  aon_clk, negedge aon_rst_n) begin
      if(! aon_rst_n) begin 
         dp_lineSt0    <= 1'b0;
         dp_lineSt1    <= 1'b0;
      end 
      else  if( sw_rst    ) begin 
         dp_lineSt0    <= 1'b0;
         dp_lineSt1    <= 1'b0;
      end 
      else begin
         dp_lineSt0    <= line_state[1]  ;
         dp_lineSt1    <= dp_lineSt0 ;
      end
   end
   
   always @(posedge  aon_clk, negedge aon_rst_n) begin
      if(! aon_rst_n) begin 
         syn_power_down <= 1'b0;
         syn_power_down1<= 1'b0;
      end
     else if( sw_rst    ) begin 
         syn_power_down <= 1'b0;
         syn_power_down1<= 1'b0;
      end
      else begin 
         syn_power_down1<= power_down;
         syn_power_down <= syn_power_down1;
      end
   end

   //glitch filter for dp(D+) line
   //---------------------------------------------------------------
   uctl_glitchFilter #(.GLITCH_CNTR_WD (GLITCH_CNTR_WD )
      )i0_glitchFilter (
      .aon_clk        (aon_clk            ), 
      .aon_rst_n      (aon_rst_n          ),   
      .sw_rst         (sw_rst             ),
      .line_state     (dm_lineSt1         ),
      .stable_time    (ss_count           ),
      .stable_signal  (dp_status          )
   );

   //glitch filter for dm(D-) line
   //---------------------------------------------------------------
   uctl_glitchFilter  #(.GLITCH_CNTR_WD (GLITCH_CNTR_WD )
     )i1_glitchFilter (
      .aon_clk        (aon_clk            ), 
      .aon_rst_n      (aon_rst_n          ),   
      .sw_rst         (sw_rst             ),
      .line_state     (dp_lineSt1         ),
      .stable_time    (ss_count           ),
      .stable_signal  (dm_status          )
   );
endmodule 
