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
// DATE           : Mon, 11 Feb 2013 21:27:09
// AUTHOR         : Lalit Kumar
// AUTHOR EMAIL   : lalit.kumar@techvulcan.com
// FILE NAME      : uctl_epcr.v
// VERSION        : 0.4
//-------------------------------------------------------------------

/*TODO
 *
 *
 * MAY 23 upgradation in control trnasfer
updation in 0.4

   all interrupts have been added


updation in 0.3
   all basic and error cases of control transfer have been implemented 
    
fixes in 0.2
 
1. new signal epcr2pe_hwStall is added to check the condition 
   packet size>wMaxPaketSize and for this condition controller 
   will drop the packet

for Rx Fs , if data is dropped generate a drop signal and send to pe with ready and pe will send NAK
if valid is pd high and  and ep buff is  full , conitnous cal full 
 not used siggnals
reg2epcr_descAddr
epcr2reg_enuCmdUpdt
epcr2pd_zeroLen
epcr2reg_enuActOut
pe2epc_idleState     
reg2epcr_enuCmdEn
reg2epcr_EnuAct
reg2epcr_descLen 16 bit

dont need to register the data from Endpoint Data block
*/

module uctl_epcr#(
   parameter   ADDR_SIZE         = 32,
               DATA_SIZE         = 32,
               REGISTER_EPDATA   = 0
   )(
   input wire                    core_clk             , //The core clock
   input wire                    uctl_rst_n           , //Active low reset
   input wire                    sw_rst               , //synchronous software reset

   // ----------------------------------------------------------------
   // pd interface      
   // ----------------------------------------------------------------
   input wire                    pd2epcr_dataValid    , //specifying data availability on the data bus       
   input wire  [DATA_SIZE-1:0]   pd2epcr_data         , //The Rx Data bus
   input wire  [3          :0]   pd2epcr_dataBE       , //Byte enable signals for the data bus
   input wire                    pd2epcr_eot          , //Last data of current transfer
 //  input wire                    pd2epcr_zeroLen      , //Indicates zero length Rx packet 

   output reg                    epcr2pd_ready        , //indicates that data is  latched into ep buffer

   // ----------------------------------------------------------------
   // PE interface      
   // ----------------------------------------------------------------
   input wire                    pe2epcr_getWrPtrs    , //get  the current endpoint attributes 
   input wire                    pe2epcr_wrEn         , //write enable signal
   input wire                    pe2epcr_rxHdrWr      , //header write request
   input wire                    pe2epcr_updtWrBuf    , //buffer update request
   input wire                    pe2epcr_regWr        ,
   //input wire                    pe2epc_idleState     , //high if PE is in IDLE state
   input wire  [3          :0]   pe2epc_epNum         , //current EP number
   //input wire  [3          :0]   pe2epc_tokenType     , //token Type:SETUP, PING, IN, OUT 
                                                      
   output reg                    epcr2pe_ready        , //indicates that data is  latched into ep buffer
   output wire                   epcr2pe_epHalt       , // device is halted 
   output wire                   epcr2pe_bufFull      , //EP buffer is full
   output wire                   epcr2pe_bufNearlyFull, //buffer is nearly full
   output wire                   epcr2pe_wrErr        , //wrong PE number, wrong direction etc
   output reg                    epcr2pe_getWrPtrsDn  , //buffer info has been read by epcr
   //output reg                    epcr2pe_epDir        , //IN/OUT
   output wire [1          :0]   epcr2pe_epType       , //EP type:Control, Interrupt, Isochro or Bulk
   output wire [3          :0]   epcr2pe_expctDataPid , //expected data token for current pkt
   output reg                    epcr2pe_hdrWrDn      , //Header read for buffer is completed
   output reg                    epcr2pe_wrBufUpdtDn  , //Buffer info has been updated on successful transfer 
   output wire                   epcr2pe_hwStall      ,
   output wire                   epcr2pe_packetDroped ,
   output wire                   epcr2pe_ctrlNAK      ,
   output wire                   epcr2pe_setupStall   ,   // more than 8 bit data in setup
   output wire [2        -1:0]   epcr2pe_enuAct   ,
   output reg [3         -1:0]   epcr2pe_ctlTransStage,

   // ----------------------------------------------------------------
   // Register interface      
   // ----------------------------------------------------------------
   input wire                    reg2epcr_enuCmdEn    , //Enumeration done using ENU_CMD_REG
   input wire [1           :0]   reg2epcr_EnuAct      , //Active status:
   input wire [15          :0]   reg2epcr_descLen     , //Length of descriptor data requested      //TODO changed
   input wire [ADDR_SIZE-1 :0]   reg2epcr_descAddr    , //Starting address for the descriptor
   input wire                    reg2epcr_stall       , //enable stall for request 
   input wire                    reg2epcr_rwCtlrType  , // 0: control read/OUT, 1: control write/IN
   input wire [16       -1:0]    reg2epc_setupLen     ,
                                                      
   output wire[1           :0]   epcr2reg_enuActOut   , //Update value for the ACT field from endpoint
   output reg                    epcr2reg_enuCmdUpdt  , //Strobe signal to update ENU_CMD_REG
   output wire[15          :0]   epcr2reg_descLenUpdt , //length of remaing transfer update cmd reg   //TODO changed      
   output wire[32        -1:0]   epcr2reg_setupData   ,
   output reg                    epcr2reg_setupRegIndex, 
   output reg                    epcr2reg_setupWrReq   ,
   output wire                   epcr2reg_bufFull      ,
   output reg                    epcr2reg_dpRcvd       , 
   output reg                    epcr2reg_setupRcvd    ,                                                    
   output reg                    epcr2reg_zlpRcvd      ,

   // ----------------------------------------------------------------
   // Endpoint Data interface 
   // ----------------------------------------------------------------

   input wire                    eptd2epcr_wrReqErr   , //Request error indication
   input wire [ADDR_SIZE-1:0]    eptd2epcr_startAddr  , //Endpoint Start Address
   input wire [ADDR_SIZE-1:0]    eptd2epcr_endAddr    , //Endpoint End Address
   input wire [ADDR_SIZE-1:0]    eptd2epcr_rdPtr      , //Endpoint Read pointer
   input wire [ADDR_SIZE-1:0]    eptd2epcr_wrPtr      , //Endpoint Write pointer
   input wire                    eptd2epcr_lastOp     , //Last operation for this EP 0 : READ,1 : WRITE            
   input wire [3          :0]    eptd2epcr_exptDataPid, //Expected Data PID for this endpoint         
   input wire                    eptd2epcr_updtDn     , //update was done successfully
   input wire                    eptd2epcr_epHalt     , //Endpoint Halt 
   input wire [1          :0]    eptd2epcr_epTrans    , //High BW # transfers per frame
   input wire [10         :0]    eptd2epcr_wMaxPktSize, //Endpoint max buffer size (wMaxPaketSize)
   //input wire                    eptd2epcr_dir        , //Endpoint Direction 0 : IN 1 : OUT
   input wire [1          :0]    eptd2epcr_epType     , //EP Type, control, bulk etc 
                           
   output reg [3          :0]    epcr2eptd_epNum      , //Physical Endpoint number
   output reg                    epcr2eptd_reqData    , //Request signal to get all the endpoint
   output reg                    epcr2eptd_updtReq    , //Update request for the below EP Attributes
   output reg                    epcr2eptd_dataFlush  ,
   output wire[ADDR_SIZE-1:0]    epcr2eptd_wrPtrOut      , //Write pointer value to be updated
   output reg [3          :0]    epcr2eptd_nxtDataPid , //next DATA token to be expected for this EP
   output reg                    epcr2eptd_setEphalt    ,
                                                      
   // ----------------------------------------------------------------
   // Memory interface 
   // ----------------------------------------------------------------
   output wire[ADDR_SIZE-1:0]    epcr2mif_addr        , //Address of the memory location in local buffer
   output wire[DATA_SIZE-1:0]    epcr2mif_data        , //Write data
   output wire                   epcr2mif_wr          , //Write request
   input  wire                   mif2epcr_ack           //Ready signal
   );
   // ----------------------------------------------------------------
   // local parameters
   // ---------------------------------------------------------------
   // FSM variables
   // ---------------------------------------------------------------
   localparam  IDLE       =  3'b000,    //default state
               GETEPPTR   =  3'b001,    //read pointers and status of end point
               RXDATA     =  3'b010,    //data transfer for OUT
               RXHDR      =  3'b011,    //write header for ACK/NYET
               RXUPDT     =  3'b100;    //update buffer info

 
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

   localparam   WRITE         = 1'b1     ,
                READ          = 1'b0     ;

      reg                   epcr2eptd_updtReq_nxt;
      reg                   mif_wr               ;
      reg                   drop_pkt             ;
      wire                  mif_wr_req           ;
      reg                   hdrMif_wr            ;
      reg  [2          :0]  current_state        , 
                            next_state           ;
      wire                  bufFull              ;
      wire                  bufNearlyFull        ;
      reg  [3:          0]  curExpDataPid        ;
      reg  [3:          0]  nxtExpDataPid        ;
      reg  [3:          0]  epcr2eptd_epNum_nxt  ;
      reg  [3:          0]  byteEn               ;
      reg                   epcr2eptd_reqData_nxt;
      reg  [ADDR_SIZE-1:0]  mifWrAddr            ;
    //reg  [ADDR_SIZE-1:0]  mifWrAddr_nxt        ;
      reg                   wr_halt              ;
      reg                   wrReqErr             ;
      reg  [ADDR_SIZE-1:0]  startAddr            ;
      reg  [ADDR_SIZE-1:0]  endAddr              ;
      reg  [ADDR_SIZE-1:0]  rdPtr                ;
      reg  [ADDR_SIZE-1:0]  wrPtr                ;
      reg  [ADDR_SIZE-1:0]  rdPtr_nxt            ;
      reg  [ADDR_SIZE-1:0]  wrPtr_nxt            ;
      reg  [3:          0]  exptDataPid          ;
      reg                   epHalt               ;
      reg  [1:          0]  epTrans              ;
      reg  [10:         0]  wMaxPktSize          ;
      reg  [1:          0]  epType               ;
      reg                   addr_load            ; 
      reg                   send_data            ;
      reg                   addr_incr            ; 
      wire [ADDR_SIZE-1:0]  available_space      ;
      reg  [ADDR_SIZE-1:0]  start_setUp_addr     ;
      wire                  epHalt_w             ;
      reg                   regAddr_load         ;
      wire [15:         0]  regNewLen            ; 
      reg  [15:         0]  transLen             ;  
      reg  [15:         0]  transLen_dataSt      ;  
      reg  [2          :0]  current_transSize    ;
      reg  [2        -1:0]  last_trans_bytes     ;
      reg                   reg_getWrPtrs        ;
      reg                   set_drop             ; 
      reg                   clr_drop             ;             
      reg                   packet_droped        ;
      reg  [4        -1:0]  setup_bytes          ;
      reg  [2        -1:0]  last_dataBE          ;
      reg                   set_halt             ; 
      reg                   clr_halt             ; 
      wire                  mpsExcd              ;
      reg                  set_setup_rcvd_flag   ;
      reg                  clr_setup_rcvd_flag   ;
      reg                  set_dp_rcvd_flag      ;
      reg                  clr_dp_rcvd_flag      ;
      reg                  clr_setup_cnt         ;
      wire                 setup_nak             ;
      reg  [15:         0] total_transLen        ;
      wire [15:         0] rem_bytes             ; 
      reg                  setup_rcvd            ;
      wire                 clr_setup_rcvd        ;
      wire                 set_data_flush_req    ;
      reg                  clr_data_flush_req    ;
      reg                  data_flush_req        ;
      reg                  start_of_setup        ;
      wire                 zlp_rcvd;
      reg                  setupWr_nxt  ; 
      reg                  incorrect_setupBytes  ;
      wire                 check_setup_bytes_count;
      wire                 bufAlreadyFull        ;
   // ---------------------------------------------------------------
   // Code starts here
   // ---------------------------------------------------------------

   assign clr_setup_rcvd = (reg2epcr_EnuAct == 2'b11) ? 1'b1 : 1'b0;
// assign total_transLen         = (reg2epc_setupLen >reg2epcr_descLen) ? reg2epcr_descLen :reg2epc_setupLen;
// assign total_transLen         = reg2epc_setupLen ; // in out transfer host can send data upto wlength 
   assign rem_bytes              = (total_transLen > transLen_dataSt)? (total_transLen - transLen_dataSt): {16{1'b0}};

   assign epcr2pe_enuAct     = reg2epcr_EnuAct ;
   assign epcr2pe_setupStall     =( setup_bytes!=8)&&(check_setup_bytes_count) || ((reg2epcr_EnuAct == 2'b11 &&
                                  reg2epcr_rwCtlrType==1'b1) && pe2epcr_getWrPtrs)? 1'b1 : 1'b0;    //don't interrupt CPU in tis case TODO
   assign epcr2pe_ctrlNAK        = (reg2epcr_EnuAct == 2'b00)&&(epType == CONTROL) ? 1'b1 : 1'b0;  
   assign epcr2reg_setupData     = pd2epcr_data;
   assign epcr2pe_packetDroped   = packet_droped;
   assign available_space        = (epcr2mif_addr  < rdPtr_nxt ) ? (rdPtr_nxt  -epcr2mif_addr  ) :
                                     ((endAddr + rdPtr ) - (startAddr + epcr2mif_addr)) ;
   assign mif_wr_req             = (mif_wr && pd2epcr_dataValid & ! pe2epcr_regWr)?1'b1 :1'b0 ;
   assign epHalt_w               =  wr_halt ? 1'b1 : epHalt;
   assign regNewLen              =  reg2epcr_descLen - transLen_dataSt;
   assign bufFull                = ((epcr2mif_addr  == rdPtr_nxt) && (eptd2epcr_lastOp == WRITE)) ? 1 :0; 
   assign bufNearlyFull          =  (available_space<wMaxPktSize) ? 1 :0; 
   assign mpsExcd                =  (transLen > wMaxPktSize) ? 1:0;           
   assign data_flush             =  ((reg2epcr_EnuAct[1] ==1'b1) && (reg2epcr_descLen != {16{1'b0}}) &&
                                    (!reg2epcr_rwCtlrType) &&(pe2epcr_regWr)) ? 1'b1:1'b0  ;  
   assign epcr2eptd_wrPtrOut     = data_flush ? start_setUp_addr :mifWrAddr;
   assign epcr2pe_hwStall        = mpsExcd ||((transLen_dataSt > reg2epcr_descLen)&&(epType==CONTROL));
   assign epcr2reg_bufFull       = bufFull;
   assign setup_nak              =  (reg2epcr_EnuAct[1] ==1'b1) &&(reg2epcr_rwCtlrType==1'b0) |(reg2epcr_EnuAct==2'b00)  ? 1'b1:1'b0; 
   assign set_data_flush_req     =  pe2epcr_regWr&(!start_of_setup)&data_flush ; 
   assign zlp_rcvd               = transLen == {16{1'b0}} ? 1'b1 : 1'b0;
   assign check_setup_bytes_count= (setupWr_nxt && (!pe2epcr_regWr)) ? 1'b1 : 1'b0;
   assign bufAlreadyFull         = ((eptd2epcr_rdPtr==eptd2epcr_wrPtr) && (eptd2epcr_lastOp == WRITE)) ? 1 :0;

     always @(posedge core_clk, negedge uctl_rst_n) begin 
        if(!uctl_rst_n) begin
           setupWr_nxt    <= 1'b0;
        end
        else if( sw_rst    ) begin
           setupWr_nxt    <= 1'b0;
        end
        else begin
           setupWr_nxt <= pe2epcr_regWr;
        end
     end


     always @(posedge core_clk, negedge uctl_rst_n) begin 
        if(!uctl_rst_n) begin
            total_transLen    <=    {16{1'b0}} ;   
         end
         else if(!uctl_rst_n) begin
            total_transLen    <=    {16{1'b0}} ;   
         end
         else if(epcr2pe_enuAct) begin
            total_transLen    <= reg2epcr_descLen;
         end
      end


   generate begin
      if(REGISTER_EPDATA == 1) begin 
         always @(posedge core_clk, negedge uctl_rst_n) begin 
            if(!uctl_rst_n) begin
               wrReqErr       <=  1'b0            ;
               startAddr      <= {ADDR_SIZE{1'b0}};
               endAddr        <= {ADDR_SIZE{1'b0}};
               exptDataPid    <= 4'b0             ;
               epHalt         <= 1'b0             ;
               epTrans        <= 2'b0             ;
               wMaxPktSize    <=11'b0             ;
               epType         <= 2'b0             ;
            end
            else if(sw_rst) begin
               wrReqErr       <=  1'b0            ;
               startAddr      <= {ADDR_SIZE{1'b0}};
               endAddr        <= {ADDR_SIZE{1'b0}};
               exptDataPid    <= 4'b0             ;
               epHalt         <= 1'b0             ;
               epTrans        <= 2'b0             ;
               wMaxPktSize    <=11'b0             ;
               epType         <= 2'b0             ;
            end
            else if(reg_getWrPtrs     /* epcr2pe_getWrPtrsDn*/) begin 
              wrReqErr       <= eptd2epcr_wrReqErr       ;
              startAddr      <= eptd2epcr_startAddr      ;
              endAddr        <= eptd2epcr_endAddr        ;
              exptDataPid    <= eptd2epcr_exptDataPid    ;
              epHalt         <= eptd2epcr_epHalt         ;
              epTrans        <= eptd2epcr_epTrans        ;
              wMaxPktSize    <= eptd2epcr_wMaxPktSize    ;
              epType         <= eptd2epcr_epType         ;
              rdPtr          <= rdPtr_nxt                ;
              wrPtr          <= wrPtr_nxt                ;
            end
         end
      end
      else begin 
         always@(*) begin
              wrReqErr        = eptd2epcr_wrReqErr       ;
              startAddr       = eptd2epcr_startAddr      ;
              endAddr         = eptd2epcr_endAddr        ;
              exptDataPid     = eptd2epcr_exptDataPid    ;
              epHalt          = eptd2epcr_epHalt         ;
              epTrans         = eptd2epcr_epTrans        ;
              wMaxPktSize     = eptd2epcr_wMaxPktSize    ;
              epType          = eptd2epcr_epType         ;
              rdPtr           = rdPtr_nxt                ;
              wrPtr           = wrPtr_nxt                ;
         end
      end
   end
  endgenerate 
   
   // start write address for cureent data of setup data stage  
   // ---------------------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         data_flush_req <= 1'b0;
      end
      else if(sw_rst   ) begin
         data_flush_req <= 1'b0;
      end
      else if(set_data_flush_req) begin
         data_flush_req <= 1'b1;
      end
      else if(clr_data_flush_req) begin
         data_flush_req <= 1'b0;
      end
   end
         

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         start_of_setup <= 1'b0;
      end   
      else if(sw_rst  ) begin
         start_of_setup <= 1'b0;
      end   
      else begin 
         start_of_setup <= pe2epcr_regWr;
      end
   end
      
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         start_setUp_addr  <= {ADDR_SIZE{1'b0}}; 
      end
      else if(sw_rst ) begin
         start_setUp_addr  <= {ADDR_SIZE{1'b0}}; 
      end
      else if((reg2epcr_EnuAct==2'b11)&&(regAddr_load))begin
         start_setUp_addr  <=  eptd2epcr_wrPtr ;      
      end
   end
      
         

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epcr2eptd_setEphalt     <=  1'b0;
      end
      else if(sw_rst) begin
         epcr2eptd_setEphalt     <=  1'b0;
      end
      else if(set_halt) begin
         epcr2eptd_setEphalt     <=  1'b1;
      end
      else if(clr_halt) begin
         epcr2eptd_setEphalt     <=  1'b0;
      end
   end
         

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         packet_droped <=  1'b0;
      end
      else if(sw_rst) begin
         packet_droped <=  1'b0;
      end
      else if(set_drop ||bufAlreadyFull  ) begin
         packet_droped <= 1'b1;
      end
      else if(clr_drop) begin
         packet_droped  <= 1'b0;
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epcr2eptd_epNum      <= 4'b0000;
         epcr2eptd_reqData    <= 1'b0   ;
      end
      else if(sw_rst) begin
         epcr2eptd_reqData    <= 1'b0   ;
      end
      else begin
         epcr2eptd_epNum      <= epcr2eptd_epNum_nxt  ;
         epcr2eptd_epNum      <= epcr2eptd_epNum_nxt  ;
         epcr2eptd_reqData    <= epcr2eptd_reqData_nxt;
      end
   end 
           assign  epcr2pe_epHalt       = epHalt_w ; 
           assign  epcr2pe_bufFull      = bufFull  |setup_nak  ;            
           assign  epcr2pe_bufNearlyFull= bufNearlyFull        ;            
           assign  epcr2pe_wrErr        = wrReqErr             ;
           assign  epcr2pe_epType       = epType               ;                                       
           assign  epcr2pe_expctDataPid = curExpDataPid        ;
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epcr2eptd_nxtDataPid<= 4'b0000;        
      end
      else if(sw_rst) begin
        epcr2eptd_nxtDataPid <= 4'b0000;        
      end
      else if(epcr2pe_getWrPtrsDn) begin
         epcr2eptd_nxtDataPid<= nxtExpDataPid     ;        
      end
   end


   //always @(*) begin 
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         mifWrAddr        <= {ADDR_SIZE{1'b0}}       ;
      end
      else if(sw_rst) begin
         mifWrAddr        <= {ADDR_SIZE{1'b0}}       ;
      end
      else if(addr_load) begin
         if((wrPtr_nxt ==endAddr)||
	     (wrPtr_nxt == startAddr) && eptd2epcr_lastOp ) begin
            mifWrAddr       <= startAddr               ;
         end
         else if((wrPtr_nxt == rdPtr_nxt) && eptd2epcr_lastOp ) begin
            mifWrAddr       <= eptd2epcr_wrPtr;
         end
         else begin 
            mifWrAddr       <= eptd2epcr_wrPtr+3'h4    ;
         end
      end
      else if(regAddr_load) begin 
         mifWrAddr       <= reg2epcr_descAddr       ;
      end   
      else if(addr_incr) begin                
         if(epcr2mif_addr==endAddr) begin
            mifWrAddr       <= startAddr               ;
         end
         else begin 
            mifWrAddr       <= mifWrAddr + 3'b100  ;
         end
      end
      else begin 
         mifWrAddr       <= mifWrAddr               ;
      end
   end

   always @(*)begin
      case(pd2epcr_dataBE)
         4'b0000: begin
            current_transSize= 3'b000;
         end
         4'b0001: begin
            current_transSize= 3'b001;
         end
         4'b0011: begin
            current_transSize= 3'b010;
         end
         4'b0111: begin
            current_transSize= 3'b011;
         end
         4'b1111: begin
            current_transSize= 3'b100;
         end
         default: begin
            current_transSize= 3'b000;
         end
      endcase
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epcr2pe_ctlTransStage   <= 3'b000;
      end
      else if(sw_rst ) begin
         epcr2pe_ctlTransStage   <= 3'b000;
      end
      else if((reg2epcr_EnuAct == 2'b11)&&(reg2epcr_descLen != {16{1'b0}})) begin
         epcr2pe_ctlTransStage <={1'b1,reg2epcr_rwCtlrType, 1'b1};
      end
      else if((reg2epcr_EnuAct == 2'b11)&&(reg2epcr_descLen == {16{1'b0}})) begin
         epcr2pe_ctlTransStage <={1'b1,reg2epcr_rwCtlrType, 1'b0};
      end
      else if(reg2epcr_EnuAct == 2'b00) begin
         epcr2pe_ctlTransStage   <= 3'b000;
      end
   end
            
   assign epcr2reg_descLenUpdt = regNewLen  ;
   assign epcr2reg_enuActOut   = (rem_bytes   == {16{1'b0}}) ||(transLen <wMaxPktSize)   ? 2'b00 : 2'b10 ;
   assign epcr2mif_addr  =pe2epcr_rxHdrWr ? wrPtr                               :  mifWrAddr ; 
   assign epcr2mif_data  =pe2epcr_rxHdrWr ? {mifWrAddr[31:2], last_dataBE     } :  pd2epcr_data;
   assign epcr2mif_wr    =pe2epcr_rxHdrWr ? hdrMif_wr                           :  mif_wr_req  ; 


   //TODO send byte enable 2'b00 in case of zlp
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         last_dataBE <= 2'b0;
      end
      else if(  sw_rst    ) begin
         last_dataBE <= 2'b0;
      end
      else if(pd2epcr_dataBE) begin 
         last_dataBE <= last_trans_bytes;
      end
      else if(zlp_rcvd && pd2epcr_eot) begin
         last_dataBE <= 2'b0;
      end
   end
         
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epcr2reg_setupWrReq   <= 1'b0   ;
         setup_bytes           <= 4'b0000;    
         epcr2reg_setupRegIndex<= 1'b1   ;
      end
      else if(sw_rst) begin
         epcr2reg_setupWrReq   <= 1'b0   ;
         setup_bytes           <= 4'b0000;    
         epcr2reg_setupRegIndex<= 1'b1   ;
      end
      else if(pe2epcr_regWr & pe2epcr_wrEn)begin 
         if(pd2epcr_dataValid) begin 
            epcr2reg_setupWrReq   <= 1'b1;
            setup_bytes           <= setup_bytes +current_transSize;
            epcr2reg_setupRegIndex<= 1'b1+epcr2reg_setupRegIndex  ;
         end
         else begin 
            epcr2reg_setupWrReq   <= 1'b0;
         end
      end
      else if(! pe2epcr_regWr ) begin 
         setup_bytes           <= 4'b0000;    
         epcr2reg_setupRegIndex<= 1'b1   ;
         epcr2reg_setupWrReq   <= 1'b0;
      end
   end

            

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         byteEn   <= {4{1'b0}};
      end
      else if(sw_rst) begin
         byteEn   <= {4{1'b0}};
      end
     // else if(send_data && pd2epcr_eot) begin
      else if(pd2epcr_dataValid) begin
         byteEn   <= pd2epcr_dataBE;
      end   
     // else begin
     //    byteEn   <= {4{1'b0}};
     // end
   end
  
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         setup_rcvd     <= 1'b0;
      end
     else  if(sw_rst    ) begin
         setup_rcvd     <= 1'b0;
      end
      else if(pe2epcr_regWr) begin 
         setup_rcvd     <= 1'b1;
      end
      else if(epcr2pe_setupStall || clr_setup_rcvd) begin
         setup_rcvd     <= 1'b0;
      end
   end
 

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         transLen       <= {16{1'b0}}; 
         transLen_dataSt<= {16{1'b0}}; 
      end
      else if(sw_rst) begin
         transLen       <= {16{1'b0}}; 
         transLen_dataSt<= {16{1'b0}}; 
      end
      else if(send_data && !pe2epcr_regWr) begin
         transLen       <= transLen + current_transSize ;
         transLen_dataSt<= transLen + current_transSize ;
      end   
      else if(addr_load ||(( epType== CONTROL) && (reg2epcr_EnuAct == 2'b00)))begin
         transLen       <= {16{1'b0}}; 
      end   
   end

   always @(*) begin 
      if(regAddr_load)begin 
         rdPtr_nxt          = eptd2epcr_rdPtr               ;//rdptr from where??
         wrPtr_nxt          = reg2epcr_descAddr             ;
      end
      else begin 
         rdPtr_nxt          = eptd2epcr_rdPtr               ;
         wrPtr_nxt          = eptd2epcr_wrPtr               ;
      end
   end
     always @(*) begin  
      case(byteEn)   
         4'b0001: last_trans_bytes = 2'b01;
         4'b0011: last_trans_bytes = 2'b10;
         4'b0111: last_trans_bytes = 2'b11;
         4'b1111: last_trans_bytes = 2'b00;
         default: last_trans_bytes = 2'b00;
      endcase
   end
   
   always @ (*)begin
      if(mif2epcr_ack | drop_pkt| pe2epcr_regWr ) begin
         epcr2pd_ready  = 1'b1;
      end
      else if(pd2epcr_dataValid) begin 
         epcr2pd_ready  = 1'b0;
      end
      else begin
         epcr2pd_ready  = 1'b1;
      end
   end

   // generate data packet received signal(irq)
   // ---------------------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epcr2reg_dpRcvd <= 1'b0;
    end
      else if(  sw_rst    ) begin
         epcr2reg_dpRcvd <= 1'b0;
      end
      else if(set_dp_rcvd_flag ) begin
         epcr2reg_dpRcvd <= 1'b1;
      end
      else if(clr_dp_rcvd_flag ) begin
         epcr2reg_dpRcvd <= 1'b0;
      end
   end

   // generate setup packet received signal(irq)
   // ---------------------------------------------------------------
    always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epcr2reg_setupRcvd <= 1'b0;
      end
      else if(  sw_rst    ) begin
         epcr2reg_setupRcvd <= 1'b0;
      end
      else if(set_setup_rcvd_flag ) begin
         epcr2reg_setupRcvd <= 1'b1;
      end
      else if(clr_setup_rcvd_flag ) begin
         epcr2reg_setupRcvd <= 1'b0;
      end
   end



   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
          epcr2eptd_updtReq   <= 1'b0              ;    
      end
      else if(sw_rst) begin 
          epcr2eptd_updtReq   <= 1'b0              ;    
      end
      else begin 
          epcr2eptd_updtReq   <=epcr2eptd_updtReq_nxt ;    
      end
   end
      
   // FSM sequential block
   // ---------------------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         current_state  <= IDLE                          ;
      end
      else if(sw_rst) begin
         current_state  <= IDLE                          ;
      end
      else begin
     current_state <= next_state                     ;
      end
   end

   // FSM combinational block
   // ---------------------------------------------------------------

   always @ * begin
    next_state              = current_state       ;
      //current_token_nxt       = current_token       ;
      //current_epNum_nxt       = current_epNum       ;
      epcr2eptd_epNum_nxt     = epcr2eptd_epNum     ;
      epcr2eptd_reqData_nxt   = epcr2eptd_reqData   ;       
      epcr2pe_ready           = 1'b0                ;
      epcr2pe_getWrPtrsDn     = 1'b0                ;
      epcr2pe_hdrWrDn         = 1'b0                ;
      curExpDataPid           = DATA0               ;
      mif_wr                  = 1'b0                ;
      hdrMif_wr               = 1'b0                ;
      epcr2pe_wrBufUpdtDn     = 1'b0                ; 
      epcr2eptd_updtReq_nxt   = epcr2eptd_updtReq   ;    
      wr_halt                 = 1'b0                ; 
      addr_load               = 1'b0                ;
      addr_incr               = 1'b0                ;
      send_data               = 1'b0                ;
      regAddr_load            = 1'b0                ;
      reg_getWrPtrs           = 1'b0                ;
      drop_pkt                = 1'b1                ;     
      set_drop                = 1'b0;
      clr_drop                = 1'b0;
      nxtExpDataPid           = DATA0;
      epcr2reg_enuCmdUpdt     = 1'b0    ;
      set_halt                =  1'b0;
      clr_halt                =  1'b0;
      set_dp_rcvd_flag        = 1'b0;
      clr_dp_rcvd_flag        = 1'b0;
      set_setup_rcvd_flag     = 1'b0;
      clr_setup_rcvd_flag     = 1'b0;
      clr_setup_cnt           = 1'b0;
      epcr2eptd_dataFlush     = 1'b0;
      clr_data_flush_req      = 1'b0;
      epcr2reg_zlpRcvd        = 1'b0;
    case(current_state)
       IDLE : begin   //default state
            clr_dp_rcvd_flag    = 1'b1;
            clr_setup_rcvd_flag = 1'b1;
            clr_halt            = 1'b1;
            epcr2eptd_epNum_nxt = pe2epc_epNum    ;
            if(pe2epcr_getWrPtrs) begin 
               clr_drop       = 1'b1;
               epcr2eptd_reqData_nxt= 1'b1        ;
               reg_getWrPtrs        = 1'b1         ;
               next_state        = GETEPPTR          ;
            end
            if(pe2epcr_rxHdrWr) begin 
               next_state        = RXHDR;
            end
            if(pe2epcr_updtWrBuf ||data_flush_req ) begin 
               epcr2eptd_updtReq_nxt   = 1'b1              ;    
               next_state        = RXUPDT;
            end
            if(pe2epcr_wrEn) begin 
               next_state        = RXDATA           ;
            end
         end
         GETEPPTR : begin
               epcr2eptd_reqData_nxt= 1'b0        ;
               clr_setup_cnt  = 1'b1;
               epcr2pe_getWrPtrsDn  = 1'b1           ; 
            addr_load               = 1'b1          ;
            if((epType == CONTROL)  && (reg2epcr_enuCmdEn == 1'b1)) begin 
               if(reg2epcr_stall== 1'b1) begin
                  wr_halt                 = 1'b1       ; 
               end
               else if(reg2epcr_EnuAct == 2'b11) begin 
                  regAddr_load   = 1'b1;
               end
            end
            //calculate next expected data token
            if(epType == BULK || epType == INTERRUPT || 
               epType == CONTROL) begin 
               if(exptDataPid == DATA0) begin
                  nxtExpDataPid           = DATA1   ;
               end
               else if(exptDataPid == DATA1) begin
                  nxtExpDataPid  = DATA0            ;
               end
               curExpDataPid  = exptDataPid         ;
            end
            if(epType == ISOCHRONOUS) begin
               case(epTrans)
                  2'b00: begin
                     nxtExpDataPid        = DATA0    ;
                     curExpDataPid        = DATA0    ;
                  end
                  
                  2'b01: begin
                     if(exptDataPid == DATA1) begin 
                        nxtExpDataPid     = DATA0    ;
                        curExpDataPid     = MDATA    ;
                     end
                     if(exptDataPid == DATA0) begin 
                        nxtExpDataPid     = DATA1    ;
                        curExpDataPid     = DATA1    ;
                     end
                  end
         
                  2'b10: begin 
                     if(exptDataPid == DATA2) begin 
                        nxtExpDataPid     = DATA1    ;
                        curExpDataPid     = MDATA    ;
                     end
                     if(exptDataPid == DATA1) begin 
                        nxtExpDataPid     = DATA0    ;
                        curExpDataPid     = MDATA    ;
                     end
                     if(exptDataPid == DATA0) begin 
                        nxtExpDataPid     = DATA2    ;
                        curExpDataPid     = DATA2    ;
                     end
                  end
                default: begin
                     nxtExpDataPid        = DATA0    ;
                     curExpDataPid        = DATA0    ;
                  end
               endcase
            end
            
            next_state                 = IDLE       ; 
         end
         RXDATA : begin
            if((epcr2pe_hwStall)&& (epType!=CONTROL) )
               set_halt    =  1'b1;
            if(!bufFull) begin 
               drop_pkt     = 1'b0    ;     
               mif_wr       = 1'b1    ;
               if(pe2epcr_wrEn) begin
                  if(mif2epcr_ack) begin
                     addr_incr = 1'b1 ;
                  end
                  if(pd2epcr_dataValid) begin 
                     send_data       = 1'b1;
                  end
                  if(pd2epcr_eot  ) begin                 
                     epcr2pe_ready  = 1'b1;
                     next_state  = IDLE   ; 
                     if(zlp_rcvd == 1'b1) begin
                        epcr2reg_zlpRcvd = 1'b1;
                     end
                  end
               end   
               else begin 
                  next_state  = IDLE                       ; 
               end  
            end 
            else if(pd2epcr_dataValid) begin 
               send_data       = 1'b1;
               set_drop       = 1'b1;
            end
            else if(pd2epcr_eot  ) begin 
               epcr2pe_ready  = 1'b1;
               next_state     = IDLE                       ; 
            end
         end

         RXHDR: begin
            hdrMif_wr         = 1'b1              ;
            if(mif2epcr_ack) begin 
               epcr2pe_hdrWrDn  = 1'b1              ;
               next_state       = IDLE              ;
            end
         end
         
         RXUPDT: begin
            if(data_flush_req) begin 
               epcr2eptd_dataFlush   = 1'b1;
            end
            if((reg2epcr_enuCmdEn == 1) && 
                  (epType == CONTROL)  && 
                  (!reg2epcr_rwCtlrType ) && ! data_flush_req)begin
               epcr2reg_enuCmdUpdt       = 1'b1    ;
            end
            if(eptd2epcr_updtDn) begin
               if(!epcr2pe_hwStall && pe2epcr_regWr) begin
                  set_setup_rcvd_flag = 1'b1;
               end
               else begin
                  set_dp_rcvd_flag = 1'b1;
               end
               epcr2eptd_updtReq_nxt= 1'b0          ;    
               epcr2pe_wrBufUpdtDn  = 1'b1          ; 
               clr_data_flush_req   = 1'b1          ;
               next_state           = IDLE          ;
            end
         end    
      endcase 
   end
endmodule   
