`timescale 1ns / 1ps
//-------------------------------------------------------------------
// Copyright © 2012 TECHVULCAN, Inc. All rights reserved.         
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, nor      
// its contents                        
// revealed in any manner to others without the express written      
// permission   of TechVulcan                   
// Licensed Material.                     
// Program Property of TECHVULCAN Incorporated.   
// ------------------------------------------------------------------
// DATE           : Thu, 28 Feb 2013 00:04:09
// AUTHOR         : MAHMOOD
// AUTHOR EMAIL   : vdn_mahmood@techvulcan.com
// FILE NAME      : uctl_packet_assembler.v
// VERSION        : 0.1
//-------------------------------------------------------------------
//   `include "uctl_asyncFiifo.v"
//   `include "uctl_crc5Gen.v"

//`include "paasync_fifo.v"
module uctl_packet_assembler #(
   parameter  PA_DATASIZE            = 18, 
              PA_ADDRSIZE            = 2
   )(
   //------------------------------------------------------
   //global signals
   //------------------------------------------------------
   input wire                coreClk                      ,//The core clock(125 Mhz)
   input wire                phyClk                       ,//PHY clock (30/60 Mhz)
   input wire                coreRst_n                    ,//
   input wire                phyRst_n                     ,//
   input wire                swRst                      ,//TODO
   //------------------------------------------------------
   //UTMI i/f
   //------------------------------------------------------
   output       [7       :0]  pa2utmi_txData              ,
   output       [7       :0]  pa2utmi_txDataH             ,
   output                     pa2utmi_txValid             ,
   output                     pa2utmi_txValidH            ,
   input  wire                utmi2pa_txReady             ,
   //------------------------------------------------------
   //protocol engine i/f
   //------------------------------------------------------   
   input wire                 pe2pa_tokenValid          ,
   input wire   [3        :0] pe2pa_tokenType           ,
   //output reg                 pa2pe_eot                   ,
   //input wire                 pe2pa_txDataTokenValid      ,
   //input wire   [3        :0] pe2pa_txDataTokenType       ,
   //------------------------------------------------------
   //ep ctrl i/f
   //------------------------------------------------------   
   input wire                 epct2pa_eot                 ,
   input wire                 epct2pa_dataValid           ,
   input wire  [31        :0] epct2pa_data                ,
   input wire  [3         :0] epct2pa_dataBE              ,
   input wire                 epct2pa_zeroLentPkt            ,
   //input wire                 epct2pa_txlastData            ,
   output wire                pa2epct_ready               ,
   //------------------------------------------------------
   //reg i/f
   //------------------------------------------------------   
   input wire                 reg2pa_tokenValid         ,
   input wire  [3         :0] reg2pa_tokenType          ,
   input wire  [3         :0] reg2pa_epNum              ,
   input wire  [6         :0] reg2pa_devID              , 
   input wire  [10        :0] reg2pa_frameNum           ,
   input wire                 reg2pa_dataBus16_8          ,
   //------------------------------------------------------
   //crc i/f
   //------------------------------------------------------   
   input wire                 crc2pa_crcValid           ,
   input wire  [15        :0] crc2pa_crc
   );

   localparam  [3:0]    IDLE           =  4'b0000 ,
                        TOK1           =  4'b0001  ,
                        TOK2           =  4'b0010  ,
                        TOK3           =  4'b0011  ,
                        DATA           =  4'b0100  ,
                        D0             =  4'b0101  ,
                        D1             =  4'b0110  ,
                        D2             =  4'b0111  ,
                        D3             =  4'b1000  ,
                        HS             =  4'b1001  ,
                        WAIT           =  4'b1010  ,
                        DUMMY          =  4'b1011  ,
                        CRC1           =  4'b1100  ,
                        CRC2           =  4'b1101  ;  
                                          
   localparam           BIT8_MODE         =  0        ,
                        BIT16_MODE        =  1        ;
   
   localparam           FROM_TOK_PID      =  4'b0001  ,          
                        FROM_DATAHS_PID   =  4'b0010  ,
                        FROM_RES          =  4'b0011  ,   
                        FROM_DATA_REG0    =  4'b0100  ,      
                        FROM_DATA_REG1    =  4'b0101  ,
                        FROM_DATA_REG2    =  4'b0110  ,
                        FROM_DATA_REG3    =  4'b0111  ,
                        FROM_CRC1         =  4'b1000  ,
                        FROM_CRC2         =  4'b1001  ,
                        FROM_DATAHS_TYPE  =  4'b1010  ,
                        FROM_TOK_TYPE     =  4'b1011  ;
                        
   localparam           FROM_SOF          =  2'b01    ,
                        FROM_TOK          =  2'b10    ,
                        FROM_DATA         =  2'b11    ; 

   
   localparam           OUT         =  4'b0001       ,
                        IN          =  4'b1001       ,
                        SETUP       =  4'b1101       ,
                        SOF         =  4'b0101       ,
                        PING        =  4'b0100       , 
                        DATA0       =  4'b0011       ,
                        DATA1       =  4'b1011       ,
                        DATA2       =  4'b0111       ,
                        MDATA       =  4'b1111       ,
                        ACK         =  4'b0010       , 
                        NAK         =  4'b1010       ,
                        NYET        =  4'b0110       ,
                        STALL       =  4'b1110       ;  

   reg   [3       :0]   state,
                        nxt_state;

   // ----------------------------------------------------------------
   // reg and wire
   // ----------------------------------------------------------------
   reg   [7             :0]   pid_tok_reg      ;
   reg   [7             :0]   pid_datahs_reg   ;
   reg   [7             :0]   res_reg          ;
   reg   [31            :0]   data_reg         ;
   reg   [3             :0]   be_reg           ;
   reg   [15            :0]   crc_reg          ;
   wire                       pid_tok_wr       ;
   wire                       pid_datahs_wr    ;
   reg                        res_wr           ;
   reg                        data_wr          ;
   reg                        ls_data_rd       ;
   wire                       set_eot_flag     ;
   reg                        clear_eot_flag   ;
   reg                        eot_flag         ;
   reg                        set_zlnt_flag    ;
   reg                        clear_zlnt_flag  ;
   reg                        zlnt_flag        ;
   reg                        res_flag         ;
   reg                        set_res_flag     ;
   reg                        clear_res_flag   ;
   reg   [3             :0]   res_from         ;
   reg   [3             :0]   data_from        ;
   reg                        be_wr            ;
   reg   [3             :0]   data_L_from      ;
   reg   [3             :0]   data_H_from      ;
   reg                        valid            ;
   reg                        valid_H          ;

   //wire  [3             :0]   pid_tok_type      ;
   //wire  [3             :0]   pid_datahs_type   ;
   reg  [7              :0]   data_L           ;
   reg  [7              :0]   data_H           ;
   //wire                       valid_L         ;
   //wire                       valid_H         ;
   wire  [7             :0]   tok_pid          ;
   wire  [15            :0]   tok_data         ;
   wire  [15            :0]   sof_data         ;
   wire  [7             :0]   datahs_pid       ;
   wire                       fifo_full        ;
   wire                       fifo_empty       ;
   wire  [17            :0]   fifo_in          ;
   wire  [17            :0]   fifo_out         ;
   reg                        fifo_wr_en       ;
   wire                       fifo_rd_en       ;
   wire                       crc_wr           ;
   wire [11           -1:0]   data_in          ; 
   wire [4              :0]   crc5_out         ;
   reg                        data_reg_full    ;
   wire                       set_data_reg_full;
   wire                       clr_data_reg_full;
   reg                        set_token_f      ; 
   reg                        clr_token_f      ; 
   reg                        token_f          ;
   //----------------------------------------------------------
   //
   //----------------------------------------------------------
   assign   fifo_in           =  {valid_H,valid,data_H,data_L        }     ;
   assign   sof_data          =  {crc5_out,reg2pa_frameNum           }     ;
   assign   tok_data          =  {crc5_out,reg2pa_epNum,reg2pa_devID }     ;
   assign   tok_pid           =  {~reg2pa_tokenType,reg2pa_tokenType }     ;
   assign   datahs_pid        =  {~pe2pa_tokenType,pe2pa_tokenType   }     ;
   assign   pa2utmi_txData    =  fifo_out[7:0]                             ;
   assign   pa2utmi_txDataH   =  fifo_out[15:8]                            ;
   assign   pa2utmi_txValid   =  (fifo_out[16]  && !fifo_empty )           ;
   assign   pa2utmi_txValidH  =  (fifo_out[17] && !fifo_empty)              ;
   assign   fifo_rd_en        =  (utmi2pa_txReady && !fifo_empty)          ;
   assign   crc_wr            =   crc2pa_crcValid                          ;
   assign   sof_pid           =  (reg2pa_tokenType == SOF )  ? 1'b1 : 1'b0 ;
   assign   hs_pid            =  (  pe2pa_tokenType == ACK   ||
                                    pe2pa_tokenType == NAK   ||
                                    pe2pa_tokenType == NYET  ||
                                    pe2pa_tokenType == STALL )  ? 1'b1 :1'b0;
   assign   pid_tok_wr        =  reg2pa_tokenValid                          ;
   assign   pid_datahs_wr     =  pe2pa_tokenValid                           ;
   assign   data_in       =  sof_pid ? reg2pa_frameNum : ({reg2pa_epNum,reg2pa_devID});
   //----------------------------------------------------------
   //fifo_instantiate
   //----------------------------------------------------------
   uctl_asyncFifo #(
      .FIFO_DATASIZE (PA_DATASIZE ), 
      .FIFO_ADDRSIZE (PA_ADDRSIZE ) 
      )pa_asyncFifo( 
      .fifo_data_out    (fifo_out), 
      .wfull            (fifo_full),      //
      .rempty           (fifo_empty),     //
      .fifo_data_in     (fifo_in),        //
      .w_en             (fifo_wr_en),     //
      .wclk             (coreClk),         //
      .wrst_n           (coreRst_n),       //
      .r_en             (fifo_rd_en), 
      .rclk             (phyClk),        //
      .rrst_n           (phyRst_n));     //

   //----------------------------------------------------------
   //crc5_instantiate
   //----------------------------------------------------------
   uctl_crc5Gen i_crc5Gen(.data_in(data_in), 
                        .crc_out(crc5_out)); 

   // ----------------------------------------------------------------
   //pid_reg
   // ----------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         pid_tok_reg    <= 1'b0;
         pid_datahs_reg <= 1'b0;
      end
      else if(swRst) begin
         pid_tok_reg    <= 1'b0;
         pid_datahs_reg <= 1'b0;
      end
      else if (pid_tok_wr) begin   //reg2pa_tokenValid
         pid_tok_reg  <= tok_pid;   //{~reg2pa_tokenType,reg2pa_tokenType};
         //set_tok_flag       <= 1'b1;
      end
      else if(pid_datahs_wr) begin  //pe2pa_tokenValid 
         pid_datahs_reg <= datahs_pid; //{~pe2pa_tokenType,pe2pa_txTokenType};
         //set_data_hs_flag   <= 1'b1;                  //TODO dont forget abt clear signal in state machine
      end
   end

   // ----------------------------------------------------------------
   //res_reg
   // ----------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         res_reg  <= {8{1'b0}};
      end
      else if(swRst) begin
         res_reg  <= {8{1'b0}};
      end
      //else if()begin          //write tok pid 16 bit mode
      //end
      //else if() begin         //write data pid in 16 bit mode
      //end
      else if(res_wr && res_from == FROM_DATAHS_PID) begin
         res_reg  <= pid_datahs_reg;
      end
      else if(res_wr && res_from == FROM_DATAHS_TYPE) begin
         res_reg  <=  datahs_pid;     //{~pe2pa_tokenType,pe2pa_txTokenType};
      end
      else if(res_wr && res_from == FROM_TOK_TYPE) begin
         res_reg  <= tok_pid;      //{~reg2pa_tokenType,reg2pa_tokenType};
      end
      else if(res_wr && res_from == FROM_DATA_REG1) begin
         res_reg  <=data_reg[15:8];
      end
      else if(res_wr && res_from == FROM_DATA_REG3) begin
         res_reg  <= data_reg[31:24];
      end
   end

   // ----------------------------------------------------------------
   //data_reg
   // ----------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         data_reg <= {32{1'b0}};
      end 
      else if(swRst) begin
         data_reg <= {32{1'b0}}; 
      end 
      else if(data_wr && (data_from == FROM_SOF)) begin
         data_reg <= {16'b0,sof_data};   //{crc5_out,reg2pa_frameNum};
      end
      else if(data_wr && (data_from == FROM_TOK)) begin
         data_reg <= {16'b0,tok_data};   //{crc5_out,epnum,addr};
      end
      else if(data_wr && (data_from == FROM_DATA)) begin
         data_reg <= epct2pa_data;
      end
   end  

   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         data_reg_full <= 1'b0;
      end 
      else if (swRst) begin
         data_reg_full <= 1'b0;
      end
      else begin
         if (set_data_reg_full) begin 
            data_reg_full <= 1'b1;
         end 
         else if (clr_data_reg_full) begin
            data_reg_full <= 1'b0;
         end
      end
   end

   assign set_data_reg_full = data_wr;
   assign clr_data_reg_full = ls_data_rd;

   assign pa2epct_ready     = ~data_reg_full | (data_reg_full & ls_data_rd);

   // ----------------------------------------------------------------
   //ByteEnable_reg
   // ----------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         be_reg   <= {4{1'b0}};
      end
      else if(swRst) begin
         be_reg   <= {4{1'b0}};
      end
     // else if(be_wr && tok) begin //TODO give correct name instead of tok
     //    be_reg   <= 4'b0011;
     // end
      else if(be_wr) begin // && data) begin  //TODO give correct name
         be_reg   <= epct2pa_dataBE;
      end
   end 

   // ----------------------------------------------------------------
   //crc_reg
   // ----------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         crc_reg  <= {16{1'b0}};
      end   
      else if(swRst) begin
         crc_reg  <= {16{1'b0}};
      end   
      else if(crc_wr) begin
         crc_reg  <= crc2pa_crc;
      end
   end
   
   //------------------------------------------------------------------
   //flag register
   //------------------------------------------------------------------
   /*always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         tok_flag       <= 1'b0;
      end   
      else if(set_tok_flag) begin
         tok_flag       <= 1'b1;
      end
      else if(clear_tok_flag) begin
         tok_flag       <= 1'b0;
      end
   end*/

   /*always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         data_hs_flag   <= 1'b0;
      end
      else if(set_data_hs_flag) begin
         data_hs_flag   <= 1'b1;
      end
      else if(clear_data_hs_flag) begin
         data_hs_flag   <= 1'b0;
      end
   end*/
   
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         res_flag    <= 1'b0;          
      end
      else if(swRst) begin
         res_flag    <= 1'b0;          
      end
      else if(set_res_flag) begin
         res_flag    <= 1'b1;
      end
      else if(clear_res_flag) begin
         res_flag    <= 1'b0;
      end
   end
   
 assign set_eot_flag    = epct2pa_eot; 
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         eot_flag <= 1'b0;
      end
      else if(swRst) begin
         eot_flag <= 1'b0;
      end
      else if(set_eot_flag) begin
         eot_flag <= 1'b1;
      end
      else if(clear_eot_flag) begin
         eot_flag <= 1'b0;
      end
   end

   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         zlnt_flag   <= 1'b0;
      end
      else if(swRst) begin
         zlnt_flag   <= 1'b0;
      end
      else if(set_zlnt_flag) begin
         zlnt_flag   <= 1'b1;
      end
      else if(clear_zlnt_flag) begin
         zlnt_flag   <= 1'b0;
      end
   end
 

   //------------------------------------------------------------
   // data_L_from
   //------------------------------------------------------------ 
   always @(*) begin 
      case(data_L_from) 
         FROM_TOK_PID: begin
            data_L   =  pid_tok_reg;
         end
         FROM_DATAHS_PID: begin
            data_L   =   pid_datahs_reg;
         end
         FROM_RES: begin
            data_L   =  res_reg;
         end
         FROM_DATA_REG0: begin
            data_L   =  data_reg[7:0];
         end
         FROM_DATA_REG1: begin
            data_L   =  data_reg[15:8];
         end
         FROM_DATA_REG2: begin
            data_L   =  data_reg[23:16];
         end
         FROM_DATA_REG3: begin
            data_L   =  data_reg[31:24];
         end
         FROM_CRC1: begin  
            data_L   =  crc_reg[7:0];
         end
         FROM_CRC2: begin
            data_L   =  crc_reg[15:8];
         end
         default: 
            data_L   =  {7{1'b0}};
      endcase
   end   

   //------------------------------------------------------------
   // data_H_from
   //------------------------------------------------------------ 
   always @(*) begin
      case(data_H_from)
            FROM_DATA_REG0 : begin
               data_H    =  data_reg[7:0];        
            end
            FROM_DATA_REG2 : begin
               data_H    =  data_reg[23:16];
            end
            FROM_CRC1      : begin
               data_H    =  crc_reg[7:0];
            end
            FROM_CRC2      : begin
               data_H    =  crc_reg[15:8];
            end
            default:
               data_H    = {7{1'b0}};
      endcase
   end  

   //------------------------------------------------------------
   // state machine
   // -----------------------------------------------------------   
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         state <= IDLE;
      end
      else begin
         state <= nxt_state;
      end
   end

   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         token_f     <= 1'b0;
      end
      else if(swRst) begin 
         token_f     <= 1'b0;
      end
      else if(set_token_f) begin 
         token_f     <= 1'b1;
      end
      else if(clr_token_f) begin 
         token_f     <= 1'b0;
      end
   end

   always @(*) begin
      nxt_state      =  state    ;
     // pid_tok_wr     =  1'b0     ;
      //pid_datahs_wr  =  1'b0     ;
      res_wr           =  1'b0     ;
      data_wr          =  1'b0     ;
      ls_data_rd       =  1'b0     ;
      data_from        =  {4{1'b0}};
      //data_ready       =  1'b0     ;
      res_from         =  {4{1'b0}};
      fifo_wr_en       =  1'b0     ;
      data_L_from      =  {4{1'b0}};
      data_H_from      =  {4{1'b0}};
      valid            =  1'b0     ;
      valid_H          =  1'b0     ;
      set_zlnt_flag    =  1'b0     ;
      clear_zlnt_flag  =  1'b0  ;
      set_res_flag     =  1'b0  ;  
      clear_res_flag   =  1'b0  ;
      //pa2epct_ready    =  1'b0  ;
      be_wr            =  1'b0  ;
      //set_eot_flag     =  1'b0  ;
      clear_eot_flag   =  1'b0   ;
      set_token_f      = 1'b0       ; 
      clr_token_f      = 1'b0       ; 
      
      case(state)
         IDLE: begin
            if(reg2pa_dataBus16_8   == BIT8_MODE) begin
               if(reg2pa_tokenValid) begin       //token packet during OTG mode
                  //set_token_f   = 1'b1       ; 
                  data_wr     =  1'b1;
                  nxt_state   =  TOK1;
                  if(sof_pid) begin
                     data_from   =  FROM_SOF ;     //write to data register
                    // nxt_state   =  TOK1     ;
                  end
                  else begin
                     data_from   =  FROM_TOK ;     //write to data register
                    // nxt_state   =  TOK1     ;
                  end
               end
               else if(pe2pa_tokenValid) begin   //data or HS packet
                  set_token_f   = 1'b1       ; 
                  if(hs_pid) begin                 //see at tok_type line   
                     nxt_state   =  HS       ;
                  end
                  /*else if(data_pid) begin        // see at tok_type line
                    nxt_state    =  DATA     ; 
                  end*/
               end 
               if(token_f) begin 
                  if(epct2pa_dataValid) begin
                  //if(!data_exist) begin          //TODO data_exist is need?
                     //data_ready  =  1'b1;
                     data_wr     =  1'b1;          //TODO added to write first data if default value of pa2epct_ready is high
                     be_wr          =  1'b1;
                     //pa2epct_ready  =  1'b1;
                     data_from   =  FROM_DATA;
                     nxt_state   =  DATA;
                  //end
                  end
                  else if(epct2pa_zeroLentPkt) begin
                     nxt_state      =  DATA;
                     set_zlnt_flag  =  1'b1;
                  end
               end
            end                                    //end of 8bit mode
           else if(reg2pa_dataBus16_8   == BIT16_MODE) begin
               if(reg2pa_tokenValid) begin
                  //set_token_f   = 1'b1       ; 
                  res_wr      =  1'b1;
                  res_from    =  FROM_TOK_TYPE;
                  data_wr     =  1'b1; 
                  nxt_state   =  TOK1; 
                  if(sof_pid) begin
                     data_from   =  FROM_SOF    ;
                  end
                  else begin
                     data_from   =  FROM_TOK    ;
                  end
               end
               else if(pe2pa_tokenValid) begin
                  set_token_f   = 1'b1       ; 
                  res_wr         =  1'b1;
                  res_from       =  FROM_DATAHS_TYPE;
                  if(hs_pid) begin
                     nxt_state   =  HS;
                  end
               end
               if(token_f) begin 
                  if(epct2pa_dataValid) begin         //valid for data path
                  //if(!data_exist) begin          data register is empty
                     //data_ready  =  1'b1;
                     //pa2epct_ready  =  1'b1;
                     data_from   =  FROM_DATA;     //select for data reg
                     res_wr      =  1'b1;
                     res_from    =  FROM_DATAHS_PID;
                     nxt_state   =  D0;  
                  //end
                  end
                  else if(epct2pa_zeroLentPkt) begin
                     nxt_state      =  CRC1;
                     set_zlnt_flag  =  1'b1;
                  end
               end
            end   //end of 16 bit mode
         end     //end of IDLE state
         
         TOK1 : begin 
            if(reg2pa_dataBus16_8   == BIT8_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en     =  1'b1        ;
                  data_L_from    =  FROM_TOK_PID; 
                  valid          =  1'b1        ;  
                  nxt_state      =  TOK2        ;
               end
            end   //end of 8bit mode
            else if(reg2pa_dataBus16_8 == BIT16_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en     =  1'b1           ;
                  data_L_from    =  FROM_RES       ;
                  data_H_from    =  FROM_DATA_REG0 ;
                  valid          =  1'b1           ;
                  valid_H        =  1'b1           ;
                  nxt_state      =  TOK3           ;
               end
            end   //end of 16 bit mode      
         end      //end of TOK1
   
         TOK2: begin
            if(reg2pa_dataBus16_8   == BIT8_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en     =  1'b1;
                  data_L_from   =  FROM_DATA_REG0;
                  valid          =  1'b1;
                  nxt_state      =  TOK3;
               end
            end      //end of 8bit mode
         end      //end of TOK2
         
         TOK3: begin
            if(reg2pa_dataBus16_8 == BIT8_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en     =  1'b1;
                  data_L_from    =  FROM_DATA_REG1;
                  valid          =  1'b1;
                  nxt_state      =  IDLE;
                  ls_data_rd     =  1'b1;
               end
            end            //end of 8bit mode
            else if(reg2pa_dataBus16_8 == BIT16_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en     =  1'b1;
                  data_L_from    =  FROM_RES;
                  //data_H_from    no need coz only 1 byte is available
                  valid          =  1'b1;
                  valid_H        =  1'b0;
                  nxt_state      =  IDLE;       //TODO check if data_flag is set
                  ls_data_rd     =  1'b1;
               end
            end      //end of 16 bit mode
         end      //end of TOK3
      
         DATA: begin                      //send DATA pid
            if(reg2pa_dataBus16_8 == BIT8_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en     =  1'b1;
                  data_L_from   =  FROM_DATAHS_PID;
                  valid          =  1'b1;
                  if(zlnt_flag) begin   //TODO zlnt_flag not yet define
                     nxt_state   =  CRC1;
                     clear_zlnt_flag   =  1'b1;
                  end
                  else if(be_reg[0]) begin
                     nxt_state      =  D0;
                  end
               end
            end 
         end   //end of DATA      
         D0: begin
            if(reg2pa_dataBus16_8 == BIT8_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en     =  1'b1;
                  data_L_from    =  FROM_DATA_REG0;
                  valid          =  1'b1;
                  if(be_reg[1]) begin
                     nxt_state      =  D1;
                  end
                  else if(eot_flag | epct2pa_eot) begin
                     ls_data_rd     = 1'b1;
                     nxt_state      =  CRC1;
                  end
               end
            end
            else if(reg2pa_dataBus16_8 == BIT16_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en     =  1'b1;
                  data_L_from    =  FROM_RES;
                  data_H_from    =  FROM_DATA_REG0;
                  valid          =  1'b1;
                  valid_H        =  1'b1;
                  if(be_reg[1]) begin
                     res_wr      =  1'b1;
                     res_from    =  FROM_DATA_REG1;
                     set_res_flag   =  1'b1;
                     if(be_reg[2]) begin
                          nxt_state   =  D2;
                     end
                     else if(eot_flag) begin
                        ls_data_rd     = 1'b1;
                        nxt_state      =  CRC1;
                     end                    
                  end
                  else if(eot_flag) begin
                     ls_data_rd        = 1'b1;
                     nxt_state         =  CRC1;
                  end
               end
            end
         end      //end of D0 state

         D1: begin
            if(reg2pa_dataBus16_8 == BIT8_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en     =  1'b1;
                  data_L_from    =  FROM_DATA_REG1;
                  valid          =  1'b1;
                  if(be_reg[2]) begin
                     nxt_state      =  D2;
                  end
                  else if(eot_flag) begin
                     ls_data_rd     = 1'b1;
                     nxt_state      =  CRC1;
                  end
               end
            end
         end   //end of D1

         D2: begin
            if(reg2pa_dataBus16_8 == BIT8_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en        =  1'b1;
                  data_L_from      =  FROM_DATA_REG2;
                  valid             =  1'b1;
                  if(be_reg[3]) begin
                     nxt_state      =  D3;
                  end
                  else if(eot_flag) begin
                     ls_data_rd     = 1'b1;
                     nxt_state      =  CRC1;
                  end 
               end
            end 
            else if(reg2pa_dataBus16_8 == BIT16_MODE) begin
              if(!fifo_full) begin
                  ls_data_rd        =  1'b1;
                  fifo_wr_en        =  1'b1;
                  data_L_from       =  FROM_RES;
                  data_H_from       =  FROM_DATA_REG2; 
                  valid             =  1'b1;
                  valid_H           =  1'b1;
                  if(be_reg[3]) begin
                     res_from       =  FROM_DATA_REG3;
                     res_wr         =  1'b1;
                     set_res_flag   =  1'b1;
                  end
                  if(epct2pa_dataValid) begin
                     data_wr        =  1'b1;
                     data_from      = FROM_DATA;
                     //pa2epct_ready  =  1'b1;
                     be_wr          =  1'b1;
                     nxt_state      =  D0;
                  end
                  
                  else if(eot_flag) begin
                     nxt_state      =  CRC1;
                  end
                  else begin
                     nxt_state      =  WAIT;
                  end
                  if(epct2pa_eot) begin
                     //set_eot_flag   =  1'b1;
                  end
               end
            end      //end 0f 16 bit
         end         //end of D2
         
         D3: begin
            if(epct2pa_eot)begin
               ////set_eot_flag   =  1'b1;
            end
            if(reg2pa_dataBus16_8 == BIT8_MODE) begin
               if(!fifo_full) begin
                  ls_data_rd        =  1'b1;
                  fifo_wr_en        =  1'b1;
                  data_L_from       =  FROM_DATA_REG3;
                  valid             =  1'b1;
                  if(epct2pa_dataValid) begin
                     data_wr        =  1'b1;
                     data_from      = FROM_DATA;
                     //pa2epct_ready  =  1'b1;
                     nxt_state      =  D0;
                     be_wr          =  1'b1;
                  end
                  else if(eot_flag) begin
                     nxt_state      =  CRC1;
                  end
                  else begin
                     nxt_state      =  WAIT;
                  end
               end
            end
         end   //end of D3
      
         HS: begin
            if(reg2pa_dataBus16_8   == BIT8_MODE || reg2pa_dataBus16_8 == BIT16_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en           =  1'b1;
                  data_L_from          =  FROM_DATAHS_PID;
                  valid                =  1'b1;
                  clr_token_f          =  1'b1;
               end
            end
            nxt_state      =  IDLE;       
            ls_data_rd     =  1'b1;
         end
         

         
         WAIT: begin
            if(reg2pa_dataBus16_8   == BIT8_MODE) begin        //TODO remove redundent logic
               if(epct2pa_dataValid) begin
                  nxt_state   =  D0;
               end
            end
            else if(reg2pa_dataBus16_8 == BIT16_MODE) begin
               if(epct2pa_dataValid) begin
                  nxt_state   =  D0;
               end
            end
         end
         
         CRC1: begin
            if(reg2pa_dataBus16_8 == BIT8_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en        =  1'b1     ;
                  data_L_from       =  FROM_CRC1;
                  nxt_state         =  CRC2     ;
                  clear_eot_flag    =  1'b1     ;
                  valid             =  1'b1     ;  
               end
            end
            else if(reg2pa_dataBus16_8 == BIT16_MODE) begin
               if(!fifo_full) begin
                  if(res_flag) begin
                     fifo_wr_en  =  1'b1;
                     data_L_from =  FROM_RES;
                     data_H_from =  FROM_CRC1;
                     valid       =  1'b1;
                     valid_H     =  1'b1;
                     nxt_state   =  CRC2;
                     clear_res_flag    =  1'b1;
                     clear_zlnt_flag   =  1'b1;
                     clear_eot_flag    =  1'b1;
                  end
                  else begin
                     fifo_wr_en  =  1'b1;
                     data_L_from =  FROM_CRC1;
                     data_H_from =  FROM_CRC2;
                     valid       =  1'b1;
                     valid_H     =  1'b1;
                     nxt_state   =  DUMMY;
                  end
               end
            end
         end   //end of CRC1

         CRC2: begin
            clr_token_f   = 1'b1       ; 
            if(reg2pa_dataBus16_8 == BIT8_MODE) begin
               if(!fifo_full) begin
                 fifo_wr_en         =  1'b1;
                 data_L_from        =  FROM_CRC2;
                 nxt_state          =  DUMMY;
                 valid              =  1'b1;
              end
            end
            else if(reg2pa_dataBus16_8 == BIT16_MODE) begin
               if(!fifo_full) begin
                  fifo_wr_en     =  1'b1;
                  data_L_from    =  FROM_CRC2;
                  valid          =  1'b1;
                  nxt_state      =  DUMMY;
               end
            end
         end   //end of CRC2
         
         DUMMY: begin
            if(!fifo_full) begin
               fifo_wr_en        =  1'b1;
               valid             =  1'b0;
               nxt_state         =  IDLE;
               ls_data_rd        =  1'b1;
            end
         end
      endcase
   end
endmodule

