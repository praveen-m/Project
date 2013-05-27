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
// DATE		   	: Wed, 24 Apr 2013 16:45:03
// AUTHOR	      : Sanjeeva
// AUTHOR EMAIL	: sanjeeva.n@techvulcan.com
// FILE NAME		: uctl_cmdInfMem.v
// Version no.    : 0.1
//-------------------------------------------------------------------
module uctl_cmdInfMem #(
parameter
  `include "../rtl/uctl_top.vh" 
)
(
   input  wire                    sys_clk          ,
   input  wire                    sysRst_n         ,
   input  wire                    core_clk         ,
   input  wire                    uctl_rst_n       ,
   input  wire                    sw_rst           ,

   //----------------------------------------------
   // Cmd IF
   //----------------------------------------------
   input  wire                    cmdIf_trEn       ,
   input  wire                    cmdIf_req        ,
   input  wire [31            :0] cmdIf_addr       ,
   input  wire                    cmdIf_wrRd       ,
   output wire                    cmdIf_ack        ,

   input  wire                    cmdIf_wrData_req ,
   input  wire [31            :0] cmdIf_wrData     ,
   output wire                    cmdIf_wrData_ack ,
   input wire  [21            :0] reg2cmdIf_memSegAddr,
   input  wire                    cmdIf_rdData_req ,
   output wire                    cmdIf_rdData_ack ,
   output wire [31            :0] cmdIf_rdData     ,


   //----------------------------------------------
   // memory interface
   //----------------------------------------------
   output wire                    mem_req          ,        
   output wire                    mem_wrRd         ,
   output wire [31            :0] mem_addr         ,                          
   output wire [31            :0] mem_wrData       ,   
   input  wire                    mem_ack          ,
   input  wire                    mem_rdVal        ,
   input  wire [31            :0] mem_rdData       ,

   //-----------------------------------------------
   // sept interface
   //-----------------------------------------------
   output wire                    cmdIf2sept_dn          ,
   input  wire                    sept2cmdIf_wr          , 
   input  wire [2             :0] sept2cmdIf_dmaMode     ,   
   input  wire [31            :0] sept2cmdIf_addr        ,//local buffer address
   input  wire [19            :0] sept2cmdIf_len         ,
   input  wire [31            :0] sept2cmdIf_epStartAddr ,
   input  wire [31            :0] sept2cmdIf_epEndAddr   ,
   
   //-----------------------------------------------
   // sepr interface
   //-----------------------------------------------
   output wire                    cmdIf2sepr_dn          ,
   input  wire                    sepr2cmdIf_rd          , 
   input  wire [2             :0] sepr2cmdIf_dmaMode     ,   
   input  wire [31            :0] sepr2cmdIf_addr        ,//local buffer address
   input  wire [19            :0] sepr2cmdIf_len         ,
   input  wire [31            :0] sepr2cmdIf_epStartAddr ,
   input  wire [31            :0] sepr2cmdIf_epEndAddr   
);

   generate begin
      if (SYS_CORE_SYNC == 1) begin

         uctl_cmdIfMif i_uctl_cmdIfMif (
            .sys_clk                    ( sys_clk               ),              
            .sysRst_n                   ( sysRst_n              ),   
            .sw_rst                     ( sw_rst                ),  
            .cmdIf_trEn                 ( cmdIf_trEn            ),  
            .cmdIf_req                  ( cmdIf_req             ),  
            .cmdIf_addr                 ( cmdIf_addr            ),  
            .cmdIf_wrRd                 ( cmdIf_wrRd            ),  
            .cmdIf_ack                  ( cmdIf_ack             ),  
            .reg2cmdIf_memSegAddr       (reg2cmdIf_memSegAddr   ),
            .cmdIf_wrData_req           ( cmdIf_wrData_req      ),  
            .cmdIf_wrData               ( cmdIf_wrData          ),  
            .cmdIf_wrData_ack           ( cmdIf_wrData_ack      ),  
           
            .cmdIf_rdData_req           ( cmdIf_rdData_req      ),  
            .cmdIf_rdData_ack           ( cmdIf_rdData_ack      ),  
            .cmdIf_rdData               ( cmdIf_rdData          ),  
            
            .mem_req                    ( mem_req               ),  
            .mem_wrRd                   ( mem_wrRd              ),  
            .mem_addr                   ( mem_addr              ),  
            .mem_wrData                 ( mem_wrData            ),  
            .mem_ack                    ( mem_ack               ),  
            .mem_rdVal                  ( mem_rdVal             ),  
            .mem_rdData                 ( mem_rdData            ),  
            
            .cmdIf2sept_dn              ( cmdIf2sept_dn         ),  
            .sept2cmdIf_wr              ( sept2cmdIf_wr         ),  
            .sept2cmdIf_dmaMode         ( sept2cmdIf_dmaMode    ),  
            .sept2cmdIf_addr            ( sept2cmdIf_addr       ),  
            .sept2cmdIf_len             ( sept2cmdIf_len        ),  
            .sept2cmdIf_epStartAddr     ( sept2cmdIf_epStartAddr),  
            .sept2cmdIf_epEndAddr       ( sept2cmdIf_epEndAddr  ),  
            
            .cmdIf2sepr_dn              ( cmdIf2sepr_dn         ),  
            .sepr2cmdIf_rd              ( sepr2cmdIf_rd         ),  
            .sepr2cmdIf_dmaMode         ( sepr2cmdIf_dmaMode    ),  
            .sepr2cmdIf_addr            ( sepr2cmdIf_addr       ),  
            .sepr2cmdIf_len             ( sepr2cmdIf_len        ),  
            .sepr2cmdIf_epStartAddr     ( sepr2cmdIf_epStartAddr),  
            .sepr2cmdIf_epEndAddr       ( sepr2cmdIf_epEndAddr  )  
         );
      end
      else begin
         uctl_cmdIfMemif_async i_uctl_cmdIfMemif_async (
            .sys_clk                    ( sys_clk               ),              
            .sysRst_n                   ( sysRst_n              ),   
            .core_clk                   ( core_clk              ),              
            .uctl_rst_n                 ( uctl_rst_n            ), 
          
            .cmdIf_trEn                 ( cmdIf_trEn            ),  
            .cmdIf_req                  ( cmdIf_req             ),  
            .cmdIf_addr                 ( cmdIf_addr            ),  
            .cmdIf_wrRd                 ( cmdIf_wrRd            ),  
            .cmdIf_ack                  ( cmdIf_ack             ),  
            
            .cmdIf_wrData_req           ( cmdIf_wrData_req      ),  
            .cmdIf_wrData               ( cmdIf_wrData          ),  
            .cmdIf_wrData_ack           ( cmdIf_wrData_ack      ),  
             
            .cmdIf_rdData_req           ( cmdIf_rdData_req      ),  
            .cmdIf_rdData_ack           ( cmdIf_rdData_ack      ),  
            .cmdIf_rdData               ( cmdIf_rdData          ),  
           
            .mem_req                    ( mem_req               ),  
            .mem_wrRd                   ( mem_wrRd              ),  
            .mem_addr                   ( mem_addr              ),  
            .mem_wrData                 ( mem_wrData            ),  
            .mem_ack                    ( mem_ack               ),  
            .mem_rdVal                  ( mem_rdVal             ),  
            .mem_rdData                 ( mem_rdData            ),  
           
            .cmdIf2sept_dn              ( cmdIf2sept_dn         ),  
            .sept2cmdIf_wr              ( sept2cmdIf_wr         ),  
            .sept2cmdIf_dmaMode         ( sept2cmdIf_dmaMode    ),  
            .sept2cmdIf_addr            ( sept2cmdIf_addr       ),  
            .sept2cmdIf_len             ( sept2cmdIf_len        ),  
            .sept2cmdIf_epStartAddr     ( sept2cmdIf_epStartAddr),  
            .sept2cmdIf_epEndAddr       ( sept2cmdIf_epEndAddr  ),  
           
            .cmdIf2sepr_dn              ( cmdIf2sepr_dn         ),  
            .sepr2cmdIf_rd              ( sepr2cmdIf_rd         ),  
            .sepr2cmdIf_dmaMode         ( sepr2cmdIf_dmaMode    ),  
            .sepr2cmdIf_addr            ( sepr2cmdIf_addr       ),  
            .sepr2cmdIf_len             ( sepr2cmdIf_len        ),  
            .sepr2cmdIf_epStartAddr     ( sepr2cmdIf_epStartAddr),  
            .sepr2cmdIf_epEndAddr       ( sepr2cmdIf_epEndAddr  )  
         );
      end
	end
   endgenerate
endmodule
