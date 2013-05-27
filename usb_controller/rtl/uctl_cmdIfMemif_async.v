`timescale 1ns / 1ps
//-------------------------------------------------------------------//
// Copyright © 2013 TECHVULCAN, Inc. All rights reserved.   
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, nor   
// its contents   
// revealed in any manner to others without the express written   
// permission of TechVulcan    
// Licensed Material.   
// Program Property of TECHVULCAN Incorporated.
// ------------------------------------------------------------------//
// DATE           : Thu; 18 Apr 2013 16:29:51
// AUTHOR         : M B Sharath Kumar
// AUTHOR EMAIL   : sharath.kumar@techvulcan.com
// FILE NAME      : uctl_cmdIfMemif_async.v
//------------------------------------------------------------------//


module uctl_cmdIfMemif_async #(
      parameter START_MEM_HADDR   =32'h0_0000, 
      parameter END_MEM_HADDR     =32'h0_03FC
)     
(
   
   input  wire                       sys_clk             ,
   input  wire                       core_clk            ,
   input  wire                       sysRst_n            ,
   input  wire                       uctl_rst_n          ,

   //----------------------------------------------//
   //          Command Interface signals
   //----------------------------------------------//
   input  wire                       cmdIf_trEn          ,
   input  wire                       cmdIf_req           ,
   input  wire  [31              :0] cmdIf_addr          ,
   input  wire                       cmdIf_wrRd          ,
   output reg                        cmdIf_ack           ,

   input  wire                       cmdIf_wrData_req    ,
   input  wire  [31              :0] cmdIf_wrData        ,
   output reg                        cmdIf_wrData_ack    ,

   input  wire                       cmdIf_rdData_req    ,
   output reg                        cmdIf_rdData_ack    ,
   output wire  [31              :0] cmdIf_rdData,


   //----------------------------------------------//
   //             memory interface
   //----------------------------------------------//
   output wire                       mem_req             ,        
   output reg                        mem_wrRd            ,
   output reg   [31              :0] mem_addr            ,                          
   output wire  [31              :0] mem_wrData          ,   
   input  wire                       mem_ack             ,
   input  wire                       mem_rdVal           ,
   input  wire  [31              :0] mem_rdData          ,

   //-----------------------------------------------
   // sept interface
   //-----------------------------------------------
   output reg                        cmdIf2sept_dn          ,
   input  wire                       sept2cmdIf_wr          , 
   input  wire [2                :0] sept2cmdIf_dmaMode     ,   
   input  wire [31               :0] sept2cmdIf_addr        ,//local buffer address
   input  wire [19               :0] sept2cmdIf_len         ,
   input  wire [31               :0] sept2cmdIf_epStartAddr ,
   input  wire [31               :0] sept2cmdIf_epEndAddr   ,
   
   //-----------------------------------------------
   // sepr interface
   //-----------------------------------------------
   output reg                        cmdIf2sepr_dn          ,
   input  wire                       sepr2cmdIf_rd          , 
   input  wire [2                :0] sepr2cmdIf_dmaMode     ,   
   input  wire [31               :0] sepr2cmdIf_addr        ,//local buffer address
   input  wire [19               :0] sepr2cmdIf_len         ,
   input  wire [31               :0] sepr2cmdIf_epStartAddr ,
   input  wire [31               :0] sepr2cmdIf_epEndAddr   
   
   );
   
   localparam  S_IDLE      =  2'b00 ,
               S_WAIT4ACK  =  2'b01 ,
               S_TRSFR     =  2'b10 ;

   localparam  C_IDLE      =  2'b00 ,
               C_WAIT      =  2'b01 ,
               C_WTRSFR    =  2'b10 ,
               C_RTRSFR    =  2'b11 ;
               
   localparam  SEPT_IDLE   =  1'b0  ,
               SEPT_TRANS  =  1'b1  ;
 
   localparam  SEPR_IDLE   =  1'b0  ,
               SEPR_TRANS  =  1'b1  ;
 
   reg  [1              :0] sys_next_state      ;        //   Sys clk states       
   reg  [1              :0] sys_curr_state      ;        //   
   reg  [1              :0] core_next_state     ;        //   Core clk states 
   reg  [1              :0] core_curr_state     ;        //   
   reg                      sept_next_state     ;        //   System End Point Tx states
   reg                      sept_curr_state     ;        //   
   reg                      sepr_next_state     ;        //   System End POint Rx states
   reg                      sepr_curr_state     ;        //   
   reg                      ld_addr_reg_nxt     ;        //   Comb-signal to store addr at the sys clk 
   reg                      ld_addr_reg         ;        //   Reg the above signal
   wire                     ld_addr_reg_nxt_s2c ;        //   Addr load signal synchronized to the core clk
   reg                      mem_addr_reg_ld     ;        //   Memory addr load signal at the core clk
   reg                      mem2cmdIf_ack       ;        //   Ack signal generated at the core clk for cmdIf_req
   wire                     cmdIf_ack_c2s       ;        //   Ack signal synchronized to the sys clk
   reg                      wrfifo_wr_req       ;        //   Write fifo write request
   reg                      wrfifo_rd_req       ;        //   Write fifo read request
   wire                     wrfifo_empty        ;        //   Write fifo empty
   wire                     wrfifo_full         ;        //   Write fifo full
   reg                      rdfifo_wr_req       ;        //   Read fifo write request
   reg                      rdfifo_rd_req       ;        //   Read fifo read request
   wire                     rdfifo_empty        ;        //   Read fifo empty
   wire                     rdfifo_full         ;        //   Read fifo full
   wire [32            :0] wrfifo_data_out      ;        //   Write fifo data out
   wire [32            :0] wrfifo_data_in       ;        //   Write fifo data in
   wire [31            :0] rdfifo_data_out      ;        //   Read fifo data out 
   wire [31            :0] rdfifo_data_in       ;        //   Read fifo data in
   wire                    cmdIf_trEn_mem       ;        //   Transfer Enable signal to the memory  
   reg  [31            :0] mem_addr_inc         ;        //   Addr bus incrementing in count of 4
   wire                    wmem_addr_inc        ;        //   Write addr increment enable signal
   wire                    rmem_addr_inc        ;        //   Read addr increment enable signal
   reg                     memIf                ;        //   Signal to check the addr range to memory  
   reg                     mem_wr               ;        //   Comb-signal to store the W/R transaction at core clk  
   reg                     mem_wr_q             ;        //   Reg for the above signal  
   reg                     cmd_wr_req_q         ;        //   Reg to store the W/R transaction at the sys clk
   reg                     last_wr              ;        //   signal to indicate the final W transaction at sys clk  
   wire                    trans_end            ;        //   Stores the MSB of wrfifo_data_out
   reg                     rdfifo_rst_n         ;        //   Reset to flush the Read fifo before the new Read
   wire                    rdfifo_sysRst_n      ;        //   System clock side reset for Read fifo   
   wire                    rdfifo_uctl_rst_n    ;        //   Core clock side reset for Read fifo  
   wire                    rdfifo_nearly_full   ;        //   Indicates the almost full condition of Read fifo
   reg  [19            :0] sept_len_q           ;        //   Counter to update the done signal to the sept
   reg                     sept_len_decr        ;        //   Enable signal to decrement the above signal
   reg  [19            :0] sepr_len_q           ;        //   counter to update the done signal to the sepr
   reg                     sepr_len_decr        ;        //   Enable signal to decrement the above signal
   reg                     wrmem_req            ;        //   Indicates the mem_req due to Write transaction
   wire                    rdmem_req            ;        //   Indicates the mem_req due to Read transaction
   reg                     rdmem_req_q          ;        //   Read req generated by set and clr flags
   reg                     rdmem_req_temp       ;        //   Read req during read fifo NOT nearly full 
   reg                     set_rdmem_req        ;        //   Set Read req flag when mem_req=0 and mem_ack=1 due to read nearly full
   reg                     clr_rdmem_req        ;        //   Clr Read req flag when mem_ack=1 after read nearly full goes low

   //----------------------------------------------//
   //      Load and increment addr input core clk
   //----------------------------------------------//
  
   always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         mem_addr    <=    {32{1'b0}};
      end
      else if(mem_addr_reg_ld) begin
         if (sept2cmdIf_dmaMode == 3'b000 || sepr2cmdIf_dmaMode == 3'b000) begin
            mem_addr    <=    cmdIf_addr;
         end
      //    Condition when both the modes are External DMA
         else if (sept2cmdIf_dmaMode == 3'b001 && sepr2cmdIf_dmaMode == 3'b001) begin
            if (cmdIf_wrRd) begin
               mem_addr    <=    sept2cmdIf_addr;
            end
            else begin 
               mem_addr    <=    sepr2cmdIf_addr;
            end
         end
         else if (sept2cmdIf_dmaMode == 3'b001) begin
            mem_addr    <=    sept2cmdIf_addr;
         end
         else if (sepr2cmdIf_dmaMode == 3'b001) begin
            mem_addr    <=    sepr2cmdIf_addr;
         end
      end
      else begin
         mem_addr    <=    mem_addr_inc;
      end
   end

   assign cmdIf_rdData     =  rdfifo_data_out;
   assign wmem_addr_inc    =  ~wrfifo_empty  &  ~trans_end  &  mem_wr   &  mem_ack;
   assign rmem_addr_inc    =  ~rdfifo_full   &  ~mem_wr     &  mem_ack;
   assign wrfifo_data_in   =  !last_wr       ?  {1'b0, cmdIf_wrData}    :  {1'b1, 32'h0};    //  Insert dummy data at the last write transfer
   assign trans_end        =  wrfifo_data_out[32] & ~wrfifo_empty; 
   assign mem_wrData       =  wrfifo_data_out[31:0]  ;

   //----------------------------------------------//
   //         Logic to increment address
   //----------------------------------------------//
  
   always @ (*) begin
      mem_addr_inc    =  mem_addr;
      if (wmem_addr_inc) begin
         if ((sept2cmdIf_dmaMode == 3'b001) && (mem_addr > sept2cmdIf_epEndAddr)) begin
            mem_addr_inc   =  sept2cmdIf_epStartAddr;
         end
         else begin
            mem_addr_inc   =  mem_addr + 3'b100;
         end
      end
      else if (rmem_addr_inc) begin
         if ((sepr2cmdIf_dmaMode == 3'b001) && (mem_addr > sepr2cmdIf_epEndAddr)) begin
            mem_addr_inc   =  sepr2cmdIf_epStartAddr;
         end
         else begin
            mem_addr_inc   =  mem_addr + 3'b100;
         end
      end
      else begin
         mem_addr_inc   =  mem_addr;
      end
   end

   //----------------------------------------------//
   //               Choose MemIf
   //----------------------------------------------//
  
   always @(*) begin
      if((cmdIf_addr >= START_MEM_HADDR) && (cmdIf_addr <=END_MEM_HADDR)) begin
         memIf =1'b1;
      end
      else begin
         memIf=1'b0;
      end
   end
   
   assign cmdIf_trEn_mem =(cmdIf_trEn && memIf) ? 1'b1 : 1'b0;   

   //----------------------------------------------//
   //          Sys_clk side signals
   //----------------------------------------------//
  
   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n ) begin
         sys_curr_state <= S_IDLE;
      end
      else begin
         sys_curr_state <= sys_next_state;
      end
   end

   //------   Preserving WR-RD request     ------//

   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n ) begin
         cmd_wr_req_q   <= 1'b0;
      end
      else if (cmdIf_wrData_req) begin
         cmd_wr_req_q   <= 1'b1;
      end
      else if (cmdIf_rdData_req) begin
         cmd_wr_req_q   <= 1'b0;
      end
   end

   //-------  Registering Address Load  -------//

   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n ) begin
         ld_addr_reg    <= 1'b0;
      end
      else begin
         ld_addr_reg    <= ld_addr_reg_nxt;
      end
   end
   
   always @(*) begin
      sys_next_state       =sys_curr_state;
      cmdIf_ack            =1'b0;
      wrfifo_wr_req        =1'b0;
      cmdIf_rdData_ack     =1'b0;
      cmdIf_wrData_ack     =1'b0;
      rdfifo_rd_req        =1'b0;
      last_wr              =1'b0;
      ld_addr_reg_nxt      =ld_addr_reg;

      case(sys_curr_state)
         S_IDLE: begin
            if(cmdIf_trEn_mem && cmdIf_req) begin
               sys_next_state    =S_WAIT4ACK;
               ld_addr_reg_nxt   =1'b1;
            end
            else begin
               ld_addr_reg_nxt   =1'b0;
            end
         end    

      //    Wait for ACK to return from core clk     

         S_WAIT4ACK: begin
            if(cmdIf_ack_c2s) begin
               sys_next_state    =S_TRSFR;
               cmdIf_ack         =1'b1;
               ld_addr_reg_nxt   =1'b0;
            end
         end   
 
         S_TRSFR: begin
            if(!cmdIf_trEn_mem || cmdIf_req) begin
            //    If the previous transfer was write only
               if (cmd_wr_req_q && !wrfifo_full) begin   
                  last_wr           =1'b1;               
                  wrfifo_wr_req     =1'b1;
               end
               sys_next_state    =S_IDLE;
            end
            else if(cmdIf_wrData_req) begin              //---- Write until fifo full
               if(!wrfifo_full) begin
                  cmdIf_wrData_ack  =1'b1;
                  wrfifo_wr_req     =1'b1;
               end
            end
            else if(cmdIf_rdData_req) begin              //---- Read until fifo empty
               if(!rdfifo_empty) begin
                  cmdIf_rdData_ack  =1'b1;
                  rdfifo_rd_req     =1'b1;
               end
            end
         end  
      endcase
   end 

   //----------------------------------------------//
   //          Core clk side signals
   //----------------------------------------------//
  
   always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n ) begin
         core_curr_state       <= C_IDLE;
      end
      else begin
         core_curr_state       <= core_next_state;
      end
   end

    always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n ) begin
         mem_wr_q   <= 1'b0;
      end
      else begin
         mem_wr_q   <= mem_wr;                     
      end
   end

   always @(*) begin
      core_next_state      =core_curr_state;
      mem_addr_reg_ld      =1'b0;
      mem2cmdIf_ack        =1'b0;
      wrfifo_rd_req        =1'b0;
      wrmem_req            =1'b0;
      rdmem_req_temp       =1'b0;
      mem_wrRd             =1'b0;
      rdfifo_wr_req        =1'b0;
      rdfifo_rst_n         =1'b1;
      sept_len_decr        =1'b0;
      sepr_len_decr        =1'b0;
      mem_wr               =mem_wr_q;
      case(core_curr_state)
         C_IDLE: begin
            if(ld_addr_reg_nxt_s2c) begin
               core_next_state   =C_WAIT;
               mem2cmdIf_ack     =1'b1;
               mem_addr_reg_ld   =1'b1;
               mem_wr            =cmdIf_wrRd;
            end
         end    

      //    Wait for the ACK to be accepted at the sys clk

         C_WAIT: begin                             
            if (!ld_addr_reg_nxt_s2c) begin
               if (mem_wr) begin
                  core_next_state   =C_WTRSFR;
               end
               else begin
                  core_next_state   =C_RTRSFR;
               end
            end
         end
                             
     //     For Write transactions    

         C_WTRSFR: begin
            if (trans_end) begin                   //---- Checking for last transfer
               wrfifo_rd_req   =1'b1;
               wrmem_req       =1'b0;
               core_next_state =C_IDLE;
            end
            else if (!wrfifo_empty) begin
               wrfifo_rd_req   =mem_ack;
               wrmem_req       =1'b1;
               mem_wrRd        =1'b1;
               sept_len_decr   =mem_ack;
            end
         end

      //    For Read transactions

         C_RTRSFR: begin
            if (ld_addr_reg_nxt_s2c) begin
               core_next_state      =C_WAIT;
               mem2cmdIf_ack        =1'b1;
               mem_addr_reg_ld      =1'b1;
               mem_wr               =cmdIf_wrRd;
               rdfifo_rst_n         =1'b0;            //---- Read fifo is reset
            end
         //    Read Prefetch using nearly full instead of FULL
            else begin
               if (!rdfifo_nearly_full) begin            
                  rdfifo_wr_req    =mem_rdVal;           
                  rdmem_req_temp   =1'b1;       
                  mem_wrRd         =1'b0;
                  sepr_len_decr    =mem_rdVal; 
               end
            end
         end  
      endcase
   end 

   //----------------------------------------------//
   // Special case fix :: ACK=0 during nearly full
   //----------------------------------------------//
  
   always @ (*) begin
   set_rdmem_req   =  1'b0;
   clr_rdmem_req   =  1'b0;
      if (rdmem_req_temp && !mem_ack) begin              
         set_rdmem_req  =  1'b1;
      end
      else if (mem_ack) begin
         clr_rdmem_req  =  1'b1;
      end
   end

   always @ (posedge core_clk or negedge uctl_rst_n) begin
      if (!uctl_rst_n) begin
         rdmem_req_q    <=  1'b0;
      end
      else if (set_rdmem_req) begin
         rdmem_req_q    <=  1'b1;
      end
      else if (clr_rdmem_req) begin
         rdmem_req_q    <=  1'b0;
      end
   end
   
   assign   rdmem_req            =  rdmem_req_q |  rdmem_req_temp ;
   assign   mem_req              =  wrmem_req   |  rdmem_req      ;
   assign   rdfifo_data_in       =  mem_rdData                    ;
   assign   rdfifo_sysRst_n      =  sysRst_n    &  rdfifo_rst_n   ;
   assign   rdfifo_uctl_rst_n    =  uctl_rst_n  &  rdfifo_rst_n   ;      

   //----------------------------------------------//
   //          System End Point Tx logic
   //----------------------------------------------//
  
   always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n ) begin
         sept_curr_state       <= SEPT_IDLE  ;
      end
      else begin
         sept_curr_state       <= sept_next_state  ;
      end
   end

   always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n ) begin
         sept_len_q  <= 20'b0;
      end
      else if (sept2cmdIf_dmaMode   == 3'b001) begin
         if (sept2cmdIf_wr) begin
            sept_len_q  <= sept2cmdIf_len ;
         end
         else if (sept_len_decr) begin
            if (sept_len_q    <  20'd4) begin
               sept_len_q     <=  20'b0;
            end
            else begin
               sept_len_q     <=  sept_len_q - 20'd4;
            end
         end
      end
   end
   
   //    Generate sept command interface done
                                                          
   always @ (*) begin
      cmdIf2sept_dn     =  1'b0  ;
      sept_next_state   =  sept_curr_state   ;    

      case (sept_curr_state) 
      SEPT_IDLE   :  begin
         if (sept2cmdIf_dmaMode  == 3'b001) begin
            if (sept2cmdIf_wr) begin
               if (sept2cmdIf_len == 20'b0) begin
                  cmdIf2sept_dn  =  1'b1  ;
               end
               else begin
                  sept_next_state   =  SEPT_TRANS  ;
               end
            end               
         end               
      end

      SEPT_TRANS  :  begin
         if (sept2cmdIf_dmaMode  == 3'b001) begin
            if (sept_len_q == 20'b0)   begin
               cmdIf2sept_dn     =  1'b1  ;
               sept_next_state   =  SEPT_IDLE   ;
            end
         end
      end
      endcase 
   end

   //----------------------------------------------//
   //          System End Point Rx logic
   //----------------------------------------------//
  
   always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n ) begin
         sepr_curr_state       <= SEPT_IDLE  ;
      end
      else begin
         sepr_curr_state       <= sepr_next_state  ;
      end
   end

   always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n ) begin
         sepr_len_q  <= 20'b0;
      end
      else if (sepr2cmdIf_dmaMode   == 3'b001) begin
         if (sepr2cmdIf_rd) begin
            sepr_len_q  <= sepr2cmdIf_len ;
         end
         else if (sepr_len_decr) begin
            if (sepr_len_q    <  20'd4) begin
               sepr_len_q     <=  20'b0;
            end
            else begin
               sepr_len_q     <=  sepr_len_q - 20'd4;
            end
         end
      end
   end

   //    Generate sepr command interface done
                                                             
   always @ (*) begin
      sepr_next_state   =  sepr_curr_state   ;    
      cmdIf2sepr_dn     =  1'b0  ;

      case (sepr_curr_state) 
      SEPT_IDLE   :  begin
         if (sepr2cmdIf_dmaMode == 3'b001) begin
            if (sepr2cmdIf_rd) begin
               if (sepr2cmdIf_len == 20'b0) begin
                  cmdIf2sepr_dn  =  1'b1  ;
               end
               else begin
                  sepr_next_state   =  SEPT_TRANS  ;
               end
            end               
         end               
      end

      SEPT_TRANS  :  begin
         if (sepr2cmdIf_dmaMode == 3'b001) begin
            if (sepr_len_q == 20'd0)   begin
               cmdIf2sepr_dn     =  1'b1  ;
               sepr_next_state   =  SEPT_IDLE   ;
            end
         end               
      end
      endcase 
   end

   //----------------------------------------------//
   //          modular assignments
   //----------------------------------------------//
  
   uctl_asyncFifo #(
   .FIFO_DATASIZE (32),
   .FIFO_ADDRSIZE (10),
   .NEAR_FULL_TH  (1)) rdfifo (
   .rclk                            ( sys_clk            ),
   .wclk                            ( core_clk           ),
   .rrst_n                          ( rdfifo_sysRst_n    ),
   .wrst_n                          ( rdfifo_uctl_rst_n  ),
   //.swRst                           ( 1'b0               ),
   .r_en                            ( rdfifo_rd_req      ),
   .w_en                            ( rdfifo_wr_req      ),
   .fifo_data_in                    ( rdfifo_data_in     ),
   .wfull                           ( rdfifo_full        ),
   .rempty                          ( rdfifo_empty       ),
   .nearly_full                     ( rdfifo_nearly_full ),
   .fifo_data_out                   ( rdfifo_data_out    )
   );
   
   uctl_asyncFifo #(
   .FIFO_DATASIZE (33),
   .FIFO_ADDRSIZE (10),
   .NEAR_FULL_TH  (1)) wrfifo  (
   .wclk                            ( sys_clk            ),
   .rclk                            ( core_clk           ),
   .wrst_n                          ( sysRst_n           ),
   .rrst_n                          ( uctl_rst_n         ),
   //.swRst                           ( 1'b0               ),
   .w_en                            ( wrfifo_wr_req      ),
   .r_en                            ( wrfifo_rd_req      ),
   .fifo_data_in                    ( wrfifo_data_in     ),
   .wfull                           ( wrfifo_full        ),
   .rempty                          ( wrfifo_empty       ),
   .fifo_data_out                   ( wrfifo_data_out    )
   );
   
   uctl_synchronizer  sys_2_core    (
   .clk                             ( core_clk           ),
   .reset                           ( uctl_rst_n         ),
   .dataIn                          ( ld_addr_reg_nxt    ),
   .dataOut                         ( ld_addr_reg_nxt_s2c)
   );

   uctl_pulsestretch  addr_ack_stretcher (
   .clock1Rst_n                     ( uctl_rst_n         ), 
   .clock1                          ( core_clk           ), 
   .clock2                          ( sys_clk            ), 
   .clock2Rst_n                     ( sysRst_n           ), 
   .pulseIn                         ( mem2cmdIf_ack      ), 
   .pulseOut                        ( cmdIf_ack_c2s      ), 
   .dataIn                          ( 1'b0               )
   );

endmodule
