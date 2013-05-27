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
// DATE			   : Mon, 04 Mar 2013 12:27:30
// AUTHOR		   : Anuj Pandey
// AUTHOR EMAIL	: anuj.pandey@techvulcan.com
// FILE NAME		: uctl_ahbCore.v
// VERSION No.    : 0.4
//-------------------------------------------------------------------
//TODO fixes in 0.4
// 1. we were using ctrl2ahbc_sRdWr to check a condition while assinging haddr and ahbc2ctrl_sWrAddr bt now we are using ctrl2ahbc_sRdWr_loc.

//TODO fixes in 0.3
// 1. htrans_nxt we were making sequential without seeing Hready. Now we seeing hready while making it sequential from nonsequential.

//TODO  fixes in 0.2
// 1. hWrite issue has been resolved. Earlier it was going low for ahbWrite and high for ahbRead.


module uctl_ahbCore #(
   parameter CNTR_WD     = 20          ,                               
             ADDR_SIZE   = 32          ,
             DATA_SIZE   = 32

)(
   //---------------------------------------------------
   // global signals
   //---------------------------------------------------
   input  wire                   uctl_sysRst_n         , 

   //---------------------------------------------------
   // System clk and soft reset
   //---------------------------------------------------
   input  wire                   sw_rst                , 
   input  wire                   uctl_sysClk           , 
 
   //---------------------------------------------------
   //control logic signals
   //---------------------------------------------------

   input  wire                   ctrl2ahbc_trEn        , // enbl signl frm control logic 2 strt the trnsfr
   input  wire [4            :0] ctrl2ahbc_beats       , // no f beats in a burst ( length f trnsfr ) 
                                                         // wil count from 1 to 16
   input  wire [2            :0] ctrl2ahbc_hSize       , // width of transfer

   output reg                    ahbc2ctrl_ack         , // ack from ahb to ctrl logic dt info has recvd 
   output reg                    ahbc2ctrl_addrDn      , // after trsnfrin burst, done frm ahb 2 ctrl lgic  
   output reg                    ahbc2ctrl_dataDn      , // after trsnfrin whole data, done frm ahb 2 ctrl lgic
   output wire [31           :0] ahbc2ctrl_sWrAddr     ,

   input  wire [ADDR_SIZE  -1:0] ctrl2ahbc_sRdAddr     , // System memory address
   input  wire [ADDR_SIZE  -1:0] ctrl2ahbc_sWrAddr     ,
   input  wire                   ctrl2ahbc_sRdWr       , // Read or write operation ( 1 - read, 0 - write) 


   
   //---------------------------------------------------
   // RD FIFO signals
   //---------------------------------------------------
   output wire                   ahbc2rdfifo_rdReq     , 

   input  wire [DATA_SIZE  -1:0] rdfifo2ahbc_rdData    ,
   input  wire                   rdfifo2ahbc_empty     ,

   //---------------------------------------------------
   // WR FIFO signals
   //---------------------------------------------------
   output wire                   ahbc2wrfifo_wrReq     ,
   output wire [DATA_SIZE    :0] ahbc2wrfifo_wrData    ,

   input  wire                   wrfifo2ahbc_full      ,
   input  wire                   wrfifo2ahbc_nfull     ,


   //---------------------------------------------------
   // ahb slave interface
   //---------------------------------------------------

   output reg                    hbusreq               ,
   output reg                    hwrite                ,  
   output reg  [1            :0] htrans                ,
   output wire [ADDR_SIZE  -1:0] haddr                 ,
   output wire [DATA_SIZE  -1:0] hwdata                ,
   output reg  [2            :0] hsize                 ,   
   output reg  [2            :0] hburst                ,        

   input  wire [DATA_SIZE  -1:0] hrdata                ,
   input  wire                   hgrant                ,
   input  wire                   hready                ,
   input  wire [1            :0] hresp            
   );

   //---------------------------------------------------
   //internal wire/reg
   //---------------------------------------------------
   reg                     hwRegRdReq                  ;
   reg                     hrRegWrReq                  ;
   wire                    hrRegRdReq                  ;
   reg                     hrRegFull_f                 ; 

   reg                     set_hrRegFull_f             ;
   wire                    clr_hrRegFull_f             ;

   reg [1              :0] part_cntr                   ; 
   reg [4              :0] beat_cntr                   ; // reg loaded with no of bytes in a burst
   reg [ADDR_SIZE    -1:0] sys_RdAddr_loc              ;  
   reg [ADDR_SIZE    -1:0] sys_RdAddr_loc_nxt          ;  
   reg [ADDR_SIZE    -1:0] sys_WrAddr_loc              ;  
   reg [ADDR_SIZE    -1:0] sys_WrAddr_loc_nxt          ;  
                                                         
   reg [1              :0] htrans_d                    ;                   
                                                             
   reg                     sys_RdAddr_ld               ; 
   reg                     sys_WrAddr_ld               ;

   reg                     beat_cntr_decr              ; // decrement signal for byte counter
   reg                     beat_cntr_incr              ;

   reg                     sys_RdAddr_incr             ; // increment signal for sys add countr
   reg                     sys_WrAddr_incr             ; // increment signal for sys add countr

   reg [2              :0] cur_state_saddr             ; // current state for system address
   reg [2              :0] nxt_state_saddr             ; // next state for  system address

   reg [1              :0] cur_state_sdata             ; // current state of sys data
   reg [1              :0] nxt_state_sdata             ; // nxt state of sys data
 
   reg                     ctrl_param_ld               ; // signal which indicates whn 2 ld signls frm ctrl
   reg [2              :0] ctrlHsize_r                 ;
   reg [4              :0] ctrlBeats_r                 ; // if of 5 bits cz it wil count from 1 to 16
   reg [DATA_SIZE    -1:0] wdata_r                     ; // internal reg in ahb for storing data
   reg [DATA_SIZE      :0] rdata_r                     ;
   reg                     hbusreq_nxt                 ;
   reg [1              :0] htrans_nxt                  ;
   reg [2              :0] hsize_nxt                   ;
   reg [2              :0] hburst_nxt                  ;
   reg                     hwrite_nxt                  ;
   wire                    beat_cntr_is_1              ;    
   reg                     sys_WrAddr_decr             ;
   reg                     sys_RdAddr_decr             ;
   reg                     wtForDataDone               ;
   reg                     ctrl2ahbc_sRdWr_r           ;
   reg [DATA_SIZE      :0] rdata_r_nxt                 ;
   reg                     rst_part_cntr               ;
   wire                    part_reg_empty              ;
   reg                     rst_beat_cntr               ;

   //---------------------------------------------------
   // local param 
   //---------------------------------------------------
   //states for  address phase
   localparam IDLE    = 3'b000        ;
   localparam WTGNT   = 3'b001        ;
   localparam TRANSRD = 3'b010        ;//trsfr state whn readin from fifo
   localparam WTRGNT  = 3'b011        ;
   localparam BUSYST  = 3'b100        ;
   localparam SPRETST = 3'b101        ;
   localparam TRANSWR = 3'b110        ;//trsfr state whn writing into the fifo
   localparam WTDPRDY = 3'b111        ;

   //states for data phase
   localparam IDLED   = 3'b00         ,
              TRANS   = 3'b01         ,
              WTDDN   = 3'b10         ;

   //Hsize params
   localparam BYTE    = 3'b000        ;
   localparam HWORD   = 3'b001        ;
   localparam WORD    = 3'b010        ;   
 

   localparam HIDLE   = 2'b00         ;
   localparam HBUSY   = 2'b01         ;
   localparam NONSEQ  = 2'b10         ;
   localparam SEQ     = 2'b11         ;
   localparam INCR16  = 3'b111        ;
   localparam INCR    = 3'b001        ;

   localparam OKAY    = 2'b00         ;
   localparam ERROR   = 2'b01         ;
   localparam RETRY   = 2'b10         ;
   localparam SPLIT   = 2'b11         ;   

   localparam AHBRD   = 1'b1          ;
   localparam AHBWR   = 1'b0          ;

   //---------------------------------------------------
   //code starts from here
   //---------------------------------------------------

   // beat counter
   always @ (posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      // beat_cntr is of 5 bits..it wil count from 1 to 16
      if(!uctl_sysRst_n) begin
         beat_cntr <= {5{1'b0}};             
      end
      else if(sw_rst) begin //TODO beat counter we have to rst whn ahbc2ctrl_dn is high ????
         beat_cntr <= {5{1'b0}};             
      end
      else begin
         if(ctrl_param_ld) begin
            beat_cntr <=ctrl2ahbc_beats;
         end
         else if (beat_cntr_decr)begin
            beat_cntr <= beat_cntr - 5'd1; 
         end
         else if(beat_cntr_incr)begin
            beat_cntr <= beat_cntr + 5'd1;
         end
         else if(rst_beat_cntr)begin
            beat_cntr <= 5'b00000;
         end
      end
   end


   always @ (posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n)begin
         htrans_d <= 2'b00;
      end
      else if(sw_rst) begin
         htrans_d <= 2'b00;
      end
      else begin
         htrans_d <= htrans;
      end
   end


   assign ahbc2rdfifo_rdReq   = (part_cntr == 2'b00 && hwRegRdReq == 1'b1) ? 1'b1: 1'b0;
   assign part_reg_empty      = (part_cntr == 2'b00) ? 1'b1: 1'b0;//TODO to be asked

   always @ (posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n)begin
         ctrl2ahbc_sRdWr_r <= 1'b0;
      end
      else if(sw_rst) begin
         ctrl2ahbc_sRdWr_r <= 1'b0;
      end
      else if(ctrl_param_ld)begin
         ctrl2ahbc_sRdWr_r <= ctrl2ahbc_sRdWr ;
      end
   end

   always @ (posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         part_cntr <= {2{1'b0}};             
      end
      else if(sw_rst || rst_part_cntr) begin
         part_cntr <= {2{1'b0}};             
      end
      else begin
         if(hwRegRdReq || hrRegWrReq) begin
            if(ctrlHsize_r == WORD) begin
               part_cntr <= 2'b00;
            end
            else if (ctrlHsize_r == HWORD && part_cntr == 2'b01) begin
               part_cntr <= 2'b00;
            end
            else if (ctrlHsize_r == BYTE  && part_cntr == 2'b11) begin
               part_cntr <= 2'b00;
            end
            else begin
               part_cntr <= part_cntr + 1'b1;
            end
         end
      end
   end
  
   // system read address
   always@(*) begin
      if(sys_RdAddr_ld) begin
         sys_RdAddr_loc_nxt = ctrl2ahbc_sRdAddr;
      end
      else if(sys_RdAddr_incr)begin 
         sys_RdAddr_loc_nxt = sys_RdAddr_loc + (1<<hsize) ;
      end
      else if(sys_RdAddr_decr)begin
         sys_RdAddr_loc_nxt = sys_RdAddr_loc - (1<<hsize) ;
      end
      else begin
         sys_RdAddr_loc_nxt = sys_RdAddr_loc;
      end    
   end

   always @ (posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         sys_RdAddr_loc <= {ADDR_SIZE{1'b0}};
      end
      else if(sw_rst) begin
         sys_RdAddr_loc <= {ADDR_SIZE{1'b0}};
      end
      else begin
         sys_RdAddr_loc <= sys_RdAddr_loc_nxt;
      end
   end

   // system write address
   always@(*) begin
      if(sys_WrAddr_ld) begin
         sys_WrAddr_loc_nxt = ctrl2ahbc_sWrAddr;
      end
      else if(sys_WrAddr_incr)begin 
         sys_WrAddr_loc_nxt = sys_WrAddr_loc + (1<<hsize) ;
      end
      else if(sys_WrAddr_decr)begin
         sys_WrAddr_loc_nxt = sys_WrAddr_loc - (1<<hsize) ;
      end
      else begin
         sys_WrAddr_loc_nxt = sys_WrAddr_loc;
      end    
   end

   always @ (posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         sys_WrAddr_loc <= {ADDR_SIZE{1'b0}};
      end
      else if(sw_rst) begin
         sys_WrAddr_loc <= {ADDR_SIZE{1'b0}};
      end
      else begin
        sys_WrAddr_loc  <= sys_WrAddr_loc_nxt;

      end
   end

   //TODO: Merge the rd and wr addr counters
   assign ahbc2ctrl_sWrAddr =  (ctrl2ahbc_sRdWr_r == AHBWR) ? sys_WrAddr_loc_nxt : sys_RdAddr_loc_nxt;

   always @ (posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         ctrlBeats_r <= 5'b00000;
         ctrlHsize_r <= 3'b000;
      end
      else if(sw_rst) begin
         ctrlBeats_r <= 5'b00000;
         ctrlHsize_r <= 3'b000;
      end
      else if (ctrl_param_ld) begin
         ctrlBeats_r <= ctrl2ahbc_beats;
         ctrlHsize_r <= ctrl2ahbc_hSize;
      end
      else begin
         ctrlBeats_r <= ctrlBeats_r; 
         ctrlHsize_r <= ctrlHsize_r; 
      end
      
   end

  always @ (posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         wdata_r <= {DATA_SIZE{1'b0}};
		end
      else if(sw_rst) begin
         wdata_r <= {DATA_SIZE{1'b0}};
		end
      else begin
         if(ahbc2rdfifo_rdReq) begin
            wdata_r <= rdfifo2ahbc_rdData;
         end
      end
   end

   assign haddr  = (ctrl2ahbc_sRdWr_r == AHBWR) ? sys_WrAddr_loc : sys_RdAddr_loc ;

   assign hwdata = wdata_r;
  
   always@(*) begin
      rdata_r_nxt = {ahbc2ctrl_dataDn, rdata_r[31:0]};
      case (ctrlHsize_r)
         WORD: begin
            rdata_r_nxt[31:0] = hrdata;
         end
         HWORD: begin
            case(part_cntr)
               2'b00    : rdata_r_nxt[15:00] = hrdata[15:00];
               2'b01    : rdata_r_nxt[31:16] = hrdata[31:16];
            endcase
         end
         BYTE: begin
            case(part_cntr)
               2'b00    : rdata_r_nxt[07:00] = hrdata[07:00];
               2'b01    : rdata_r_nxt[15:08] = hrdata[15:08];
               2'b10    : rdata_r_nxt[23:16] = hrdata[23:16];
               2'b11    : rdata_r_nxt[31:24] = hrdata[31:24];
            endcase
         end
      endcase
   end

   always@(posedge uctl_sysClk or negedge uctl_sysRst_n)begin
      if(!uctl_sysRst_n)begin
         rdata_r <= {DATA_SIZE{1'b0}};
      end
      else if(sw_rst)begin
         rdata_r <= {DATA_SIZE{1'b0}};
      end
      else begin
         if(hrRegWrReq) begin
            rdata_r <= rdata_r_nxt; 
         end
      end
   end
   assign ahbc2wrfifo_wrData = rdata_r;
   
   assign hrRegRdReq = (hrRegFull_f && !wrfifo2ahbc_full);
   assign ahbc2wrfifo_wrReq = hrRegRdReq; 

   assign clr_hrRegFull_f = 1'b1;
   always@(*) begin
      set_hrRegFull_f = 1'b0;
      case (hrRegWrReq)
         1'b0: begin
            set_hrRegFull_f = 1'b0;
         end
         1'b1: begin
            case (ctrlHsize_r)
               WORD: begin
                  set_hrRegFull_f = 1'b1;
               end
               HWORD: begin
                  if(part_cntr == 2'b01 || ahbc2ctrl_dataDn == 1'b1)begin
                     set_hrRegFull_f = 1'b1;
                  end
                  else begin
                     set_hrRegFull_f = 1'b0;
                  end
               end
               BYTE: begin
                  if(part_cntr == 2'b11 || ahbc2ctrl_dataDn == 1'b1) begin
                     set_hrRegFull_f = 1'b1;
                  end
                  else begin
                     set_hrRegFull_f = 1'b0;
                  end
               end
            endcase
         end
      endcase
   end

   always @ (posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         hrRegFull_f <= 1'b0;
      end
      else if (sw_rst) begin
         hrRegFull_f <= 1'b0;
      end
      else begin
         if(set_hrRegFull_f) begin
            hrRegFull_f <= 1'b1;
         end
         else if(clr_hrRegFull_f) begin
            hrRegFull_f <= 1'b0;
         end
      end
   end


   
   always @ (posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         hbusreq <= 1'b0;                     
         htrans  <= HIDLE;                     
         hsize   <= 3'b000;                     
         hburst  <= 3'b000;  
         hwrite  <= 1'b0;                    
      end   
      else if(sw_rst) begin
         hbusreq <= 1'b0;                     
         htrans  <= HIDLE;                     
         hsize   <= 3'b000;                     
         hburst  <= 3'b000;  
         hwrite  <= 1'b0;                    
      end   
      else begin
         hbusreq <= hbusreq_nxt;                     
         htrans  <= htrans_nxt;                     
         hsize   <= hsize_nxt;                     
         hburst  <= hburst_nxt;
         hwrite  <= hwrite_nxt;
      end 
   end

   assign beat_cntr_is_1 = (beat_cntr == 5'b00001) ? 1'b1 : 1'b0;


   // sys address state machine
   // -------------------------------------
   always@(*) begin
      nxt_state_saddr   = cur_state_saddr;
      hwrite_nxt        = hwrite; 
      hbusreq_nxt       = hbusreq;
      htrans_nxt        = htrans;                     
      hburst_nxt        = hburst;
      ahbc2ctrl_ack     = 1'b0;
      hsize_nxt         = hsize;
      wtForDataDone     = 1'b0;
      ahbc2ctrl_addrDn  = 1'b0;
      ctrl_param_ld     = 1'b0;
      hwRegRdReq        = 1'b0;
      beat_cntr_decr    = 1'b0;
      beat_cntr_incr    = 1'b0;
      sys_RdAddr_ld     = 1'b0;
      sys_WrAddr_ld     = 1'b0;
      sys_WrAddr_decr   = 1'b0;
      sys_RdAddr_decr   = 1'b0;
      sys_WrAddr_incr   = 1'b0;
      sys_RdAddr_incr   = 1'b0;
      rst_beat_cntr     = 1'b0;
      case(cur_state_saddr) 
         // default state 
         IDLE: begin//{
            htrans_nxt = HIDLE;
            hwrite_nxt = 1'b0;
            hbusreq_nxt= 1'b0;
            hburst_nxt = 3'b000;
            hsize_nxt  = BYTE;
            rst_beat_cntr = 1'b1;
            if(ctrl2ahbc_trEn == 1'b1)begin
               ctrl_param_ld        = 1'b1;  
               ahbc2ctrl_ack        = 1'b1;
               if(ctrl2ahbc_sRdWr== AHBRD)begin
                  sys_RdAddr_ld  = 1'b1;
                  if(wrfifo2ahbc_nfull == 1'b1) begin
                     nxt_state_saddr = WTDPRDY;
                  end
                  else begin
                     nxt_state_saddr    = WTGNT;
                     hbusreq_nxt        = 1'b1;
                  end
               end
               else begin
                  sys_WrAddr_ld  = 1'b1;
                  if(rdfifo2ahbc_empty) begin
                     nxt_state_saddr = WTDPRDY;
                  end
                  else begin
                     nxt_state_saddr    = WTGNT;
                     hbusreq_nxt        = 1'b1;
                  end
               end
            end

         end//}

         WTDPRDY: begin
            if(ctrl2ahbc_sRdWr_r == AHBRD) begin
               if(wrfifo2ahbc_nfull == 1'b0) begin
                  hbusreq_nxt     = 1'b1;
                  nxt_state_saddr = WTGNT;
               end
            end
            else begin
               if(!rdfifo2ahbc_empty) begin
                  hbusreq_nxt     = 1'b1;
                  nxt_state_saddr = WTGNT;
               end
            end
         end

         // state when waiting for Bus grant
         WTGNT:  begin
            hbusreq_nxt          = 1'b1;
            if(hgrant == 1'b1 && hready == 1'b1) begin
               htrans_nxt          = NONSEQ;
               hsize_nxt           = ctrlHsize_r;

               if(ctrl2ahbc_sRdWr_r==AHBWR)     begin
                  nxt_state_saddr  = TRANSRD; //ahbWrite
                  hwrite_nxt       = 1'b1;
               end
               else begin
                  nxt_state_saddr  = TRANSWR; //ahbRead
                  hwrite_nxt       = 1'b0;
               end

               if(ctrlBeats_r == 5'b10000)       begin
                  hburst_nxt       = INCR16; 
               end
               else begin
                  hburst_nxt       = INCR;
               end
            end
         end


         // transfer state for reading from fifo--write state w.r.t ahb slave 
         TRANSRD: begin // ahbWrite
            hbusreq_nxt      = 1'b1;
            if(hready)begin
               htrans_nxt       = SEQ;
               if(rdfifo2ahbc_empty && part_reg_empty)begin
                  nxt_state_saddr = BUSYST;               
                  htrans_nxt      = HBUSY;
               end
               else begin//{
                  hwRegRdReq  = 1'b1;
                  sys_WrAddr_incr   = 1'b1;
                  beat_cntr_decr   = 1'b1;
                  // The last address phase is going on
                  if(beat_cntr_is_1) begin
                     if(ctrl2ahbc_trEn) begin
                        ctrl_param_ld   = 1'b1;
                        sys_WrAddr_ld   = 1'b1;
                        hbusreq_nxt     = 1'b1;
                        ahbc2ctrl_ack   = 1'b1;
                        if(hgrant)  begin
                           if(ctrl2ahbc_sRdWr == AHBWR)begin
                              nxt_state_saddr   = TRANSRD;
                           end 
                           else begin
                              nxt_state_saddr   = TRANSWR;
                           end               
                           htrans_nxt        = NONSEQ; // new burst
                        end
                        else begin
                           nxt_state_saddr = WTGNT;
                        end
                     end
                     else begin
                        nxt_state_saddr = IDLE;               
                        htrans_nxt      = HIDLE;
                     end
                     wtForDataDone    =  1'b1;
                     ahbc2ctrl_addrDn =  1'b1;
                  end
                  else if (hgrant) begin
                     nxt_state_saddr  = TRANSRD;
                  end
                  else if (~hgrant) begin 
                     // Lost the grant in the mid of transfer.
                     // wait for grant again. This time we
                     // always go for INCR.
                     nxt_state_saddr = WTRGNT;
                  end
               end//}
            end
            else if(hresp == SPLIT || hresp == RETRY)begin
               nxt_state_saddr = SPRETST;
               htrans_nxt      = HIDLE;
               sys_WrAddr_decr = 1'b1;
               beat_cntr_incr  = 1'b1;
               hbusreq_nxt     = 1'b1;
            end//hready
         end
         
         // transfr state for writing into the fifo..reading w.r.t ahb slave
         TRANSWR: begin // ahbRead
            hbusreq_nxt          = 1'b1;
            if(hready)begin
               htrans_nxt           = SEQ;
               if(wrfifo2ahbc_nfull == 1'b1)begin
                  nxt_state_saddr = BUSYST;               
                  htrans_nxt      = HBUSY;
               end
               else begin//{
                  beat_cntr_decr   = 1'b1;
                  sys_RdAddr_incr  = 1'b1;
                  // The last address phase is going on
                  if(beat_cntr_is_1) begin
                     if(ctrl2ahbc_trEn) begin
                        if(hgrant)  begin
                           if(ctrl2ahbc_sRdWr == AHBWR)begin
                              nxt_state_saddr   = TRANSRD;
                           end 
                           else begin
                              nxt_state_saddr   = TRANSWR;
                           end               
                           htrans_nxt      = NONSEQ; // new burst
                        end
                        else begin
                           nxt_state_saddr = WTGNT;
                        end
                        ctrl_param_ld     = 1'b1;
                        sys_RdAddr_ld     = 1'b1;
                        hbusreq_nxt       = 1'b1;
                        ahbc2ctrl_ack     = 1'b1;
                     end
                     else begin
                        nxt_state_saddr = IDLE;               
                        htrans_nxt      = HIDLE;
                     end
                     wtForDataDone    = 1'b1;
                     ahbc2ctrl_addrDn = 1'b1;
                  end
                  else if (hgrant) begin
                     nxt_state_saddr  = TRANSWR;
                  end
                  else if (~hgrant) begin 
                     // Lost the grant in the mid of transfer.
                     // wait for grant again. This time we
                     // always go for INCR.
                     nxt_state_saddr = WTRGNT;
                  end
               end//}
            end
            else if(hresp == SPLIT || hresp == RETRY)begin
               nxt_state_saddr = SPRETST;
               htrans_nxt      = HIDLE;
               sys_RdAddr_decr = 1'b1;
               beat_cntr_incr  = 1'b1;
               hbusreq_nxt     = 1'b1;
            end//hready

         end


         // wait for Re-grant state
         WTRGNT: begin
            hbusreq_nxt          = 1'b1;
            if(hgrant && hready)begin
               htrans_nxt       = NONSEQ;  // new transfer
               hburst_nxt       = INCR;    // always INCR

               if(ctrl2ahbc_sRdWr_r==AHBWR)begin
                  nxt_state_saddr  = TRANSRD;
               end
               else begin
                  nxt_state_saddr  = TRANSWR;
               end
            end
         end
         
         // when fifo is either full or empty
         BUSYST: begin
            if(!rdfifo2ahbc_empty && hready)begin
               nxt_state_saddr = TRANSRD;               
               htrans_nxt      = SEQ;
            end
            else if(!wrfifo2ahbc_nfull && hready)begin
               nxt_state_saddr = TRANSWR;               
               htrans_nxt      = SEQ;
            end
            else begin
               htrans_nxt      = HBUSY;
            end
         end


         //split-retry state
         SPRETST: begin                                          
            hbusreq_nxt = 1'b1;
            if(hgrant & hready) begin
               if(ctrl2ahbc_sRdWr_r==AHBWR)begin
                  nxt_state_saddr = TRANSRD;
               end
               else begin
                  nxt_state_saddr = TRANSWR;
               end
               htrans_nxt = NONSEQ;
               hburst_nxt= INCR;
            end
            else begin
               htrans_nxt = HIDLE;
            end
         end

      endcase
    end

   //state machine for system data
   always@(*) begin
      nxt_state_sdata   = cur_state_sdata;
      ahbc2ctrl_dataDn  = 1'b0;
      rst_part_cntr     = 1'b0;
      hrRegWrReq        = 1'b0;

      case(cur_state_sdata) 

         IDLED: begin
            if(hready) begin
               if(wtForDataDone) begin
                  nxt_state_sdata = WTDDN;
               end
               else if (htrans == NONSEQ) begin
                  nxt_state_sdata = TRANS;
               end 
               else begin
                  nxt_state_sdata = IDLED;
               end
            end
         end

         TRANS : begin
            if(hready && htrans_d != HBUSY) begin
               if(hresp == RETRY || hresp == SPLIT) begin
                  hrRegWrReq = 1'b0;
                  nxt_state_sdata = IDLED;
               end
               else begin
                  if(wtForDataDone) begin
                     nxt_state_sdata = WTDDN;
                  end
                  if((!wrfifo2ahbc_full || !hrRegFull_f)&&ctrl2ahbc_sRdWr_r == AHBRD) begin
                     hrRegWrReq = 1'b1;
                  end
               end
            end
         end

         WTDDN: begin//{
            if(hready) begin
               ahbc2ctrl_dataDn = 1'b1;
               rst_part_cntr    = 1'b1;
               if(wtForDataDone) begin
                  nxt_state_sdata = WTDDN;
               end
               else if (htrans == NONSEQ) begin
                  nxt_state_sdata = TRANS;
               end 
               else begin
                  nxt_state_sdata = IDLED;
               end

               if((!wrfifo2ahbc_full || !hrRegFull_f)&&ctrl2ahbc_sRdWr_r==AHBRD) begin
                  hrRegWrReq = 1'b1;
               end

            end
         end//}
      endcase

   end
    

   // for system address
   always@(posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         cur_state_saddr <= IDLE;
      end
      else if (sw_rst) begin
         cur_state_saddr <=  IDLE;
      end
      else begin
         cur_state_saddr <= nxt_state_saddr;
      end
   end 


   // for system data
   always@(posedge uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n) begin
         cur_state_sdata <= IDLE;
      end
      else if (sw_rst) begin
         cur_state_sdata <=  IDLE;
      end
      else begin
         cur_state_sdata <= nxt_state_sdata;
      end
   end 

endmodule

