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
// DATE		   	: Fri, 08 Feb 2013 14:59:02
// AUTHOR	      : Lalit Kumar
// AUTHOR EMAIL	: lalit.kumar@techvulcan.com
// FILE NAME		: uctl_protocol_engine.v
// VERSION        : 0.4
//-------------------------------------------------------------------
/* TODO
 *
 *
 * MAY 23 upgradation in control trnasfer
updation in 0.4

   all interrupts have been added

updation in 0.3
   all basic and error cases of control transfer have been implemented 
    
fixes in 0.2
 1. STALL has provided highest priority for handshake 
 2. new signal epcr2pe_hwStall is added to check the condition 
   packet size>wMaxPaketSize and for this condition controller 
   will drop the packet

epct2peReadError
epcr2peWriteError
pd2pe_ready        should be from epc   changed to epcr2pe_ready   
RxHS1 to TxHeader state transition (is it needed ?) action: removed
TxHs (redundant ?)   action : removed
pa2pe_dataReady   ??how to use??  action removed      
PING in OTG mode
data PID is not matching 
*/


module uctl_protocol_engine ( 
   input wire                   core_clk                  , //The core clock
   input wire                   uctl_rst_n                , //Active low reset
   input wire                   sw_rst                    , //synchronous software reset

   // ------------------------------------------------ ----------------
   // pd interface      
   // ------------------------------------------------ ----------------
   input wire                   pd2pe_tokenValid          , //token received from PD
   input wire [3				:0]  pd2pe_tokenType           , //token type:token, data pid, handshake
   input wire [3				:0]  pd2pe_epNum               , //Endpoint number
   input wire                   pd2pe_eot                 , //Last data received by PD for OUT
   input wire                   pd2pe_lpmValid               ,//LPM valid
   input wire [10        :0]    pd2pe_lpmData                ,//LPM data

  // input wire                   pd2pe_zeroLenPkt        , //zero data payload packet received TODO

   // ------------------------------------------------ ----------------
   // epcr interface  
   // ------------------------------------------------ ----------------
   input wire                   epcr2pe_epHalt            , //current Rx EP is halted      
   input wire                   epcr2pe_bufFull           , //Rx Buffer full
   input wire                   epcr2pe_bufNearlyFull     , //available space is <wMaxPaketSize
   input wire                   epcr2pe_wrErr             , //wrong PE number, wrong direction etc
   input wire                   epcr2pe_getWrPtrsDn          , //buffer info has been read by epcr
  // input wire                 epcr2pe_epDir             , //EP is IN or OUT                                      
   input wire [1				:0]  epcr2pe_epType            , //EP type:Control, Interrupt, Isochro or Bulk
   input wire [3				:0]  epcr2pe_expctDataPid      , //expected data token for current pkt
   input wire                   epcr2pe_hdrWrDn           , //Header read for buffer is completed
   input wire                   epcr2pe_wrBufUpdtDn       , //Buffer info has been updated on successful transfer
   input wire                   epcr2pe_hwStall           ,
   input wire                   epcr2pe_ready             , //last data has been accepted by epc
   input wire                   epcr2pe_packetDroped      ,
   input wire                   epcr2pe_ctrlNAK           ,
   input wire                   epcr2pe_setupStall        ,   // more than 8 bit data in setup
   input wire [2         -1:0]  epcr2pe_enuAct            ,
   input wire [3         -1:0]  epcr2pe_ctlTransStage     ,

   output reg                   pe2epcr_getWrPtrs         , //read pointer info(wptr,full, direction etc)
   output reg                   pe2epcr_wrEn              , //write enable signal for incoming data packet
   output reg                   pe2epcr_rxHdrWr           , //write header after last data of pkt received
   output reg                   pe2epcr_updtWrBuf         , //update buffer info on successful transmission
   output wire                  pe2epcr_regWr             ,
   output wire                  pe2eptd_initIsoPid        ,

   // ------------------------------------------------------------------
   // crc interface      
   // ----------------------------------------------------------------
   input wire                   crc2pe_statusValid        , //CRC valid signal from CRC engine
   input wire                   crc2pe_status             , //1: Valid CRC match, 0	: mismatch

   // ----------------------------------------------------------------
   // epct interface  
   // ----------------------------------------------------------------
   input wire                   epct2pe_rdErr             , //Ep error	:direction, EP number etc..
   input wire                   epct2pe_getRdPtrsDn          , //current status of EP has been received
  // input wire                   epct2pe_epDir             , //direction of current EP				: IN or OUT
   input wire [1				:0]  epct2pe_epType            , //EP type:bulk, isoch, intterupt or control
   input wire [3				:0]  epct2pe_expctDataPid      , //expected data PID	:DATA0,DATA1,..,..MDATA etc
   input wire                   epct2pe_hdrRdDn           , //header read is completed
   input wire                   epct2pe_rdBufUpdtDn       , //buffer info is updated in data reg after successful transfer
   input wire                   epct2pe_epHalt            , //end point halt condition
   input wire                   epct2pe_epZeroLenEn       , //if high, send zero length packet
   input wire                   epct2pe_bufEmpty          , //buffer is empty

   output reg                   pe2epct_rdEn                , //buffer read enable signal
   output reg                   pe2epct_hdrRd             , //header read command 
   output reg                   pe2epct_updtRdBuf         , //update buffer signal
   output reg                   pe2epct_getRdPtrs         , //get buffer pointers and status
   output reg                   pe2eptd_intPid            ,
   output reg                   pe2epct_ctrlZlp           ,  //send zlp for control if IN data stage is completed and new IN token is received

   // ----------------------------------------------------------------              
   // pa interface 
   // ----------------------------------------------------------------           
   input wire                   pa2pe_eot                 , //PA has received last data from epct

   //For OTG
   output reg                  pe2pa_tokenValid           , //valid Token PID is available for PA
   output reg  [3				:0] pe2pa_tokenType            , //Token type to transmit: SETUP, IN, OUT etc

   // ----------------------------------------------------------------
   //    epc interface   
   // --------------- -------------------------------------------------  
   output  reg                 pe2epc_idleState           , //high if PE is in IDLE state
   output  wire[3          :0] pe2epc_epNum               , //current EP number
   output  wire[3          :0] pe2epc_tokenType           , //token Type:SETUP, PING, IN, OUT 


   // -----------------------------------------------------------------
   // reg interface 
   // -----------------------------------------------------------------
   //for OTG
   input wire                   reg2pe_enHost              , // 0	: device mode, 1:host mode
   input wire                   reg2pe_enOTGTrans          , //OTG transfer started
   input wire [3           :0]  reg2pe_epNum               , //
   input wire                   reg2pe_devHalt             , // Device is halted if set
   input wire [2				 :0] reg2pe_usbMode             , // LS,FS,HS,SS TODO    
   input wire [3            :0] reg2pe_tokenType           ,    
   output wire                  pe2reg_transSent           ,
   output wire                  pe2reg_clrCmdReg           ,
   output reg                   pe2reg_lpmRcvd             ,
   output reg                   pe2reg_remoteWakeUp        , 
   // -----------------------------------------------------------------
   // eptd interface 
   // -----------------------------------------------------------------
   input  wire                  eptd2pe_noTransPending     ,
   // -----------------------------------------------------------------
   // frame counter interface 
   // -----------------------------------------------------------------
   input  wire                   frmCntr2pe_frmBndry       
);
   
   // ----------------------------------------------------------------
   // reg/wires
   // ---------------------------------------------------------------
   reg   [3                 :0] current_token      ;
   reg   [3                 :0] current_epNum      ;
   reg                          epct_rdErr         ; 
   reg   [1                 :0] epct_epType        ;
   wire   [1                 :0]      epType        ;
   reg   [3                 :0] epct_expctDataPid  ;
   reg                          epct_epHalt        ;
   reg                          epct_epZeroLenEn   ;
   reg                          epct_bufEmpty      ;
   reg                          epcr_epHalt        ;
   wire                         epcr_bufFull       ;
   wire                         epcr_bufNearlyFull ;
   reg                          epcr_wrErr         ;
   reg   [1                 :0] epcr_epType        ;
   reg   [3                 :0] epcr_expctDataPid  ;
   reg   [3                 :0] current_token_nxt  ;
   reg   [3                 :0] current_epNum_nxt  ;
   reg                          regisretRdPtrs     ;
   reg                          regisretWrPtrs     ; 
   wire                         packet_droped      ;
   reg                          set_reg_wr_flag    ;  
   reg                          clr_reg_wr_flag    ;  
   reg                           set_hw_stall      ; 
   reg                           clr_hw_stall      ;
   reg                           hw_stall          ; 
   reg                           setup_trans       ;
   reg                           data_pidRcvd      ;
   wire                          packet_accepted   ; 
   wire                          hs_bulk_ep        ; 
   wire                          rx_stall          ;
 //wire                          status_stage_stall      ;
   wire                          tx_stall          ;
   wire                          ctrlTx_stall      ;
   wire                          tx_hs             ;
   wire                          devToken_val      ;
   wire                          otgToken_val      ;
   wire                          ctr_INd_stage_done;
   wire                          ctr_OUTd_stage_done;
   reg                           set_staus_nak    ; 
   reg                           clr_staus_nak    ; 
   reg                           status_nak       ;
   reg [10               -1:0]   lpm_atributes    ;
   wire                          ctrINDataStageZlp ;
   reg  [3               -1:0]   nxt_ctrlStage     ;
   reg                           pe2epct_ctrlZlp_nxt;

   // ----------------------------------------------------------------
   // local parameters
   // ---------------------------------------------------------------
   // FSM variables
   // ---------------------------------------------------------------
   reg  [4                 :0] current_state, 
                               next_state;
   localparam  IDLE           =  5'b00000,    //default state
               DEV_GETEPPTR   =  5'b00001,    //read pointers and status of end point
               DEV_TXHS       =  5'b00010,    //handshake if IN &empty,Halt or PING, 
               DEV_TXHDR      =  5'b00011,    //read header for IN transfer
               DEV_TXDATA     =  5'b00100,    //data transfer state for IN transfer
               DEV_ISOUPDT    =  5'b00101,    //buffer update for isochronous IN
               TXUPDT         =  5'b00110,    //buffer update in case of non isochronous IN
               DEV_RXDATA     =  5'b00111,    //data transfer for OUT
               DEV_RXHS       =  5'b01000,    //generate handshake for OUT 
               DEV_RXHDR      =  5'b01001,    //write header for ACK/NYET
               DEV_RXUPDT     =  5'b01010,    //update buffer info
               HOST_GETEPPTR  =  5'b01011,    //read pointers and status of end point
               HOST_TXTOKEN   =  5'b01100,    //generate token in OTG mode
               HOST_TXHDR     =  5'b01101,    //read header for OTG OUT
               HOST_TXDATA    =  5'b01110,    //transfer data for OTG OUT
               CRCCHK         =  5'b01111,    //update buffer info
               LPM            =  5'b10000;
   
   // token type parameters       
   // ---------------------------------------------------------------
   localparam  OUT            =  4'b0001 ,  
               IN             =  4'b1001 , 
               PING           =  4'b0100 , 
               SETUP          =  4'b1101 , 
               DATA0          =  4'b0011 , 
               DATA1          =  4'b1011 , 
               DATA2          =  4'b0111 , 
               MDATA          =  4'b1111 , 
               ACK            =  4'b0010 , 
               NAK            =  4'b1010 , 
               STALL          =  4'b1110 , 
               NYET           =  4'b0110 ,
               RSRVD          =  4'b0000 ; 

   // end point type parameters       
   // ---------------------------------------------------------------
    localparam CONTROL        = 2'b00    ,    
               ISOCHRONOUS    = 2'b01    ,
               BULK           = 2'b10    ,
               INTERRUPT      = 2'b11    ;

   // usb mode (speed) type parameters       
   // ---------------------------------------------------------------
     localparam LS            = 3'b000    ,
                FS            = 3'b001    ,
                HS            = 3'b010    ,
                SS            = 3'b011    ;

   // control transfer setup stages          
   // ---------------------------------------------------------------
   localparam  STATUS_OUT     = 3'b100    ,
               STATUS_IN      = 3'b110    ,
               DATA_OUT       = 3'b101    ,
               DATA_IN        = 3'b111    ;
   // ---------------------------------------------------------------
   // Code starts here
   // ---------------------------------------------------------------
   assign ctrINDataStageZlp   = nxt_ctrlStage  &&(current_token == IN)&& (epcr2pe_enuAct==2'b00) ? 1'b1:1'b0; 
   assign pe2reg_transSent    = 1'b0;
   assign pe2eptd_initIsoPid  = frmCntr2pe_frmBndry; 
   assign pe2reg_clrCmdReg    = (pe2eptd_intPid ||ctr_INd_stage_done ||ctr_OUTd_stage_done)&& (epcr2pe_enuAct != 2'b11)    ? 1'b1:1'b0;
   assign packet_droped       = epcr2pe_packetDroped ;        
   assign pe2epcr_regWr       = setup_trans;
   assign init_wrong_pid      =( epcr2pe_enuAct    ==2'b11) && data_pidRcvd && !setup_trans&&(pd2pe_tokenType!= DATA1) ? 1'b1: 1'b0;  
   assign packet_accepted     =(epcr_bufNearlyFull||(epcr_bufFull && !packet_droped))? 1'b1:1'b0; 
   assign hs_bulk_ep          =((reg2pe_usbMode == HS)&&(epcr_epType==BULK))? 1'b1:1'b0;
   assign rx_stall            = (epcr_epHalt||epcr2pe_hwStall||(epcr_epType == CONTROL) && hw_stall) ? 1'b1:1'b0;
   assign tx_hs               = (epct2pe_bufEmpty || epct2pe_epHalt || (epct_epType == CONTROL) && hw_stall)? 1'b1 :1'b0;
   assign otgToken_val        =(reg2pe_enHost && reg2pe_enOTGTrans)? 1'b1 : 1'b0;
   assign devToken_val        =(!reg2pe_enHost && pd2pe_tokenValid) ? 1'b1 : 1'b0;
 //assign tx_stall            = (epct_epHalt ||epcr_epHalt || reg2pe_devHalt || (epct_epType == CONTROL) && hw_stall)?1'b1: 1'b0;
   assign tx_stall            = ((epct_epHalt&& (current_token==IN)) ||
                                (epcr_epHalt&& (current_token==PING)) || reg2pe_devHalt) ? 1'b1 : 1'b0;
   assign ctrlTx_stall        = ((epType == CONTROL) && hw_stall)?1'b1: 1'b0;
   assign epType              = (current_token==PING) ? epcr_epType : epct_epType;
   assign ctr_INd_stage_done  = (epcr2pe_ctlTransStage== DATA_OUT) && (pd2pe_tokenType== IN)? 1'b1 : 1'b0;
   assign ctr_OUTd_stage_done = (epcr2pe_ctlTransStage== DATA_IN ) && (pd2pe_tokenType==OUT) ? 1'b1 : 1'b0;
   assign hs_nak              = (((current_token == IN  )&& epct_bufEmpty)|| status_nak  ||
                                 (current_token == PING)&& (epcr_bufFull || //Bulk OUT and Control endpoints 
                                 epcr_bufNearlyFull)) ? 1'b1: 1'b0;
   assign pe2epc_epNum        = current_epNum	;
   assign pe2epc_tokenType    = current_token	; 
   assign epcr_bufFull        = epcr2pe_bufFull | epcr2pe_ctrlNAK;  
   assign epcr_bufNearlyFull  = epcr2pe_bufNearlyFull;  


   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         nxt_ctrlStage  <= 3'b000;
      end
      else if(  sw_rst    ) begin
         nxt_ctrlStage  <= 3'b000;
      end
      else if((epcr2pe_enuAct    ==2'b11) && (epcr2pe_ctlTransStage == DATA_IN)) begin
         nxt_ctrlStage  <= STATUS_OUT;
      end
   end
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         lpm_atributes  <= {11{1'b0}};    
      end
      else if(sw_rst    ) begin
         lpm_atributes  <= {11{1'b0}};    
      end
      else if(pd2pe_lpmValid) begin 
         lpm_atributes  <= pd2pe_lpmData;
      end
      else begin
         lpm_atributes  <= lpm_atributes;
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         status_nak  <= 1'b0;
      end
      else if(sw_rst   ) begin
         status_nak  <= 1'b0;
      end
      else if(set_staus_nak     ) begin
         status_nak  <= 1'b1;
      end
      else if(clr_staus_nak     ) begin
         status_nak  <= 1'b0;
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         hw_stall    <= 1'b0;
      end
      else if(sw_rst   ) begin
         hw_stall    <= 1'b0;
      end
      else if(set_hw_stall | epcr2pe_setupStall|init_wrong_pid/*|status_stage_stall*/) begin //stall for 1. wrong data pid in setup
         hw_stall    <= 1'b1;                                         //          2. more than 8B in setup
      end                                                             //          3. wrong 1st data pid in data stage 
      else if(clr_hw_stall) begin
         hw_stall    <= 1'b0;
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         current_token        <= RSRVD;
         current_epNum        <= 4'b0 ; 
      end
      else if( sw_rst) begin
         current_token        <= RSRVD;
         current_epNum        <= 4'b0 ; 
      end
      else begin
		   current_token        <= current_token_nxt    ;
		   current_epNum        <= current_epNum_nxt    ;
      end
   end

  
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epct_rdErr           <= 1'b0 ;
         epct_epType          <= 1'b0 ;
         epct_expctDataPid    <= 1'b0 ;
         epct_epHalt          <= 1'b0 ;
         epct_epZeroLenEn     <= 1'b0 ;
         epct_bufEmpty        <= 1'b0 ;
         epcr_epHalt          <= 1'b0 ;
         epcr_wrErr           <= 1'b0 ;
         epcr_epType          <= 1'b0 ;
         epcr_expctDataPid    <= 1'b0 ;

      end
      else if( sw_rst) begin
         epct_rdErr           <= 1'b0 ;
         epct_epType          <= 1'b0 ;
         epct_expctDataPid    <= 1'b0 ;
         epct_epHalt          <= 1'b0 ;
         epct_epZeroLenEn     <= 1'b0 ;
         epct_bufEmpty        <= 1'b0 ;
         epcr_epHalt          <= 1'b0 ;
         epcr_wrErr           <= 1'b0 ;
         epcr_epType          <= 1'b0 ;
         epcr_expctDataPid    <= 1'b0 ;

      end
      else begin
         if(regisretRdPtrs) begin 
            epct_rdErr        <= epct2pe_rdErr        ; 
            epct_epType       <= epct2pe_epType       ;
            epct_expctDataPid <= epct2pe_expctDataPid ;
            epct_epHalt       <= epct2pe_epHalt       ;
            epct_epZeroLenEn  <= epct2pe_epZeroLenEn  ; 
            epct_bufEmpty     <= epct2pe_bufEmpty     ;
         end  
         if(regisretWrPtrs) begin 
            epcr_epHalt       <= epcr2pe_epHalt       ;  
            epcr_wrErr        <= epcr2pe_wrErr        ;  
            epcr_epType       <= epcr2pe_epType       ;  
            epcr_expctDataPid <= epcr2pe_expctDataPid ;  
         end
      end
   end
 

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         pe2epct_ctrlZlp    <=  1'b0;
      end
      else if(  sw_rst    ) begin
         pe2epct_ctrlZlp    <=  1'b0;
      end
      else begin 
         pe2epct_ctrlZlp    <= pe2epct_ctrlZlp_nxt;
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         setup_trans  <= 1'b0;
      end
      else if(sw_rst) begin
         setup_trans  <= 1'b0;
      end
      else if(set_reg_wr_flag)begin
         setup_trans  <= 1'b1;
      end
      else if(clr_reg_wr_flag)begin
         setup_trans  <= 1'b0;
      end
   end
      
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         current_state  <= IDLE                       ;
      end
      else if(sw_rst) begin
         current_state  <= IDLE                       ;
      end
      else begin
		   current_state <= next_state                  ;
      end
   end

   // FSM combinational block
   // ---------------------------------------------------------------
   always @ * begin
   	next_state              = current_state;
      current_token_nxt       = current_token;
      current_epNum_nxt       = current_epNum;
      pe2epcr_getWrPtrs       = 1'b0         ;              
      pe2epct_getRdPtrs       = 1'b0         ;
      pe2epcr_wrEn            = 1'b0         ;
      pe2epct_hdrRd           = 1'b0         ;
      pe2epct_rdEn            = 1'b0         ;
      pe2epct_updtRdBuf       = 1'b0         ;
      pe2epcr_rxHdrWr         = 1'b0         ;
      pe2epcr_updtWrBuf       = 1'b0         ;
      pe2pa_tokenValid        = 1'b0         ;
      regisretRdPtrs          = 1'b0         ;
      regisretWrPtrs          = 1'b0         ;
      pe2epc_idleState        = 1'b0         ;   
      pe2pa_tokenType         = 4'b0         ;
      set_reg_wr_flag         = 1'b0         ;
      clr_reg_wr_flag         = 1'b0         ;
      pe2eptd_intPid          = 1'b0         ;
      set_hw_stall            = 1'b0         ;
      clr_hw_stall            = 1'b0         ;
      data_pidRcvd            = 1'b0         ;
      set_staus_nak           = 1'b0         ;
      clr_staus_nak           = 1'b0         ;
      pe2reg_lpmRcvd          = 1'b0         ;
      pe2reg_remoteWakeUp     = 1'b0         ;
      pe2epct_ctrlZlp_nxt     = pe2epct_ctrlZlp;

	   case(current_state)
	      IDLE : begin 
            pe2epc_idleState     = 1'b1             ;   
            if(otgToken_val) begin 
		         current_token_nxt = reg2pe_tokenType ;
		         current_epNum_nxt = reg2pe_epNum     ;
               next_state        = HOST_GETEPPTR    ;   
            end 
            if(devToken_val) begin 
               current_token_nxt  = pd2pe_tokenType ;
		         current_epNum_nxt  = pd2pe_epNum     ;
               if(pd2pe_tokenType  == SETUP ||
                  pd2pe_tokenType  == IN    ||
                  pd2pe_tokenType  == OUT   ||
                  (pd2pe_tokenType  ==  PING) &&
                   reg2pe_usbMode == HS) begin                                                     
                  next_state        = DEV_GETEPPTR  ;
                  
               end  
               else if(pd2pe_tokenType  == DATA0 &&
                       pd2pe_lpmValid   == 1'b1) begin 
                  next_state     = LPM ;
               end
                  
               else if(pd2pe_tokenType  == DATA0 || 
                       pd2pe_tokenType  == DATA1 || 
                       pd2pe_tokenType  == DATA2 || 
                       pd2pe_tokenType  == MDATA) begin 
                       data_pidRcvd     =  1'b1;
                  next_state     = DEV_RXDATA      ;
               end 
               else if(pd2pe_tokenType  == ACK ||
                       pd2pe_tokenType  == NYET) begin 
                  next_state        =  TXUPDT   	;                      
               end 
            end   
         end 

         DEV_GETEPPTR : begin
            if(current_token == IN) begin 
               pe2epct_getRdPtrs = 1'b1         	;
               if(ctr_OUTd_stage_done) begin 
                  set_staus_nak     = 1'b1;
               end
            end 
            else if(current_token ==SETUP) begin 
               set_reg_wr_flag   = 1'b1;
               clr_hw_stall      = 1'b1;
               pe2epcr_getWrPtrs = 1'b1         	;                                       
               if(epcr2pe_getWrPtrsDn) begin 
                  regisretWrPtrs   =     1'b1      	;  
                  next_state        = IDLE             	;
               end
            end
            else begin 
            /* if(ctr_INd_stage_done ) begin 
                  set_staus_nak  = 1'b1;
               end */
               pe2epcr_getWrPtrs = 1'b1         	;                                       
            end  
            if(epct2pe_getRdPtrsDn) begin 
               regisretRdPtrs =1'b1             	;
               if(epct2pe_rdErr) begin 
                  next_state          = IDLE    	;
               end
               else if(ctrINDataStageZlp   )begin // send zlp  if IN data stage has been completed
                  next_state  = DEV_TXHDR;        // and  IN token is received
                  pe2epct_ctrlZlp_nxt   = 1'b1;
               end
                  
              else  if(tx_hs) begin 
                  if(epct2pe_epType != ISOCHRONOUS) begin 
                     next_state          = DEV_TXHS	;   
                  end
                  else begin 
                     next_state          = IDLE    	;
                  end
               end    
               else  begin 
                  next_state     = DEV_TXHDR    	;
               end
            end
            if(epcr2pe_getWrPtrsDn) begin 
               regisretWrPtrs   =     1'b1      	;  
               if(current_token == PING) begin 
                  if(epcr2pe_wrErr) begin       //if err no hs TODO  
                     next_state = IDLE          	;
                  end 
                  else begin 
                     next_state = DEV_TXHS      	;
                  end
               end
               else if(current_token == OUT ||
                  current_token == SETUP)begin 
                  next_state    = IDLE          	;
               end
            end
         end

         DEV_TXHS : begin
            clr_staus_nak        = 1'b1;
            pe2pa_tokenValid     = 1'b1         	;
            if(tx_stall || ctrlTx_stall) begin 
               pe2pa_tokenType   = STALL        	;
            end
            else if(hs_nak) begin 
               pe2pa_tokenType      = NAK       	;            // no NYET for nearlyfull
            end
            else begin 
               pe2pa_tokenType      = ACK       	;
            end
           next_state  =  IDLE               	;
         end

         DEV_TXHDR: begin
              if(epct_epZeroLenEn | ctrINDataStageZlp    ) begin //|| ((epct2pe_epType == ISOCHRONOUS)&& epct_bufEmpty)) begin 
                 pe2pa_tokenValid= 1'b1           	   ;   
                 pe2pa_tokenType = epct_expctDataPid  ; 
                 next_state  =  IDLE               	;
                 pe2epct_ctrlZlp_nxt   = 1'b0;
              end
              else begin 
                pe2epct_hdrRd      = 1'b1;
                if(epct2pe_hdrRdDn) begin
                   pe2pa_tokenValid= 1'b1;   
                   pe2pa_tokenType = epct_expctDataPid;
                   next_state      = DEV_TXDATA     	;     
                end
              end
            end

         DEV_TXDATA: begin
            pe2epct_rdEn      = 1'b1              	;
            if(pa2pe_eot) begin 
               if(epct_epType == ISOCHRONOUS)begin  
                  next_state  =  DEV_ISOUPDT    	;
                  end
               else begin 
                  next_state  =  IDLE           	;
               end
            end
         end
         
         DEV_ISOUPDT : begin
            pe2epct_updtRdBuf       = 1'b1      	;
            if(epct2pe_rdBufUpdtDn) begin 
               next_state           = IDLE      	;
            end
         end

         TXUPDT : begin
            pe2epct_updtRdBuf = 1'b1            	;
            if(epct2pe_rdBufUpdtDn)begin 
               next_state     = IDLE            	;
            end
         end

         DEV_RXDATA : begin
            pe2epcr_wrEn      = 1'b1            	;
            if(pd2pe_eot && epcr2pe_ready)begin    //TODO
               next_state     = CRCCHK;
            // clr_reg_wr_flag= 1'b1  ;
            end
         end

         CRCCHK : begin   
            if(crc2pe_statusValid) begin 
               if(crc2pe_status == 1'b1)begin 
                  if(epcr_epType == ISOCHRONOUS) begin
                     next_state     = DEV_RXHDR;
                  end
                  else begin
                     next_state        = DEV_RXHS  	;
                  end
               end
               else begin 
                  next_state        = IDLE      	;
               end
            end
         end

         DEV_RXHS : begin
            clr_staus_nak        = 1'b1;
            if((setup_trans==1'b1)&&(epcr_epType == CONTROL)) begin 
               pe2pa_tokenType   = ACK  ;
               pe2pa_tokenValid  = 1'b1 ;   
               next_state        = DEV_RXUPDT;
               pe2eptd_intPid    = 1'b1 ;
               if(current_token != DATA0) begin
                  set_hw_stall   = 1'b1;
               end
            end
            else if(setup_trans == 1'b0) begin  
               if(epcr_epType != ISOCHRONOUS) begin 
                  pe2pa_tokenValid     = 1'b1      	;   
                  if(rx_stall) begin 
                     pe2pa_tokenType   = STALL     	;
                     clr_reg_wr_flag   = 1'b1  ;
                     next_state        = IDLE      	;
                  end 
                  else if((epcr2pe_ctrlNAK ||status_nak )) begin
                     pe2pa_tokenType   = NAK       	;
                     next_state        = IDLE      	;
                  end
                  else if(current_token != epcr_expctDataPid )begin 
                     pe2pa_tokenType   = ACK       	;
                     next_state        = IDLE      	;
                  end
                  else if(epcr_bufFull && packet_droped)begin 
                     pe2pa_tokenType   = NAK       	;
                     next_state        = IDLE      	;
                  end
   
                  else if(packet_accepted) begin 
                     if(hs_bulk_ep) begin 
                        pe2pa_tokenType   = NYET      	;
                     end
                     else begin 
                        pe2pa_tokenType   = ACK       	;
                     end
                     next_state        = DEV_RXHDR 	;
                  end
                  else begin 
                     pe2pa_tokenType   = ACK       	;
                     next_state        = DEV_RXHDR 	;
                  end
               end
               else begin
                  if(epcr_bufFull)begin 
                     next_state        = IDLE         	;
                  end
                  else begin 
                     next_state        = DEV_RXHDR 	;
                  end
               end
            end
            else begin
               next_state  = IDLE;
            end
         end

         DEV_RXHDR : begin
            pe2epcr_rxHdrWr   = 1'b1            	;
            if(epcr2pe_hdrWrDn)begin 
               next_state     = DEV_RXUPDT      	;
            end
         end

         DEV_RXUPDT : begin 
            if(setup_trans) begin 
               clr_reg_wr_flag   = 1'b1 ;
               next_state        = IDLE          ;
            end
            else begin
               pe2epcr_updtWrBuf    = 1'b1          ;
               if( epcr2pe_wrBufUpdtDn) begin 
                  next_state        = IDLE          ;
               end
            end
         end
                              
         HOST_GETEPPTR : begin 
            //pe2epc_epNum         = current_epNum	;
            if(current_token     == IN) begin 
               pe2epcr_getWrPtrs = 1'b1         	;                                       
            end 
            else begin 
               pe2epct_getRdPtrs = 1'b1         	;
            end  
            if(epct2pe_getRdPtrsDn || epcr2pe_getWrPtrsDn) begin 
               if(epcr_wrErr || epct_rdErr) begin 
                  next_state     = IDLE         	;
               end
               else begin 
                  next_state     = HOST_TXTOKEN 	; 
               end
            end
         end 
                              
         HOST_TXTOKEN : begin
            pe2pa_tokenValid  =  1'b1           	;
            pe2pa_tokenType   =  current_token  	;
            if(current_token  == OUT || 
               current_token  == SETUP ) begin
               next_state     =  HOST_TXHDR     	;     
            end
            else begin
               next_state     = IDLE            	;
            end
         end

         HOST_TXHDR : begin
            pe2epct_hdrRd = 1'b1                	;
            if(epct2pe_hdrRdDn) begin 
               pe2pa_tokenValid= 1'b1           	;   
               pe2pa_tokenType = epct_expctDataPid	; 
               next_state      = HOST_TXDATA    	;
            end
         end

         HOST_TXDATA : begin
            /*if(epct_epZeroLenEn) begin 
               next_state     = IDLE            	;
            end
            else*/ if(pa2pe_eot) begin 
               if(epct_epType == ISOCHRONOUS)begin 
                  next_state  =  TXUPDT         	;
               end
               else begin
                  next_state  = IDLE            	; 
               end
            end
         end

      LPM : begin
         if(lpm_atributes[3:0] == 4'b0001)begin         //L1 (Sleep 
            pe2pa_tokenValid   = 1'b1;
            if(eptd2pe_noTransPending) begin
               pe2pa_tokenType   = ACK ; 
               pe2reg_lpmRcvd    = 1'b1;
               if(lpm_atributes[8] ==1'b1)begin         //L1 (Sleep 
                  pe2reg_remoteWakeUp = 1'b1;
               end
            end
            else begin
               pe2pa_tokenType   = NYET;
            end
         end
         next_state   = IDLE;
      end
      endcase  //end fo FSM combinational block
   end
endmodule

