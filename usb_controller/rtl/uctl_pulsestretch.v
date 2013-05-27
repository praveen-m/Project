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
// DATE		   	: Fri, 12 Apr 2013 17:15:45
// AUTHOR	      : Sanjeeva
// AUTHOR EMAIL	: sanjeeva.n@techvulcan.com
// FILE NAME		: uctl_pulsestretch.v
// VERSION        : 0.1
//-------------------------------------------------------------------

module uctl_pulsestretch #(
   parameter BYPASS      = 0,
   parameter DATA_WD     = 1
   )(

   input  wire                clock1Rst_n       ,//system reset
   input  wire                clock1            ,//system clock
   input  wire                clock2            ,//Core clock 
   input  wire                clock2Rst_n       ,//Core Reset
   input  wire                pulseIn           ,//input pulse
   output wire                pulseOut          ,//output pulse
   input  wire[DATA_WD-1 : 0] dataIn            ,//data input
   output wire[DATA_WD-1 : 0] dataOut            //data output
);

   reg  [DATA_WD-1 : 0]       reg_dataIn        ;
   reg                        pulseStrh         ;
   wire                       coreSyncFlop      ;
   reg                        delayFlop2        ;
   wire                       sysSyncFlop2      ;

   generate begin
      if (BYPASS == 0) begin
         // pulse stretcher a/c to pulseIn clock 1.
         always @ (posedge clock1 , negedge clock1Rst_n) begin
            if(!clock1Rst_n)begin
               pulseStrh            <= 1'b0           ;
            end
            else begin
               if(pulseIn == 1'b1) begin
                  pulseStrh         <= 1'b1           ;
               end
               else if(sysSyncFlop2 == 1'b1)begin
                  pulseStrh         <= 1'b0           ;
               end
            end
         end
         
         uctl_synchronizer i_clock2_synchronizer(
            .clk     (clock2         ), 
            .reset   (clock2Rst_n    ), 
            .dataIn  (pulseStrh      ),       
            .dataOut (coreSyncFlop   )
           );


         // register data 
         always @ (posedge clock1 , negedge clock1Rst_n) begin
            if(!clock1Rst_n)begin
               reg_dataIn <= {DATA_WD{1'b0}};
            end
            else if(pulseIn == 1'b1) begin
               reg_dataIn <= dataIn;
            end
         end

         assign dataOut = reg_dataIn ;

         // delay flop for edge detector
         always @(posedge clock2 , negedge clock2Rst_n) begin
            if (!clock2Rst_n) begin
               delayFlop2           <= 1'b0           ;
            end
            else begin
               delayFlop2           <= coreSyncFlop   ;
            end
         end

         // output edge detector
         assign pulseOut = (coreSyncFlop  && (!delayFlop2)) ? 1'b1 : 1'b0 ;


         uctl_synchronizer i_clock1_synchronizer(
            .clk     (clock1         ), 
            .reset   (clock1Rst_n    ), 
            .dataIn  (coreSyncFlop   ),       
            .dataOut (sysSyncFlop2   )
           );

		end
      else begin
         assign pulseOut  = pulseIn;
         assign dataOut   = dataIn;
      end
	end
   endgenerate

endmodule
