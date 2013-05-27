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
// DATE			   : Thu, 14 Feb 2013 00:21:16
// AUTHOR		   : MAHMOOD
// AUTHOR EMAIL	: vdn_mahmood@techvulcan.com
// FILE NAME		: uctl_packet_decoder.v
// VERSION        : 0.6
//-------------------------------------------------------------------

/* updates 
version 0.6
EOT delayed by one cycle
data packet without OUT or SETUP packet improved
pid_ping signal removed

version 0.5
LPM is implemented

version 0.4
frame count logic is implemented 

version 0.3
crc5_data modified
swrst is added in state machine

version 0.2   
FLUSH state included
bug fix for DATA packet without token packet

version 0.1 
(datavalid for crc16,all pd2reg -> pd2eptd, crc5 fixed)
(minor change ;->,crc16 fixed)
*/


module uctl_packet_decoder#(
   parameter  PD_DATASIZE            = 25, 
              PD_ADDRSIZE            = 2
   )(
   // ----------------------------------------------------------------
   // Global signals
   // ----------------------------------------------------------------
   input wire                coreClk                      ,//The core clock(125 Mhz)
   input wire                phyClk                       ,//PHY clock (30/60 Mhz)
   input wire                coreRst_n                    ,//
   input wire                phyRst_n                     ,//
   input wire                swRst                        ,// soft reset
   // ----------------------------------------------------------------
   // utmi i/f
   // ----------------------------------------------------------------
   // utmi2pd
   input wire                utmi2pd_rxActive             ,//indicate start and end of transaction
   input wire                utmi2pd_rxError              ,//error is detected
   input wire                utmi2pd_rxValid              ,//valid data on lower data bus
   input wire                utmi2pd_rxValidH             ,//valid data on higher data bus
   input wire  [7        :0] utmi2pd_rxData               ,//lower data bus
   input wire  [7        :0] utmi2pd_rxDataH              ,//higher data bus
   // ----------------------------------------------------------------
   // protocol engine i/f
   // ----------------------------------------------------------------
   output reg               pd2pe_tokenValid             ,//Token packet rcvd sucessfully
   output     [3        :0] pd2pe_tokenType              ,//PId type
   output     [3        :0] pd2pe_epNum                  ,//Virtual endpoint number
   output reg               pd2frmCntrr_frmNumValid      ,//frame number received
   output     [10       :0] pd2frmCntrr_FrameNum         ,//frame number
   output reg               pd2pe_zeroLenPkt             ,//detection of zero length packet
   // ----------------------------------------------------------------
   // epcr2pd
   // ----------------------------------------------------------------
   input wire                epcr2pd_ready               ,//ready to accept data on data bus
   // ----------------------------------------------------------------
   // ep ctrl i/f
   // ----------------------------------------------------------------
   output reg               pd2epcr_eot                  ,//Indicate end of data transfer
   output                   pd2epcr_dataValid            ,//valid data on data bus
   output     [31       :0] pd2epcr_data                 ,//data bus
   output     [3        :0] pd2epcr_dataBE               ,//byte enable for data bus
   // ----------------------------------------------------------------
   // crc16 i/f
   // ----------------------------------------------------------------            
   output reg               pd2crc16_crcValid            ,//crc16 received
   output     [15       :0] pd2crc16_crc                 ,//Crc16
   output wire              pd2crc16_dataValid           ,
   // ----------------------------------------------------------------
   // reg i/f
   // ----------------------------------------------------------------
   // reg2pd
   input wire                reg2pd_dataBus16_8           ,//8 or 16 bit mode indication 
   input wire [6         :0] reg2pd_devID                 ,//device address
   output reg                pd2pe_lpmValid               ,//LPM valid
   output wire[10        :0] pd2pe_lpmData                ,//LPM data  

   // pd2reg
   output                   pd2eptd_statusStrobe          ,//new status in error signal //TODO pd2eptd_sta
   output reg               pd2eptd_crc5                  ,//indicate crc5 error
   output reg               pd2eptd_pid                   ,//PID error
   output reg               pd2eptd_err                   ,//receive error     
   output     [4        :0] pd2eptd_epNum    
   );

   
   localparam        IDLE           =  3'd0           ,
                     D0             =  3'd1           ,
                     D1             =  3'd2           ,
                     D2             =  3'd3           ,
                     D3             =  3'd4           ,
                     CRC5_CHECK     =  3'd5           ,
                     DR             =  3'd6           ,
                     FLUSH          =  3'd7           ;
                                                     
   localparam        UT_IDLE        =  2'd0           ,
                     UT_TR          =  2'd1           ,
                     UT_C1          =  2'd2           ;
   
   reg        [2         :0]  state                   ,
                              nxt_state               ;
   reg        [1         :0]  utmi_curr_state         ,
                              utmi_next_state         ;

   localparam         BIT8_MODE   = 1'b0              ,
                      BIT16_MODE  = 1'b1              ;

   localparam         FROM_RES       =  2'b00         ,  //TODO comment
                      FROM_D2        =  2'b01         ,
                      FROM_D1        =  2'b10         ,
                      FROM_HD1       =  2'b11         ;


   localparam        OUT         =  8'b11100001       ,
                     IN          =  8'b01101001       ,
                     SETUP       =  8'b00101101       ,
                     SOF         =  8'b10100101       ,
                     PING        =  8'b10110100       , 
                     DATA0       =  8'b11000011       ,
                     DATA1       =  8'b01001011       ,
                     DATA2       =  8'b10000111       ,
                     MDATA       =  8'b00001111       ,
                     ACK         =  8'b11010010       , 
                     NAK         =  8'b01011010       ,
                     NYET        =  8'b10010110       ,
                     STALL       =  8'b00011110       ,  
                     EXT         =  8'b11110000       ;

   reg                        pd2epcr_eot1	      ;//TODO TEMP
   reg   [7             :0]   pid_reg                 ;
   reg   [7             :0]   res_reg                 ;
   reg   [7             :0]   d0_reg                  ;
   reg   [7             :0]   d1_reg                  ;
   reg   [7             :0]   d2_reg                  ;
   reg   [7             :0]   d3_reg                  ;
   reg   [3             :0]   be_reg                  ;
   reg   [7             :0]   crc1_reg;
   reg   [7             :0]   crc2_reg;

  // reg                        rxactive_d1             ;
  // reg                        rxactive_d2             ;
  // reg                        rxactive_d3             ;
  // reg                        rxvalid_d1              ;
  // reg                        rxvalid_d2              ;
  // reg                        rxvalidH_d1             ;
  // reg                        rxvalidH_d2             ;
  // reg   [7             :0]   rxdata_d1               ;
  // reg   [7             :0]   rxdata_d2               ;
  // reg   [7             :0]   rxdataH_d1              ;
   reg                        pid_wr                  ;
   reg                        res_wr                  ;
   reg                        d0_reg_wr               ;
   reg                        d1_reg_wr               ;
   reg                        d2_reg_wr               ;
   reg                        d3_reg_wr               ;
   reg                        set_be0_f               ;
   reg                        clr_be_f                ;
   reg                        set_be1_f               ;
   reg                        set_be2_f               ;
   reg                        set_be3_f               ;
   reg                        crc_wr                  ; 
   reg                        crc1_wr                 ; 
   reg                        crc2_wr                 ;
   reg                        tok_rcvd_nxt            ;
   reg                        crc_rcvd_nxt            ;
   reg                        pd2pe_lpmValid_nxt      ;
   reg                        zlnt_rcvd_nxt           ;
   reg                        set_tok_pid_f           ;
   reg                        clr_tok_pid_f           ;
   reg                        set_data_pid_f          ;
   reg                        clr_data_pid_f          ;
   reg                        set_data_f              ;
   reg                        clr_data_f              ;
   reg                        data_f                  ;
   //reg                        data_valid            ;
   reg   [1             :0]   d0_d2_from              ;
   reg   [1             :0]   d1_d3_from              ;
   reg   [1             :0]   crc1_from               ;
   reg   [1             :0]   crc2_from               ;
   reg                        tok_pid_f               ;
   reg                        data_pid_f              ;
   reg                        status_strobe_d         ;
   //reg                        rxactive_nxt            ;
   reg                        d_f                     ;
   reg                        set_d_f                 ;
   wire                       clr_d_f                 ;
   reg                        clr_d_f_temp            ;
   
   reg   [19            :0]   utmi_rxif_d1            ;
   reg   [19            :0]   utmi_rxif_d2            ;
   
   reg                        utmi_eot                ;
   

   reg                        utmi_data_pkt_f         ;
   reg                        set_utmi_data_pkt_f     ;
   reg                        clr_utmi_data_pkt_f     ;

   reg                        utmi_sot                ;
   reg                        utmi_crc1_phase         ;
   reg                        utmi_crc2_phase         ;

   reg                        set_exp_sub_pid_f       ;
   reg                        clr_exp_sub_pid_f       ;
   reg                        exp_sub_pid_f           ;

   reg                        set_sub_pid_f           ;
   reg                        clr_sub_pid_f           ;
   reg                        sub_pid_f               ;
   
   reg                        fifo_overflw_f          ;
   wire                       set_fifo_overflw_f      ;
   wire                       clr_fifo_overflw_f      ;
   reg                        fifo_r_en               ;

   ///wire                       rxactive_b             ;
   wire                       rxactive                ;
   wire                       rxvalid                 ;
   wire                       rxvalidH                ;
   wire                       rxerror                 ;
   wire  [7             :0]   rxdata                  ;
   wire  [7             :0]   rxdataH                 ;
   wire                       fifo_full               ;
   wire                       fifo_empty              ;
   wire                       fifo_w_en               ;

   //wire                       crc_phase             ; 
   wire                       crc1_phase              ; 
   wire                       crc2_phase              ;
   wire                       pid_err                 ;
   wire                       crc5_err                ;
   wire                       addr_err                ;
   wire  [24            :0]   fifo_data_in            ;
   wire  [24            :0]   fifo_data_out           ;    
   
   //wire                       pid_ping                ;
   wire                       pid_sof                 ;
   wire                       tok_pid                 ;                  
   wire  [6             :0]   dev_addr                ;
   //wire                       data_exists           ;
   wire                        eot                     ;
   wire  [10            :0]   crc5_data               ;
   wire  [4             :0]   crc5                    ;
   wire                       status_strobe           ;
   wire                       pid_tok                 ;
   wire                       pid_data                ;
   wire                       pid_hs                  ;
   //wire                       data_packet           ;
   wire                       tr_err                  ;
   wire  [19            :0]   utmi_rxif               ;

   wire                       utmi_rxactive           ;
   wire                       utmi_rxactive_d1        ;
   wire                       utmi_rxactive_d2        ;
   //reg                        utmi_rxactive_d3        ;

   wire                       utmi_rxvalid_d2         ;                                       
//   wire                       utmi_rxvalid_d1         ;
//   wire                       utmi_rxvalid            ;
   
//   wire                       utmi_rxvalidH_d2        ;
//   wire                       utmi_rxvalidH_d1        ;
//   wire                       utmi_rxvalidH           ;

   wire  [7             :0]   utmi_rxData_d2          ;
   reg                        crc5_enbl               ;
   //reg  [10:0] temp;
//----------------------------------------------------------------------------------
   assign   pd2pe_tokenType         =  pid_reg[3:0]                                                ;
   assign   pd2pe_epNum             =  {d1_reg[2:0], d0_reg[7]}                                    ;
   assign   pd2eptd_epNum           =  (pid_reg == IN) ? ({1'b1,pd2pe_epNum}) : ({1'b0,pd2pe_epNum});
   assign   pd2frmCntrr_FrameNum    =  {d1_reg[2:0], d0_reg}                                       ;
   assign   pd2pe_lpmData           =  {d1_reg[2:0], d0_reg}                                       ;
   assign   dev_addr                =  d0_reg[6:0]                                                 ;  //TODO to give mux, cond(if tok_pid)
   assign   pd2epcr_data            =  {d3_reg,d2_reg,d1_reg,d0_reg}                               ;
   assign   pd2epcr_dataBE          =  be_reg                                                     ;
   assign   pd2crc16_crc            =  {crc2_reg,crc1_reg}                                         ;
   assign   tok_pid                 =   (pid_reg ==  IN     ||                       
                                         pid_reg ==  OUT    ||           
                                         pid_reg ==  PING   ||
                                         pid_reg ==  SOF    ||
                                         pid_reg ==  SETUP   ) ?1:0;

   //assign   pid_ping                =  (pid_reg == PING) ? 1'b1 : 1'b0                             ;
   assign   ext_pid                 =  (pid_reg == EXT ) ?  1'b1: 1'b0                             ;
   assign   pid_sof                 =  (pid_reg == SOF) ? 1'b1 : 1'b0                              ;
   assign   pid_err                 =  (pid_reg[3:0]   != ~pid_reg[7:4]) ? 1'b1 : 1'b0             ;   
   assign   addr_err                =  (reg2pd_devID   != dev_addr) ? 1'b1 : 1'b0                  ; 
   assign   crc5_data               =  {d1_reg[2:0],d0_reg}                                        ;
   assign   crc5                    =  d1_reg[7:3]                                                 ;
   
   assign   status_strobe           =  (pid_err|crc5_err|rxerror) ? 1'b1 : 1'b0              ;
   assign   pd2epcr_dataValid       =  d_f ;     //data_valid               
   assign   pd2eptd_statusStrobe    =  (status_strobe && !status_strobe_d) ? 1'b1 : 1'b0           ;
   assign   d_reg_empty             =  ((d_f  == 1'b0) || (d_f == 1'b1 && epcr2pd_ready))    ;
   assign   pd2crc16_dataValid      =  (pd2epcr_dataValid && epcr2pd_ready) ? 1'b1  :  1'b0  ;
   

   assign pid_hs               =                         (rxdata ==  ACK  ||
                                                          rxdata ==  NAK  ||
                                                          rxdata ==  NYET ||
                                                          rxdata ==  STALL )?1:0;
                                                         

   assign pid_data             =                         (rxdata ==  DATA0 ||
                                                          rxdata ==  DATA1 ||
                                                          rxdata ==  DATA2 ||
                                                          rxdata ==  MDATA  ) ?1:0;
                                                         
   
    assign pid_tok             =                         (rxdata ==  IN     ||
                                                          rxdata ==  OUT    ||
                                                          rxdata ==  PING   ||
                                                          rxdata ==  SOF    ||
                                                          rxdata ==  SETUP   ) ?1:0;

   assign pid_extend              =                      (rxdata  == EXT)  ? 1'b1 : 1'b0;



   /*assign data_packet          =                         (pid_reg    ==  DATA0 ||
                                                          pid_reg    ==  DATA1 ||
                                                          pid_reg    ==  DATA2 ||
                                                          pid_reg    ==  MDATA  );*/

   /*assign hs_packet            =                          (pid_reg    ==  ACK  ||
                                                          pid_reg     ==  NAK  ||
                                                          pid_reg     ==  NYET ||
                                                          pid_reg     ==  STALL );*/

   /*assign token_packet         =                         (pid_reg == IN       ||
                                                          pid_reg ==  OUT     ||
                                                          pid_reg ==  PING    ||
                                                          pid_reg ==  SOF     ||
                                                          pid_reg ==  SETUP      );*/
   /*always @(*) begin
      for(int i=0;i<8;i=i+1) begin
         temp[i]  =  d0_reg[7-i];
      end
      for(int i=8 ; i<12; i=i+1) begin
         temp[i]  =  d1_reg[i-8];
      end
   end
   */
 

   //--------------------------------------------------------------
   //CRC5 checker instantiation
   //--------------------------------------------------------------
    uctl_crc5Chkr i_crc5Check(
                     //.rst(coreRst_n),
                     .crc_out(crc5),
                     .crc_rx_data(crc5_data),
                     .enbl(crc5_enbl),             //TODO think enable is need
                     .crc5_error(crc5_err));

   


   // -------------------------------------------------------------

   assign   utmi_rxif               =  {  
                                          utmi2pd_rxDataH   ,
                                          utmi2pd_rxData    ,
                                          utmi2pd_rxValidH  ,
                                          utmi2pd_rxValid   ,
                                          utmi2pd_rxError   ,
                                          utmi2pd_rxActive  
                                       };

   // Delay the UTMI interface signals so that we create markers
   //---------------------------------------------------------------
   always @(posedge phyClk or negedge phyRst_n) begin
      if(!phyRst_n) begin
         utmi_rxif_d1 <= {20{1'b0}};
         utmi_rxif_d2 <= {20{1'b0}};
      end
      else if(swRst) begin
         utmi_rxif_d1 <= {20{1'b0}};
         utmi_rxif_d2 <= {20{1'b0}};
      end
      else begin
         utmi_rxif_d1 <= utmi_rxif;
         utmi_rxif_d2 <= utmi_rxif_d1;
      end
   end

   assign utmi_rxactive_d2 = utmi_rxif_d2[0];
   assign utmi_rxactive_d1 = utmi_rxif_d1[0];
   assign utmi_rxactive    = utmi_rxif[0];

   assign utmi_rxvalid_d2  = utmi_rxif_d2[2];
   //assign utmi_rxvalid_d1  = utmi_rxif_d1[2];
   //assign utmi_rxvalid     = utmi_rxif[2];

   //assign utmi_rxvalidH_d2 = utmi_rxif_d2[3];
   //assign utmi_rxvalidH_d1 = utmi_rxif_d1[3];
   //assign utmi_rxvalidH    = utmi_rxif[3];

   assign utmi_rxData_d2   = utmi_rxif_d2[11:4];

   /*always @(posedge phyClk or negedge phyRst_n) begin
      if(!phyRst_n) begin
         utmi_rxactive_d3 <= 1'b0;
      end
      else if(swRst) begin
         utmi_rxactive_d3 <= 1'b0;
      end
      else begin
         utmi_rxactive_d3 <= utmi_rxactive_d2;
      end
   end*/

   always @(posedge phyClk or negedge phyRst_n) begin
      if(!phyRst_n) begin
         utmi_data_pkt_f <= 1'b0;
      end
      else if(swRst) begin
         utmi_data_pkt_f <= 1'b0;
      end
      else begin
         if (set_utmi_data_pkt_f) begin
            utmi_data_pkt_f <= 1'b1;
         end
         else if (clr_utmi_data_pkt_f) begin
            utmi_data_pkt_f <= 1'b0;
         end
      end
   end

   always @(posedge phyClk or negedge phyRst_n) begin
      if(!phyRst_n) begin
         utmi_curr_state <= UT_IDLE;
      end
      else begin
         utmi_curr_state <= utmi_next_state;
      end
   end

   always @(*) begin
      utmi_next_state      = utmi_curr_state;
      utmi_sot             = 1'b0;
      utmi_crc1_phase      = 1'b0;
      utmi_crc2_phase      = 1'b0;
      utmi_eot             = 1'b0;
      set_utmi_data_pkt_f  = 1'b0;
      clr_utmi_data_pkt_f  = 1'b0;
   
      case(utmi_curr_state)
         UT_IDLE: begin          //IDLE
            if(utmi_rxactive_d2 && utmi_rxvalid_d2) begin                                                            
               if (~utmi_rxactive_d1) begin
                  utmi_next_state = UT_IDLE;
                  utmi_eot        = 1'b1;
               end
               else begin
                  utmi_next_state = UT_TR;
                  if (utmi_rxData_d2 ==  DATA0 || utmi_rxData_d2 ==  DATA1 ||
                      utmi_rxData_d2 ==  DATA2 || utmi_rxData_d2 ==  MDATA  ) begin
                     set_utmi_data_pkt_f = 1'b1;
                  end
               end
               utmi_sot           = 1'b1;
            end
         end

         UT_TR: begin         //Transaction phase
            if(utmi_data_pkt_f) begin 
               if(reg2pd_dataBus16_8 == BIT16_MODE) begin
                  if (!utmi_rxactive_d1 && utmi_rxactive_d2 && utmi_rxvalid_d2) begin
                     utmi_next_state   = UT_IDLE;
                     utmi_crc1_phase   = 1'b1;
                     utmi_eot          = 1'b1;
                     clr_utmi_data_pkt_f = 1'b1;
                  end
               end 
               else begin
                  if (!utmi_rxactive && utmi_rxactive_d1 && utmi_rxactive_d2 && utmi_rxvalid_d2) begin
                     utmi_next_state   = UT_C1;
                     utmi_crc1_phase   = 1'b1;
                  end
               end

            end
            else begin
               if (!utmi_rxactive_d1 && utmi_rxactive_d2 && utmi_rxvalid_d2) begin
                  utmi_next_state      = UT_IDLE;
                  utmi_eot             = 1'b1;
                  clr_utmi_data_pkt_f  = 1'b1;
               end
            end
         end

         UT_C1: begin
            if(utmi_rxvalid_d2 & utmi_rxactive_d2) begin
               utmi_next_state      = UT_IDLE;
               utmi_crc2_phase      = 1'b1;
               utmi_eot             = 1'b1;
               clr_utmi_data_pkt_f  = 1'b1;
            end
         end

      endcase
   end

   //--------------------------------------------------------------
   //async fifo
   //--------------------------------------------------------------
    uctl_asyncFifo #(
      .FIFO_DATASIZE (PD_DATASIZE ), 
      .FIFO_ADDRSIZE (PD_ADDRSIZE )
      ) pd_asyncFifo( 
      .fifo_data_out    (fifo_data_out ), 
      .wfull            (fifo_full     ), 
      .rempty           (fifo_empty    ), 
      .fifo_data_in     (fifo_data_in  ),
      .w_en             (fifo_w_en     ),
      .wclk             (phyClk        ), 
      .wrst_n           (phyRst_n      ), 
      .r_en             (fifo_r_en     ), 
      .rclk             (coreClk       ), 
      .rrst_n           (coreRst_n     )
      //.numOfData        (numOfData     ),
      //.nearly_full      (nearly_full   )
   ); 

   assign   rxactive                =  fifo_data_out[0]     & ~fifo_empty;
   assign   rxerror                 =  fifo_data_out[1]     & ~fifo_empty;
   assign   rxvalid                 =  fifo_data_out[2]     & ~fifo_empty;
   assign   rxvalidH                =  fifo_data_out[3]     & ~fifo_empty;
   assign   rxdata                  =  fifo_data_out[11:4]  ;  
   assign   rxdataH                 =  fifo_data_out[19:12] ;
   assign   sot                     =  fifo_data_out[20]    & ~fifo_empty;
   assign   crc1_phase              =  fifo_data_out[21]    & ~fifo_empty;
   assign   crc2_phase              =  fifo_data_out[22]    & ~fifo_empty;
   assign   eot                     =  fifo_data_out[23]    & ~fifo_empty;
   assign   tr_err                  =  fifo_data_out[24]    & ~fifo_empty;

   assign   fifo_data_in  = {
                              fifo_overflw_f ,
                              utmi_eot       ,
                              utmi_crc2_phase,
                              utmi_crc1_phase,
                              utmi_sot       ,
                              utmi_rxif_d2
                            };

   assign   fifo_w_en    =  (((utmi_rxactive_d2 & utmi_rxvalid_d2) | utmi2pd_rxError ) );
   
   assign   set_fifo_overflw_f = fifo_full & fifo_w_en;
   // Clear the over flow flag when rxacitve goes low
   assign   clr_fifo_overflw_f = ~utmi_rxactive_d2    ;
   assign   clr_d_f            = epcr2pd_ready  || clr_d_f_temp ;
   
   always @(posedge phyClk or negedge phyRst_n) begin
      if(!phyRst_n) begin
         fifo_overflw_f <= 1'b0;
      end
      else if(swRst) begin
         fifo_overflw_f <= 1'b0;
      end
      else begin
         if (set_fifo_overflw_f) begin
            fifo_overflw_f <= 1'b1;
         end
         else if (clr_fifo_overflw_f) begin
            fifo_overflw_f <= 1'b0;
         end
      end
   end
   //---------------------------------------------------------------
   //pid register block
   //---------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin                    
      if(!coreRst_n) begin
         pid_reg  <= {8{1'b0}};
      end
      else if(swRst) begin
         pid_reg  <= {8{1'b0}};
      end
      else if(pid_wr) begin
         pid_reg  <= rxdata;
      end
   end
   
   //---------------------------------------------------------------
   // residual registers
   //---------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin                 
      if(!coreRst_n) begin
         res_reg  <= {8{1'b0}};
      end 
      else if(swRst) begin
         res_reg  <= {8{1'b0}};
      end 
      else if(res_wr) begin
         res_reg  <= rxdataH;
      end
   end
   
   //---------------------------------------------------------------
   //data zero(D0) register
   //---------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin                 
      if(!coreRst_n) begin
         d0_reg   <= {8{1'b0}};
      end
      else if(swRst) begin
         d0_reg   <= {8{1'b0}};
      end
      else if(d0_reg_wr && (d0_d2_from == FROM_RES)) begin //16bit mode
         d0_reg   <= res_reg;
      end
      else if(d0_reg_wr) begin
         d0_reg   <= rxdata;
      end
   end 
   //---------------------------------------------------------------
   //D1 register
   //---------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin//d1 register
      if(!coreRst_n) begin
         d1_reg   <= {8{1'b0}};
      end
      else if(swRst) begin
         d1_reg   <= {8{1'b0}};
      end
      else if(d1_reg_wr) begin
         d1_reg   <= rxdata;
      end
   end
   //---------------------------------------------------------------
   //D2 register
   //---------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         d2_reg   <= {8{1'b0}};
      end
      else if(swRst) begin
         d2_reg   <= {8{1'b0}};
      end
      else if(d2_reg_wr && (d0_d2_from == FROM_RES)) begin
         d2_reg   <= res_reg;
      end
      else if(d2_reg_wr) begin
         d2_reg   <= rxdata;
      end
   end

   //---------------------------------------------------------------
   //D3 register
   //---------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         d3_reg   <= {8{1'b0}};
      end
      else if(swRst) begin
         d3_reg   <= {8{1'b0}};
      end
      else if(d3_reg_wr) begin
         d3_reg   <= rxdata;
      end
   end 
   //---------------------------------------------------------------
   //CRC registers
   //---------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         {crc1_reg,crc2_reg}  <= {16{1'b0}};
      end
      else if(swRst) begin
         {crc1_reg,crc2_reg}  <= {16{1'b0}};
      end
      else if(crc_wr && (crc1_from == FROM_RES)) begin
         {crc1_reg,crc2_reg}  <= {res_reg,rxdata};    
      end
      else if(crc_wr && (crc2_from == FROM_HD1))begin
         {crc1_reg,crc2_reg}  <= {rxdata,rxdataH};
      end
      else if(crc1_wr) begin
         crc1_reg     <= rxdata;       
      end
      else if(crc2_wr) begin
         crc2_reg     <=    rxdata;
      end
   end

   //---------------------------------------------------------------------
   //byte enable register
   //----------------------------------------------------------------------
  always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         be_reg   <= 4'b0000;
      end
      else if(swRst) begin
         be_reg   <= 4'b0000;
      end
      else if(set_be3_f) begin
         be_reg   <= 4'b1111;
      end
      else if(set_be2_f) begin
         be_reg   <= 4'b0111;
      end
      else if(set_be1_f) begin
         be_reg   <= 4'b0011;
      end
      else if(set_be0_f) begin
         be_reg   <= 4'b0001;
      end
      else if(clr_be_f) begin
         be_reg   <= 4'b0000;
      end
   end 

   //-----------------------------------------------------------
   //flag registers
   //-----------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         tok_pid_f   <= 1'b0;
      end
      else if(swRst) begin
         tok_pid_f   <= 1'b0;
      end
      else if(set_tok_pid_f == 1'b1) begin
         tok_pid_f   <= 1'b1;
      end
      else if(clr_tok_pid_f == 1'b1) begin
         tok_pid_f   <= 1'b0;
      end
   end

   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         data_pid_f  <= 1'b0;
      end
      else if(swRst) begin
         data_pid_f  <= 1'b0;
      end
      else if(set_data_pid_f == 1'b1) begin
         data_pid_f  <= 1'b1;
      end
      else if(clr_data_pid_f) begin
         data_pid_f  <= 1'b0;
      end
   end   
   
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         d_f   <= 1'b0;
      end
      else if(swRst) begin
         d_f   <= 1'b0;
      end
      else if(set_d_f) begin
         d_f   <= 1'b1;
      end
      else if(clr_d_f) begin
         d_f   <= 1'b0;
      end
   end

   //------------------------------------------------------------
   // token and CRC rcvd
   //------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin              
      if(!coreRst_n) begin
         pd2pe_tokenValid     <= 1'b0;
         pd2crc16_crcValid    <= 1'b0;
         pd2pe_lpmValid       <= 1'b0;                  
      end
      else if(swRst) begin
         pd2pe_tokenValid     <= 1'b0;
         pd2crc16_crcValid    <= 1'b0;
         pd2pe_lpmValid       <= 1'b0;                  
      end
      else begin
         pd2pe_tokenValid     <= tok_rcvd_nxt; 
         pd2crc16_crcValid    <= crc_rcvd_nxt;
         pd2pe_lpmValid       <= pd2pe_lpmValid_nxt;
      end
   end
   //---------------------------------------------------------------
   //
   //---------------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin   //TODO  not clear much
      if(!coreRst_n) begin
         pd2eptd_pid           <= 1'b0;
         pd2eptd_crc5          <= 1'b0;
         pd2eptd_err           <= 1'b0;
         status_strobe_d       <= 1'b0;
      end
      else if(swRst) begin
         pd2eptd_pid           <= 1'b0;
         pd2eptd_crc5          <= 1'b0;
         pd2eptd_err           <= 1'b0;
         status_strobe_d       <= 1'b0;
      end
      else begin 
         pd2eptd_pid           <= pid_err;
         pd2eptd_crc5          <= crc5_err;
         status_strobe_d       <= status_strobe;
         pd2eptd_err           <= rxerror;
      end
   end

   //------------------------------------------------------------
   // state machine
   // -----------------------------------------------------------   
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         state <= IDLE;
      end
      else if(swRst) begin
         state <= IDLE;
      end
      else begin
         state <= nxt_state;
      end
   end
 
   always @(*) begin
      nxt_state               =  state ;
      pid_wr                  =  1'b0  ;
      res_wr                  =  1'b0  ;

      fifo_r_en               =  1'b0  ;
      d0_reg_wr               =  1'b0  ;   
      d1_reg_wr               =  1'b0  ;   
      d2_reg_wr               =  1'b0  ;
      d3_reg_wr               =  1'b0  ;   
      d0_d2_from              =  2'b00 ;
      d1_d3_from              =  2'b00 ;

      set_be0_f               =  1'b0  ;   
      set_be1_f               =  1'b0  ;   
      set_be2_f               =  1'b0  ;   
      set_be3_f               =  1'b0  ;
      clr_be_f                =  1'b0  ;   

      crc1_wr                 =  1'b0  ;
      crc2_wr                 =  1'b0  ;   
      crc_wr                  =  1'b0  ;   
      crc1_from               =  2'b00 ;
      crc2_from               =  2'b00 ; 

      set_d_f                 =  1'b0  ;

      tok_rcvd_nxt            =  1'b0  ;   
      crc_rcvd_nxt            =  1'b0  ;   
      zlnt_rcvd_nxt         =  1'b0  ;   
      //data_valid              =  1'b0  ;
      
      set_tok_pid_f           =  1'b0  ;
      set_data_pid_f          =  1'b0  ;

      clr_tok_pid_f           =  1'b0  ;
      clr_data_pid_f          =  1'b0  ;

      pd2epcr_eot1             =  1'b0  ;  
      crc5_enbl               =  1'b0  ;  //TODO CHECKING PURPOSE
      
      set_data_f              =  1'b0  ;
      clr_data_f              =  1'b0  ;
      clr_d_f_temp            =  1'b0  ;

      pd2pe_lpmValid_nxt      =  1'b0  ;

      set_exp_sub_pid_f       =  1'b0  ;
      clr_exp_sub_pid_f       =  1'b0  ;

      set_sub_pid_f           =  1'b0  ;
      clr_sub_pid_f           =  1'b0  ;
      
      pd2frmCntrr_frmNumValid =  1'b0  ;

   case(state)
      IDLE: begin //{
         clr_be_f     =  1'b1;
         if(fifo_empty  == 1'b0) begin
            fifo_r_en   =  1'b1;
            if(reg2pd_dataBus16_8 == BIT8_MODE) begin          //8 bit mode
               if(sot) begin
                  pid_wr      =  1'b1;
                  if(pid_hs  == 1'b1) begin //HS PID //TODO change on 07/03 pid_tok -> pid_hs
                     tok_rcvd_nxt   =  1'b1;
                     nxt_state      =  IDLE;
                     pd2epcr_eot1    =  1'b1;
                  end
                  else if(rxdata == DATA0 && exp_sub_pid_f) begin
                     set_sub_pid_f  =  1'b1;
                     clr_exp_sub_pid_f =  1'b1;
                     nxt_state      =  D0;
                  end
                  else if(pid_data  == 1'b1 && !(exp_sub_pid_f)) begin             //DATA PID
                     if(data_f) begin
                        clr_data_f         =  1'b1;
                        tok_rcvd_nxt       =  1'b1;               //pulse signal
                        set_data_pid_f     =  1'b1;
                        nxt_state          =  D0;
                     end
                     else begin
                        nxt_state          =  FLUSH;  
                     end
                  end
                  else if(pid_tok   == 1'b1) begin             //TOKEN PID
                     set_tok_pid_f  =  1'b1;
                     nxt_state      =  D0;
                  end
                  else if(rxdata == EXT) begin             //TODO 17/05/13
                    // set_ext_pid_f  =  1'b1;
                     nxt_state      =  D0;
                  end
               end
            end                                                //8bit mode end
            else if(reg2pd_dataBus16_8 == BIT16_MODE) begin    //16 bit mode start
               if(sot) begin
                  pid_wr      =  1'b1;
                  res_wr      =  1'b1;
                  if(pid_hs == 1'b1)begin 
                     tok_rcvd_nxt   =  1'b1;
                     nxt_state      =  IDLE;
                     pd2epcr_eot1    =  1'b1;
                  end
                  else if(rxdata == DATA0 && exp_sub_pid_f) begin
                     set_sub_pid_f  =  1'b1;
                     clr_exp_sub_pid_f =  1'b1;
                     nxt_state      =  D0;
                  end
                  else if(pid_data == 1'b1 && !(exp_sub_pid_f)) begin
                     if(data_f) begin
                        clr_data_f           =  1'b1;
                        set_data_pid_f       =  1'b1;             //for zero lnt packet
                        tok_rcvd_nxt         =  1'b1;
                        nxt_state            =  D0;   
                     end
                     else begin
                        nxt_state         =  FLUSH;
                     end
                  end
                  else if(pid_tok == 1'b1) begin
                     set_tok_pid_f        =  1'b1;
                     nxt_state            =  D0;
                  end
                  else if(rxdata == EXT) begin             //TODO 17/05/13
                    // set_ext_pid_f  =  1'b1;
                     nxt_state      =  D0;
                  end
               end
            end
         end
      end               //IDLE state end
      
      FLUSH: begin
         clr_data_f  =  1'b1;    //clear data_phase flag
         clr_d_f_temp =  1'b1;    //clear data flag through temp clear
         if(fifo_empty == 1'b0) begin
            fifo_r_en   =  1'b1;
           // clr_d_f_temp =  1'b1;    //clear data flag through temp clear
            if(eot) begin
               nxt_state   =  IDLE;
            end
         end
      end

      DR: begin         //data residual state
         if(fifo_empty == 1'b0 && d_reg_empty) begin
            fifo_r_en      =  1'b1;
            if(rxvalidH) begin
               crc_wr         =  1'b1;
               crc1_from      =  FROM_D1;
               crc2_from      =  FROM_HD1;
               crc_rcvd_nxt   =  1'b1;
            end
            else begin
               crc_wr         =  1'b1;
               crc1_from      =  FROM_RES;
               crc2_from      =  FROM_D1;
               crc_rcvd_nxt   =  1'b1;
            end

            pd2epcr_eot1    =  1'b1;
            nxt_state      =  IDLE;
         end

      end

      D0: begin
         if(fifo_empty  == 1'b0 && d_reg_empty) begin
            if(reg2pd_dataBus16_8 == BIT8_MODE) begin
               fifo_r_en   =  1'b1;
               if(crc1_phase && !(sub_pid_f)) begin
                  crc1_wr     =  1'b1;
                  nxt_state   =  D1;
                  end
               else if(crc2_phase && !(sub_pid_f)) begin
                  crc2_wr        =  1'b1;
                  crc_rcvd_nxt   =  1'b1;    
                  nxt_state      =  IDLE;
                  pd2epcr_eot1    =  1'b1;
               end 
               else if(rxvalid) begin
                  d0_reg_wr      =  1'b1;
                  d0_d2_from     =  FROM_D2;
                  set_be0_f      =  1'b1;
                  nxt_state      =  D1;
               end
            end      //8bit mode end

            else if(reg2pd_dataBus16_8 == BIT16_MODE) begin
               if(eot) begin
                  if(tok_pid_f || (pid_reg == EXT) || sub_pid_f) begin
                     fifo_r_en   =  1'b1;
                     d0_reg_wr   =  1'b1;
                     d0_d2_from  =  FROM_RES;
                     
                     d1_reg_wr      =  1'b1;
                     d1_d3_from     =  FROM_D1;
                     set_be1_f      =  1'b1;

                     res_wr         =  1'b1;

                     //crc5_en     =  1'b1;
                     pd2epcr_eot1 =  1'b1;
                     nxt_state   =  CRC5_CHECK;
                     //crc5_enbl   =  1'b1;
                  end
                  else begin

                     if(rxvalidH) begin
                        d0_reg_wr      =  1'b1;
                        d0_d2_from     =  FROM_RES;
                        set_be0_f      =  1'b1;
                        set_d_f        =  1'b1;

                        nxt_state      =  DR;
                     end
                     else if(!sub_pid_f) begin
                        fifo_r_en      =  1'b1;

                        crc_wr         =  1'b1;
                        crc1_from      =  FROM_RES;
                        crc2_from      =  FROM_D1;
                        crc_rcvd_nxt   =  1'b1;

                        if(data_pid_f) begin
                           zlnt_rcvd_nxt     =  1'b1;
                           clr_data_pid_f = 1'b1;
                        end
                        pd2epcr_eot1    =  1'b1;
                        nxt_state      =  IDLE;
                     end
                  end
               end//eot
               else if(rxvalidH) begin
                  d0_reg_wr         =  1'b1;
                  d0_d2_from        =  FROM_RES;
                  set_be0_f         =  1'b1;
                  d1_reg_wr         =  1'b1;
                  d1_d3_from        =  FROM_D1;
                  set_be1_f         =  1'b1;
                  res_wr            =  1'b1;
                  clr_tok_pid_f     =  1'b1;
                  clr_data_pid_f    =  1'b1;

                  fifo_r_en         =  1'b1;
                  nxt_state         =  D2;
               end

            end//16 bit mode end
         end
      end //D0 state end  
      
      D1: begin
         if(fifo_empty  == 1'b0 && d_reg_empty) begin
            fifo_r_en   =  1'b1;
            if(reg2pd_dataBus16_8 == BIT8_MODE) begin
               if(eot) begin
                  pd2epcr_eot1   =  1'b1;
                  if(tok_pid_f || (pid_reg == EXT) || sub_pid_f ) begin
                     d1_reg_wr         =   1'b1;   
                     d1_d3_from        =   FROM_D2;
                     clr_tok_pid_f     =   1'b1;
                     nxt_state         =  CRC5_CHECK;
                     //crc5_enbl         =  1'b1;
                  end
                  else if(data_pid_f) begin
                     zlnt_rcvd_nxt      =  1'b1;
                     clr_data_pid_f       =  1'b1;
                     nxt_state            =  IDLE;
                     crc2_wr              =  1'b1;
                     crc2_from            =  FROM_D2;
                     crc_rcvd_nxt         =  1'b1;
                  end
                  else if(crc2_phase && !(sub_pid_f)) begin
                     crc2_wr        =  1'b1;
                     crc2_from      =  FROM_D2;
                     crc_rcvd_nxt   =  1'b1;
                     nxt_state      =  IDLE; 
                  end 
               end      //end of eot

               else if(crc1_phase && !(sub_pid_f)) begin
                  crc1_wr        =  1'b1;
                  nxt_state      =  D2;
                  set_d_f        =  1'b1;          // D0 have valid data
               end
                 
               else if(rxvalid) begin
                  d1_reg_wr       =  1'b1;
                  d1_d3_from      =  FROM_D2;
                  set_be1_f       =  1'b1;
                  clr_data_pid_f  =  1'b1;
                  nxt_state       =  D2;
               end
            end
         end
      end
      D2: begin
         if(fifo_empty  == 1'b0 && d_reg_empty) begin 
            if(reg2pd_dataBus16_8 == BIT8_MODE) begin
               fifo_r_en   =  1'b1;
               if(eot)  begin
                  nxt_state      =  IDLE;
                  pd2epcr_eot1    =  1'b1;
                  if(crc2_phase) begin
                     crc2_wr        =  1'b1;
                     crc2_from      =  FROM_D2;
                     crc_rcvd_nxt   =  1'b1;
                  end
               end      //end of eot
               else if(crc1_phase) begin
                  crc1_wr     =  1'b1;
                  //crc1_from   =  FROM_D2;
                  nxt_state   =  D3;
                  set_d_f  =  1'b1;          //D0,D1 having valid data
                  //if(epcr2pd_ready) begin
                  //   clr_d_f   =  1'b1;
                  //end
                  //if(data_exists == 1'b1) begin
                  //   data_valid  =  1'b1;
                  //end
               end
               else if(rxvalid) begin
                  d2_reg_wr   =  1'b1;
                  d0_d2_from  =  FROM_D2;
                  set_be2_f   =  1'b1;
                  nxt_state   =  D3;
               end
            end      //end of 8bit mode
            else if(reg2pd_dataBus16_8 == BIT16_MODE) begin
               if(eot) begin                 // this is crc_phase for 16 bit mode
                  set_d_f     =  1'b1;  //D0,D1 may begin D2 also have data if rxvalidH is high
                  if(rxvalidH) begin
                     //set_d_f  =  1'b1;
                     d2_reg_wr   =  1'b1;
                     d0_d2_from  =  FROM_RES;
                     set_be2_f   =  1'b1;

                     nxt_state   =  DR;
                  end
                  else begin
                     nxt_state   =  DR;
                  end
               end   //end of eot
               else if(rxvalid)begin
                  d2_reg_wr         =  1'b1;
                  d0_d2_from        =  FROM_RES;
                  d3_reg_wr         =  1'b1;
                  d1_d3_from        =  FROM_D1;
                  set_be2_f         =  1'b1;
                  set_be3_f         =  1'b1;
                  res_wr            =  1'b1;

                  set_d_f           =  1'b1;//all 4 data reg have valid data in 16 bit mode
                  fifo_r_en         =  1'b1;
                  nxt_state         =  D0;
               end
            end      //end of 16 bit mode
         end
      end
      D3: begin
         if(fifo_empty  == 1'b0 && d_reg_empty) begin 
            fifo_r_en   =  1'b1;
            if(reg2pd_dataBus16_8 == BIT8_MODE) begin
               if(crc2_phase) begin
                  nxt_state      =  IDLE;
                  crc2_wr        =  1'b1;
                  //crc2_from      =  FROM_D2;
                  crc_rcvd_nxt   =  1'b1; 
                  pd2epcr_eot1    =  1'b1;
               end
               else if(crc1_phase) begin
                  crc1_wr     =  1'b1;
                  //crc1_from   =  FROM_D2;
                  nxt_state   =  D0;
                  set_d_f  =  1'b1;        //D0,D1,D2 have valid data
                  //if(epcr2pd_ready) begin
                  //   clr_d_f   =  1'b1;
                  //end
               end
               else if(rxvalid) begin
                  d3_reg_wr   =  1'b1;
                  d1_d3_from  =  FROM_D2;
                  set_be3_f   =  1'b1; 
                  nxt_state   =  D0;
                  set_d_f     =  1'b1;                //all four have valid data
                  //if(ep_numepcr2pd_ready) begin
                  //   clr_d_f   =  1'b1;
                  //end
               end
            end   //end of 8bit
         end   
      end   //end of d3
      CRC5_CHECK: begin          //5
         crc5_enbl  =  1'b1;
         nxt_state   =  IDLE;
         if(tok_pid && pid_sof) begin     //SOF packet
            pd2epcr_eot1 =  1'b1;
            if(!crc5_err) begin
               clr_tok_pid_f     =  1'b1;
               tok_rcvd_nxt      =  1'b1;
               pd2frmCntrr_frmNumValid  = 1'b1;
               nxt_state         =  IDLE;  
               clr_data_f        =  1'b1;
            end
         end
         else if(tok_pid && !pid_sof) begin
            if(!crc5_err && !addr_err) begin
               clr_tok_pid_f     = 1'b1;
               tok_rcvd_nxt      = 1'b1;
               nxt_state         = IDLE;    
               if((pid_reg == OUT) || (pid_reg == SETUP)) begin
                  set_data_f  =  1'b1;
               end
            end
            else begin
               nxt_state   =  IDLE;
               clr_data_f  =  1'b1;
            end
         end
         else if(pid_reg == EXT) begin
            if(!crc5_err && !addr_err) begin
             //tok_rcvd_nxt      =  1'b1;
               set_exp_sub_pid_f  =  1'b1;
              //clr_ext_pid_f  =  1'b1;
               nxt_state      =  IDLE;
            end
         end
         else if(sub_pid_f) begin
            clr_sub_pid_f  =  1'b1;
            if(!crc5_err) begin
               tok_rcvd_nxt      =  1'b1;
               pd2pe_lpmValid_nxt=  1'b1;
            end
         end
      end      //CRC5_CHECK end
      
      endcase 
   end

   //-------------------------------------------------------
   //zero length packet
   //-------------------------------------------------------
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         pd2pe_zeroLenPkt  =  1'b0;
      end
      else if (swRst) begin
         pd2pe_zeroLenPkt  =  1'b0;
      end
      else begin
         pd2pe_zeroLenPkt  =  zlnt_rcvd_nxt;
      end
   end
   
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         data_f   =  1'b0;    //indicate data packet is for this device
      end
      else if (swRst) begin
         data_f   =  1'b0;
      end
      else if(set_data_f)   begin
         data_f   =  1'b1;
      end
      else if(clr_data_f) begin
         data_f   =  1'b0;
      end
   end
   
   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         exp_sub_pid_f  = 1'b0;
      end
      else if(swRst) begin
         exp_sub_pid_f  =  1'b0;
      end
      else if(set_exp_sub_pid_f) begin
         exp_sub_pid_f  =  1'b1;
      end
      else if(clr_exp_sub_pid_f) begin
         exp_sub_pid_f  =  1'b0;
      end
   end

   always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
         sub_pid_f  = 1'b0;
      end
      else if(swRst) begin
         sub_pid_f  =  1'b0;
      end
      else if(set_sub_pid_f) begin
         sub_pid_f  =  1'b1;
      end
      else if(clr_sub_pid_f) begin
         sub_pid_f  =  1'b0;
      end
   end

     always @(posedge coreClk or negedge coreRst_n) begin
      if(!coreRst_n) begin
	      pd2epcr_eot <= 1'b0;
       //  pd2reg_lpmRcvd =  1'b0;
      end
      else if(swRst) begin
	      pd2epcr_eot <= 1'b0;
      //   pd2reg_lpmRcvd =  1'b0;
      end
      else begin
	      pd2epcr_eot<= pd2epcr_eot1	;
     //    pd2reg_lpmRcvd =  lpm_rcvd_nxt;
      end
     end
endmodule
         
       



