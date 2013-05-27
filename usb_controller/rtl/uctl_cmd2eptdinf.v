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
// DATE		   	: Fri, 12 Apr 2013 16:28:47
// AUTHOR	      : Sanjeeva
// AUTHOR EMAIL	: sanjeeva.n@techvulcan.com
// FILE NAME		: uctl_cmd2eptdinf.v
// VERSION        : 0.1
//-------------------------------------------------------------------
module uctl_cmd2eptdinf 
   (

   input  wire                       sysRst_n         ,
   input  wire                       sys_clk          ,
   input  wire                       core_clk         ,
   input  wire                       uctl_rst_n       ,
 
   //----------------------------------------------
   // cmd interface
   //----------------------------------------------
   
   input  wire                       cmdIf_trEn       ,
   input  wire                       cmdIf_req        ,
   input  wire [31               :0] cmdIf_addr       ,
   input  wire                       cmdIf_wrRd       ,
   output wire                       cmdIf_ack        ,

   input  wire                       cmdIf_wrData_req ,
   input  wire [31               :0] cmdIf_wrData     ,
   output reg                        cmdIf_wrData_ack ,

   input  wire                       cmdIf_rdData_req ,
   output reg                        cmdIf_rdData_ack ,
   output reg  [31               :0] cmdIf_rdData     ,
   
   //----------------------------------------------
   // endpoint data interface
   //----------------------------------------------
  
   input  wire [31               :0] eptd2cmd_rdData  ,
   output reg                        cmd2eptd_wrReq   ,
   output wire [31               :0] cmd2eptd_wrData  ,
   output wire [31               :0] cmd2eptd_addr   
   
   );                          
   // -------------------------------------------
   // FSM variables and parameters
   // -------------------------------------------
   localparam  [1             :0]    IDLE1       = 2'b00 , 
                                     WAIT4ACK1   = 2'b01 ,
                                     TRANS1      = 2'b10 ,
                                     WAIT4EMPTY1 = 2'b11 ;

   localparam                        IDLE2       = 1'b0  , 
                                     TRANS2      = 1'b1  ;
  
   localparam                        RDIDLE      = 1'b0  ,
                                     RDTRANS     = 1'b1  ;

   reg         [1             :0]    sysCurr_state       , 
                                     sysNext_state       ;

   reg                               coreCurr_state      , 
                                     coreNext_state      ;

   reg                               sysRdCstate         , 
                                     sysRdNstate         ;


   reg                               addr_ld_ack         ;
   reg                               addr_ld             ;
   reg                               reg_addr_ld         ;
   reg                               fifo_write          ;
   reg                               fifo_read           ;
   reg                               set_tr_end          ;
   reg                               rdAddr_ld           ;
   reg         [31             :0]   rdAddr              ;
   reg         [31             :0]   wrAddr              ;
   reg                               regData_ld          ;
   reg                               addr_inc            ;
   reg                               wrcmdIf_ack         ;
   reg                               rdcmdIf_ack         ;
   reg        [32             :0]    fifo_dataIn         ;
   reg                               reg_trEnd           ;
   reg                               addr_ld_nxt         ;

   wire                              addr_ld_s2c         ;
   wire                              addr_ack_c2s        ;
   wire                              fifo_full           ;
   wire                              fifo_empty          ;
   wire       [32             :0]    fifo_dataOut        ; 

   /********************************************************************/
   // writing data to endpoint data system clock
   /********************************************************************/

   // -------------------------------------------
   // Next state logic system clock
   // -------------------------------------------
   always @(*)begin
      sysNext_state                    = sysCurr_state;
      addr_ld_nxt                      = addr_ld; 
      wrcmdIf_ack                      = 1'b0;
      fifo_write                       = 1'b0;
      cmdIf_wrData_ack                 = 1'b0;
      set_tr_end                       = 1'b0;

      case (sysCurr_state)
         IDLE1  :  begin
            if(cmdIf_trEn && cmdIf_req && cmdIf_wrRd)begin
               addr_ld_nxt             = 1'b1;
               sysNext_state           = WAIT4ACK1; 
            end
         end 

         WAIT4ACK1 :  begin
               addr_ld_nxt             = 1'b1;
            if(addr_ack_c2s == 1'b1)begin
               addr_ld_nxt             = 1'b0;
               wrcmdIf_ack             = 1'b1;
               sysNext_state           = TRANS1; 
            end
         end

         TRANS1 :  begin
            if((cmdIf_trEn == 1'b0) || (cmdIf_req == 1'b1))begin
               fifo_write              = 1'b1;
               sysNext_state           = IDLE1;
               set_tr_end              = 1'b1;
            end
            else if((cmdIf_trEn == 1'b1) && (cmdIf_wrData_req == 1'b1) && (!fifo_full))begin
               cmdIf_wrData_ack        = 1'b1;
               fifo_write              = 1'b1;
               sysNext_state           = TRANS1; 
            end
         end

         default :   sysNext_state     = sysCurr_state;
      endcase
   end

   // -------------------------------------------
   // State register system clock
   // -------------------------------------------
   always @( posedge sys_clk, negedge sysRst_n ) begin
      if(!sysRst_n) begin
         sysCurr_state              <= IDLE1;
      end
      else begin
         sysCurr_state              <= sysNext_state;
      end
   end

   always @( posedge sys_clk, negedge sysRst_n ) begin
      if(!sysRst_n) begin
         addr_ld              <= 1'b0;
      end
      else begin
         addr_ld              <= addr_ld_nxt;
      end
   end

   // address load synchronizer

   uctl_synchronizer i_clock2_synchronizer(
      .clk     (core_clk), 
      .reset   (uctl_rst_n), 
      .dataIn  (addr_ld),       
      .dataOut (addr_ld_s2c)
   );

   // fifo data input
   always @ (*) begin
      if(set_tr_end)begin
         fifo_dataIn                = {1'b1,{32{1'b0}}};
      end
      else begin
         fifo_dataIn                = {1'b0,cmdIf_wrData};
      end
   end

   /********************************************************************/
   // asyn fifo
   /********************************************************************/
   uctl_asyncFifo #(
      .FIFO_DATASIZE (33),
      .FIFO_ADDRSIZE (10)
      ) i_uctl_asyncFifo (
     .wclk                          ( sys_clk       ), 
     .rclk                          ( core_clk      ), 
     .wrst_n                        ( sysRst_n      ), 
     .rrst_n                        ( uctl_rst_n    ), 
     .w_en                          ( fifo_write    ), 
     .r_en                          ( fifo_read     ), 
     .fifo_data_in                  ( fifo_dataIn   ), 
     .wfull                         ( fifo_full     ), 
     .rempty                        ( fifo_empty    ), 
     .fifo_data_out                 ( fifo_dataOut  )
   );

   /********************************************************************/
   // core clock
   /********************************************************************/

   // -------------------------------------------
   // Next state logic core clock
   // -------------------------------------------
   always @(*)begin
      coreNext_state                   = coreCurr_state;
      fifo_read                        = 1'b0;
      cmd2eptd_wrReq                   = 1'b0;
      reg_addr_ld                      = 1'b0;
      addr_ld_ack                      = 1'b0;

      case (coreCurr_state)

         IDLE2  :  begin
            if(addr_ld_s2c == 1'b1)begin
               reg_addr_ld             = 1'b1;
               addr_ld_ack             = 1'b1;
               coreNext_state          = TRANS2;
            end
         end

         TRANS2 :  begin
            if(!fifo_empty)begin
               fifo_read               = 1'b1;
               if (reg_trEnd) begin
                  coreNext_state       = IDLE2;
               end
               else begin
                  cmd2eptd_wrReq       = 1'b1;
               end
            end
         end

         default :coreNext_state       = coreCurr_state;

      endcase
   end

   assign cmd2eptd_wrData           = fifo_dataOut[31:0];

   // -------------------------------------------
   // State register core clock
   // -------------------------------------------
   always @( posedge core_clk, negedge uctl_rst_n ) begin
      if(!uctl_rst_n) begin
         coreCurr_state         <= IDLE2;
      end
      else begin
         coreCurr_state         <= coreNext_state;
      end
   end

   // address register
   always @ (posedge core_clk , negedge uctl_rst_n) begin
      if(!uctl_rst_n)begin
         wrAddr          <= {32{1'b0}};
      end
      else begin
         if(reg_addr_ld == 1'b1)begin
            wrAddr       <= cmdIf_addr;
         end
         else if(!fifo_empty && !reg_trEnd ) begin
            wrAddr              <= wrAddr   + 3'b100;
         end
         else begin
            wrAddr              <= wrAddr;
         end
      end
   end

   // address ack stretcher
   uctl_pulsestretch  addr_ack_stretcher (
   .clock1Rst_n                 ( uctl_rst_n      ), 
   .clock1                      ( core_clk        ), 
   .clock2                      ( sys_clk         ), 
   .clock2Rst_n                 ( sysRst_n        ), 
   .pulseIn                     ( addr_ld_ack     ), 
   .pulseOut                    ( addr_ack_c2s    ) 
   );

   // fifo transmission end
   always @ (*) begin
      if((!fifo_empty) && (fifo_dataOut[32] == 1'b1))begin
         reg_trEnd              = 1'b1;
      end
      else begin
         reg_trEnd              = 1'b0;
      end
   end

   assign cmdIf_ack     = (cmdIf_wrRd == 1'b1) ? wrcmdIf_ack : rdcmdIf_ack ;
   assign cmd2eptd_addr = (cmdIf_wrRd == 1'b1) ? wrAddr      : rdAddr      ;

   /********************************************************************/ 
   // reading data from endpoint data
   /********************************************************************/

   always @(*)begin
      sysRdNstate                   = sysRdCstate;
      rdAddr_ld                     = 1'b0;
      rdcmdIf_ack                   = 1'b0;
      regData_ld                    = 1'b0;
      addr_inc                      = 1'b1;
      cmdIf_rdData_ack              = 1'b1;

      case (sysRdCstate)
         RDIDLE  :  begin
            if(cmdIf_trEn && cmdIf_req && !cmdIf_wrRd)begin
               rdcmdIf_ack          = 1'b1  ;
               rdAddr_ld            = 1'b1  ;
               sysRdNstate          = RDTRANS;
            end
         end

         RDTRANS  :  begin
            if((cmdIf_trEn == 1'b0) || (cmdIf_req == 1'b1))begin
               sysRdNstate          = RDIDLE;
            end
            else if((cmdIf_trEn == 1'b1) && (cmdIf_rdData_req == 1'b1)) begin
               addr_inc             = 1'b1   ;
               regData_ld           = 1'b1   ;
               cmdIf_rdData_ack     = 1'b1   ;
               sysRdNstate          = RDTRANS;
            end
         end

         default : sysRdNstate                   = sysRdCstate;

      endcase
   end

   // -------------------------------------------
   // State register system clock for reading
   // -------------------------------------------
   always @( posedge sys_clk, negedge sysRst_n ) begin
      if(!sysRst_n) begin
         sysRdCstate              <= RDIDLE;
      end
      else begin
         sysRdCstate              <= sysRdNstate;
      end
   end

   // read address load
   always @( posedge sys_clk, negedge sysRst_n ) begin
      if(!sysRst_n) begin
         rdAddr                   <= {32{1'b0}};
      end
      else if(rdAddr_ld) begin
         rdAddr                   <= cmdIf_addr;
      end
      else if(addr_inc) begin
         rdAddr                   <= rdAddr + 3'b100;
      end
   end

   // read data load
   always @( posedge sys_clk, negedge sysRst_n ) begin
      if(!sysRst_n) begin
         cmdIf_rdData             <= {32{1'b0}};
      end
      else if(regData_ld) begin
         cmdIf_rdData             <= eptd2cmd_rdData;
      end
   end

endmodule 





