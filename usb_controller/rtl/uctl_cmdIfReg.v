`timescale 1ns / 1ps
//-------------------------------------------------------------------
// Copyright © 2013 TECHVULCAN, Inc. All rights reserved.   
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, nor   
// its contents   
// revealed in any manner to others without the express written   
// permission of TechVulcan    
// Licensed Material.   
// Program Property of TECHVULCAN Incorporated.
// ------------------------------------------------------------------
// DATE           : Sun, 03 Mar 2013 20:00:39
// AUTHOR         : Darshan Naik
// AUTHOR EMAIL   : darshan.naik@techvulcan.com
// FILE NAME      : uctl_cmdIfReg.v
// Version        : 0.2      
//-------------------------------------------------------------------


// VERSION        : 0.2 
//                   state machine added  
// VERSION        : 0.1 
//                   intial release

/* TODO

*/

//-------------------------------------------------------------------
//-------------------------------------------------------------------

module uctl_cmdIfReg #(
           parameter START_EPT_HADDR   =32'h00_0920,
           parameter END_EPT_HADDR     =32'h00_0D1F,
           parameter START_REG_HADDR1  =32'h00_0800,  
           parameter END_REG_HADDR1    =32'h00_091B   
            
)(
   
   input  wire                       sys_clk          ,
   input  wire                       sysRst_n         ,
   input  wire                       sw_rst           ,
 
   //----------------------------------------------
   // cmd interface
   //----------------------------------------------
   
   input  wire                       cmdIf_trEn       ,
   input  wire                       cmdIf_req        ,
   input  wire [31               :0] cmdIf_addr       ,
   input  wire                       cmdIf_wrRd       ,
   output reg                        cmdIf_ack        ,

   input  wire                       cmdIf_wrData_req ,
   input  wire [31               :0] cmdIf_wrData     ,
   output reg                        cmdIf_wrData_ack ,

   input  wire                       cmdIf_rdData_req ,
   output wire                       cmdIf_rdData_ack ,
   output wire [31               :0] cmdIf_rdData     ,

   

   //----------------------------------------------
   // register interface
   //----------------------------------------------
  
   input  wire [31               :0] reg2cmd_rdData   ,
   output reg                        cmd2reg_wrReq    ,
   output reg                        cmd2reg_rdReq    ,        
   output wire [31               :0] cmd2reg_wrData   ,
   output wire [31               :0] cmd2reg_addr     ,
   
   //----------------------------------------------
   // endpoin data interface
   //----------------------------------------------
  
   input  wire [31               :0] eptd2cmd_rdData  ,
   output reg                        cmd2eptd_wrReq   ,
   output reg                        cmd2eptd_rdReq   ,        
   output wire [31               :0] cmd2eptd_wrData  ,
   output wire [31               :0] cmd2eptd_addr
   
   );                          
   
   localparam  BYTE     =3'b000,
               HWORD    =3'b001,
               WORD     =3'b010;

   localparam  IDLE     =2'b00 ,
               REG_CTRL =2'b01 ,
               EPTD_CTRL=2'b10 ;   
   
   reg [31                 :0] data_eptd_r   ;  
   reg [31                 :0] data_regBk_r  ;
   reg [31                 :0] addr_r        ;
   reg [1                  :0] cur_state     ;
   reg [1                  :0] next_state    ;   
   reg                         addr_ld       ;
   reg                         addr_incr     ;    
   reg                         rd_fr_reg     ;  
   reg                         eptd_data_ld  ;
   reg                         regBk_data_ld ;
   reg                         regBk_ack     ;
   reg                         eptd_ack      ;
   reg                         rdData_ack    ;    
 

   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n) begin
         addr_r <= {32{1'b0}};
      end
      else begin
         if(addr_ld) begin
            addr_r <= cmdIf_addr;
         end
         else if(addr_incr) begin
            addr_r <= addr_r+ 3'b100;
         end
      end
   end

   
   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n) begin
         data_eptd_r <= {32{1'b0}};
      end
      else begin
         if(eptd_data_ld) begin
            data_eptd_r <= eptd2cmd_rdData;
         end
      end
   end

   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n) begin
         data_regBk_r <= {32{1'b0}};
      end
      else begin
         if(regBk_data_ld) begin
            data_regBk_r <= reg2cmd_rdData;
         end
      end
   end

   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n) begin
         rdData_ack <= 1'b0;
      end
      else begin
         if(regBk_ack) begin
            rdData_ack <= 1'b1;
         end
         else if (eptd_ack) begin
            rdData_ack <= 1'b1;
         end
         else begin
            rdData_ack <= 1'b0;
         end
      end
   end
   
   assign cmd2eptd_addr    = addr_r       ;
   assign cmd2reg_addr     = addr_r       ;

   // write operation
   assign cmd2reg_wrData   = cmdIf_wrData ;  
   
   assign cmd2eptd_wrData  = cmdIf_wrData ;
   
   //read operation   
   
   assign cmdIf_rdData     = rd_fr_reg ?   data_regBk_r :   data_eptd_r ;
   
   assign cmdIf_rdData_ack = rdData_ack;
   
   
   always @(posedge sys_clk or negedge sysRst_n) begin   
      if(!sysRst_n) begin   
         cur_state <= IDLE;
      end
      else if(sw_rst) begin
         cur_state <= IDLE;   
      end
      else begin
         cur_state <= next_state;
      end
   end 

   always @ (*) begin
      next_state        = cur_state;
      cmdIf_ack         = 1'b0;
      addr_ld           = 1'b0;
      addr_incr         = 1'b0;
      rd_fr_reg         = 1'b0;
      cmd2reg_rdReq     = 1'b0;
      cmdIf_wrData_ack  = 1'b0;
      cmd2reg_wrReq     = 1'b0;
      cmd2eptd_rdReq    = 1'b0;
      cmd2eptd_wrReq    = 1'b0;
      eptd_data_ld      = 1'b0;
      regBk_data_ld     = 1'b0;
      regBk_ack         = 1'b0; 
      eptd_ack          = 1'b0;
      case(cur_state)
         IDLE : begin
            if(cmdIf_trEn && cmdIf_req) begin
               if ((cmdIf_addr >= START_EPT_HADDR) && (cmdIf_addr <=END_EPT_HADDR)) begin
                  cmdIf_ack   = 1'b1;
                  addr_ld     = 1'b1;  
                  next_state  = EPTD_CTRL;   
               end
               else if ((cmdIf_addr >= START_REG_HADDR1) && (cmdIf_addr <=END_REG_HADDR1)) begin
                  cmdIf_ack   = 1'b1;
                  addr_ld     = 1'b1;                    
                  next_state  = REG_CTRL;
               end
            end
         end
         
         REG_CTRL : begin
            if(cmdIf_trEn && cmdIf_wrData_req) begin
               addr_incr         = 1'b1;
               cmdIf_wrData_ack  = 1'b1;
               cmd2reg_wrReq     = 1'b1;
            end
            else if (cmdIf_trEn && cmdIf_rdData_req) begin
               rd_fr_reg         = 1'b1;
               regBk_data_ld     = 1'b1;
               regBk_ack         = 1'b1;
               cmd2reg_rdReq     = 1'b1;
               if(rdData_ack) begin
                  addr_incr         = 1'b1;
                  regBk_ack         = 1'b0;
               end
            end
            else if(cmdIf_trEn && cmdIf_req) begin
               if ((cmdIf_addr >= START_EPT_HADDR) && (cmdIf_addr <=END_EPT_HADDR)) begin
                  cmdIf_ack   = 1'b1;
                  addr_ld     = 1'b1;                  
                  next_state  = EPTD_CTRL;   
               end
               else if ((cmdIf_addr >= START_REG_HADDR1) && (cmdIf_addr <=END_REG_HADDR1)) begin
                  cmdIf_ack   = 1'b1;
                  addr_ld     = 1'b1;                 
               end
            end
            else begin
               next_state  =IDLE;   
            end
         end

         EPTD_CTRL : begin
            if(cmdIf_trEn && cmdIf_wrData_req) begin
               addr_incr         = 1'b1;
               cmdIf_wrData_ack  = 1'b1;
               cmd2eptd_wrReq    = 1'b1;
            end
            else if (cmdIf_trEn && cmdIf_rdData_req) begin
               eptd_data_ld      = 1'b1;
               eptd_ack          = 1'b1;
               cmd2eptd_rdReq    = 1'b1;
               if(rdData_ack) begin
                  addr_incr         = 1'b1;
                  eptd_ack          = 1'b0;
               end
            end
            else if(cmdIf_trEn && cmdIf_req) begin
               if ((cmdIf_addr >= START_EPT_HADDR) && (cmdIf_addr <=END_EPT_HADDR)) begin
                  cmdIf_ack   = 1'b1;
                  addr_ld     = 1'b1;                     
               end
               else if ((cmdIf_addr >= START_REG_HADDR1) && (cmdIf_addr <=END_REG_HADDR1)) begin
                  cmdIf_ack   = 1'b1;
                  addr_ld     = 1'b1;   
                  next_state  = REG_CTRL;               
               end
            end
            else begin
               next_state  =IDLE;   
            end
         end

         default :  next_state        = cur_state;
      
      endcase
   end
        
endmodule 
  
