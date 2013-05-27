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
// DATE		   	: Tue, 26 Feb 2013 12:47:42
// AUTHOR	      : Lalit Kumar
// AUTHOR EMAIL	: lalit.kumar@techvulcan.com
// FILE NAME		: uctl_bankSel.v
// VERSION        : 0.1
//-------------------------------------------------------------------

module uctl_bankSel (
   input  wire [2       -1:0] uctl_offsetAddr   ,  // 3,2 lsb of address
   input  wire                uctl_req          , 
   input  wire [4       -1:0] uctl_bankAck      ,
   input  wire [4       -1:0] uctl_bankDVl      ,
   output wire [4       -1:0] uctl_bankReq      ,   // request to each bang
   output wire                uctl_rdAck        ,
   output wire                uctl_dValid   
   );

   assign uctl_bankReq    = uctl_req<< uctl_offsetAddr;
   assign uctl_rdAck      = |uctl_bankAck        ;
   assign uctl_dValid     = |uctl_bankDVl        ;
endmodule

   
