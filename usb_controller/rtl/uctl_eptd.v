`timescale 1ns / 1ps
//-------------------------------------------------------------------
// Copyright © 2012 TECHVULCAN, Inc. All rights reserved.		   
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, nor	   
// its contents							   
// revealed in any manner to others without the express written	   
// permission	of TechVulcan 					   
// Licensed Material.						   
// Program Property of TECHVULCAN Incorporated.	
// ------------------------------------------------------------------
// DATE		     	: Fri, 15 Feb 2013 17:13:51
// AUTHOR	      : Sanjeeva
// AUTHOR EMAIL	: sanjeeva.n@techvulcan.com
// FILE NAME		: uctl_eptd.v
// VERSION        : 0.4
//-------------------------------------------------------------------
/*TODO
* eptd2epcr_ReqErr -- error request on end point number
* priority for updating signals from endpoint controllers should be updated to epct first(currently epcr is high priority).
*/
/********************************************************************/
/*
//UPDATE 0.2
* all register have changed to 0.4 usb spec.
* endpoint number is changed to 4-bits.
* control register 2 is added.
* status register is added.
* ack register is added.
* all address is changed and parameterized.
//UPDATE 0.3
* added fullPktCnt signal both read and write
//Update 0.4
*pe2eptd_initIsoPid signal and related logic is added
//eptd2pe_noTransPending signal added for lmp transfer
*/

/********************************************************************/
module uctl_eptd 
#(   parameter  
  `include "../rtl/uctl_regConfig.vh" 
  
   )
(
   input wire                 sw_rst                  ,
  // -----------------------------------------------
  // Global Signal
  // -----------------------------------------------

   input wire                 core_clk                ,//Core clock 
   input wire                 uctl_rst_n              ,//Reset

  // -----------------------------------------------
  // command interface
  // -----------------------------------------------

   input wire [ADDR_SIZE-1:0] cmd2eptd_addr           ,//Address bus
 //input wire                 cmd2eptd_en             ,//Enable signal for doing a read or a write operation
   input wire [DATA_SIZE-1:0] cmd2eptd_wrData         ,//Data Input
   input wire                 cmd2eptd_wrReq          ,//Register write enable signal

   output reg [DATA_SIZE-1:0] eptd2cmd_rdData         ,//Data out
   //----------------------------------------------
   // pe interface
   //----------------------------------------------
   input wire                 pe2eptd_intPid          ,
   input wire                 pe2eptd_initIsoPid      ,
   output wire                eptd2pe_noTransPending  ,
  // -----------------------------------------------
  // packet decoder
  // -----------------------------------------------
   input wire                 pd2eptd_statusStrobe    ,
   input wire                 pd2eptd_crc5            ,
   input wire                 pd2eptd_pid             ,
   input wire                 pd2eptd_err             ,
   input wire[4            :0]pd2eptd_epNum           ,

  // -----------------------------------------------
  // EPC Write Interface
  // -----------------------------------------------

   input wire [3     :0]      epcr2eptd_epNum         ,//Physical Endpoint number
   input wire                 epcr2eptd_reqData       ,//Request signal 
   input wire                 epcr2eptd_updtReq       ,//Update request 
   input  wire                epcr2eptd_dataFlush  ,
   input wire [ADDR_SIZE-1:0] epcr2eptd_wrPtrOut      ,//Write pointer value to be updated
   input wire [3     :0]      epcr2eptd_nxtDataPid    ,//The expected data PID for that EP  //TODO only 2 bits assigned
   input  wire                epcr2eptd_setEphalt    ,
    
   output reg                 eptd2epcr_wrReqErr      ,//OUT Request error indication //TODO all request error to be updated
   output wire [ADDR_SIZE-1:0]eptd2epcr_startAddr     ,//Endpoint Start Address
   output wire [ADDR_SIZE-1:0]eptd2epcr_endAddr       ,//Endpoint End Address
   output wire [ADDR_SIZE-1:0]eptd2epcr_rdPtr         ,//Endpoint Read pointer
   output wire [ADDR_SIZE-1:0]eptd2epcr_wrPtr         ,//Endpoint Write pointer
   output wire                eptd2epcr_lastOp        ,//Last operation
   output wire [3     :0]     eptd2epcr_exptDataPid   ,//The expected data PID for that EP
   output reg                 eptd2epcr_updtDn        ,//Return status signal 
   output wire [10    :0]     eptd2epcr_wMaxPktSize   ,//Endpoint max buffer size
   output wire [1     :0]     eptd2epcr_epType        ,//Endpoint Type
   //output wire              eptd2epcr_dir           ,//Endpoint Direction
   output wire [1     :0]     eptd2epcr_epTrans       ,//High BW # transfers per frame
   output wire                eptd2epcr_epHalt        ,//Endpoint Halt

  // -----------------------------------------------
  // EPC Read Interface 
  // -----------------------------------------------

   input wire [3     :0]      epct2eptd_epNum         ,//Physical Endpoint number
   input wire                 epct2eptd_reqData       ,//Request signal
   input wire                 epct2eptd_updtReq       ,//Update request
   input wire [ADDR_SIZE-1:0] epct2eptd_rdPtrOut      ,//Read pointer value to be updated
   input wire [3     :0]      epct2eptd_nxtExpDataPid ,//The expected data PID for that EP   //TODO only 2 bits assigned
   
   output reg                 eptd2epct_reqErr        ,//OUT Request error indication //TODO all request error to be updated
   output wire                eptd2epct_zLenPkt       ,//zero length pkt
   output wire [ADDR_SIZE-1:0]eptd2epct_startAddr     ,//Endpoint Start Address
   output wire [ADDR_SIZE-1:0]eptd2epct_endAddr       ,//Endpoint End Address
   output wire [ADDR_SIZE-1:0]eptd2epct_rdPtr         ,//Endpoint Read pointer
   output wire [ADDR_SIZE-1:0]eptd2epct_wrPtr         ,//Endpoint Write pointer
   output wire                eptd2epct_lastOp        ,//Last operation
   output wire [3     :0]     eptd2epct_exptDataPid   ,//The expected data PID for that EP
   output reg                 eptd2epct_updtDn        ,//Return status signal 
 //output wire [14     :0]    eptd2epct_wMaxPktSize   ,//Endpoint max buffer size
   output wire [1     :0]     eptd2epct_epType        ,//Endpoint Type
 //output wire                eptd2epct_dir           ,//Endpoint Direction
   output wire [1     :0]     eptd2epct_epTrans       ,//High BW # transfers per frame
   output wire                eptd2epct_epHalt        ,//Endpoint Halt

  // -----------------------------------------------
  //  Sys_EPC Write Interface
  // -----------------------------------------------

   input wire [3     :0]      sept2eptd_epNum         ,//Physical Endpoint number
   input wire                 sept2eptd_reqData       ,//Request signal
   input wire                 sept2eptd_updtReq       ,//Update request
   input wire [ADDR_SIZE-1:0] sept2eptd_wrPtrOut      ,//Wirte pointer value to be updated

   output reg                 eptd2sept_reqErr        ,//OUT Request error indication //TODO all request error to be updated
   output wire [ADDR_SIZE-1:0]eptd2sept_startAddr     ,//Endpoint Start Address
   output wire [ADDR_SIZE-1:0]eptd2sept_endAddr       ,//Endpoint End Address
   output wire [ADDR_SIZE-1:0]eptd2sept_rdPtr         ,//Endpoint Read pointer
   output wire [ADDR_SIZE-1:0]eptd2sept_wrPtr         ,//Endpoint Write pointer
   output reg                 eptd2sept_updtDn        ,//Return status signal
   output wire [10    :0]     eptd2sept_bSize         ,//Endpoint max buffer size
   output wire                eptd2sept_lastOp        ,//Last operation
   output wire [PKTCNTWD-1 :0]eptd2sept_fullPktCnt    ,

  // -----------------------------------------------
  //  Sys_EPC Read Interface
  // -----------------------------------------------

   input wire [3     :0]      sepr2eptd_epNum         ,//Physical Endpoint number
   input wire                 sepr2eptd_reqData       ,//Request signal
   input wire                 sepr2eptd_updtReq       ,//Update request
   input wire [ADDR_SIZE-1:0] sepr2eptd_rdPtr         ,//Wirte pointer value to be updated
   
   output reg                 eptd2sepr_ReqErr        ,//OUT Request error indication //TODO all request error to be updated
   output wire [ADDR_SIZE-1:0]eptd2sepr_startAddr     ,//Endpoint Start Address
   output wire [ADDR_SIZE-1:0]eptd2sepr_endAddr       ,//Endpoint End Address
   output wire [ADDR_SIZE-1:0]eptd2sepr_rdPtr         ,//Endpoint Read pointer
   output wire [ADDR_SIZE-1:0]eptd2sepr_wrPtr         ,//Endpoint Write pointer
   output wire                eptd2sepr_lastOp        ,//Last operation
   output wire [PKTCNTWD-1 :0]eptd2sepr_fullPktCnt    ,
   output reg                 eptd2sepr_updtDn         //Return status signal
);

   //---------------------------------------------------
   // Local parameter
   //---------------------------------------------------
   localparam              READ   =  1'b0,
                           WRITE  =  1'b1;

   //---------------------------------------------------
   // Local wires and registers
   //---------------------------------------------------
   reg        [ADDR_SIZE-1    :0]   ept_SA   [0:ADDR_SIZE-1] ;
   reg        [ADDR_SIZE-1    :0]   ept_EA   [0:ADDR_SIZE-1] ;
   reg        [ADDR_SIZE-1    :0]   ept_CR1  [0:ADDR_SIZE-1] ;
   reg        [ADDR_SIZE-1    :0]   ept_CR2  [0:ADDR_SIZE-1] ;
   reg        [ADDR_SIZE-1    :0]   ept_wPtr [0:ADDR_SIZE-1] ;
   reg        [ADDR_SIZE-1    :0]   ept_rPtr [0:ADDR_SIZE-1] ;
   reg        [ADDR_SIZE-1    :0]   ept_arPtr[0:16-1]        ;
   reg        [ADDR_SIZE-1    :0]   ept_stat [0:ADDR_SIZE-1] ;
   reg        [ADDR_SIZE-1    :0]   ept_fullPktCnt [0:ADDR_SIZE-1] ;

   reg        [ADDR_SIZE-1    :0]   wren_SA                  ;
   reg        [ADDR_SIZE-1    :0]   wren_EA                  ;
   reg        [ADDR_SIZE-1    :0]   wren_CR1                 ;
   reg        [ADDR_SIZE-1    :0]   wren_CR2                 ;
   reg        [ADDR_SIZE-1    :0]   wren_wPtr                ;
   reg        [ADDR_SIZE-1    :0]   wren_rPtr                ;
   reg        [16-1           :0]   wren_arPtr               ;
   reg        [ADDR_SIZE-1    :0]   wren_stat                ;
   reg        [ADDR_SIZE-1    :0]   wren_fullPktCnt                ;

   reg        [ADDR_SIZE-1    :0]   rden_SA                  ;
   reg        [ADDR_SIZE-1    :0]   rden_EA                  ;
   reg        [ADDR_SIZE-1    :0]   rden_CR1                 ;
   reg        [ADDR_SIZE-1    :0]   rden_CR2                 ;
   reg        [ADDR_SIZE-1    :0]   rden_wPtr                ;
   reg        [ADDR_SIZE-1    :0]   rden_rPtr                ;
   reg        [16-1           :0]   rden_arPtr               ;
   reg        [ADDR_SIZE-1    :0]   rden_stat                ;
   reg        [ADDR_SIZE-1    :0]   rden_fullPktCnt          ;

   reg                              lastOp [0:ADDR_SIZE-1]   ;

   reg                              epcrUpdt                 ;
   reg                              epctUpdt                 ;
   reg                              seprUpdt                 ;
   reg                              septUpdt                 ;
   wire       [ADDR_SIZE-1    :0]   noTransPending           ;
   wire                             rdWrEn                   ;

   //---------------------------------------------------
   // Code Starts From Here
   //---------------------------------------------------
   always @(*)begin
   //---------------------------------------------------
   // wirte enable for different address
      wren_SA     = 32'h00000                    ;
      wren_EA     = 32'h00000                    ;
      wren_CR1    = 32'h00000                    ;
      wren_CR2    = 32'h00000                    ;
      wren_wPtr   = 32'h00000                    ;
      wren_rPtr   = 32'h00000                    ;
      wren_arPtr  = 16'h0000                     ;
      wren_stat   = 32'h00000                    ;
      wren_fullPktCnt = 32'h00000                ;

      rden_SA     = 32'h00000                    ;
      rden_EA     = 32'h00000                    ;
      rden_CR1    = 32'h00000                    ;
      rden_CR2    = 32'h00000                    ;
      rden_wPtr   = 32'h00000                    ;
      rden_rPtr   = 32'h00000                    ;
      rden_arPtr  = 16'h0000                     ;
      rden_stat   = 32'h00000                    ;
      rden_fullPktCnt = 32'h00000                ;

      case(cmd2eptd_addr)
      // endpoint 0
         EPT0_SA :  begin
            wren_SA[0]     = cmd2eptd_wrReq      ;
            rden_SA[0]     = 1'b1      ;
         end
         EPT0_EA :  begin
            wren_EA[0]     = cmd2eptd_wrReq      ;
            rden_EA[0]     = 1'b1      ;
         end
         EPT0_CR1 :  begin
            wren_CR1[0]    = cmd2eptd_wrReq      ;
            rden_CR1[0]    = 1'b1      ;
         end
         EPT0_CR2 :  begin
            wren_CR2[0]    = cmd2eptd_wrReq      ;
            rden_CR2[0]    = 1'b1      ;
         end
         EPT0_WPTR :  begin
            wren_wPtr[0]   = cmd2eptd_wrReq      ;
            rden_wPtr[0]   = 1'b1      ;
         end 
         EPT0_RPTR :  begin
            wren_rPtr[0]   = cmd2eptd_wrReq      ;
            rden_rPtr[0]   = 1'b1      ;
         end
         EPT0_STAT :  begin
            wren_stat[0]   = cmd2eptd_wrReq      ;
            rden_stat[0]   = 1'b1      ;
         end
      // endpoint 1
         EPT1_SA :  begin
            wren_SA[1]     = cmd2eptd_wrReq      ;
            rden_SA[1]     = 1'b1      ;
         end
         EPT1_EA :  begin
            wren_EA[1]     = cmd2eptd_wrReq      ;
            rden_EA[1]     = 1'b1      ;
         end
         EPT1_CR1 :  begin
            wren_CR1[1]    = cmd2eptd_wrReq      ;
            rden_CR1[1]    = 1'b1      ;
         end
         EPT1_CR2 :  begin
            wren_CR2[1]    = cmd2eptd_wrReq      ;
            rden_CR2[1]    = 1'b1      ;
         end
         EPT1_WPTR :  begin
            wren_wPtr[1]   = cmd2eptd_wrReq      ;
            rden_wPtr[1]   = 1'b1      ;
         end 
         EPT1_RPTR :  begin
            wren_rPtr[1]   = cmd2eptd_wrReq      ;
            rden_rPtr[1]   = 1'b1      ;
         end
         EPT1_STAT :  begin
            wren_stat[1]   = cmd2eptd_wrReq      ;
            rden_stat[1]   = 1'b1      ;
         end
      // endpoint 2
         EPT2_SA :  begin
            wren_SA[2]     = cmd2eptd_wrReq      ;
            rden_SA[2]     = 1'b1      ;
         end
         EPT2_EA :  begin
            wren_EA[2]     = cmd2eptd_wrReq      ;
            rden_EA[2]     = 1'b1      ;
         end
         EPT2_CR1 :  begin
            wren_CR1[2]    = cmd2eptd_wrReq      ;
            rden_CR1[2]    = 1'b1      ;
         end
         EPT2_CR2 :  begin
            wren_CR2[2]    = cmd2eptd_wrReq      ;
            rden_CR2[2]    = 1'b1      ;
         end
         EPT2_WPTR :  begin
            wren_wPtr[2]   = cmd2eptd_wrReq      ;
            rden_wPtr[2]   = 1'b1      ;
         end 
         EPT2_RPTR :  begin
            wren_rPtr[2]   = cmd2eptd_wrReq      ;
            rden_rPtr[2]   = 1'b1      ;
         end
         EPT2_STAT :  begin
            wren_stat[2]   = cmd2eptd_wrReq      ;
            rden_stat[2]   = 1'b1      ;
         end
      // endpoint 3
         EPT3_SA :  begin
            wren_SA[3]     = cmd2eptd_wrReq      ;
            rden_SA[3]     = 1'b1      ;
         end
         EPT3_EA :  begin
            wren_EA[3]     = cmd2eptd_wrReq      ;
            rden_EA[3]     = 1'b1      ;
         end
         EPT3_CR1 :  begin
            wren_CR1[3]    = cmd2eptd_wrReq      ;
            rden_CR1[3]    = 1'b1      ;
         end
         EPT3_CR2 :  begin
            wren_CR2[3]    = cmd2eptd_wrReq      ;
            rden_CR2[3]    = 1'b1      ;
         end
         EPT3_WPTR :  begin
            wren_wPtr[3]   = cmd2eptd_wrReq      ;
            rden_wPtr[3]   = 1'b1      ;
         end 
         EPT3_RPTR :  begin
            wren_rPtr[3]   = cmd2eptd_wrReq      ;
            rden_rPtr[3]   = 1'b1      ;
         end
         EPT3_STAT :  begin
            wren_stat[3]   = cmd2eptd_wrReq      ;
            rden_stat[3]   = 1'b1      ;
         end
      // endpoint 4
         EPT4_SA :  begin
            wren_SA[4]     = cmd2eptd_wrReq      ;
            rden_SA[4]     = 1'b1      ;
         end
         EPT4_EA :  begin
            wren_EA[4]     = cmd2eptd_wrReq      ;
            rden_EA[4]     = 1'b1      ;
         end
         EPT4_CR1 :  begin
            wren_CR1[4]    = cmd2eptd_wrReq      ;
            rden_CR1[4]    = 1'b1      ;
         end
         EPT4_CR2 :  begin
            wren_CR2[4]    = cmd2eptd_wrReq      ;
            rden_CR2[4]    = 1'b1      ;
         end
         EPT4_WPTR :  begin
            wren_wPtr[4]   = cmd2eptd_wrReq      ;
            rden_wPtr[4]   = 1'b1      ;
         end 
         EPT4_RPTR :  begin
            wren_rPtr[4]   = cmd2eptd_wrReq      ;
            rden_rPtr[4]   = 1'b1      ;
         end
         EPT4_STAT :  begin
            wren_stat[4]   = cmd2eptd_wrReq      ;
            rden_stat[4]   = 1'b1      ;
         end
      // endpoint 5
         EPT5_SA :  begin
            wren_SA[5]     = cmd2eptd_wrReq      ;
            rden_SA[5]     = 1'b1      ;
         end
         EPT5_EA :  begin
            wren_EA[5]     = cmd2eptd_wrReq      ;
            rden_EA[5]     = 1'b1      ;
         end
         EPT5_CR1 :  begin
            wren_CR1[5]    = cmd2eptd_wrReq      ;
            rden_CR1[5]    = 1'b1      ;
         end
         EPT5_CR2 :  begin
            wren_CR2[5]    = cmd2eptd_wrReq      ;
            rden_CR2[5]    = 1'b1      ;
         end
         EPT5_WPTR :  begin
            wren_wPtr[5]   = cmd2eptd_wrReq      ;
            rden_wPtr[5]   = 1'b1      ;
         end 
         EPT5_RPTR :  begin
            wren_rPtr[5]   = cmd2eptd_wrReq      ;
            rden_rPtr[5]   = 1'b1      ;
         end
         EPT5_STAT :  begin
            wren_stat[5]   = cmd2eptd_wrReq      ;
            rden_stat[5]   = 1'b1      ;
         end
      // endpoint 6
         EPT6_SA :  begin
            wren_SA[6]     = cmd2eptd_wrReq      ;
            rden_SA[6]     = 1'b1      ;
         end
         EPT6_EA :  begin
            wren_EA[6]     = cmd2eptd_wrReq      ;
            rden_EA[6]     = 1'b1      ;
         end
         EPT6_CR1 :  begin
            wren_CR1[6]    = cmd2eptd_wrReq      ;
            rden_CR1[6]    = 1'b1      ;
         end
         EPT6_CR2 :  begin
            wren_CR2[6]    = cmd2eptd_wrReq      ;
            rden_CR2[6]    = 1'b1      ;
         end
         EPT6_WPTR :  begin
            wren_wPtr[6]   = cmd2eptd_wrReq      ;
            rden_wPtr[6]   = 1'b1      ;
         end 
         EPT6_RPTR :  begin
            wren_rPtr[6]   = cmd2eptd_wrReq      ;
            rden_rPtr[6]   = 1'b1      ;
         end
         EPT6_STAT :  begin
            wren_stat[6]   = cmd2eptd_wrReq      ;
            rden_stat[6]   = 1'b1      ;
         end
      // endpoint 7
         EPT7_SA :  begin
            wren_SA[7]     = cmd2eptd_wrReq      ;
            rden_SA[7]     = 1'b1      ;
         end
         EPT7_EA :  begin
            wren_EA[7]     = cmd2eptd_wrReq      ;
            rden_EA[7]     = 1'b1      ;
         end
         EPT7_CR1 :  begin
            wren_CR1[7]    = cmd2eptd_wrReq      ;
            rden_CR1[7]    = 1'b1      ;
         end
         EPT7_CR2 :  begin
            wren_CR2[7]    = cmd2eptd_wrReq      ;
            rden_CR2[7]    = 1'b1      ;
         end
         EPT7_WPTR :  begin
            wren_wPtr[7]   = cmd2eptd_wrReq      ;
            rden_wPtr[7]   = 1'b1      ;
         end 
         EPT7_RPTR :  begin
            wren_rPtr[7]   = cmd2eptd_wrReq      ;
            rden_rPtr[7]   = 1'b1      ;
         end
         EPT7_STAT :  begin
            wren_stat[7]   = cmd2eptd_wrReq      ;
            rden_stat[7]   = 1'b1      ;
         end
      // endpoint 8
         EPT8_SA :  begin
            wren_SA[8]     = cmd2eptd_wrReq      ;
            rden_SA[8]     = 1'b1      ;
         end
         EPT8_EA :  begin
            wren_EA[8]     = cmd2eptd_wrReq      ;
            rden_EA[8]     = 1'b1      ;
         end
         EPT8_CR1 :  begin
            wren_CR1[8]    = cmd2eptd_wrReq      ;
            rden_CR1[8]    = 1'b1      ;
         end
         EPT8_CR2 :  begin
            wren_CR2[8]    = cmd2eptd_wrReq      ;
            rden_CR2[8]    = 1'b1      ;
         end
         EPT8_WPTR :  begin
            wren_wPtr[8]   = cmd2eptd_wrReq      ;
            rden_wPtr[8]   = 1'b1      ;
         end 
         EPT8_RPTR :  begin
            wren_rPtr[8]   = cmd2eptd_wrReq      ;
            rden_rPtr[8]   = 1'b1      ;
         end
         EPT8_STAT :  begin
            wren_stat[8]   = cmd2eptd_wrReq      ;
            rden_stat[8]   = 1'b1      ;
         end
      // endpoint 9
         EPT9_SA :  begin
            wren_SA[9]     = cmd2eptd_wrReq      ;
            rden_SA[9]     = 1'b1      ;
         end
         EPT9_EA :  begin
            wren_EA[9]     = cmd2eptd_wrReq      ;
            rden_EA[9]     = 1'b1      ;
         end
         EPT9_CR1 :  begin
            wren_CR1[9]    = cmd2eptd_wrReq      ;
            rden_CR1[9]    = 1'b1      ;
         end
         EPT9_CR2 :  begin
            wren_CR2[9]    = cmd2eptd_wrReq      ;
            rden_CR2[9]    = 1'b1      ;
         end
         EPT9_WPTR :  begin
            wren_wPtr[9]   = cmd2eptd_wrReq      ;
            rden_wPtr[9]   = 1'b1      ;
         end 
         EPT9_RPTR :  begin
            wren_rPtr[9]   = cmd2eptd_wrReq      ;
            rden_rPtr[9]   = 1'b1      ;
         end
         EPT9_STAT :  begin
            wren_stat[9]   = cmd2eptd_wrReq      ;
            rden_stat[9]   = 1'b1      ;
         end
      // endpoint 10
         EPT10_SA :  begin
            wren_SA[10]     = cmd2eptd_wrReq     ;
            rden_SA[10]     = 1'b1     ;
         end
         EPT10_EA :  begin
            wren_EA[10]     = cmd2eptd_wrReq     ;
            rden_EA[10]     = 1'b1     ;
         end
         EPT10_CR1 :  begin
            wren_CR1[10]    = cmd2eptd_wrReq     ;
            rden_CR1[10]    = 1'b1     ;
         end
         EPT10_CR2 :  begin
            wren_CR2[10]    = cmd2eptd_wrReq     ;
            rden_CR2[10]    = 1'b1     ;
         end
         EPT10_WPTR :  begin
            wren_wPtr[10]   = cmd2eptd_wrReq     ;
            rden_wPtr[10]   = 1'b1     ;
         end 
         EPT10_RPTR :  begin
            wren_rPtr[10]   = cmd2eptd_wrReq     ;
            rden_rPtr[10]   = 1'b1     ;
         end
         EPT10_STAT :  begin
            wren_stat[10]   = cmd2eptd_wrReq     ;
            rden_stat[10]   = 1'b1     ;
         end
      // endpoint 11
         EPT11_SA :  begin
            wren_SA[11]     = cmd2eptd_wrReq     ;
            rden_SA[11]     = 1'b1     ;
         end
         EPT11_EA :  begin
            wren_EA[11]     = cmd2eptd_wrReq     ;
            rden_EA[11]     = 1'b1     ;
         end
         EPT11_CR1 :  begin
            wren_CR1[11]    = cmd2eptd_wrReq     ;
            rden_CR1[11]    = 1'b1     ;
         end
         EPT11_CR2 :  begin
            wren_CR2[11]    = cmd2eptd_wrReq     ;
            rden_CR2[11]    = 1'b1     ;
         end
         EPT11_WPTR :  begin
            wren_wPtr[11]   = cmd2eptd_wrReq     ;
            rden_wPtr[11]   = 1'b1     ;
         end 
         EPT11_RPTR :  begin
            wren_rPtr[11]   = cmd2eptd_wrReq     ;
            rden_rPtr[11]   = 1'b1     ;
         end
         EPT11_STAT :  begin
            wren_stat[11]   = cmd2eptd_wrReq     ;
            rden_stat[11]   = 1'b1     ;
         end
      // endpoint 12
         EPT12_SA :  begin
            wren_SA[12]     = cmd2eptd_wrReq     ;
            rden_SA[12]     = 1'b1     ;
         end
         EPT12_EA :  begin
            wren_EA[12]     = cmd2eptd_wrReq     ;
            rden_EA[12]     = 1'b1     ;
         end
         EPT12_CR1 :  begin
            wren_CR1[12]    = cmd2eptd_wrReq     ;
            rden_CR1[12]    = 1'b1     ;
         end
         EPT12_CR2 :  begin
            wren_CR2[12]    = cmd2eptd_wrReq     ;
            rden_CR2[12]    = 1'b1     ;
         end
         EPT12_WPTR :  begin
            wren_wPtr[12]   = cmd2eptd_wrReq     ;
            rden_wPtr[12]   = 1'b1     ;
         end 
         EPT12_RPTR :  begin
            wren_rPtr[12]   = cmd2eptd_wrReq     ;
            rden_rPtr[12]   = 1'b1     ;
         end
         EPT12_STAT :  begin
            wren_stat[12]   = cmd2eptd_wrReq     ;
            rden_stat[12]   = 1'b1     ;
         end
      // endpoint 13
         EPT13_SA :  begin
            wren_SA[13]     = cmd2eptd_wrReq     ;
            rden_SA[13]     = 1'b1     ;
         end
         EPT13_EA :  begin
            wren_EA[13]     = cmd2eptd_wrReq     ;
            rden_EA[13]     = 1'b1     ;
         end
         EPT13_CR1 :  begin
            wren_CR1[13]    = cmd2eptd_wrReq     ;
            rden_CR1[13]    = 1'b1     ;
         end
         EPT13_CR2 :  begin
            wren_CR2[13]    = cmd2eptd_wrReq     ;
            rden_CR2[13]    = 1'b1     ;
         end
         EPT13_WPTR :  begin
            wren_wPtr[13]   = cmd2eptd_wrReq     ;
            rden_wPtr[13]   = 1'b1     ;
         end 
         EPT13_RPTR :  begin
            wren_rPtr[13]   = cmd2eptd_wrReq     ;
            rden_rPtr[13]   = 1'b1     ;
         end
         EPT13_STAT :  begin
            wren_stat[13]   = cmd2eptd_wrReq     ;
            rden_stat[13]   = 1'b1     ;
         end
      // endpoint 14
         EPT14_SA :  begin
            wren_SA[14]     = cmd2eptd_wrReq     ;
            rden_SA[14]     = 1'b1     ;
         end
         EPT14_EA :  begin
            wren_EA[14]     = cmd2eptd_wrReq     ;
            rden_EA[14]     = 1'b1     ;
         end
         EPT14_CR1 :  begin
            wren_CR1[14]    = cmd2eptd_wrReq     ;
            rden_CR1[14]    = 1'b1     ;
         end
         EPT14_CR2 :  begin
            wren_CR2[14]    = cmd2eptd_wrReq     ;
            rden_CR2[14]    = 1'b1     ;
         end
         EPT14_WPTR :  begin
            wren_wPtr[14]   = cmd2eptd_wrReq     ;
            rden_wPtr[14]   = 1'b1     ;
         end 
         EPT14_RPTR :  begin
            wren_rPtr[14]   = cmd2eptd_wrReq     ;
            rden_rPtr[14]   = 1'b1     ;
         end
         EPT14_STAT :  begin
            wren_stat[14]   = cmd2eptd_wrReq     ;
            rden_stat[14]   = 1'b1     ;
         end
      // endpoint 15
         EPT15_SA :  begin
            wren_SA[15]     = cmd2eptd_wrReq     ;
            rden_SA[15]     = 1'b1     ;
         end
         EPT15_EA :  begin
            wren_EA[15]     = cmd2eptd_wrReq     ;
            rden_EA[15]     = 1'b1     ;
         end
         EPT15_CR1 :  begin
            wren_CR1[15]    = cmd2eptd_wrReq     ;
            rden_CR1[15]    = 1'b1     ;
         end
         EPT15_CR2 :  begin
            wren_CR2[15]    = cmd2eptd_wrReq     ;
            rden_CR2[15]    = 1'b1     ;
         end
         EPT15_WPTR :  begin
            wren_wPtr[15]   = cmd2eptd_wrReq     ;
            rden_wPtr[15]   = 1'b1     ;
         end 
         EPT15_RPTR :  begin
            wren_rPtr[15]   = cmd2eptd_wrReq     ;
            rden_rPtr[15]   = 1'b1     ;
         end
         EPT15_STAT :  begin
            wren_stat[15]   = cmd2eptd_wrReq     ;
            rden_stat[15]   = 1'b1     ;
         end
      // endpoint 16
         EPT16_SA :  begin
            wren_SA[16]     = cmd2eptd_wrReq     ;
            rden_SA[16]     = 1'b1     ;
         end
         EPT16_EA :  begin
            wren_EA[16]     = cmd2eptd_wrReq     ;
            rden_EA[16]     = 1'b1     ;
         end
         EPT16_CR1 :  begin
            wren_CR1[16]    = cmd2eptd_wrReq     ;
            rden_CR1[16]    = 1'b1     ;
         end
         EPT16_CR2 :  begin
            wren_CR2[16]    = cmd2eptd_wrReq     ;
            rden_CR2[16]    = 1'b1     ;
         end
         EPT16_WPTR :  begin
            wren_wPtr[16]   = cmd2eptd_wrReq     ;
            rden_wPtr[16]   = 1'b1     ;
         end 
         EPT16_RPTR :  begin
            wren_rPtr[16]   = cmd2eptd_wrReq     ;
            rden_rPtr[16]   = 1'b1     ;
         end
         EPT16_ARPTR :  begin
            wren_arPtr[0]   = cmd2eptd_wrReq     ;
            rden_arPtr[0]   = 1'b1     ;
         end
         EPT16_STAT :  begin
            wren_stat[16]   = cmd2eptd_wrReq     ;
            rden_stat[16]   = 1'b1     ;
         end
      // endpoint 17
         EPT17_SA :  begin
            wren_SA[17]     = cmd2eptd_wrReq     ;
            rden_SA[17]     = 1'b1     ;
         end
         EPT17_EA :  begin
            wren_EA[17]     = cmd2eptd_wrReq     ;
            rden_EA[17]     = 1'b1     ;
         end
         EPT17_CR1 :  begin
            wren_CR1[17]    = cmd2eptd_wrReq     ;
            rden_CR1[17]    = 1'b1     ;
         end
         EPT17_CR2 :  begin
            wren_CR2[17]    = cmd2eptd_wrReq     ;
            rden_CR2[17]    = 1'b1     ;
         end
         EPT17_WPTR :  begin
            wren_wPtr[17]   = cmd2eptd_wrReq     ;
            rden_wPtr[17]   = 1'b1     ;
         end 
         EPT17_RPTR :  begin
            wren_rPtr[17]   = cmd2eptd_wrReq     ;
            rden_rPtr[17]   = 1'b1     ;
         end
         EPT17_ARPTR :  begin
            wren_arPtr[1]   = cmd2eptd_wrReq     ;
            rden_arPtr[1]   = 1'b1     ;
         end
         EPT17_STAT :  begin
            wren_stat[17]   = cmd2eptd_wrReq     ;
            rden_stat[17]   = 1'b1     ;
         end
      // endpoint 18
         EPT18_SA :  begin
            wren_SA[18]     = cmd2eptd_wrReq     ;
            rden_SA[18]     = 1'b1     ;
         end
         EPT18_EA :  begin
            wren_EA[18]     = cmd2eptd_wrReq     ;
            rden_EA[18]     = 1'b1     ;
         end
         EPT18_CR1 :  begin
            wren_CR1[18]    = cmd2eptd_wrReq     ;
            rden_CR1[18]    = 1'b1     ;
         end
         EPT18_CR2 :  begin
            wren_CR2[18]    = cmd2eptd_wrReq     ;
            rden_CR2[18]    = 1'b1     ;
         end
         EPT18_WPTR :  begin
            wren_wPtr[18]   = cmd2eptd_wrReq     ;
            rden_wPtr[18]   = 1'b1     ;
         end 
         EPT18_RPTR :  begin
            wren_rPtr[18]   = cmd2eptd_wrReq     ;
            rden_rPtr[18]   = 1'b1     ;
         end
         EPT18_ARPTR :  begin
            wren_arPtr[2]   = cmd2eptd_wrReq     ;
            rden_arPtr[2]   = 1'b1     ;
         end
         EPT18_STAT :  begin
            wren_stat[18]   = cmd2eptd_wrReq     ;
            rden_stat[18]   = 1'b1     ;
         end
      // endpoint 19
         EPT19_SA :  begin
            wren_SA[19]     = cmd2eptd_wrReq     ;
            rden_SA[19]     = 1'b1     ;
         end
         EPT19_EA :  begin
            wren_EA[19]     = cmd2eptd_wrReq     ;
            rden_EA[19]     = 1'b1     ;
         end
         EPT19_CR1 :  begin
            wren_CR1[19]    = cmd2eptd_wrReq     ;
            rden_CR1[19]    = 1'b1     ;
         end
         EPT19_CR2 :  begin
            wren_CR2[19]    = cmd2eptd_wrReq     ;
            rden_CR2[19]    = 1'b1     ;
         end
         EPT19_WPTR :  begin
            wren_wPtr[19]   = cmd2eptd_wrReq     ;
            rden_wPtr[19]   = 1'b1     ;
         end 
         EPT19_RPTR :  begin
            wren_rPtr[19]   = cmd2eptd_wrReq     ;
            rden_rPtr[19]   = 1'b1     ;
         end
         EPT19_ARPTR :  begin
            wren_arPtr[3]   = cmd2eptd_wrReq     ;
            rden_arPtr[3]   = 1'b1     ;
         end
         EPT19_STAT :  begin
            wren_stat[19]   = cmd2eptd_wrReq     ;
            rden_stat[19]   = 1'b1     ;
         end
      // endpoint 20
         EPT20_SA :  begin
            wren_SA[20]     = cmd2eptd_wrReq     ;
            rden_SA[20]     = 1'b1     ;
         end
         EPT20_EA :  begin
            wren_EA[20]     = cmd2eptd_wrReq     ;
            rden_EA[20]     = 1'b1     ;
         end
         EPT20_CR1 :  begin
            wren_CR1[20]    = cmd2eptd_wrReq     ;
            rden_CR1[20]    = 1'b1     ;
         end
         EPT20_CR2 :  begin
            wren_CR2[20]    = cmd2eptd_wrReq     ;
            rden_CR2[20]    = 1'b1     ;
         end
         EPT20_WPTR :  begin
            wren_wPtr[20]   = cmd2eptd_wrReq     ;
            rden_wPtr[20]   = 1'b1     ;
         end 
         EPT20_RPTR :  begin
            wren_rPtr[20]   = cmd2eptd_wrReq     ;
            rden_rPtr[20]   = 1'b1     ;
         end
         EPT20_ARPTR :  begin
            wren_arPtr[4]   = cmd2eptd_wrReq     ;
            rden_arPtr[4]   = 1'b1     ;
         end
         EPT20_STAT :  begin
            wren_stat[20]   = cmd2eptd_wrReq     ;
            rden_stat[20]   = 1'b1     ;
         end
      // endpoint 21
         EPT21_SA :  begin
            wren_SA[21]     = cmd2eptd_wrReq     ;
            rden_SA[21]     = 1'b1     ;
         end
         EPT21_EA :  begin
            wren_EA[21]     = cmd2eptd_wrReq     ;
            rden_EA[21]     = 1'b1     ;
         end
         EPT21_CR1 :  begin
            wren_CR1[21]    = cmd2eptd_wrReq     ;
            rden_CR1[21]    = 1'b1     ;
         end
         EPT21_CR2 :  begin
            wren_CR2[21]    = cmd2eptd_wrReq     ;
            rden_CR2[21]    = 1'b1     ;
         end
         EPT21_WPTR :  begin
            wren_wPtr[21]   = cmd2eptd_wrReq     ;
            rden_wPtr[21]   = 1'b1     ;
         end 
         EPT21_RPTR :  begin
            wren_rPtr[21]   = cmd2eptd_wrReq     ;
            rden_rPtr[21]   = 1'b1     ;
         end
         EPT21_ARPTR :  begin
            wren_arPtr[5]   = cmd2eptd_wrReq     ;
            rden_arPtr[5]   = 1'b1     ;
         end
         EPT21_STAT :  begin
            wren_stat[21]   = cmd2eptd_wrReq     ;
            rden_stat[21]   = 1'b1     ;
         end
      // endpoint 22
         EPT22_SA :  begin
            wren_SA[22]     = cmd2eptd_wrReq     ;
            rden_SA[22]     = 1'b1     ;
         end
         EPT22_EA :  begin
            wren_EA[22]     = cmd2eptd_wrReq     ;
            rden_EA[22]     = 1'b1     ;
         end
         EPT22_CR1 :  begin
            wren_CR1[22]    = cmd2eptd_wrReq     ;
            rden_CR1[22]    = 1'b1     ;
         end
         EPT22_CR2 :  begin
            wren_CR2[22]    = cmd2eptd_wrReq     ;
            rden_CR2[22]    = 1'b1     ;
         end
         EPT22_WPTR :  begin
            wren_wPtr[22]   = cmd2eptd_wrReq     ;
            rden_wPtr[22]   = 1'b1     ;
         end 
         EPT22_RPTR :  begin
            wren_rPtr[22]   = cmd2eptd_wrReq     ;
            rden_rPtr[22]   = 1'b1     ;
         end
         EPT22_ARPTR :  begin
            wren_arPtr[6]   = cmd2eptd_wrReq     ;
            rden_arPtr[6]   = 1'b1     ;
         end
         EPT22_STAT :  begin
            wren_stat[22]   = cmd2eptd_wrReq     ;
            rden_stat[22]   = 1'b1     ;
         end
      // endpoint 23
         EPT23_SA :  begin
            wren_SA[23]     = cmd2eptd_wrReq     ;
            rden_SA[23]     = 1'b1     ;
         end
         EPT23_EA :  begin
            wren_EA[23]     = cmd2eptd_wrReq     ;
            rden_EA[23]     = 1'b1     ;
         end
         EPT23_CR1 :  begin
            wren_CR1[23]    = cmd2eptd_wrReq     ;
            rden_CR1[23]    = 1'b1     ;
         end
         EPT23_CR2 :  begin
            wren_CR2[23]    = cmd2eptd_wrReq     ;
            rden_CR2[23]    = 1'b1     ;
         end
         EPT23_WPTR :  begin
            wren_wPtr[23]   = cmd2eptd_wrReq     ;
            rden_wPtr[23]   = 1'b1     ;
         end 
         EPT23_RPTR :  begin
            wren_rPtr[23]   = cmd2eptd_wrReq     ;
            rden_rPtr[23]   = 1'b1     ;
         end
         EPT23_ARPTR :  begin
            wren_arPtr[7]   = cmd2eptd_wrReq     ;
            rden_arPtr[7]   = 1'b1     ;
         end
         EPT23_STAT :  begin
            wren_stat[23]   = cmd2eptd_wrReq     ;
            rden_stat[23]   = 1'b1     ;
         end
      // endpoint 24
         EPT24_SA :  begin
            wren_SA[24]     = cmd2eptd_wrReq     ;
            rden_SA[24]     = 1'b1     ;
         end
         EPT24_EA :  begin
            wren_EA[24]     = cmd2eptd_wrReq     ;
            rden_EA[24]     = 1'b1     ;
         end
         EPT24_CR1 :  begin
            wren_CR1[24]    = cmd2eptd_wrReq     ;
            rden_CR1[24]    = 1'b1     ;
         end
         EPT24_CR2 :  begin
            wren_CR2[24]    = cmd2eptd_wrReq     ;
            rden_CR2[24]    = 1'b1     ;
         end
         EPT24_WPTR :  begin
            wren_wPtr[24]   = cmd2eptd_wrReq     ;
            rden_wPtr[24]   = 1'b1     ;
         end 
         EPT24_RPTR :  begin
            wren_rPtr[24]   = cmd2eptd_wrReq     ;
            rden_rPtr[24]   = 1'b1     ;
         end
         EPT24_ARPTR :  begin
            wren_arPtr[8]   = cmd2eptd_wrReq     ;
            rden_arPtr[8]   = 1'b1     ;
         end
         EPT24_STAT :  begin
            wren_stat[24]   = cmd2eptd_wrReq     ;
            rden_stat[24]   = 1'b1     ;
         end
      // endpoint 25
         EPT25_SA :  begin
            wren_SA[25]     = cmd2eptd_wrReq     ;
            rden_SA[25]     = 1'b1     ;
         end
         EPT25_EA :  begin
            wren_EA[25]     = cmd2eptd_wrReq     ;
            rden_EA[25]     = 1'b1     ;
         end
         EPT25_CR1 :  begin
            wren_CR1[25]    = cmd2eptd_wrReq     ;
            rden_CR1[25]    = 1'b1     ;
         end
         EPT25_CR2 :  begin
            wren_CR2[25]    = cmd2eptd_wrReq     ;
            rden_CR2[25]    = 1'b1     ;
         end
         EPT25_WPTR :  begin
            wren_wPtr[25]   = cmd2eptd_wrReq     ;
            rden_wPtr[25]   = 1'b1     ;
         end 
         EPT25_RPTR :  begin
            wren_rPtr[25]   = cmd2eptd_wrReq     ;
            rden_rPtr[25]   = 1'b1     ;
         end
         EPT25_ARPTR :  begin
            wren_arPtr[9]   = cmd2eptd_wrReq     ;
            rden_arPtr[9]   = 1'b1     ;
         end
         EPT25_STAT :  begin
            wren_stat[25]   = cmd2eptd_wrReq     ;
            rden_stat[25]   = 1'b1     ;
         end
      // endpoint 26
         EPT26_SA :  begin
            wren_SA[26]     = cmd2eptd_wrReq     ;
            rden_SA[26]     = 1'b1     ;
         end
         EPT26_EA :  begin
            wren_EA[26]     = cmd2eptd_wrReq     ;
            rden_EA[26]     = 1'b1     ;
         end
         EPT26_CR1 :  begin
            wren_CR1[26]    = cmd2eptd_wrReq     ;
            rden_CR1[26]    = 1'b1     ;
         end
         EPT26_CR2 :  begin
            wren_CR2[26]    = cmd2eptd_wrReq     ;
            rden_CR2[26]    = 1'b1     ;
         end
         EPT26_WPTR :  begin
            wren_wPtr[26]   = cmd2eptd_wrReq     ;
            rden_wPtr[26]   = 1'b1     ;
         end 
         EPT26_RPTR :  begin
            wren_rPtr[26]   = cmd2eptd_wrReq     ;
            rden_rPtr[26]   = 1'b1     ;
         end
         EPT26_ARPTR :  begin
            wren_arPtr[10]  = cmd2eptd_wrReq     ;
            rden_arPtr[10]  = 1'b1     ;
         end
         EPT26_STAT :  begin
            wren_stat[26]   = cmd2eptd_wrReq     ;
            rden_stat[26]   = 1'b1     ;
         end
      // endpoint 27
         EPT27_SA :  begin
            wren_SA[27]     = cmd2eptd_wrReq     ;
            rden_SA[27]     = 1'b1     ;
         end
         EPT27_EA :  begin
            wren_EA[27]     = cmd2eptd_wrReq     ;
            rden_EA[27]     = 1'b1     ;
         end
         EPT27_CR1 :  begin
            wren_CR1[27]    = cmd2eptd_wrReq     ;
            rden_CR1[27]    = 1'b1     ;
         end
         EPT27_CR2 :  begin
            wren_CR2[27]    = cmd2eptd_wrReq     ;
            rden_CR2[27]    = 1'b1     ;
         end
         EPT27_WPTR :  begin
            wren_wPtr[27]   = cmd2eptd_wrReq     ;
            rden_wPtr[27]   = 1'b1     ;
         end 
         EPT27_RPTR :  begin
            wren_rPtr[27]   = cmd2eptd_wrReq     ;
            rden_rPtr[27]   = 1'b1     ;
         end
         EPT27_ARPTR :  begin
            wren_arPtr[11]  = cmd2eptd_wrReq     ;
            rden_arPtr[11]  = 1'b1     ;
         end
         EPT27_STAT :  begin
            wren_stat[27]   = cmd2eptd_wrReq     ;
            rden_stat[27]   = 1'b1     ;
         end
      // endpoint 28
         EPT28_SA :  begin
            wren_SA[28]     = cmd2eptd_wrReq     ;
            rden_SA[28]     = 1'b1     ;
         end
         EPT28_EA :  begin
            wren_EA[28]     = cmd2eptd_wrReq     ;
            rden_EA[28]     = 1'b1     ;
         end
         EPT28_CR1 :  begin
            wren_CR1[28]    = cmd2eptd_wrReq     ;
            rden_CR1[28]    = 1'b1     ;
         end
         EPT28_CR2 :  begin
            wren_CR2[28]    = cmd2eptd_wrReq     ;
            rden_CR2[28]    = 1'b1     ;
         end
         EPT28_WPTR :  begin
            wren_wPtr[28]   = cmd2eptd_wrReq     ;
            rden_wPtr[28]   = 1'b1     ;
         end 
         EPT28_RPTR :  begin
            wren_rPtr[28]   = cmd2eptd_wrReq     ;
            rden_rPtr[28]   = 1'b1     ;
         end
         EPT28_ARPTR :  begin
            wren_arPtr[12]  = cmd2eptd_wrReq     ;
            rden_arPtr[12]  = 1'b1     ;
         end
         EPT28_STAT :  begin
            wren_stat[28]   = cmd2eptd_wrReq     ;
            rden_stat[28]   = 1'b1     ;
         end
      // endpoint 29
         EPT29_SA :  begin
            wren_SA[29]     = cmd2eptd_wrReq     ;
            rden_SA[29]     = 1'b1     ;
         end
         EPT29_EA :  begin
            wren_EA[29]     = cmd2eptd_wrReq     ;
            rden_EA[29]     = 1'b1     ;
         end
         EPT29_CR1 :  begin
            wren_CR1[29]    = cmd2eptd_wrReq     ;
            rden_CR1[29]    = 1'b1     ;
         end
         EPT29_CR2 :  begin
            wren_CR2[29]    = cmd2eptd_wrReq     ;
            rden_CR2[29]    = 1'b1     ;
         end
         EPT29_WPTR :  begin
            wren_wPtr[29]   = cmd2eptd_wrReq     ;
            rden_wPtr[29]   = 1'b1     ;
         end 
         EPT29_RPTR :  begin
            wren_rPtr[29]   = cmd2eptd_wrReq     ;
            rden_rPtr[29]   = 1'b1     ;
         end
         EPT29_ARPTR :  begin
            wren_arPtr[13]  = cmd2eptd_wrReq     ;
            rden_arPtr[13]  = 1'b1     ;
         end
         EPT29_STAT :  begin
            wren_stat[29]   = cmd2eptd_wrReq     ;
            rden_stat[29]   = 1'b1     ;
         end
      // endpoint 30         
         EPT30_SA :  begin
            wren_SA[30]     = cmd2eptd_wrReq     ;
            rden_SA[30]     = 1'b1     ;
         end
         EPT30_EA :  begin
            wren_EA[30]     = cmd2eptd_wrReq     ;
            rden_EA[30]     = 1'b1     ;
         end
         EPT30_CR1 :  begin
            wren_CR1[30]    = cmd2eptd_wrReq     ;
            rden_CR1[30]    = 1'b1     ;
         end
         EPT30_CR2 :  begin
            wren_CR2[30]    = cmd2eptd_wrReq     ;
            rden_CR2[30]    = 1'b1     ;
         end
         EPT30_WPTR :  begin
            wren_wPtr[30]   = cmd2eptd_wrReq     ;
            rden_wPtr[30]   = 1'b1     ;
         end 
         EPT30_RPTR :  begin
            wren_rPtr[30]   = cmd2eptd_wrReq     ;
            rden_rPtr[30]   = 1'b1     ;
         end
         EPT30_ARPTR :  begin
            wren_arPtr[14]  = cmd2eptd_wrReq     ;
            rden_arPtr[14]  = 1'b1     ;
         end
         EPT30_STAT :  begin
            wren_stat[30]   = cmd2eptd_wrReq     ;
            rden_stat[30]   = 1'b1     ;
         end
      // endpoint 31
         EPT31_SA :  begin
            wren_SA[31]     = cmd2eptd_wrReq     ;
            rden_SA[31]     = 1'b1     ;
         end
         EPT31_EA :  begin
            wren_EA[31]     = cmd2eptd_wrReq     ;
            rden_EA[31]     = 1'b1     ;
         end
         EPT31_CR1 :  begin
            wren_CR1[31]    = cmd2eptd_wrReq     ;
            rden_CR1[31]    = 1'b1     ;
         end
         EPT31_CR2 :  begin
            wren_CR2[31]    = cmd2eptd_wrReq     ;
            rden_CR2[31]    = 1'b1     ;
         end
         EPT31_WPTR :  begin
            wren_wPtr[31]   = cmd2eptd_wrReq     ;
            rden_wPtr[31]   = 1'b1     ;
         end 
         EPT31_RPTR :  begin
            wren_rPtr[31]   = cmd2eptd_wrReq     ;
            rden_rPtr[31]   = 1'b1     ;
         end
         EPT31_ARPTR :  begin
            wren_arPtr[15]  = cmd2eptd_wrReq     ;
            rden_arPtr[15]  = 1'b1     ;
         end
         EPT31_STAT :  begin
            wren_stat[31]   = cmd2eptd_wrReq     ;
            rden_stat[31]   = 1'b1     ;
         end
         EPT0_FULLBUFCNT :  begin
            wren_fullPktCnt[0]    = cmd2eptd_wrReq     ;
            rden_fullPktCnt[0]    = 1'b1      ;
         end
         EPT1_FULLBUFCNT :  begin
            wren_fullPktCnt[1]    = cmd2eptd_wrReq     ;
            rden_fullPktCnt[1]    = 1'b1      ;
         end
         EPT2_FULLBUFCNT :  begin
            wren_fullPktCnt[2]    = cmd2eptd_wrReq     ;
            rden_fullPktCnt[2]    = 1'b1      ;
         end
         EPT3_FULLBUFCNT :  begin
            wren_fullPktCnt[3]    = cmd2eptd_wrReq     ;
            rden_fullPktCnt[3]    = 1'b1      ;
         end
         EPT4_FULLBUFCNT :  begin
            wren_fullPktCnt[4]    = cmd2eptd_wrReq     ;
            rden_fullPktCnt[4]    = 1'b1      ;
         end
         EPT5_FULLBUFCNT :  begin
            wren_fullPktCnt[5]    = cmd2eptd_wrReq     ;
            rden_fullPktCnt[5]    = 1'b1      ;
         end
         EPT6_FULLBUFCNT :  begin
            wren_fullPktCnt[6]    = cmd2eptd_wrReq     ;
            rden_fullPktCnt[6]    = 1'b1      ;
         end
         EPT7_FULLBUFCNT :  begin
            wren_fullPktCnt[7]    = cmd2eptd_wrReq     ;
            rden_fullPktCnt[7]    = 1'b1      ;
         end
         EPT8_FULLBUFCNT :  begin
            wren_fullPktCnt[8]    = cmd2eptd_wrReq     ;
            rden_fullPktCnt[8]    = 1'b1      ;
         end
         EPT9_FULLBUFCNT :  begin
            wren_fullPktCnt[9]    = cmd2eptd_wrReq     ;
            rden_fullPktCnt[9]    = 1'b1      ;
         end
         EPT10_FULLBUFCNT :  begin
            wren_fullPktCnt[10]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[10]    = 1'b1     ;
         end
         EPT11_FULLBUFCNT :  begin
            wren_fullPktCnt[11]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[11]    = 1'b1     ;
         end
         EPT12_FULLBUFCNT :  begin
            wren_fullPktCnt[12]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[12]    = 1'b1     ;
         end
         EPT13_FULLBUFCNT :  begin
            wren_fullPktCnt[13]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[13]    = 1'b1     ;
         end
         EPT14_FULLBUFCNT :  begin
            wren_fullPktCnt[14]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[14]    = 1'b1     ;
         end
         EPT15_FULLBUFCNT :  begin
            wren_fullPktCnt[15]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[15]    = 1'b1     ;
         end
         EPT16_FULLBUFCNT :  begin
            wren_fullPktCnt[16]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[16]    = 1'b1     ;
         end
         EPT17_FULLBUFCNT :  begin
            wren_fullPktCnt[17]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[17]    = 1'b1     ;
         end
         EPT18_FULLBUFCNT :  begin
            wren_fullPktCnt[18]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[18]    = 1'b1     ;
         end
         EPT19_FULLBUFCNT :  begin
            wren_fullPktCnt[19]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[19]    = 1'b1     ;
         end
         EPT20_FULLBUFCNT :  begin
            wren_fullPktCnt[20]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[20]    = 1'b1     ;
         end
         EPT21_FULLBUFCNT :  begin
            wren_fullPktCnt[21]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[21]    = 1'b1     ;
         end
         EPT22_FULLBUFCNT :  begin
            wren_fullPktCnt[22]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[22]    = 1'b1     ;
         end
         EPT23_FULLBUFCNT :  begin
            wren_fullPktCnt[23]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[23]    = 1'b1     ;
         end
         EPT24_FULLBUFCNT :  begin
            wren_fullPktCnt[24]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[24]    = 1'b1     ;
         end
         EPT25_FULLBUFCNT :  begin
            wren_fullPktCnt[25]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[25]    = 1'b1     ;
         end
         EPT26_FULLBUFCNT :  begin
            wren_fullPktCnt[26]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[26]    = 1'b1     ;
         end
         EPT27_FULLBUFCNT :  begin
            wren_fullPktCnt[27]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[27]    = 1'b1     ;
         end
         EPT28_FULLBUFCNT :  begin
            wren_fullPktCnt[28]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[28]    = 1'b1     ;
         end
         EPT29_FULLBUFCNT :  begin
            wren_fullPktCnt[29]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[29]    = 1'b1     ;
         end
         EPT30_FULLBUFCNT :  begin
            wren_fullPktCnt[30]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[30]    = 1'b1     ;
         end
         EPT31_FULLBUFCNT :  begin
            wren_fullPktCnt[31]    = cmd2eptd_wrReq    ;
            rden_fullPktCnt[31]    = 1'b1     ;
         end

         default :  begin
         wren_EA     = 32'h00000                 ;
         wren_CR1    = 32'h00000                 ;
         wren_CR2    = 32'h00000                 ;
         wren_wPtr   = 32'h00000                 ;
         wren_rPtr   = 32'h00000                 ;
         wren_arPtr  = 16'h0000                  ;
         wren_stat   = 32'h00000                 ;
         wren_fullPktCnt = 32'h00000             ;

         rden_SA     = 32'h00000                 ;
         rden_EA     = 32'h00000                 ;
         rden_CR1    = 32'h00000                 ;
         rden_CR2    = 32'h00000                 ;
         rden_wPtr   = 32'h00000                 ;
         rden_rPtr   = 32'h00000                 ;
         rden_arPtr  = 16'h0000                  ;
         rden_stat   = 32'h00000                 ;
         rden_fullPktCnt = 32'h00000                 ;
         end
      endcase
   end

   // --------------------------------------------------
   // Start Address registers
   // --------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         ept_SA[0]   <= {32{1'b0}} ;
         ept_SA[1]   <= {32{1'b0}} ;
         ept_SA[2]   <= {32{1'b0}} ;
         ept_SA[3]   <= {32{1'b0}} ;
         ept_SA[4]   <= {32{1'b0}} ;
         ept_SA[5]   <= {32{1'b0}} ;
         ept_SA[6]   <= {32{1'b0}} ;
         ept_SA[7]   <= {32{1'b0}} ;
         ept_SA[8]   <= {32{1'b0}} ;
         ept_SA[9]   <= {32{1'b0}} ;
         ept_SA[10]  <= {32{1'b0}} ;
         ept_SA[11]  <= {32{1'b0}} ;
         ept_SA[12]  <= {32{1'b0}} ;
         ept_SA[13]  <= {32{1'b0}} ;
         ept_SA[14]  <= {32{1'b0}} ;
         ept_SA[15]  <= {32{1'b0}} ;
         ept_SA[16]  <= {32{1'b0}} ;
         ept_SA[17]  <= {32{1'b0}} ;
         ept_SA[18]  <= {32{1'b0}} ;
         ept_SA[19]  <= {32{1'b0}} ;
         ept_SA[20]  <= {32{1'b0}} ;
         ept_SA[21]  <= {32{1'b0}} ;
         ept_SA[22]  <= {32{1'b0}} ;
         ept_SA[23]  <= {32{1'b0}} ;
         ept_SA[24]  <= {32{1'b0}} ;
         ept_SA[25]  <= {32{1'b0}} ;
         ept_SA[26]  <= {32{1'b0}} ;
         ept_SA[27]  <= {32{1'b0}} ;
         ept_SA[28]  <= {32{1'b0}} ;
         ept_SA[29]  <= {32{1'b0}} ;
         ept_SA[30]  <= {32{1'b0}} ;
         ept_SA[31]  <= {32{1'b0}} ; 
      end
      else if(sw_rst == 1'b1)begin
         ept_SA[0]   <= {32{1'b0}} ;
         ept_SA[1]   <= {32{1'b0}} ;
         ept_SA[2]   <= {32{1'b0}} ;
         ept_SA[3]   <= {32{1'b0}} ;
         ept_SA[4]   <= {32{1'b0}} ;
         ept_SA[5]   <= {32{1'b0}} ;
         ept_SA[6]   <= {32{1'b0}} ;
         ept_SA[7]   <= {32{1'b0}} ;
         ept_SA[8]   <= {32{1'b0}} ;
         ept_SA[9]   <= {32{1'b0}} ;
         ept_SA[10]  <= {32{1'b0}} ;
         ept_SA[11]  <= {32{1'b0}} ;
         ept_SA[12]  <= {32{1'b0}} ;
         ept_SA[13]  <= {32{1'b0}} ;
         ept_SA[14]  <= {32{1'b0}} ;
         ept_SA[15]  <= {32{1'b0}} ;
         ept_SA[16]  <= {32{1'b0}} ;
         ept_SA[17]  <= {32{1'b0}} ;
         ept_SA[18]  <= {32{1'b0}} ;
         ept_SA[19]  <= {32{1'b0}} ;
         ept_SA[20]  <= {32{1'b0}} ;
         ept_SA[21]  <= {32{1'b0}} ;
         ept_SA[22]  <= {32{1'b0}} ;
         ept_SA[23]  <= {32{1'b0}} ;
         ept_SA[24]  <= {32{1'b0}} ;
         ept_SA[25]  <= {32{1'b0}} ;
         ept_SA[26]  <= {32{1'b0}} ;
         ept_SA[27]  <= {32{1'b0}} ;
         ept_SA[28]  <= {32{1'b0}} ;
         ept_SA[29]  <= {32{1'b0}} ;
         ept_SA[30]  <= {32{1'b0}} ;
         ept_SA[31]  <= {32{1'b0}} ; 
      end
      else begin
         if(wren_SA[0] == 1'b1)begin
            ept_SA[0]      <= cmd2eptd_wrData;
         end
         if(wren_SA[1] == 1'b1)begin
            ept_SA[1]      <= cmd2eptd_wrData;
         end
         if(wren_SA[2] == 1'b1)begin
            ept_SA[2]      <= cmd2eptd_wrData;
         end
         if(wren_SA[3] == 1'b1)begin
            ept_SA[3]      <= cmd2eptd_wrData;
         end
         if(wren_SA[4] == 1'b1)begin
            ept_SA[4]      <= cmd2eptd_wrData;
         end
         if(wren_SA[5] == 1'b1)begin
            ept_SA[5]      <= cmd2eptd_wrData;
         end
         if(wren_SA[6] == 1'b1)begin
            ept_SA[6]      <= cmd2eptd_wrData;
         end
         if(wren_SA[7] == 1'b1)begin
            ept_SA[7]      <= cmd2eptd_wrData;
         end
         if(wren_SA[8] == 1'b1)begin
            ept_SA[8]      <= cmd2eptd_wrData;
         end
         if(wren_SA[9] == 1'b1)begin
            ept_SA[9]      <= cmd2eptd_wrData;
         end
         if(wren_SA[10] == 1'b1)begin
            ept_SA[10]      <= cmd2eptd_wrData;
         end
         if(wren_SA[11] == 1'b1)begin
            ept_SA[11]      <= cmd2eptd_wrData;
         end
         if(wren_SA[12] == 1'b1)begin
            ept_SA[12]      <= cmd2eptd_wrData;
         end
         if(wren_SA[13] == 1'b1)begin
            ept_SA[13]      <= cmd2eptd_wrData;
         end
         if(wren_SA[14] == 1'b1)begin
            ept_SA[14]      <= cmd2eptd_wrData;
         end
         if(wren_SA[15] == 1'b1)begin
            ept_SA[15]      <= cmd2eptd_wrData;
         end
         if(wren_SA[16] == 1'b1)begin
            ept_SA[16]      <= cmd2eptd_wrData;
         end
         if(wren_SA[17] == 1'b1)begin
            ept_SA[17]      <= cmd2eptd_wrData;
         end
         if(wren_SA[18] == 1'b1)begin
            ept_SA[18]      <= cmd2eptd_wrData;
         end
         if(wren_SA[19] == 1'b1)begin
            ept_SA[19]      <= cmd2eptd_wrData;
         end
         if(wren_SA[20] == 1'b1)begin
            ept_SA[20]      <= cmd2eptd_wrData;
         end
         if(wren_SA[21] == 1'b1)begin
            ept_SA[21]      <= cmd2eptd_wrData;
         end
         if(wren_SA[22] == 1'b1)begin
            ept_SA[22]      <= cmd2eptd_wrData;
         end
         if(wren_SA[23] == 1'b1)begin
            ept_SA[23]      <= cmd2eptd_wrData;
         end
         if(wren_SA[24] == 1'b1)begin
            ept_SA[24]      <= cmd2eptd_wrData;
         end
         if(wren_SA[25] == 1'b1)begin
            ept_SA[25]      <= cmd2eptd_wrData;
         end
         if(wren_SA[26] == 1'b1)begin
            ept_SA[26]      <= cmd2eptd_wrData;
         end
         if(wren_SA[27] == 1'b1)begin
            ept_SA[27]      <= cmd2eptd_wrData;
         end
         if(wren_SA[28] == 1'b1)begin
            ept_SA[28]      <= cmd2eptd_wrData;
         end
         if(wren_SA[29] == 1'b1)begin
            ept_SA[29]      <= cmd2eptd_wrData;
         end
         if(wren_SA[30] == 1'b1)begin
            ept_SA[30]      <= cmd2eptd_wrData;
         end
         if(wren_SA[31] == 1'b1)begin
            ept_SA[31]      <= cmd2eptd_wrData;
         end
      end
   end

   // --------------------------------------------------
   // End address register
   // --------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         ept_EA[0]   <= {32{1'b0}} ;
         ept_EA[1]   <= {32{1'b0}} ;
         ept_EA[2]   <= {32{1'b0}} ;
         ept_EA[3]   <= {32{1'b0}} ;
         ept_EA[4]   <= {32{1'b0}} ;
         ept_EA[5]   <= {32{1'b0}} ;
         ept_EA[6]   <= {32{1'b0}} ;
         ept_EA[7]   <= {32{1'b0}} ;
         ept_EA[8]   <= {32{1'b0}} ;
         ept_EA[9]   <= {32{1'b0}} ;
         ept_EA[10]  <= {32{1'b0}} ;
         ept_EA[11]  <= {32{1'b0}} ;
         ept_EA[12]  <= {32{1'b0}} ;
         ept_EA[13]  <= {32{1'b0}} ;
         ept_EA[14]  <= {32{1'b0}} ;
         ept_EA[15]  <= {32{1'b0}} ;
         ept_EA[16]  <= {32{1'b0}} ;
         ept_EA[17]  <= {32{1'b0}} ;
         ept_EA[18]  <= {32{1'b0}} ;
         ept_EA[19]  <= {32{1'b0}} ;
         ept_EA[20]  <= {32{1'b0}} ;
         ept_EA[21]  <= {32{1'b0}} ;
         ept_EA[22]  <= {32{1'b0}} ;
         ept_EA[23]  <= {32{1'b0}} ;
         ept_EA[24]  <= {32{1'b0}} ;
         ept_EA[25]  <= {32{1'b0}} ;
         ept_EA[26]  <= {32{1'b0}} ;
         ept_EA[27]  <= {32{1'b0}} ;
         ept_EA[28]  <= {32{1'b0}} ;
         ept_EA[29]  <= {32{1'b0}} ;
         ept_EA[30]  <= {32{1'b0}} ;
         ept_EA[31]  <= {32{1'b0}} ; 
      end
      else if(sw_rst == 1'b1)begin
         ept_EA[0]   <= {32{1'b0}} ;
         ept_EA[1]   <= {32{1'b0}} ;
         ept_EA[2]   <= {32{1'b0}} ;
         ept_EA[3]   <= {32{1'b0}} ;
         ept_EA[4]   <= {32{1'b0}} ;
         ept_EA[5]   <= {32{1'b0}} ;
         ept_EA[6]   <= {32{1'b0}} ;
         ept_EA[7]   <= {32{1'b0}} ;
         ept_EA[8]   <= {32{1'b0}} ;
         ept_EA[9]   <= {32{1'b0}} ;
         ept_EA[10]  <= {32{1'b0}} ;
         ept_EA[11]  <= {32{1'b0}} ;
         ept_EA[12]  <= {32{1'b0}} ;
         ept_EA[13]  <= {32{1'b0}} ;
         ept_EA[14]  <= {32{1'b0}} ;
         ept_EA[15]  <= {32{1'b0}} ;
         ept_EA[16]  <= {32{1'b0}} ;
         ept_EA[17]  <= {32{1'b0}} ;
         ept_EA[18]  <= {32{1'b0}} ;
         ept_EA[19]  <= {32{1'b0}} ;
         ept_EA[20]  <= {32{1'b0}} ;
         ept_EA[21]  <= {32{1'b0}} ;
         ept_EA[22]  <= {32{1'b0}} ;
         ept_EA[23]  <= {32{1'b0}} ;
         ept_EA[24]  <= {32{1'b0}} ;
         ept_EA[25]  <= {32{1'b0}} ;
         ept_EA[26]  <= {32{1'b0}} ;
         ept_EA[27]  <= {32{1'b0}} ;
         ept_EA[28]  <= {32{1'b0}} ;
         ept_EA[29]  <= {32{1'b0}} ;
         ept_EA[30]  <= {32{1'b0}} ;
         ept_EA[31]  <= {32{1'b0}} ; 
      end
      else begin
         if(wren_EA[0] == 1'b1)begin
            ept_EA[0]      <= cmd2eptd_wrData;
         end
         if(wren_EA[1] == 1'b1)begin
            ept_EA[1]      <= cmd2eptd_wrData;
         end
         if(wren_EA[2] == 1'b1)begin
            ept_EA[2]      <= cmd2eptd_wrData;
         end
         if(wren_EA[3] == 1'b1)begin
            ept_EA[3]      <= cmd2eptd_wrData;
         end
         if(wren_EA[4] == 1'b1)begin
            ept_EA[4]      <= cmd2eptd_wrData;
         end
         if(wren_EA[5] == 1'b1)begin
            ept_EA[5]      <= cmd2eptd_wrData;
         end
         if(wren_EA[6] == 1'b1)begin
            ept_EA[6]      <= cmd2eptd_wrData;
         end
         if(wren_EA[7] == 1'b1)begin
            ept_EA[7]      <= cmd2eptd_wrData;
         end
         if(wren_EA[8] == 1'b1)begin
            ept_EA[8]      <= cmd2eptd_wrData;
         end
         if(wren_EA[9] == 1'b1)begin
            ept_EA[9]      <= cmd2eptd_wrData;
         end
         if(wren_EA[10] == 1'b1)begin
            ept_EA[10]      <= cmd2eptd_wrData;
         end
         if(wren_EA[11] == 1'b1)begin
            ept_EA[11]      <= cmd2eptd_wrData;
         end
         if(wren_EA[12] == 1'b1)begin
            ept_EA[12]      <= cmd2eptd_wrData;
         end
         if(wren_EA[13] == 1'b1)begin
            ept_EA[13]      <= cmd2eptd_wrData;
         end
         if(wren_EA[14] == 1'b1)begin
            ept_EA[14]      <= cmd2eptd_wrData;
         end
         if(wren_EA[15] == 1'b1)begin
            ept_EA[15]      <= cmd2eptd_wrData;
         end
         if(wren_EA[16] == 1'b1)begin
            ept_EA[16]      <= cmd2eptd_wrData;
         end
         if(wren_EA[17] == 1'b1)begin
            ept_EA[17]      <= cmd2eptd_wrData;
         end
         if(wren_EA[18] == 1'b1)begin
            ept_EA[18]      <= cmd2eptd_wrData;
         end
         if(wren_EA[19] == 1'b1)begin
            ept_EA[19]      <= cmd2eptd_wrData;
         end
         if(wren_EA[20] == 1'b1)begin
            ept_EA[20]      <= cmd2eptd_wrData;
         end
         if(wren_EA[21] == 1'b1)begin
            ept_EA[21]      <= cmd2eptd_wrData;
         end
         if(wren_EA[22] == 1'b1)begin
            ept_EA[22]      <= cmd2eptd_wrData;
         end
         if(wren_EA[23] == 1'b1)begin
            ept_EA[23]      <= cmd2eptd_wrData;
         end
         if(wren_EA[24] == 1'b1)begin
            ept_EA[24]      <= cmd2eptd_wrData;
         end
         if(wren_EA[25] == 1'b1)begin
            ept_EA[25]      <= cmd2eptd_wrData;
         end
         if(wren_EA[26] == 1'b1)begin
            ept_EA[26]      <= cmd2eptd_wrData;
         end
         if(wren_EA[27] == 1'b1)begin
            ept_EA[27]      <= cmd2eptd_wrData;
         end
         if(wren_EA[28] == 1'b1)begin
            ept_EA[28]      <= cmd2eptd_wrData;
         end
         if(wren_EA[29] == 1'b1)begin
            ept_EA[29]      <= cmd2eptd_wrData;
         end
         if(wren_EA[30] == 1'b1)begin
            ept_EA[30]      <= cmd2eptd_wrData;
         end
         if(wren_EA[31] == 1'b1)begin
            ept_EA[31]      <= cmd2eptd_wrData;
         end
      end
   end

   // --------------------------------------------------
   // Control register 1
   // --------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         ept_CR1[0]   <= {32{1'b0}} ;
         ept_CR1[1]   <= {32{1'b0}} ;
         ept_CR1[2]   <= {32{1'b0}} ;
         ept_CR1[3]   <= {32{1'b0}} ;
         ept_CR1[4]   <= {32{1'b0}} ;
         ept_CR1[5]   <= {32{1'b0}} ;
         ept_CR1[6]   <= {32{1'b0}} ;
         ept_CR1[7]   <= {32{1'b0}} ;
         ept_CR1[8]   <= {32{1'b0}} ;
         ept_CR1[9]   <= {32{1'b0}} ;
         ept_CR1[10]  <= {32{1'b0}} ;
         ept_CR1[11]  <= {32{1'b0}} ;
         ept_CR1[12]  <= {32{1'b0}} ;
         ept_CR1[13]  <= {32{1'b0}} ;
         ept_CR1[14]  <= {32{1'b0}} ;
         ept_CR1[15]  <= {32{1'b0}} ;
         ept_CR1[16]  <= {32{1'b0}} ;
         ept_CR1[17]  <= {32{1'b0}} ;
         ept_CR1[18]  <= {32{1'b0}} ;
         ept_CR1[19]  <= {32{1'b0}} ;
         ept_CR1[20]  <= {32{1'b0}} ;
         ept_CR1[21]  <= {32{1'b0}} ;
         ept_CR1[22]  <= {32{1'b0}} ;
         ept_CR1[23]  <= {32{1'b0}} ;
         ept_CR1[24]  <= {32{1'b0}} ;
         ept_CR1[25]  <= {32{1'b0}} ;
         ept_CR1[26]  <= {32{1'b0}} ;
         ept_CR1[27]  <= {32{1'b0}} ;
         ept_CR1[28]  <= {32{1'b0}} ;
         ept_CR1[29]  <= {32{1'b0}} ;
         ept_CR1[30]  <= {32{1'b0}} ;
         ept_CR1[31]  <= {32{1'b0}} ;
      end
      else if(sw_rst == 1'b1)begin
         ept_CR1[0]   <= {32{1'b0}} ;
         ept_CR1[1]   <= {32{1'b0}} ;
         ept_CR1[2]   <= {32{1'b0}} ;
         ept_CR1[3]   <= {32{1'b0}} ;
         ept_CR1[4]   <= {32{1'b0}} ;
         ept_CR1[5]   <= {32{1'b0}} ;
         ept_CR1[6]   <= {32{1'b0}} ;
         ept_CR1[7]   <= {32{1'b0}} ;
         ept_CR1[8]   <= {32{1'b0}} ;
         ept_CR1[9]   <= {32{1'b0}} ;
         ept_CR1[10]  <= {32{1'b0}} ;
         ept_CR1[11]  <= {32{1'b0}} ;
         ept_CR1[12]  <= {32{1'b0}} ;
         ept_CR1[13]  <= {32{1'b0}} ;
         ept_CR1[14]  <= {32{1'b0}} ;
         ept_CR1[15]  <= {32{1'b0}} ;
         ept_CR1[16]  <= {32{1'b0}} ;
         ept_CR1[17]  <= {32{1'b0}} ;
         ept_CR1[18]  <= {32{1'b0}} ;
         ept_CR1[19]  <= {32{1'b0}} ;
         ept_CR1[20]  <= {32{1'b0}} ;
         ept_CR1[21]  <= {32{1'b0}} ;
         ept_CR1[22]  <= {32{1'b0}} ;
         ept_CR1[23]  <= {32{1'b0}} ;
         ept_CR1[24]  <= {32{1'b0}} ;
         ept_CR1[25]  <= {32{1'b0}} ;
         ept_CR1[26]  <= {32{1'b0}} ;
         ept_CR1[27]  <= {32{1'b0}} ;
         ept_CR1[28]  <= {32{1'b0}} ;
         ept_CR1[29]  <= {32{1'b0}} ;
         ept_CR1[30]  <= {32{1'b0}} ;
         ept_CR1[31]  <= {32{1'b0}} ;
      end
      else begin
         if(wren_CR1[0] == 1'b1)begin
            ept_CR1[0]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[1] == 1'b1)begin
            ept_CR1[1]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[2] == 1'b1)begin
            ept_CR1[2]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[3] == 1'b1)begin
            ept_CR1[3]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[4] == 1'b1)begin
            ept_CR1[4]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[5] == 1'b1)begin
            ept_CR1[5]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[6] == 1'b1)begin
            ept_CR1[6]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[7] == 1'b1)begin
            ept_CR1[7]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[8] == 1'b1)begin
            ept_CR1[8]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[9] == 1'b1)begin
            ept_CR1[9]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[10] == 1'b1)begin
            ept_CR1[10]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[11] == 1'b1)begin
            ept_CR1[11]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[12] == 1'b1)begin
            ept_CR1[12]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[13] == 1'b1)begin
            ept_CR1[13]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[14] == 1'b1)begin
            ept_CR1[14]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[15] == 1'b1)begin
            ept_CR1[15]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[16] == 1'b1)begin
            ept_CR1[16]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[17] == 1'b1)begin
            ept_CR1[17]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[18] == 1'b1)begin
            ept_CR1[18]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[19] == 1'b1)begin
            ept_CR1[19]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[20] == 1'b1)begin
            ept_CR1[20]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[21] == 1'b1)begin
            ept_CR1[21]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[22] == 1'b1)begin
            ept_CR1[22]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[23] == 1'b1)begin
            ept_CR1[23]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[24] == 1'b1)begin
            ept_CR1[24]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[25] == 1'b1)begin
            ept_CR1[25]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[26] == 1'b1)begin
            ept_CR1[26]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[27] == 1'b1)begin
            ept_CR1[27]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[28] == 1'b1)begin
            ept_CR1[28]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[29] == 1'b1)begin
            ept_CR1[29]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[30] == 1'b1)begin
            ept_CR1[30]      <= cmd2eptd_wrData;
         end
         if(wren_CR1[31] == 1'b1)begin
            ept_CR1[31]      <= cmd2eptd_wrData;
         end

         if(epcrUpdt == 1'b1)begin
            ept_CR1[{1'b0,epcr2eptd_epNum}]  <={ept_CR1[{1'b0,epcr2eptd_epNum}][31:30],
                                                lastOp[{1'b0,epcr2eptd_epNum}],
                                                epcr2eptd_nxtDataPid[3:2],
                                                ept_CR1[{1'b0,epcr2eptd_epNum}][26:0]};
         end

         if(epctUpdt == 1'b1)begin
            ept_CR1[{1'b1,epct2eptd_epNum}]  <={ept_CR1[{1'b1,epct2eptd_epNum}][31:30], 
                                                lastOp[{1'b1,epct2eptd_epNum}],
                                                epct2eptd_nxtExpDataPid[3:2], 
                                                ept_CR1[{1'b1,epct2eptd_epNum}][26:0]};
         end

         if(septUpdt == 1'b1)begin
            ept_CR1[{1'b1,sept2eptd_epNum}]  <={ept_CR1[{1'b1,sept2eptd_epNum}][31:30], 
                                                lastOp[{1'b1,sept2eptd_epNum}],
                                                ept_CR1[{1'b1,sept2eptd_epNum}][28:0]};
         end

         if(seprUpdt == 1'b1)begin
            ept_CR1[{1'b0,sepr2eptd_epNum}]  <={ept_CR1[{1'b0,sepr2eptd_epNum}][31:30], 
                                                lastOp[{1'b0,sepr2eptd_epNum}],
                                                ept_CR1[{1'b0,sepr2eptd_epNum}][28:0]};
         end

         if(epcr2eptd_setEphalt) begin 
            ept_CR1[{1'b0,epcr2eptd_epNum}]  <={1'b1,ept_CR1[{1'b0,epcr2eptd_epNum}][30:00]};
         // ept_CR1[{1'b1,epcr2eptd_epNum}]  <={1'b1,ept_CR1[{1'b1,epcr2eptd_epNum}][30:00]};
         end

         if(pe2eptd_intPid)begin
            ept_CR1[{1'b0,epcr2eptd_epNum}]  <={ept_CR1[{1'b0,epcr2eptd_epNum}][31:29],
                                                2'b10,
                                                ept_CR1[{1'b0,epcr2eptd_epNum}][26:0]};
            ept_CR1[{1'b1,epct2eptd_epNum}]  <={ept_CR1[{1'b1,epct2eptd_epNum}][31:29], 
                                                2'b10, 
                                                ept_CR1[{1'b1,epct2eptd_epNum}][26:0]};
         end
         if(pe2eptd_initIsoPid)begin
            if((ept_CR1[0][26:25] >= 2'b01  ) && (ept_CR1[0][2:1] == 2'b01))begin
               ept_CR1[0][28:27]             <= 2'b11;
            end
            if((ept_CR1[1][26:25] >= 2'b01  ) && (ept_CR1[1][2:1] == 2'b01))begin
               ept_CR1[1][28:27]             <= 2'b11;
            end
            if((ept_CR1[2][26:25] >= 2'b01  ) && (ept_CR1[2][2:1] == 2'b01))begin
               ept_CR1[2][28:27]             <= 2'b11;
            end
            if((ept_CR1[3][26:25] >= 2'b01  ) && (ept_CR1[3][2:1] == 2'b01))begin
               ept_CR1[3][28:27]             <= 2'b11;
            end
            if((ept_CR1[4][26:25] >= 2'b01  ) && (ept_CR1[4][2:1] == 2'b01))begin
               ept_CR1[4][28:27]             <= 2'b11;
            end
            if((ept_CR1[5][26:25] >= 2'b01  ) && (ept_CR1[5][2:1] == 2'b01))begin
               ept_CR1[5][28:27]             <= 2'b11;
            end
            if((ept_CR1[6][26:25] >= 2'b01  ) && (ept_CR1[6][2:1] == 2'b01))begin
               ept_CR1[6][28:27]             <= 2'b11;
            end
            if((ept_CR1[7][26:25] >= 2'b01  ) && (ept_CR1[7][2:1] == 2'b01))begin
               ept_CR1[7][28:27]             <= 2'b11;
            end
            if((ept_CR1[8][26:25] >= 2'b01  ) && (ept_CR1[8][2:1] == 2'b01))begin
               ept_CR1[8][28:27]             <= 2'b11;
            end
            if((ept_CR1[9][26:25] >= 2'b01  ) && (ept_CR1[9][2:1] == 2'b01))begin
               ept_CR1[9][28:27]             <= 2'b11;
            end
            if((ept_CR1[10][26:25] >= 2'b01 ) && (ept_CR1[10][2:1] == 2'b01))begin
               ept_CR1[10][28:27]            <= 2'b11;
            end
            if((ept_CR1[11][26:25] >= 2'b01 ) && (ept_CR1[11][2:1] == 2'b01))begin
               ept_CR1[11][28:27]            <= 2'b11;
            end
            if((ept_CR1[12][26:25] >= 2'b01 ) && (ept_CR1[12][2:1] == 2'b01))begin
               ept_CR1[12][28:27]            <= 2'b11;
            end
            if((ept_CR1[13][26:25] >= 2'b01 ) && (ept_CR1[13][2:1] == 2'b01))begin
               ept_CR1[13][28:27]            <= 2'b11;
            end
            if((ept_CR1[14][26:25] >= 2'b01 ) && (ept_CR1[14][2:1] == 2'b01))begin
               ept_CR1[14][28:27]            <= 2'b11;
            end
            if((ept_CR1[15][26:25] >= 2'b01 ) && (ept_CR1[15][2:1] == 2'b01))begin
               ept_CR1[15][28:27]            <= 2'b11;
            end
            if((ept_CR1[16][26:25] == 2'b01 ) && (ept_CR1[16][2:1] == 2'b01))begin
               ept_CR1[16][28:27]            <= 2'b10;
            end
            else if((ept_CR1[16][26:25] == 2'b10 ) && (ept_CR1[16][2:1] == 2'b01))begin
               ept_CR1[16][28:27]            <= 2'b01;
            end
            if((ept_CR1[17][26:25] == 2'b01 ) && (ept_CR1[17][2:1] == 2'b01))begin
               ept_CR1[17][28:27]            <= 2'b10;
            end
            else if((ept_CR1[17][26:25] == 2'b10 ) && (ept_CR1[17][2:1] == 2'b01))begin
               ept_CR1[17][28:27]            <= 2'b01;
            end
            if((ept_CR1[18][26:25] == 2'b01 ) && (ept_CR1[18][2:1] == 2'b01))begin
               ept_CR1[18][28:27]            <= 2'b10;
            end
            else if((ept_CR1[18][26:25] == 2'b10 ) && (ept_CR1[18][2:1] == 2'b01))begin
               ept_CR1[18][28:27]            <= 2'b01;
            end
            if((ept_CR1[19][26:25] == 2'b01 ) && (ept_CR1[19][2:1] == 2'b01))begin
               ept_CR1[19][28:27]            <= 2'b10;
            end
            else if((ept_CR1[19][26:25] == 2'b10 ) && (ept_CR1[19][2:1] == 2'b01))begin
               ept_CR1[19][28:27]            <= 2'b01;
            end
            if((ept_CR1[20][26:25] == 2'b01 ) && (ept_CR1[20][2:1] == 2'b01))begin
               ept_CR1[20][28:27]            <= 2'b10;
            end
            else if((ept_CR1[20][26:25] == 2'b10 ) && (ept_CR1[20][2:1] == 2'b01))begin
               ept_CR1[20][28:27]            <= 2'b01;
            end
            if((ept_CR1[21][26:25] == 2'b01 ) && (ept_CR1[21][2:1] == 2'b01))begin
               ept_CR1[21][28:27]            <= 2'b10;
            end
            else if((ept_CR1[21][26:25] == 2'b10 ) && (ept_CR1[21][2:1] == 2'b01))begin
               ept_CR1[21][28:27]            <= 2'b01;
            end
            if((ept_CR1[22][26:25] == 2'b01 ) && (ept_CR1[22][2:1] == 2'b01))begin
               ept_CR1[22][28:27]            <= 2'b10;
            end
            else if((ept_CR1[22][26:25] == 2'b10 ) && (ept_CR1[22][2:1] == 2'b01))begin
               ept_CR1[22][28:27]            <= 2'b01;
            end
            if((ept_CR1[23][26:25] == 2'b01 ) && (ept_CR1[23][2:1] == 2'b01))begin
               ept_CR1[23][28:27]            <= 2'b10;
            end
            else if((ept_CR1[23][26:25] == 2'b10 ) && (ept_CR1[23][2:1] == 2'b01))begin
               ept_CR1[23][28:27]            <= 2'b01;
            end
            if((ept_CR1[24][26:25] == 2'b01 ) && (ept_CR1[24][2:1] == 2'b01))begin
               ept_CR1[24][28:27]            <= 2'b10;
            end
            else if((ept_CR1[24][26:25] == 2'b10 ) && (ept_CR1[24][2:1] == 2'b01))begin
               ept_CR1[24][28:27]            <= 2'b01;
            end
            if((ept_CR1[25][26:25] == 2'b01 ) && (ept_CR1[25][2:1] == 2'b01))begin
               ept_CR1[25][28:27]            <= 2'b10;
            end
            else if((ept_CR1[25][26:25] == 2'b10 ) && (ept_CR1[25][2:1] == 2'b01))begin
               ept_CR1[25][28:27]            <= 2'b01;
            end
            if((ept_CR1[26][26:25] == 2'b01 ) && (ept_CR1[26][2:1] == 2'b01))begin
               ept_CR1[26][28:27]            <= 2'b10;
            end
            else if((ept_CR1[26][26:25] == 2'b10 ) && (ept_CR1[26][2:1] == 2'b01))begin
               ept_CR1[26][28:27]            <= 2'b01;
            end
            if((ept_CR1[27][26:25] == 2'b01 ) && (ept_CR1[27][2:1] == 2'b01))begin
               ept_CR1[27][28:27]            <= 2'b10;
            end
            else if((ept_CR1[27][26:25] == 2'b10 ) && (ept_CR1[27][2:1] == 2'b01))begin
               ept_CR1[27][28:27]            <= 2'b01;
            end
            if((ept_CR1[28][26:25] == 2'b01 ) && (ept_CR1[28][2:1] == 2'b01))begin
               ept_CR1[28][28:27]            <= 2'b10;
            end
            else if((ept_CR1[28][26:25] == 2'b10 ) && (ept_CR1[28][2:1] == 2'b01))begin
               ept_CR1[28][28:27]            <= 2'b01;
            end
            if((ept_CR1[29][26:25] == 2'b01 ) && (ept_CR1[29][2:1] == 2'b01))begin
               ept_CR1[29][28:27]            <= 2'b10;
            end
            else if((ept_CR1[29][26:25] == 2'b10 ) && (ept_CR1[29][2:1] == 2'b01))begin
               ept_CR1[29][28:27]            <= 2'b01;
            end
            if((ept_CR1[30][26:25] == 2'b01 ) && (ept_CR1[30][2:1] == 2'b01))begin
               ept_CR1[30][28:27]            <= 2'b10;
            end
            else if((ept_CR1[30][26:25] == 2'b10 ) && (ept_CR1[30][2:1] == 2'b01))begin
               ept_CR1[30][28:27]            <= 2'b01;
            end
            if((ept_CR1[31][26:25] == 2'b01 ) && (ept_CR1[31][2:1] == 2'b01))begin
               ept_CR1[31][28:27]            <= 2'b10;
            end
            else if((ept_CR1[31][26:25] == 2'b10 ) && (ept_CR1[31][2:1] == 2'b01))begin
               ept_CR1[31][28:27]            <= 2'b01;
            end
         end
      end
   end
   // --------------------------------------------------
   // Control register 2
   // --------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         ept_CR2[0]   <= {32{1'b0}} ;
         ept_CR2[1]   <= {32{1'b0}} ;
         ept_CR2[2]   <= {32{1'b0}} ;
         ept_CR2[3]   <= {32{1'b0}} ;
         ept_CR2[4]   <= {32{1'b0}} ;
         ept_CR2[5]   <= {32{1'b0}} ;
         ept_CR2[6]   <= {32{1'b0}} ;
         ept_CR2[7]   <= {32{1'b0}} ;
         ept_CR2[8]   <= {32{1'b0}} ;
         ept_CR2[9]   <= {32{1'b0}} ;
         ept_CR2[10]  <= {32{1'b0}} ;
         ept_CR2[11]  <= {32{1'b0}} ;
         ept_CR2[12]  <= {32{1'b0}} ;
         ept_CR2[13]  <= {32{1'b0}} ;
         ept_CR2[14]  <= {32{1'b0}} ;
         ept_CR2[15]  <= {32{1'b0}} ;
         ept_CR2[16]  <= {32{1'b0}} ;
         ept_CR2[17]  <= {32{1'b0}} ;
         ept_CR2[18]  <= {32{1'b0}} ;
         ept_CR2[19]  <= {32{1'b0}} ;
         ept_CR2[20]  <= {32{1'b0}} ;
         ept_CR2[21]  <= {32{1'b0}} ;
         ept_CR2[22]  <= {32{1'b0}} ;
         ept_CR2[23]  <= {32{1'b0}} ;
         ept_CR2[24]  <= {32{1'b0}} ;
         ept_CR2[25]  <= {32{1'b0}} ;
         ept_CR2[26]  <= {32{1'b0}} ;
         ept_CR2[27]  <= {32{1'b0}} ;
         ept_CR2[28]  <= {32{1'b0}} ;
         ept_CR2[29]  <= {32{1'b0}} ;
         ept_CR2[30]  <= {32{1'b0}} ;
         ept_CR2[31]  <= {32{1'b0}} ;
      end
      else if(sw_rst == 1'b1)begin
         ept_CR2[0]   <= {32{1'b0}} ;
         ept_CR2[1]   <= {32{1'b0}} ;
         ept_CR2[2]   <= {32{1'b0}} ;
         ept_CR2[3]   <= {32{1'b0}} ;
         ept_CR2[4]   <= {32{1'b0}} ;
         ept_CR2[5]   <= {32{1'b0}} ;
         ept_CR2[6]   <= {32{1'b0}} ;
         ept_CR2[7]   <= {32{1'b0}} ;
         ept_CR2[8]   <= {32{1'b0}} ;
         ept_CR2[9]   <= {32{1'b0}} ;
         ept_CR2[10]  <= {32{1'b0}} ;
         ept_CR2[11]  <= {32{1'b0}} ;
         ept_CR2[12]  <= {32{1'b0}} ;
         ept_CR2[13]  <= {32{1'b0}} ;
         ept_CR2[14]  <= {32{1'b0}} ;
         ept_CR2[15]  <= {32{1'b0}} ;
         ept_CR2[16]  <= {32{1'b0}} ;
         ept_CR2[17]  <= {32{1'b0}} ;
         ept_CR2[18]  <= {32{1'b0}} ;
         ept_CR2[19]  <= {32{1'b0}} ;
         ept_CR2[20]  <= {32{1'b0}} ;
         ept_CR2[21]  <= {32{1'b0}} ;
         ept_CR2[22]  <= {32{1'b0}} ;
         ept_CR2[23]  <= {32{1'b0}} ;
         ept_CR2[24]  <= {32{1'b0}} ;
         ept_CR2[25]  <= {32{1'b0}} ;
         ept_CR2[26]  <= {32{1'b0}} ;
         ept_CR2[27]  <= {32{1'b0}} ;
         ept_CR2[28]  <= {32{1'b0}} ;
         ept_CR2[29]  <= {32{1'b0}} ;
         ept_CR2[30]  <= {32{1'b0}} ;
         ept_CR2[31]  <= {32{1'b0}} ;
      end
      else begin
         if(wren_CR2[0] == 1'b1)begin
            ept_CR2[0]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[1] == 1'b1)begin
            ept_CR2[1]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[2] == 1'b1)begin
            ept_CR2[2]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[3] == 1'b1)begin
            ept_CR2[3]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[4] == 1'b1)begin
            ept_CR2[4]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[5] == 1'b1)begin
            ept_CR2[5]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[6] == 1'b1)begin
            ept_CR2[6]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[7] == 1'b1)begin
            ept_CR2[7]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[8] == 1'b1)begin
            ept_CR2[8]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[9] == 1'b1)begin
            ept_CR2[9]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[10] == 1'b1)begin
            ept_CR2[10]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[11] == 1'b1)begin
            ept_CR2[11]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[12] == 1'b1)begin
            ept_CR2[12]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[13] == 1'b1)begin
            ept_CR2[13]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[14] == 1'b1)begin
            ept_CR2[14]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[15] == 1'b1)begin
            ept_CR2[15]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[16] == 1'b1)begin
            ept_CR2[16]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[17] == 1'b1)begin
            ept_CR2[17]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[18] == 1'b1)begin
            ept_CR2[18]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[19] == 1'b1)begin
            ept_CR2[19]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[20] == 1'b1)begin
            ept_CR2[20]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[21] == 1'b1)begin
            ept_CR2[21]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[22] == 1'b1)begin
            ept_CR2[22]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[23] == 1'b1)begin
            ept_CR2[23]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[24] == 1'b1)begin
            ept_CR2[24]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[25] == 1'b1)begin
            ept_CR2[25]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[26] == 1'b1)begin
            ept_CR2[26]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[27] == 1'b1)begin
            ept_CR2[27]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[28] == 1'b1)begin
            ept_CR2[28]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[29] == 1'b1)begin
            ept_CR2[29]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[30] == 1'b1)begin
            ept_CR2[30]      <= cmd2eptd_wrData;
         end
         if(wren_CR2[31] == 1'b1)begin
            ept_CR2[31]      <= cmd2eptd_wrData;
         end
      end
   end
   // --------------------------------------------------
   // Write pointer register
   // --------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         ept_wPtr[0]   <= {32{1'b0}} ;
         ept_wPtr[1]   <= {32{1'b0}} ;
         ept_wPtr[2]   <= {32{1'b0}} ;
         ept_wPtr[3]   <= {32{1'b0}} ;
         ept_wPtr[4]   <= {32{1'b0}} ;
         ept_wPtr[5]   <= {32{1'b0}} ;
         ept_wPtr[6]   <= {32{1'b0}} ;
         ept_wPtr[7]   <= {32{1'b0}} ;
         ept_wPtr[8]   <= {32{1'b0}} ;
         ept_wPtr[9]   <= {32{1'b0}} ;
         ept_wPtr[10]  <= {32{1'b0}} ;
         ept_wPtr[11]  <= {32{1'b0}} ;
         ept_wPtr[12]  <= {32{1'b0}} ;
         ept_wPtr[13]  <= {32{1'b0}} ;
         ept_wPtr[14]  <= {32{1'b0}} ;
         ept_wPtr[15]  <= {32{1'b0}} ;
         ept_wPtr[16]  <= {32{1'b0}} ;
         ept_wPtr[17]  <= {32{1'b0}} ;
         ept_wPtr[18]  <= {32{1'b0}} ;
         ept_wPtr[19]  <= {32{1'b0}} ;
         ept_wPtr[20]  <= {32{1'b0}} ;
         ept_wPtr[21]  <= {32{1'b0}} ;
         ept_wPtr[22]  <= {32{1'b0}} ;
         ept_wPtr[23]  <= {32{1'b0}} ;
         ept_wPtr[24]  <= {32{1'b0}} ;
         ept_wPtr[25]  <= {32{1'b0}} ;
         ept_wPtr[26]  <= {32{1'b0}} ;
         ept_wPtr[27]  <= {32{1'b0}} ;
         ept_wPtr[28]  <= {32{1'b0}} ;
         ept_wPtr[29]  <= {32{1'b0}} ;
         ept_wPtr[30]  <= {32{1'b0}} ;
         ept_wPtr[31]  <= {32{1'b0}} ; 
      end
      else if(sw_rst == 1'b1)begin
         ept_wPtr[0]   <= {32{1'b0}} ;
         ept_wPtr[1]   <= {32{1'b0}} ;
         ept_wPtr[2]   <= {32{1'b0}} ;
         ept_wPtr[3]   <= {32{1'b0}} ;
         ept_wPtr[4]   <= {32{1'b0}} ;
         ept_wPtr[5]   <= {32{1'b0}} ;
         ept_wPtr[6]   <= {32{1'b0}} ;
         ept_wPtr[7]   <= {32{1'b0}} ;
         ept_wPtr[8]   <= {32{1'b0}} ;
         ept_wPtr[9]   <= {32{1'b0}} ;
         ept_wPtr[10]  <= {32{1'b0}} ;
         ept_wPtr[11]  <= {32{1'b0}} ;
         ept_wPtr[12]  <= {32{1'b0}} ;
         ept_wPtr[13]  <= {32{1'b0}} ;
         ept_wPtr[14]  <= {32{1'b0}} ;
         ept_wPtr[15]  <= {32{1'b0}} ;
         ept_wPtr[16]  <= {32{1'b0}} ;
         ept_wPtr[17]  <= {32{1'b0}} ;
         ept_wPtr[18]  <= {32{1'b0}} ;
         ept_wPtr[19]  <= {32{1'b0}} ;
         ept_wPtr[20]  <= {32{1'b0}} ;
         ept_wPtr[21]  <= {32{1'b0}} ;
         ept_wPtr[22]  <= {32{1'b0}} ;
         ept_wPtr[23]  <= {32{1'b0}} ;
         ept_wPtr[24]  <= {32{1'b0}} ;
         ept_wPtr[25]  <= {32{1'b0}} ;
         ept_wPtr[26]  <= {32{1'b0}} ;
         ept_wPtr[27]  <= {32{1'b0}} ;
         ept_wPtr[28]  <= {32{1'b0}} ;
         ept_wPtr[29]  <= {32{1'b0}} ;
         ept_wPtr[30]  <= {32{1'b0}} ;
         ept_wPtr[31]  <= {32{1'b0}} ; 
      end
      else begin
         if(wren_wPtr[0] == 1'b1)begin
            ept_wPtr[0]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[1] == 1'b1)begin
            ept_wPtr[1]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[2] == 1'b1)begin
            ept_wPtr[2]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[3] == 1'b1)begin
            ept_wPtr[3]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[4] == 1'b1)begin
            ept_wPtr[4]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[5] == 1'b1)begin
            ept_wPtr[5]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[6] == 1'b1)begin
            ept_wPtr[6]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[7] == 1'b1)begin
            ept_wPtr[7]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[8] == 1'b1)begin
            ept_wPtr[8]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[9] == 1'b1)begin
            ept_wPtr[9]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[10] == 1'b1)begin
            ept_wPtr[10]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[11] == 1'b1)begin
            ept_wPtr[11]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[12] == 1'b1)begin
            ept_wPtr[12]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[13] == 1'b1)begin
            ept_wPtr[13]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[14] == 1'b1)begin
            ept_wPtr[14]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[15] == 1'b1)begin
            ept_wPtr[15]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[16] == 1'b1)begin
            ept_wPtr[16]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[17] == 1'b1)begin
            ept_wPtr[17]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[18] == 1'b1)begin
            ept_wPtr[18]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[19] == 1'b1)begin
            ept_wPtr[19]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[20] == 1'b1)begin
            ept_wPtr[20]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[21] == 1'b1)begin
            ept_wPtr[21]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[22] == 1'b1)begin
            ept_wPtr[22]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[23] == 1'b1)begin
            ept_wPtr[23]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[24] == 1'b1)begin
            ept_wPtr[24]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[25] == 1'b1)begin
            ept_wPtr[25]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[26] == 1'b1)begin
            ept_wPtr[26]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[27] == 1'b1)begin
            ept_wPtr[27]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[28] == 1'b1)begin
            ept_wPtr[28]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[29] == 1'b1)begin
            ept_wPtr[29]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[30] == 1'b1)begin
            ept_wPtr[30]      <= cmd2eptd_wrData;
         end
         if(wren_wPtr[31] == 1'b1)begin
            ept_wPtr[31]      <= cmd2eptd_wrData;
         end
         if(epcrUpdt == 1'b1)begin
            ept_wPtr[{1'b0,epcr2eptd_epNum}] <= epcr2eptd_wrPtrOut;
         end
         else begin
            ept_wPtr[{1'b0,epcr2eptd_epNum}] <= ept_wPtr[{1'b0,epcr2eptd_epNum}];
         end
         if(septUpdt == 1'b1)begin
            ept_wPtr[{1'b1,sept2eptd_epNum}] <= sept2eptd_wrPtrOut;
         end
         else begin
            ept_wPtr[{1'b1,sept2eptd_epNum}] <= ept_wPtr[{1'b1,sept2eptd_epNum}];
         end
      end
   end

   // --------------------------------------------------
   // Read Pointer register
   // --------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         ept_rPtr[0]   <= {32{1'b0}} ;
         ept_rPtr[1]   <= {32{1'b0}} ;
         ept_rPtr[2]   <= {32{1'b0}} ;
         ept_rPtr[3]   <= {32{1'b0}} ;
         ept_rPtr[4]   <= {32{1'b0}} ;
         ept_rPtr[5]   <= {32{1'b0}} ;
         ept_rPtr[6]   <= {32{1'b0}} ;
         ept_rPtr[7]   <= {32{1'b0}} ;
         ept_rPtr[8]   <= {32{1'b0}} ;
         ept_rPtr[9]   <= {32{1'b0}} ;
         ept_rPtr[10]  <= {32{1'b0}} ;
         ept_rPtr[11]  <= {32{1'b0}} ;
         ept_rPtr[12]  <= {32{1'b0}} ;
         ept_rPtr[13]  <= {32{1'b0}} ;
         ept_rPtr[14]  <= {32{1'b0}} ;
         ept_rPtr[15]  <= {32{1'b0}} ;
         ept_rPtr[16]  <= {32{1'b0}} ;
         ept_rPtr[17]  <= {32{1'b0}} ;
         ept_rPtr[18]  <= {32{1'b0}} ;
         ept_rPtr[19]  <= {32{1'b0}} ;
         ept_rPtr[20]  <= {32{1'b0}} ;
         ept_rPtr[21]  <= {32{1'b0}} ;
         ept_rPtr[22]  <= {32{1'b0}} ;
         ept_rPtr[23]  <= {32{1'b0}} ;
         ept_rPtr[24]  <= {32{1'b0}} ;
         ept_rPtr[25]  <= {32{1'b0}} ;
         ept_rPtr[26]  <= {32{1'b0}} ;
         ept_rPtr[27]  <= {32{1'b0}} ;
         ept_rPtr[28]  <= {32{1'b0}} ;
         ept_rPtr[29]  <= {32{1'b0}} ;
         ept_rPtr[30]  <= {32{1'b0}} ;
         ept_rPtr[31]  <= {32{1'b0}} ; 
      end
      else if(sw_rst == 1'b1)begin
         ept_rPtr[0]   <= {32{1'b0}} ;
         ept_rPtr[1]   <= {32{1'b0}} ;
         ept_rPtr[2]   <= {32{1'b0}} ;
         ept_rPtr[3]   <= {32{1'b0}} ;
         ept_rPtr[4]   <= {32{1'b0}} ;
         ept_rPtr[5]   <= {32{1'b0}} ;
         ept_rPtr[6]   <= {32{1'b0}} ;
         ept_rPtr[7]   <= {32{1'b0}} ;
         ept_rPtr[8]   <= {32{1'b0}} ;
         ept_rPtr[9]   <= {32{1'b0}} ;
         ept_rPtr[10]  <= {32{1'b0}} ;
         ept_rPtr[11]  <= {32{1'b0}} ;
         ept_rPtr[12]  <= {32{1'b0}} ;
         ept_rPtr[13]  <= {32{1'b0}} ;
         ept_rPtr[14]  <= {32{1'b0}} ;
         ept_rPtr[15]  <= {32{1'b0}} ;
         ept_rPtr[16]  <= {32{1'b0}} ;
         ept_rPtr[17]  <= {32{1'b0}} ;
         ept_rPtr[18]  <= {32{1'b0}} ;
         ept_rPtr[19]  <= {32{1'b0}} ;
         ept_rPtr[20]  <= {32{1'b0}} ;
         ept_rPtr[21]  <= {32{1'b0}} ;
         ept_rPtr[22]  <= {32{1'b0}} ;
         ept_rPtr[23]  <= {32{1'b0}} ;
         ept_rPtr[24]  <= {32{1'b0}} ;
         ept_rPtr[25]  <= {32{1'b0}} ;
         ept_rPtr[26]  <= {32{1'b0}} ;
         ept_rPtr[27]  <= {32{1'b0}} ;
         ept_rPtr[28]  <= {32{1'b0}} ;
         ept_rPtr[29]  <= {32{1'b0}} ;
         ept_rPtr[30]  <= {32{1'b0}} ;
         ept_rPtr[31]  <= {32{1'b0}} ;
      end
      else begin
         if(wren_rPtr[0] == 1'b1)begin
            ept_rPtr[0]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[1] == 1'b1)begin
            ept_rPtr[1]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[2] == 1'b1)begin
            ept_rPtr[2]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[3] == 1'b1)begin
            ept_rPtr[3]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[4] == 1'b1)begin
            ept_rPtr[4]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[5] == 1'b1)begin
            ept_rPtr[5]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[6] == 1'b1)begin
            ept_rPtr[6]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[7] == 1'b1)begin
            ept_rPtr[7]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[8] == 1'b1)begin
            ept_rPtr[8]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[9] == 1'b1)begin
            ept_rPtr[9]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[10] == 1'b1)begin
            ept_rPtr[10]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[11] == 1'b1)begin
            ept_rPtr[11]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[12] == 1'b1)begin
            ept_rPtr[12]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[13] == 1'b1)begin
            ept_rPtr[13]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[14] == 1'b1)begin
            ept_rPtr[14]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[15] == 1'b1)begin
            ept_rPtr[15]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[16] == 1'b1)begin
            ept_rPtr[16]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[17] == 1'b1)begin
            ept_rPtr[17]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[18] == 1'b1)begin
            ept_rPtr[18]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[19] == 1'b1)begin
            ept_rPtr[19]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[20] == 1'b1)begin
            ept_rPtr[20]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[21] == 1'b1)begin
            ept_rPtr[21]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[22] == 1'b1)begin
            ept_rPtr[22]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[23] == 1'b1)begin
            ept_rPtr[23]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[24] == 1'b1)begin
            ept_rPtr[24]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[25] == 1'b1)begin
            ept_rPtr[25]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[26] == 1'b1)begin
            ept_rPtr[26]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[27] == 1'b1)begin
            ept_rPtr[27]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[28] == 1'b1)begin
            ept_rPtr[28]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[29] == 1'b1)begin
            ept_rPtr[29]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[30] == 1'b1)begin
            ept_rPtr[30]      <= cmd2eptd_wrData;
         end
         if(wren_rPtr[31] == 1'b1)begin
            ept_rPtr[31]      <= cmd2eptd_wrData;
         end
         if(epctUpdt == 1'b1)begin
            ept_rPtr[{1'b1,epct2eptd_epNum}]   <= epct2eptd_rdPtrOut;
         end
         else begin
            ept_rPtr[{1'b1,epct2eptd_epNum}]   <= ept_rPtr[{1'b1,epct2eptd_epNum}];
         end
         if(seprUpdt == 1'b1)begin
            ept_rPtr[{1'b0,sepr2eptd_epNum}]   <= sepr2eptd_rdPtr;
         end
         else begin
            ept_rPtr[{1'b0,sepr2eptd_epNum}]   <= ept_rPtr[{1'b0,sepr2eptd_epNum}];
         end
      end
   end

   // --------------------------------------------------
   // ack Register
   // --------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         ept_arPtr[0]   <= {32{1'b0}} ;
         ept_arPtr[1]   <= {32{1'b0}} ;
         ept_arPtr[2]   <= {32{1'b0}} ;
         ept_arPtr[3]   <= {32{1'b0}} ;
         ept_arPtr[4]   <= {32{1'b0}} ;
         ept_arPtr[5]   <= {32{1'b0}} ;
         ept_arPtr[6]   <= {32{1'b0}} ;
         ept_arPtr[7]   <= {32{1'b0}} ;
         ept_arPtr[8]   <= {32{1'b0}} ;
         ept_arPtr[9]   <= {32{1'b0}} ;
         ept_arPtr[10]  <= {32{1'b0}} ;
         ept_arPtr[11]  <= {32{1'b0}} ;
         ept_arPtr[12]  <= {32{1'b0}} ;
         ept_arPtr[13]  <= {32{1'b0}} ;
         ept_arPtr[14]  <= {32{1'b0}} ;
         ept_arPtr[15]  <= {32{1'b0}} ;
      end
      else if(sw_rst == 1'b1)begin
         ept_arPtr[0]   <= {32{1'b0}} ;
         ept_arPtr[1]   <= {32{1'b0}} ;
         ept_arPtr[2]   <= {32{1'b0}} ;
         ept_arPtr[3]   <= {32{1'b0}} ;
         ept_arPtr[4]   <= {32{1'b0}} ;
         ept_arPtr[5]   <= {32{1'b0}} ;
         ept_arPtr[6]   <= {32{1'b0}} ;
         ept_arPtr[7]   <= {32{1'b0}} ;
         ept_arPtr[8]   <= {32{1'b0}} ;
         ept_arPtr[9]   <= {32{1'b0}} ;
         ept_arPtr[10]  <= {32{1'b0}} ;
         ept_arPtr[11]  <= {32{1'b0}} ;
         ept_arPtr[12]  <= {32{1'b0}} ;
         ept_arPtr[13]  <= {32{1'b0}} ;
         ept_arPtr[14]  <= {32{1'b0}} ;
         ept_arPtr[15]  <= {32{1'b0}} ;
      end
      else begin
         if(wren_arPtr[0] == 1'b1)begin
            ept_arPtr[0]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[1] == 1'b1)begin
            ept_arPtr[1]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[2] == 1'b1)begin
            ept_arPtr[2]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[3] == 1'b1)begin
            ept_arPtr[3]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[4] == 1'b1)begin
            ept_arPtr[4]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[5] == 1'b1)begin
            ept_arPtr[5]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[6] == 1'b1)begin
            ept_arPtr[6]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[7] == 1'b1)begin
            ept_arPtr[7]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[8] == 1'b1)begin
            ept_arPtr[8]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[9] == 1'b1)begin
            ept_arPtr[9]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[10] == 1'b1)begin
            ept_arPtr[10]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[11] == 1'b1)begin
            ept_arPtr[11]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[12] == 1'b1)begin
            ept_arPtr[12]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[13] == 1'b1)begin
            ept_arPtr[13]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[14] == 1'b1)begin
            ept_arPtr[14]      <= cmd2eptd_wrData;
         end
         if(wren_arPtr[15] == 1'b1)begin
            ept_arPtr[15]      <= cmd2eptd_wrData;
         end
      end
   end
   // --------------------------------------------------
   // Status Register
   // --------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         ept_stat[0]   <= {32{1'b0}} ;
         ept_stat[1]   <= {32{1'b0}} ;
         ept_stat[2]   <= {32{1'b0}} ;
         ept_stat[3]   <= {32{1'b0}} ;
         ept_stat[4]   <= {32{1'b0}} ;
         ept_stat[5]   <= {32{1'b0}} ;
         ept_stat[6]   <= {32{1'b0}} ;
         ept_stat[7]   <= {32{1'b0}} ;
         ept_stat[8]   <= {32{1'b0}} ;
         ept_stat[9]   <= {32{1'b0}} ;
         ept_stat[10]  <= {32{1'b0}} ;
         ept_stat[11]  <= {32{1'b0}} ;
         ept_stat[12]  <= {32{1'b0}} ;
         ept_stat[13]  <= {32{1'b0}} ;
         ept_stat[14]  <= {32{1'b0}} ;
         ept_stat[15]  <= {32{1'b0}} ;
         ept_stat[16]  <= {32{1'b0}} ;
         ept_stat[17]  <= {32{1'b0}} ;
         ept_stat[18]  <= {32{1'b0}} ;
         ept_stat[19]  <= {32{1'b0}} ;
         ept_stat[20]  <= {32{1'b0}} ;
         ept_stat[21]  <= {32{1'b0}} ;
         ept_stat[22]  <= {32{1'b0}} ;
         ept_stat[23]  <= {32{1'b0}} ;
         ept_stat[24]  <= {32{1'b0}} ;
         ept_stat[25]  <= {32{1'b0}} ;
         ept_stat[26]  <= {32{1'b0}} ;
         ept_stat[27]  <= {32{1'b0}} ;
         ept_stat[28]  <= {32{1'b0}} ;
         ept_stat[29]  <= {32{1'b0}} ;
         ept_stat[30]  <= {32{1'b0}} ;
         ept_stat[31]  <= {32{1'b0}} ; 
      end
      else if(sw_rst == 1'b1)begin
         ept_stat[0]   <= {32{1'b0}} ;
         ept_stat[1]   <= {32{1'b0}} ;
         ept_stat[2]   <= {32{1'b0}} ;
         ept_stat[3]   <= {32{1'b0}} ;
         ept_stat[4]   <= {32{1'b0}} ;
         ept_stat[5]   <= {32{1'b0}} ;
         ept_stat[6]   <= {32{1'b0}} ;
         ept_stat[7]   <= {32{1'b0}} ;
         ept_stat[8]   <= {32{1'b0}} ;
         ept_stat[9]   <= {32{1'b0}} ;
         ept_stat[10]  <= {32{1'b0}} ;
         ept_stat[11]  <= {32{1'b0}} ;
         ept_stat[12]  <= {32{1'b0}} ;
         ept_stat[13]  <= {32{1'b0}} ;
         ept_stat[14]  <= {32{1'b0}} ;
         ept_stat[15]  <= {32{1'b0}} ;
         ept_stat[16]  <= {32{1'b0}} ;
         ept_stat[17]  <= {32{1'b0}} ;
         ept_stat[18]  <= {32{1'b0}} ;
         ept_stat[19]  <= {32{1'b0}} ;
         ept_stat[20]  <= {32{1'b0}} ;
         ept_stat[21]  <= {32{1'b0}} ;
         ept_stat[22]  <= {32{1'b0}} ;
         ept_stat[23]  <= {32{1'b0}} ;
         ept_stat[24]  <= {32{1'b0}} ;
         ept_stat[25]  <= {32{1'b0}} ;
         ept_stat[26]  <= {32{1'b0}} ;
         ept_stat[27]  <= {32{1'b0}} ;
         ept_stat[28]  <= {32{1'b0}} ;
         ept_stat[29]  <= {32{1'b0}} ;
         ept_stat[30]  <= {32{1'b0}} ;
         ept_stat[31]  <= {32{1'b0}} ; 
      end
      else begin
         if(wren_stat[0] == 1'b1)begin
            ept_stat[0]      <= cmd2eptd_wrData;
         end
         if(wren_stat[1] == 1'b1)begin
            ept_stat[1]      <= cmd2eptd_wrData;
         end
         if(wren_stat[2] == 1'b1)begin
            ept_stat[2]      <= cmd2eptd_wrData;
         end
         if(wren_stat[3] == 1'b1)begin
            ept_stat[3]      <= cmd2eptd_wrData;
         end
         if(wren_stat[4] == 1'b1)begin
            ept_stat[4]      <= cmd2eptd_wrData;
         end
         if(wren_stat[5] == 1'b1)begin
            ept_stat[5]      <= cmd2eptd_wrData;
         end
         if(wren_stat[6] == 1'b1)begin
            ept_stat[6]      <= cmd2eptd_wrData;
         end
         if(wren_stat[7] == 1'b1)begin
            ept_stat[7]      <= cmd2eptd_wrData;
         end
         if(wren_stat[8] == 1'b1)begin
            ept_stat[8]      <= cmd2eptd_wrData;
         end
         if(wren_stat[9] == 1'b1)begin
            ept_stat[9]      <= cmd2eptd_wrData;
         end
         if(wren_stat[10] == 1'b1)begin
            ept_stat[10]      <= cmd2eptd_wrData;
         end
         if(wren_stat[11] == 1'b1)begin
            ept_stat[11]      <= cmd2eptd_wrData;
         end
         if(wren_stat[12] == 1'b1)begin
            ept_stat[12]      <= cmd2eptd_wrData;
         end
         if(wren_stat[13] == 1'b1)begin
            ept_stat[13]      <= cmd2eptd_wrData;
         end
         if(wren_stat[14] == 1'b1)begin
            ept_stat[14]      <= cmd2eptd_wrData;
         end
         if(wren_stat[15] == 1'b1)begin
            ept_stat[15]      <= cmd2eptd_wrData;
         end
         if(wren_stat[16] == 1'b1)begin
            ept_stat[16]      <= cmd2eptd_wrData;
         end
         if(wren_stat[17] == 1'b1)begin
            ept_stat[17]      <= cmd2eptd_wrData;
         end
         if(wren_stat[18] == 1'b1)begin
            ept_stat[18]      <= cmd2eptd_wrData;
         end
         if(wren_stat[19] == 1'b1)begin
            ept_stat[19]      <= cmd2eptd_wrData;
         end
         if(wren_stat[20] == 1'b1)begin
            ept_stat[20]      <= cmd2eptd_wrData;
         end
         if(wren_stat[21] == 1'b1)begin
            ept_stat[21]      <= cmd2eptd_wrData;
         end
         if(wren_stat[22] == 1'b1)begin
            ept_stat[22]      <= cmd2eptd_wrData;
         end
         if(wren_stat[23] == 1'b1)begin
            ept_stat[23]      <= cmd2eptd_wrData;
         end
         if(wren_stat[24] == 1'b1)begin
            ept_stat[24]      <= cmd2eptd_wrData;
         end
         if(wren_stat[25] == 1'b1)begin
            ept_stat[25]      <= cmd2eptd_wrData;
         end
         if(wren_stat[26] == 1'b1)begin
            ept_stat[26]      <= cmd2eptd_wrData;
         end
         if(wren_stat[27] == 1'b1)begin
            ept_stat[27]      <= cmd2eptd_wrData;
         end
         if(wren_stat[28] == 1'b1)begin
            ept_stat[28]      <= cmd2eptd_wrData;
         end
         if(wren_stat[29] == 1'b1)begin
            ept_stat[29]      <= cmd2eptd_wrData;
         end
         if(wren_stat[30] == 1'b1)begin
            ept_stat[30]      <= cmd2eptd_wrData;
         end
         if(wren_stat[31] == 1'b1)begin
            ept_stat[31]      <= cmd2eptd_wrData;
         end
         if(pd2eptd_statusStrobe == 1'b1)begin
            ept_stat[pd2eptd_epNum] <= {ept_stat[pd2eptd_epNum][31:17],pd2eptd_err,pd2eptd_pid,pd2eptd_crc5,ept_stat[pd2eptd_epNum][13:0]};
         end
      end
   end

 // --------------------------------------------------
   // Full packet count
   // --------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         ept_fullPktCnt[0]   <= {32{1'b0}} ;
         ept_fullPktCnt[1]   <= {32{1'b0}} ;
         ept_fullPktCnt[2]   <= {32{1'b0}} ;
         ept_fullPktCnt[3]   <= {32{1'b0}} ;
         ept_fullPktCnt[4]   <= {32{1'b0}} ;
         ept_fullPktCnt[5]   <= {32{1'b0}} ;
         ept_fullPktCnt[6]   <= {32{1'b0}} ;
         ept_fullPktCnt[7]   <= {32{1'b0}} ;
         ept_fullPktCnt[8]   <= {32{1'b0}} ;
         ept_fullPktCnt[9]   <= {32{1'b0}} ;
         ept_fullPktCnt[10]  <= {32{1'b0}} ;
         ept_fullPktCnt[11]  <= {32{1'b0}} ;
         ept_fullPktCnt[12]  <= {32{1'b0}} ;
         ept_fullPktCnt[13]  <= {32{1'b0}} ;
         ept_fullPktCnt[14]  <= {32{1'b0}} ;
         ept_fullPktCnt[15]  <= {32{1'b0}} ;
         ept_fullPktCnt[16]  <= {32{1'b0}} ;
         ept_fullPktCnt[17]  <= {32{1'b0}} ;
         ept_fullPktCnt[18]  <= {32{1'b0}} ;
         ept_fullPktCnt[19]  <= {32{1'b0}} ;
         ept_fullPktCnt[20]  <= {32{1'b0}} ;
         ept_fullPktCnt[21]  <= {32{1'b0}} ;
         ept_fullPktCnt[22]  <= {32{1'b0}} ;
         ept_fullPktCnt[23]  <= {32{1'b0}} ;
         ept_fullPktCnt[24]  <= {32{1'b0}} ;
         ept_fullPktCnt[25]  <= {32{1'b0}} ;
         ept_fullPktCnt[26]  <= {32{1'b0}} ;
         ept_fullPktCnt[27]  <= {32{1'b0}} ;
         ept_fullPktCnt[28]  <= {32{1'b0}} ;
         ept_fullPktCnt[29]  <= {32{1'b0}} ;
         ept_fullPktCnt[30]  <= {32{1'b0}} ;
         ept_fullPktCnt[31]  <= {32{1'b0}} ; 
      end
      else if(sw_rst == 1'b1)begin
         ept_fullPktCnt[0]   <= {32{1'b0}} ;
         ept_fullPktCnt[1]   <= {32{1'b0}} ;
         ept_fullPktCnt[2]   <= {32{1'b0}} ;
         ept_fullPktCnt[3]   <= {32{1'b0}} ;
         ept_fullPktCnt[4]   <= {32{1'b0}} ;
         ept_fullPktCnt[5]   <= {32{1'b0}} ;
         ept_fullPktCnt[6]   <= {32{1'b0}} ;
         ept_fullPktCnt[7]   <= {32{1'b0}} ;
         ept_fullPktCnt[8]   <= {32{1'b0}} ;
         ept_fullPktCnt[9]   <= {32{1'b0}} ;
         ept_fullPktCnt[10]  <= {32{1'b0}} ;
         ept_fullPktCnt[11]  <= {32{1'b0}} ;
         ept_fullPktCnt[12]  <= {32{1'b0}} ;
         ept_fullPktCnt[13]  <= {32{1'b0}} ;
         ept_fullPktCnt[14]  <= {32{1'b0}} ;
         ept_fullPktCnt[15]  <= {32{1'b0}} ;
         ept_fullPktCnt[16]  <= {32{1'b0}} ;
         ept_fullPktCnt[17]  <= {32{1'b0}} ;
         ept_fullPktCnt[18]  <= {32{1'b0}} ;
         ept_fullPktCnt[19]  <= {32{1'b0}} ;
         ept_fullPktCnt[20]  <= {32{1'b0}} ;
         ept_fullPktCnt[21]  <= {32{1'b0}} ;
         ept_fullPktCnt[22]  <= {32{1'b0}} ;
         ept_fullPktCnt[23]  <= {32{1'b0}} ;
         ept_fullPktCnt[24]  <= {32{1'b0}} ;
         ept_fullPktCnt[25]  <= {32{1'b0}} ;
         ept_fullPktCnt[26]  <= {32{1'b0}} ;
         ept_fullPktCnt[27]  <= {32{1'b0}} ;
         ept_fullPktCnt[28]  <= {32{1'b0}} ;
         ept_fullPktCnt[29]  <= {32{1'b0}} ;
         ept_fullPktCnt[30]  <= {32{1'b0}} ;
         ept_fullPktCnt[31]  <= {32{1'b0}} ; 
      end
      else begin
         if(wren_fullPktCnt[0] == 1'b1)begin
            ept_fullPktCnt[0]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[1] == 1'b1)begin
            ept_fullPktCnt[1]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[2] == 1'b1)begin
            ept_fullPktCnt[2]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[3] == 1'b1)begin
            ept_fullPktCnt[3]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[4] == 1'b1)begin
            ept_fullPktCnt[4]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[5] == 1'b1)begin
            ept_fullPktCnt[5]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[6] == 1'b1)begin
            ept_fullPktCnt[6]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[7] == 1'b1)begin
            ept_fullPktCnt[7]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[8] == 1'b1)begin
            ept_fullPktCnt[8]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[9] == 1'b1)begin
            ept_fullPktCnt[9]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[10] == 1'b1)begin
            ept_fullPktCnt[10]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[11] == 1'b1)begin
            ept_fullPktCnt[11]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[12] == 1'b1)begin
            ept_fullPktCnt[12]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[13] == 1'b1)begin
            ept_fullPktCnt[13]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[14] == 1'b1)begin
            ept_fullPktCnt[14]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[15] == 1'b1)begin
            ept_fullPktCnt[15]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[16] == 1'b1)begin
            ept_fullPktCnt[16]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[17] == 1'b1)begin
            ept_fullPktCnt[17]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[18] == 1'b1)begin
            ept_fullPktCnt[18]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[19] == 1'b1)begin
            ept_fullPktCnt[19]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[20] == 1'b1)begin
            ept_fullPktCnt[20]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[21] == 1'b1)begin
            ept_fullPktCnt[21]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[22] == 1'b1)begin
            ept_fullPktCnt[22]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[23] == 1'b1)begin
            ept_fullPktCnt[23]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[24] == 1'b1)begin
            ept_fullPktCnt[24]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[25] == 1'b1)begin
            ept_fullPktCnt[25]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[26] == 1'b1)begin
            ept_fullPktCnt[26]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[27] == 1'b1)begin
            ept_fullPktCnt[27]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[28] == 1'b1)begin
            ept_fullPktCnt[28]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[29] == 1'b1)begin
            ept_fullPktCnt[29]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[30] == 1'b1)begin
            ept_fullPktCnt[30]      <= cmd2eptd_wrData;
         end
         if(wren_fullPktCnt[31] == 1'b1)begin
            ept_fullPktCnt[31]      <= cmd2eptd_wrData;
         end
         if((epcrUpdt == 1'b1) && (seprUpdt == 1'b0))begin
            ept_fullPktCnt[{1'b0,epcr2eptd_epNum}][PKTCNTWD-1:0]  <= ept_fullPktCnt[{1'b0,epcr2eptd_epNum}][PKTCNTWD-1:0] + 1'b1;
         end
         if((epctUpdt == 1'b1) && (septUpdt == 1'b0))begin
            ept_fullPktCnt[{1'b1,epct2eptd_epNum}][PKTCNTWD-1:0]  <= ept_fullPktCnt[{1'b1,epct2eptd_epNum}][PKTCNTWD-1:0] - 1'b1;
         end
         if((septUpdt == 1'b1) && (epctUpdt == 1'b0))begin
            ept_fullPktCnt[{1'b1,sept2eptd_epNum}][PKTCNTWD-1:0]  <= ept_fullPktCnt[{1'b1,sept2eptd_epNum}][PKTCNTWD-1:0] + 1'b1;
         end
         if((seprUpdt == 1'b1) && (epcrUpdt == 1'b0))begin
            ept_fullPktCnt[{1'b0,sepr2eptd_epNum}][PKTCNTWD-1:0]  <= ept_fullPktCnt[{1'b0,sepr2eptd_epNum}][PKTCNTWD-1:0] - 1'b1;
         end
      end
   end

   // --------------------------------------------------
   // lmp no transfer pending
   // --------------------------------------------------

   assign eptd2pe_noTransPending = (/*ept_fullPktCnt[0] || ept_fullPktCnt[1] || ept_fullPktCnt[2] || ept_fullPktCnt[3] || ept_fullPktCnt[4] 
                                   || ept_fullPktCnt[5] || ept_fullPktCnt[6] || ept_fullPktCnt[7] || ept_fullPktCnt[8] || ept_fullPktCnt[9] 
                                   || ept_fullPktCnt[10] || ept_fullPktCnt[11] || ept_fullPktCnt[12] || ept_fullPktCnt[13] || ept_fullPktCnt[14] 
                                   || ept_fullPktCnt[15] || */ept_fullPktCnt[16] || ept_fullPktCnt[17] || ept_fullPktCnt[18] || ept_fullPktCnt[19] 
                                   || ept_fullPktCnt[20] || ept_fullPktCnt[21] || ept_fullPktCnt[22] || ept_fullPktCnt[23] || ept_fullPktCnt[24] 
                                   || ept_fullPktCnt[25] || ept_fullPktCnt[26] || ept_fullPktCnt[27] || ept_fullPktCnt[28] || ept_fullPktCnt[29] 
                                   || ept_fullPktCnt[30] || ept_fullPktCnt[31] ) ? 1'b0 : 1'b1;
   // --------------------------------------------------
   // read data output
   // --------------------------------------------------
	
   always @ (rden_SA,rden_EA,rden_CR1,rden_CR2,rden_wPtr,rden_rPtr,rden_stat,rden_arPtr,rden_fullPktCnt) begin
      // Start Address reading
      if(rden_SA[0] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[0];
      end
      else if(rden_SA[1] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[1];
      end
      else if(rden_SA[2] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[2];
      end
      else if(rden_SA[3] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[3];
      end
      else if(rden_SA[4] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[4];
      end
      else if(rden_SA[5] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[5];
      end
      else if(rden_SA[6] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[6];
      end
      else if(rden_SA[7] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[7];
      end
      else if(rden_SA[8] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[8];
      end
      else if(rden_SA[9] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[9];
      end
      else if(rden_SA[10] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[10];
      end
      else if(rden_SA[11] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[11];
      end
      else if(rden_SA[12] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[12];
      end
      else if(rden_SA[13] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[13];
      end
      else if(rden_SA[14] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[14];
      end
      else if(rden_SA[15] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[15];
      end
      else if(rden_SA[16] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[16];
      end
      else if(rden_SA[17] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[17];
      end
      else if(rden_SA[18] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[18];
      end
      else if(rden_SA[19] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[19];
      end
      else if(rden_SA[20] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[20];
      end
      else if(rden_SA[21] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[21];
      end
      else if(rden_SA[22] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[22];
      end
      else if(rden_SA[23] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[23];
      end
      else if(rden_SA[24] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[24];
      end
      else if(rden_SA[25] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[25];
      end
      else if(rden_SA[26] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[26];
      end
      else if(rden_SA[27] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[27];
      end
      else if(rden_SA[28] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[28];
      end
      else if(rden_SA[29] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[29];
      end
      else if(rden_SA[30] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[30];
      end
      else if(rden_SA[31] == 1'b1)begin
         eptd2cmd_rdData      = ept_SA[31];
      end

      // End address reading
      else if(rden_EA[0] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[0];
      end
      else if(rden_EA[1] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[1];
      end
      else if(rden_EA[2] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[2];
      end
      else if(rden_EA[3] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[3];
      end
      else if(rden_EA[4] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[4];
      end
      else if(rden_EA[5] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[5];
      end
      else if(rden_EA[6] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[6];
      end
      else if(rden_EA[7] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[7];
      end
      else if(rden_EA[8] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[8];
      end
      else if(rden_EA[9] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[9];
      end
      else if(rden_EA[10] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[10];
      end
      else if(rden_EA[11] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[11];
      end
      else if(rden_EA[12] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[12];
      end
      else if(rden_EA[13] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[13];
      end
      else if(rden_EA[14] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[14];
      end
      else if(rden_EA[15] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[15];
      end
      else if(rden_EA[16] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[16];
      end
      else if(rden_EA[17] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[17];
      end
      else if(rden_EA[18] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[18];
      end
      else if(rden_EA[19] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[19];
      end
      else if(rden_EA[20] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[20];
      end
      else if(rden_EA[21] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[21];
      end
      else if(rden_EA[22] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[22];
      end
      else if(rden_EA[23] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[23];
      end
      else if(rden_EA[24] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[24];
      end
      else if(rden_EA[25] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[25];
      end
      else if(rden_EA[26] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[26];
      end
      else if(rden_EA[27] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[27];
      end
      else if(rden_EA[28] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[28];
      end
      else if(rden_EA[29] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[29];
      end
      else if(rden_EA[30] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[30];
      end
      else if(rden_EA[31] == 1'b1)begin
         eptd2cmd_rdData      = ept_EA[31];
      end

      // Control Register 1 reading
      else if(rden_CR1[0] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[0];
      end
      else if(rden_CR1[1] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[1];
      end
      else if(rden_CR1[2] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[2];
      end
      else if(rden_CR1[3] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[3];
      end
      else if(rden_CR1[4] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[4];
      end
      else if(rden_CR1[5] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[5];
      end
      else if(rden_CR1[6] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[6];
      end
      else if(rden_CR1[7] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[7];
      end
      else if(rden_CR1[8] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[8];
      end
      else if(rden_CR1[9] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[9];
      end
      else if(rden_CR1[10] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[10];
      end
      else if(rden_CR1[11] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[11];
      end
      else if(rden_CR1[12] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[12];
      end
      else if(rden_CR1[13] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[13];
      end
      else if(rden_CR1[14] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[14];
      end
      else if(rden_CR1[15] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[15];
      end
      else if(rden_CR1[16] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[16];
      end
      else if(rden_CR1[17] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[17];
      end
      else if(rden_CR1[18] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[18];
      end
      else if(rden_CR1[19] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[19];
      end
      else if(rden_CR1[20] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[20];
      end
      else if(rden_CR1[21] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[21];
      end
      else if(rden_CR1[22] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[22];
      end
      else if(rden_CR1[23] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[23];
      end
      else if(rden_CR1[24] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[24];
      end
      else if(rden_CR1[25] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[25];
      end
      else if(rden_CR1[26] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[26];
      end
      else if(rden_CR1[27] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[27];
      end
      else if(rden_CR1[28] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[28];
      end
      else if(rden_CR1[29] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[29];
      end
      else if(rden_CR1[30] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[30];
      end
      else if(rden_CR1[31] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR1[31];
      end

      // Control Register 2 reading
      else if(rden_CR2[0] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[0];
      end
      else if(rden_CR2[1] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[1];
      end
      else if(rden_CR2[2] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[2];
      end
      else if(rden_CR2[3] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[3];
      end
      else if(rden_CR2[4] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[4];
      end
      else if(rden_CR2[5] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[5];
      end
      else if(rden_CR2[6] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[6];
      end
      else if(rden_CR2[7] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[7];
      end
      else if(rden_CR2[8] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[8];
      end
      else if(rden_CR2[9] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[9];
      end
      else if(rden_CR2[10] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[10];
      end
      else if(rden_CR2[11] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[11];
      end
      else if(rden_CR2[12] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[12];
      end
      else if(rden_CR2[13] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[13];
      end
      else if(rden_CR2[14] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[14];
      end
      else if(rden_CR2[15] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[15];
      end
      else if(rden_CR2[16] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[16];
      end
      else if(rden_CR2[17] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[17];
      end
      else if(rden_CR2[18] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[18];
      end
      else if(rden_CR2[19] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[19];
      end
      else if(rden_CR2[20] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[20];
      end
      else if(rden_CR2[21] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[21];
      end
      else if(rden_CR2[22] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[22];
      end
      else if(rden_CR2[23] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[23];
      end
      else if(rden_CR2[24] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[24];
      end
      else if(rden_CR2[25] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[25];
      end
      else if(rden_CR2[26] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[26];
      end
      else if(rden_CR2[27] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[27];
      end
      else if(rden_CR2[28] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[28];
      end
      else if(rden_CR2[29] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[29];
      end
      else if(rden_CR2[30] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[30];
      end
      else if(rden_CR2[31] == 1'b1)begin
         eptd2cmd_rdData      = ept_CR2[31];
      end

      // Write pointer reading
      else if(rden_wPtr[0] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[0];
      end
      else if(rden_wPtr[1] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[1];
      end
      else if(rden_wPtr[2] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[2];
      end
      else if(rden_wPtr[3] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[3];
      end
      else if(rden_wPtr[4] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[4];
      end
      else if(rden_wPtr[5] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[5];
      end
      else if(rden_wPtr[6] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[6];
      end
      else if(rden_wPtr[7] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[7];
      end
      else if(rden_wPtr[8] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[8];
      end
      else if(rden_wPtr[9] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[9];
      end
      else if(rden_wPtr[10] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[10];
      end
      else if(rden_wPtr[11] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[11];
      end
      else if(rden_wPtr[12] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[12];
      end
      else if(rden_wPtr[13] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[13];
      end
      else if(rden_wPtr[14] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[14];
      end
      else if(rden_wPtr[15] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[15];
      end
      else if(rden_wPtr[16] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[16];
      end
      else if(rden_wPtr[17] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[17];
      end
      else if(rden_wPtr[18] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[18];
      end
      else if(rden_wPtr[19] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[19];
      end
      else if(rden_wPtr[20] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[20];
      end
      else if(rden_wPtr[21] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[21];
      end
      else if(rden_wPtr[22] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[22];
      end
      else if(rden_wPtr[23] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[23];
      end
      else if(rden_wPtr[24] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[24];
      end
      else if(rden_wPtr[25] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[25];
      end
      else if(rden_wPtr[26] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[26];
      end
      else if(rden_wPtr[27] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[27];
      end
      else if(rden_wPtr[28] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[28];
      end
      else if(rden_wPtr[29] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[29];
      end
      else if(rden_wPtr[30] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[30];
      end
      else if(rden_wPtr[31] == 1'b1)begin
         eptd2cmd_rdData      = ept_wPtr[31];
      end

      // Read Pointer 
      else if(rden_rPtr[0] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[0];
      end
      else if(rden_rPtr[1] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[1];
      end
      else if(rden_rPtr[2] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[2];
      end
      else if(rden_rPtr[3] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[3];
      end
      else if(rden_rPtr[4] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[4];
      end
      else if(rden_rPtr[5] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[5];
      end
      else if(rden_rPtr[6] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[6];
      end
      else if(rden_rPtr[7] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[7];
      end
      else if(rden_rPtr[8] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[8];
      end
      else if(rden_rPtr[9] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[9];
      end
      else if(rden_rPtr[10] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[10];
      end
      else if(rden_rPtr[11] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[11];
      end
      else if(rden_rPtr[12] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[12];
      end
      else if(rden_rPtr[13] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[13];
      end
      else if(rden_rPtr[14] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[14];
      end
      else if(rden_rPtr[15] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[15];
      end
      else if(rden_rPtr[16] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[16];
      end
      else if(rden_rPtr[17] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[17];
      end
      else if(rden_rPtr[18] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[18];
      end
      else if(rden_rPtr[19] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[19];
      end
      else if(rden_rPtr[20] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[20];
      end
      else if(rden_rPtr[21] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[21];
      end
      else if(rden_rPtr[22] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[22];
      end
      else if(rden_rPtr[23] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[23];
      end
      else if(rden_rPtr[24] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[24];
      end
      else if(rden_rPtr[25] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[25];
      end
      else if(rden_rPtr[26] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[26];
      end
      else if(rden_rPtr[27] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[27];
      end
      else if(rden_rPtr[28] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[28];
      end
      else if(rden_rPtr[29] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[29];
      end
      else if(rden_rPtr[30] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[30];
      end
      else if(rden_rPtr[31] == 1'b1)begin
         eptd2cmd_rdData      = ept_rPtr[31];
      end

      // ack Register reading
      else if(rden_arPtr[0] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[0];
      end
      else if(rden_arPtr[1] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[1];
      end
      else if(rden_arPtr[2] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[2];
      end
      else if(rden_arPtr[3] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[3];
      end
      else if(rden_arPtr[4] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[4];
      end
      else if(rden_arPtr[5] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[5];
      end
      else if(rden_arPtr[6] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[6];
      end
      else if(rden_arPtr[7] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[7];
      end
      else if(rden_arPtr[8] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[8];
      end
      else if(rden_arPtr[9] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[9];
      end
      else if(rden_arPtr[10] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[10];
      end
      else if(rden_arPtr[11] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[11];
      end
      else if(rden_arPtr[12] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[12];
      end
      else if(rden_arPtr[13] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[13];
      end
      else if(rden_arPtr[14] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[14];
      end
      else if(rden_arPtr[15] == 1'b1)begin
         eptd2cmd_rdData      = ept_arPtr[15];
      end

      // status Register reading
      else if(rden_stat[0] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[0];
      end
      else if(rden_stat[1] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[1];
      end
      else if(rden_stat[2] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[2];
      end
      else if(rden_stat[3] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[3];
      end
      else if(rden_stat[4] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[4];
      end
      else if(rden_stat[5] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[5];
      end
      else if(rden_stat[6] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[6];
      end
      else if(rden_stat[7] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[7];
      end
      else if(rden_stat[8] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[8];
      end
      else if(rden_stat[9] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[9];
      end
      else if(rden_stat[10] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[10];
      end
      else if(rden_stat[11] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[11];
      end
      else if(rden_stat[12] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[12];
      end
      else if(rden_stat[13] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[13];
      end
      else if(rden_stat[14] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[14];
      end
      else if(rden_stat[15] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[15];
      end
      else if(rden_stat[16] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[16];
      end
      else if(rden_stat[17] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[17];
      end
      else if(rden_stat[18] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[18];
      end
      else if(rden_stat[19] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[19];
      end
      else if(rden_stat[20] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[20];
      end
      else if(rden_stat[21] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[21];
      end
      else if(rden_stat[22] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[22];
      end
      else if(rden_stat[23] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[23];
      end
      else if(rden_stat[24] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[24];
      end
      else if(rden_stat[25] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[25];
      end
      else if(rden_stat[26] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[26];
      end
      else if(rden_stat[27] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[27];
      end
      else if(rden_stat[28] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[28];
      end
      else if(rden_stat[29] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[29];
      end
      else if(rden_stat[30] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[30];
      end
      else if(rden_stat[31] == 1'b1)begin
         eptd2cmd_rdData      = ept_stat[31];
      end
         // full buf count
      else if(rden_fullPktCnt[0] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[0];
      end
      else if(rden_fullPktCnt[1] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[1];
      end
      else if(rden_fullPktCnt[2] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[2];
      end
      else if(rden_fullPktCnt[3] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[3];
      end
      else if(rden_fullPktCnt[4] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[4];
      end
      else if(rden_fullPktCnt[5] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[5];
      end
      else if(rden_fullPktCnt[6] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[6];
      end
      else if(rden_fullPktCnt[7] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[7];
      end
      else if(rden_fullPktCnt[8] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[8];
      end
      else if(rden_fullPktCnt[9] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[9];
      end
      else if(rden_fullPktCnt[10] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[10];
      end
      else if(rden_fullPktCnt[11] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[11];
      end
      else if(rden_fullPktCnt[12] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[12];
      end
      else if(rden_fullPktCnt[13] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[13];
      end
      else if(rden_fullPktCnt[14] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[14];
      end
      else if(rden_fullPktCnt[15] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[15];
      end
      else if(rden_fullPktCnt[16] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[16];
      end
      else if(rden_fullPktCnt[17] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[17];
      end
      else if(rden_fullPktCnt[18] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[18];
      end
      else if(rden_fullPktCnt[19] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[19];
      end
      else if(rden_fullPktCnt[20] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[20];
      end
      else if(rden_fullPktCnt[21] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[21];
      end
      else if(rden_fullPktCnt[22] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[22];
      end
      else if(rden_fullPktCnt[23] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[23];
      end
      else if(rden_fullPktCnt[24] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[24];
      end
      else if(rden_fullPktCnt[25] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[25];
      end
      else if(rden_fullPktCnt[26] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[26];
      end
      else if(rden_fullPktCnt[27] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[27];
      end
      else if(rden_fullPktCnt[28] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[28];
      end
      else if(rden_fullPktCnt[29] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[29];
      end
      else if(rden_fullPktCnt[30] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[30];
      end
      else if(rden_fullPktCnt[31] == 1'b1)begin
         eptd2cmd_rdData       = ept_fullPktCnt[31];
      end
      else begin
         eptd2cmd_rdData      = {32{1'b0}};
      end
	end

   // --------------------------------------------------
   // update register request
   // --------------------------------------------------
  // always @( posedge core_clk, negedge uctl_rst_n ) begin
   always @(*) begin 
      if(epcr2eptd_updtReq == 1'b1)begin
         epcrUpdt         = 1'b1 ;
         eptd2epcr_updtDn = 1'b1 ;
         eptd2sepr_updtDn = 1'b0 ;
         eptd2sept_updtDn = 1'b0 ;
         eptd2epct_updtDn = 1'b0 ;
         epctUpdt         = 1'b0 ;
         septUpdt         = 1'b0 ;
         seprUpdt         = 1'b0 ;
      end
      else if(sepr2eptd_updtReq == 1'b1)begin
         seprUpdt         = 1'b1 ;
         eptd2sepr_updtDn = 1'b1 ;
         eptd2epcr_updtDn = 1'b0 ;
         eptd2sept_updtDn = 1'b0 ;
         eptd2epct_updtDn = 1'b0 ;
         epcrUpdt         = 1'b0 ;
         epctUpdt         = 1'b0 ;
         septUpdt         = 1'b0 ;
      end
      else if(sept2eptd_updtReq == 1'b1)begin
         septUpdt         = 1'b1 ;
         eptd2sept_updtDn = 1'b1 ;
         eptd2epcr_updtDn = 1'b0 ;
         eptd2sepr_updtDn = 1'b0 ;
         eptd2epct_updtDn = 1'b0 ;
         epcrUpdt         = 1'b0 ;
         epctUpdt         = 1'b0 ;
         seprUpdt         = 1'b0 ;
      end
      else if(epct2eptd_updtReq == 1'b1)begin
         epctUpdt         = 1'b1 ;
         eptd2epct_updtDn = 1'b1 ;
         eptd2epcr_updtDn = 1'b0 ;
         eptd2sepr_updtDn = 1'b0 ;
         eptd2sept_updtDn = 1'b0 ;
         epcrUpdt         = 1'b0 ;
         septUpdt         = 1'b0 ;
         seprUpdt         = 1'b0 ;
      end
      else begin
         eptd2epcr_updtDn = 1'b0 ;
         eptd2sepr_updtDn = 1'b0 ;
         eptd2sept_updtDn = 1'b0 ;
         eptd2epct_updtDn = 1'b0 ;
         epcrUpdt         = 1'b0 ;
         epctUpdt         = 1'b0 ;
         septUpdt         = 1'b0 ;
         seprUpdt         = 1'b0 ;
      end
   end

 assign rdWrEn =(((epcr2eptd_updtReq)||(sept2eptd_updtReq))&&((sepr2eptd_updtReq)||(epct2eptd_updtReq)))? 1'b1 : 1'b0;

   // --------------------------------------------------
   // update register request
   // --------------------------------------------------
 /*  //always @( posedge core_clk, negedge uctl_rst_n ) begin
   always @(*) begin 
      if(rdWrEn)begin
         lastOp = WRITE;
      end
      else if((epcr2eptd_updtReq)||(sept2eptd_updtReq))begin 
         lastOp = WRITE;
      end
      else if((sepr2eptd_updtReq)||(epct2eptd_updtReq))begin
         lastOp = READ;
      end
      else begin
         lastOp = READ;
      end
   end*/

   always @( posedge core_clk, negedge uctl_rst_n ) begin
      if(!uctl_rst_n)begin
         lastOp[0] <= READ;
         lastOp[1] <= READ;
         lastOp[2] <= READ;
         lastOp[3] <= READ;
         lastOp[4] <= READ;
         lastOp[5] <= READ;
         lastOp[6] <= READ;
         lastOp[7] <= READ;
         lastOp[8] <= READ;
         lastOp[9] <= READ;
         lastOp[10] <= READ;
         lastOp[11] <= READ;
         lastOp[12] <= READ;
         lastOp[13] <= READ;
         lastOp[14] <= READ;
         lastOp[15] <= READ;
         lastOp[16] <= READ;
         lastOp[17] <= READ;
         lastOp[18] <= READ;
         lastOp[19] <= READ;
         lastOp[20] <= READ;
         lastOp[21] <= READ;
         lastOp[22] <= READ;
         lastOp[23] <= READ;
         lastOp[24] <= READ;
         lastOp[25] <= READ;
         lastOp[26] <= READ;
         lastOp[27] <= READ;
         lastOp[28] <= READ;
         lastOp[29] <= READ;
         lastOp[30] <= READ;
         lastOp[31] <= READ;

      end
      else begin
         if(sept2eptd_updtReq)begin
            lastOp[{1'b1,sept2eptd_epNum}]      <= WRITE;
         end
         if(sepr2eptd_updtReq)begin
            lastOp[{1'b0,sepr2eptd_epNum}]      <= READ ;
         end
         if(epcr2eptd_updtReq)begin
            if(epcr2eptd_dataFlush  ) begin 
               lastOp[{1'b0,epcr2eptd_epNum}]   <= READ ;
            end
            else begin 
               lastOp[{1'b0,epcr2eptd_epNum}]      <= WRITE;
            end
         end
         if(epct2eptd_updtReq)begin
            lastOp[{1'b1,epct2eptd_epNum}]      <= READ ;
         end
      end
   end

   // --------------------------------------------------
   // EPC Wirte Interface
   // --------------------------------------------------
   always @(*) begin
      if ( epcr2eptd_reqData == 1'b1) begin//TODO
         eptd2epcr_wrReqErr  = 1'b0;
      end
      else begin
         eptd2epcr_wrReqErr  = 1'b1;
      end
   end

   assign   eptd2epcr_startAddr   = ept_SA[{1'b0,epcr2eptd_epNum}]          ;
   assign   eptd2epcr_endAddr     = ept_EA[{1'b0,epcr2eptd_epNum}]          ;
   assign   eptd2epcr_rdPtr       = ept_rPtr[{1'b0,epcr2eptd_epNum}]        ;
   assign   eptd2epcr_wrPtr       = ept_wPtr[{1'b0,epcr2eptd_epNum}]        ;
   assign   eptd2epcr_lastOp      = lastOp  [{1'b0,epcr2eptd_epNum}]   ;
   assign   eptd2epcr_exptDataPid = {ept_CR1[{1'b0,epcr2eptd_epNum}][28:27], 2'b11}  ;//TODO: only 2 bits assigned other 2 bits constant
   assign   eptd2epcr_wMaxPktSize = ept_CR1[{1'b0,epcr2eptd_epNum}][24:14]  ;
   assign   eptd2epcr_epType      = ept_CR1[{1'b0,epcr2eptd_epNum}][2:1]    ;
   assign   eptd2epcr_dir         = ept_CR1[{1'b0,epcr2eptd_epNum}][0]      ;
   assign   eptd2epcr_epTrans     = ept_CR1[{1'b0,epcr2eptd_epNum}][26:25]  ;
   assign   eptd2epcr_epHalt      = ept_CR1[{1'b0,epcr2eptd_epNum}][31]     ;
   // --------------------------------------------------
   // EPC Read Interface
   // --------------------------------------------------
   always @(*) begin
      if(epct2eptd_reqData == 1'b1) begin//TODO
         eptd2epct_reqErr  = 1'b0;
      end
      else begin
         eptd2epct_reqErr  = 1'b1;
      end
   end

   assign   eptd2epct_zLenPkt      = ept_CR1[{1'b1,epct2eptd_epNum}][30]    ;
   assign   eptd2epct_startAddr    = ept_SA[{1'b1,epct2eptd_epNum}]         ;
   assign   eptd2epct_endAddr      = ept_EA[{1'b1,epct2eptd_epNum}]         ;
   assign   eptd2epct_rdPtr        = ept_rPtr[{1'b1,epct2eptd_epNum}]       ;
   assign   eptd2epct_wrPtr        = ept_wPtr[{1'b1,epct2eptd_epNum}]       ;
   assign   eptd2epct_lastOp       = lastOp [{1'b1,epct2eptd_epNum}] ;
   assign   eptd2epct_exptDataPid  = {ept_CR1[{1'b1,epct2eptd_epNum}][28:27] , 2'b11};
 //assign   eptd2epct_wMaxPktSize  = ept_CR1[{1'b1,epct2eptd_epNum}][24:14] ;
   assign   eptd2epct_epType       = ept_CR1[{1'b1,epct2eptd_epNum}][2:1]   ;
 //assign   eptd2epct_dir          = ept_CR1[{1'b1,epct2eptd_epNum}][0]     ;
   assign   eptd2epct_epTrans      = ept_CR1[{1'b1,epct2eptd_epNum}][26:25] ;
   assign   eptd2epct_epHalt       = ept_CR1[{1'b1,epct2eptd_epNum}][31]    ;
   // --------------------------------------------------
   // Sys_EPC Write Interface
   // --------------------------------------------------
   always @(*) begin
      if ( sept2eptd_reqData == 1'b1) begin//TODO
         eptd2sept_reqErr = 1'b0;
      end
      else begin
         eptd2sept_reqErr = 1'b1;
      end
   end
   assign   eptd2sept_fullPktCnt   = ept_fullPktCnt[{1'b1,sept2eptd_epNum}] ;
   assign   eptd2sept_startAddr    = ept_SA[{1'b1,sept2eptd_epNum}]         ;
   assign   eptd2sept_endAddr      = ept_EA[{1'b1,sept2eptd_epNum}]         ;
   assign   eptd2sept_rdPtr        = ept_rPtr[{1'b1,sept2eptd_epNum}]       ;
   assign   eptd2sept_wrPtr        = ept_wPtr[{1'b1,sept2eptd_epNum}]       ;
   assign   eptd2sept_lastOp       = lastOp[{1'b1,sept2eptd_epNum}];
   assign   eptd2sept_bSize        = ept_CR1[{1'b1,sept2eptd_epNum}][24:14] ;
   // --------------------------------------------------
   // Sys_EPC Read Interface
   // --------------------------------------------------
   always @(*) begin
      if ( sepr2eptd_reqData == 1'b1) begin//TODO
         eptd2sepr_ReqErr = 1'b0;
      end
      else begin
         eptd2sepr_ReqErr = 1'b1;
      end
   end
    assign    eptd2sepr_fullPktCnt   = ept_fullPktCnt[{1'b0,sepr2eptd_epNum}] ;  
  assign    eptd2sepr_startAddr    = ept_SA[{1'b0,sepr2eptd_epNum}]         ;
  assign    eptd2sepr_endAddr      = ept_EA[{1'b0,sepr2eptd_epNum}]         ;
  assign    eptd2sepr_rdPtr        = ept_rPtr[{1'b0,sepr2eptd_epNum}]       ;
  assign    eptd2sepr_wrPtr        = ept_wPtr[{1'b0,sepr2eptd_epNum}]       ;
  assign    eptd2sepr_lastOp       = lastOp[{1'b0,sepr2eptd_epNum}]; 
endmodule
