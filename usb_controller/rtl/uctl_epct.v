`timescale 1ns / 1ps
//-------------------------------------------------------------------
// Copyright © 2013 TECHVULCAN, Inc. All rights reserved.     
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, no     
// its contents              
// revealed in any manner to others without the express written    
// permission of TechVulcan           
// Licensed Material.          
// Program Property of TECHVULCAN Incorporated. 
// ------------------------------------------------------------------
// DATE           : Thu, 14 Feb 2013 01:48:49
// AUTHOR         : Lalit Kumar
// AUTHOR EMAIL   : lalit.kumar@techvulcan.com
// FILE NAME      : uctl_epct.v
// VERSION        : 0.4
//-------------------------------------------------------------------

/*  
 *
 *
 * MAY 23 upgradation in control trnasfer
updation in 0.4

   all interrupts have been added

updation in 0.3
   all basic and error cases of control transfer have been implemented 
    
fixes in 0.2 
ISOCHRONOUS empty ep fixed not to generate handshake NAK
*/

module uctl_epct#(
   parameter   ADDR_SIZE         = 32,
               DATA_SIZE         = 32,
               REGISTER_EPDATA   = 0
   )(
   input wire                    core_clk             , //The core clock
   input wire                    uctl_rst_n           , //Active low reset
   input wire                    sw_rst              , //synchronous software reset

   // ----------------------------------------------------------------
   // pa interface      
   // ----------------------------------------------------------------
   input  wire                   pa2epct_ready        , //indicates that data is  latched into ep buffer
   output wire                   epct2pa_dataValid    , //specifying data availability on the data bus       
   output wire [DATA_SIZE-1:0]   epct2pa_data         , //The Rx Data bus
   output wire [3          :0]   epct2pa_dataBE       , //Byte enable signals for the data bus
   output reg                    epct2pa_eot          , //Last data of current transfer
   output wire                   epct2pa_zeroLen      , //Indicates zero length Rx packet 


   // ----------------------------------------------------------------
   // PE interface      
   // ----------------------------------------------------------------
   input wire                    pe2epct_getRdPtrs    , //get  the current endpoint attributes 
   input wire                    pe2epct_ctrlZlp      , //send zlp for control if IN data stage is completed and new IN token is received
   input wire                    pe2epct_rdEn         , //write enable signal
   input wire                    pe2epct_hdrRd        , //header write request
   input wire                    pe2epct_updtRdBuf    , //buffer update request
   input wire                    pe2epc_idleState     , //high if PE is in IDLE state
   input wire  [3          :0]   pe2epc_epNum         , //current EP number
 //  input wire  [3          :0]   pe2epc_tokenType     , //token Type:SETUP, PING, IN, OUT 
                                                      
   output wire                   epct2pe_epHalt       , // device is halted 
   output wire                   epct2pe_epZeroLenEn  , //     
   output wire                   epct2pe_bufEmpty     , //EP buffer is full
   output wire                   epct2pe_rdErr        , //wrong PE number, wrong direction etc
   output reg                    epct2pe_getRdPtrsDn, //buffer info has been read by epct
   //output reg                    epct2pe_epDir        , //IN/OUT
   output wire [1          :0]   epct2pe_epType       , //EP type:Control, Interrupt, Isochro or Bulk
   output wire [3          :0]   epct2pe_expctDataPid , //expected data token for current pkt
   output reg                    epct2pe_hdrRdDn      , //Header read for buffer is completed
   output reg                    epct2pe_rdBufUpdtDn  , //Buffer info has been updated on successful transfer 
  // output reg                    epct2pe_eot          , //last data has been written in EP buffer 

   // ----------------------------------------------------------------
   // Register interface      
   // ----------------------------------------------------------------
   input wire                    reg2epct_enuCmdEn    , //Enumeration done using ENU_CMD_REG
   input wire [1          :0]    reg2epct_EnuAct      , //Active status:
   input wire [15         :0]    reg2epct_descLen     , //Length of descriptor data requested
   input wire [ADDR_SIZE-1:0]    reg2epct_descAddr    , //Starting address for the descriptor
   input wire                    reg2epct_stall       , //enable stall for request 
   input wire                    reg2epct_rwCtlrType  , // 0: control read, 1: control write
   input wire [16       -1:0]    reg2epc_setupLen     ,
                                                      
   output wire[1           :0]   epct2reg_enuActOut   , //Update value for the ACT field from endpoint
   output reg                    epct2reg_enuCmdUpdt  , //Strobe signal to update ENU_CMD_REG
   output wire[15           :0]  epct2reg_descLenUpdt , // update this value of length
   output wire                   epct2reg_bufEmpty    ,
   output reg                    epct2reg_dpSend      ,
   output reg                    epct2reg_zlpSent     ,                
   // ----------------------------------------------------------------
   // Endpoint Data interface 
   // ----------------------------------------------------------------

   input wire                    eptd2epct_reqErr     , //Request error indication
   input wire [ADDR_SIZE-1:0]    eptd2epct_startAddr  , //Endpoint Start Address
   input wire [ADDR_SIZE-1:0]    eptd2epct_endAddr    , //Endpoint End Address
   input wire [ADDR_SIZE-1:0]    eptd2epct_rdPtr      , //Endpoint Read pointer
   input wire [ADDR_SIZE-1:0]    eptd2epct_wrPtr      , //Endpoint Write pointer
   input wire                    eptd2epct_lastOp     , //Last operation for this EP 0 : READ,1 : WRITE            
   input wire [3          :0]    eptd2epct_exptDataPid, //Expected Data PID for this endpoint         
   input wire                    eptd2epct_updtDn     , //update was done successfully
   input wire                    eptd2epct_epHalt     , //Endpoint Halt 
   input wire [1          :0]    eptd2epct_epTrans    , //High BW # transfers permicro frame
 //input wire [11         :0]    eptd2epct_wMaxPktSize, //Endpoint max buffer size (wMaxPaketSize)
 //input wire                    eptd2epct_dir        , //Endpoint direction 0 : IN 1 : OUT
   input wire [1          :0]    eptd2epct_epType     , //EP Type, control, bulk etc 
   input wire                    eptd2epct_zLenPkt    , //Respond to IN requests to this EP with zero len pkt 

   output reg [3          :0]    epct2eptd_epNum      , //Physical Endpoint number
   output reg                    epct2eptd_reqData    , //Request signal to get all the endpoint
   output reg                    epct2eptd_updtReq    , //Update request for the below EP Attributes
   output wire[ADDR_SIZE-1:0]    epct2eptd_rdPtrOut      , //Write pointer value to be updated
   output reg [3          :0]    epct2eptd_nxtExpDataPid , //next DATA token to be expected for this EP
                                                      
   // ----------------------------------------------------------------
   // Memory interface 
   // ----------------------------------------------------------------
   output wire [ADDR_SIZE-1:0]   epct2mif_addr        , //Address of the memory location in local buffer
   output wire                   epct2mif_rd          , //Write request

   input wire                    mif2epct_ack         , //Ready signal
   input wire [DATA_SIZE-1:0]    mif2epct_data        , //Write data
   input wire                    mif2epct_dVal       
   );
   // ----------------------------------------------------------------
   // local parameters
   // ---------------------------------------------------------------
   // FSM variables

   reg  [2                 :0] current_state, 
                               next_state;
   localparam  IDLE       =  3'b000,    //default state
               GETEPPTR   =  3'b001,    //read pointers and status of end point
               TXDATA     =  3'b010,    //data transfer for OUT
               TXHDR      =  3'b011,    //write header for ACK/NYET
               TXUPDT     =  3'b100,    //update buffer info
               EOT        =  3'b101;

   // end point type parameters       
   // ---------------------------------------------------------------
    localparam CONTROL        = 2'b00    ,    
               ISOCHRONOUS    = 2'b01    ,
               BULK           = 2'b10    ,
               INTERRUPT      = 2'b11    ;

   // usb mode (speed) type parameters       
   // ---------------------------------------------------------------
     localparam LS            = 2'b00,
                FS            = 2'b01,
                HS            = 2'b10,
                SS            = 2'b11;

   // token type parameters       
   // ---------------------------------------------------------------
   localparam  RSRVD          =  4'B0000 ,
               OUT            =  4'b0001 ,  
               IN             =  4'b1001 , 
               PING           =  4'b0100 , 
               SETUP          =  4'b1101 , 
               DATA0          =  4'b0011 , 
               DATA1          =  4'b1011 , 
               DATA2          =  4'b0111 , 
               MDATA          =  4'b1111 ; 

      reg                   epct2mif_rd_r        ;
      reg                   epct2mif_rd_nxt      ; //Write request
      reg                   bufEmpty             ;
      reg  [3:          0]  curExpDataPid        ;
      reg  [3:          0]  nxtExpDataPid        ;
      reg  [3:          0]  epct2eptd_epNum_nxt  ;
      reg                   epct2eptd_reqData_nxt;
      reg  [ADDR_SIZE-1:0]  mifRdAddr            ;
      wire [ADDR_SIZE-1:0]  last_data_addr       ;
      reg  [ADDR_SIZE-1:0]  mifRdAddr_nxt        ;
      reg                   rd_halt              ;
      reg  [ADDR_SIZE-1:0]  startAddr            ;
      reg  [ADDR_SIZE-1:0]  endAddr              ;
      reg  [ADDR_SIZE-1:0]  rdPtr                ;
      reg  [ADDR_SIZE-1:0]  rdPtr_nxt            ;
      reg  [ADDR_SIZE-1:0]  wrPtr_nxt            ;
      reg  [ADDR_SIZE-1:0]  currentPktHdr        ;
      reg  [3:          0]  exptDataPid          ;
      reg                   epHalt               ;
      reg  [1:          0]  epTrans              ;
      reg  [3:          0]  epType               ;
      reg                   addr_load            ; 
      reg                   addr_incr        ; 
      wire                  epHalt_w             ;
      reg                   regAddr_load         ;
      reg                   rdPtrsRcvd           ;
      reg                   set_last_req_acked;
      reg                   clr_last_req_acked; 
      reg                   last_req_acked    ;
      wire [15:         0]  rem_bytes           ; 
      reg  [15:         0]  total_transLen ;
      reg  [15:         0]  currentPkt_len              ;  
      reg  [2          :0]  current_transSize     ;
      reg  [3          :0]  dataBE               ;           
      reg                   currentPktHdr_ld      ;
      reg  [DATA_SIZE-1:0]  mif2epct_data_h       ;
      reg                   mif2epct_dVal_h       ;
      reg                   rdEn_r                ;
      wire                 zeroLen_pkt            ;
      wire                 mif_rd                 ;
      reg                  clr_dval               ;
   // wire                 setup_stall            ;
      wire                 setup_zlp              ;
      reg  [4        -1:0] setupBE                ;
      reg                  send_NAK               ;          
      reg                  set_pkt_sent           ;      
      reg                  clr_pkt_sent           ;
      wire                 data_trans_completed   ;
      reg                  clr_pkt_size           ;
      reg                  clr_pkt_size_nxt       ;

   // ---------------------------------------------------------------
   // Code starts here
   // ---------------------------------------------------------------
   assign last_data_addr         = ( {currentPktHdr[31:2], 2'b00}== startAddr) ? endAddr :{currentPktHdr[31:2], 2'b00} - 3'b100; 
 //assign data_trans_completed   = ((epType!= CONTROL)&&(mifRdAddr == last_data_addr)||((epType==CONTROL)&& rem_bytes==16'b0 ))?1'b1:1'b0;
   assign data_trans_completed   = (mifRdAddr == last_data_addr)?1'b1:1'b0;
// assign total_transLen         = (reg2epc_setupLen >reg2epct_descLen) ? reg2epct_descLen :reg2epc_setupLen;
// assign total_transLen         = reg2epct_descLen; //device can send data upto the programmed length 
   assign rem_bytes              = (reg2epct_descLen>currentPkt_len)? (reg2epct_descLen-currentPkt_len): {16{1'b0}};
   assign setup_zlp              = (epType== CONTROL) &&(reg2epct_descLen ==1'b0) ? 1'b1  :1'b0;
// assign setup_stall            = (epType== CONTROL) &&(! rem_bytes) ? 1'b1               :1'b0;
   assign epct2pe_epZeroLenEn    = eptd2epct_zLenPkt|| setup_zlp;       
   assign epct2pa_zeroLen        = (epct2pe_epZeroLenEn||pe2epct_ctrlZlp)? 1'b1: 1'b0      ;
   assign epct2pa_dataValid      = (mif2epct_dVal | mif2epct_dVal_h) && rdEn_r; 
   assign epHalt_w               = rd_halt ? 1'b1 : epHalt;
   assign epct2pa_data           = mif2epct_dVal  ? mif2epct_data : mif2epct_data_h;
   assign epct2pa_dataBE         = last_req_acked ? dataBE           :  4'b1111 ;
   assign epct2mif_addr          = mifRdAddr                  ; 
   assign zeroLen_pkt            = ((rdPtr+4)== {currentPktHdr[31:2], 2'b00}) ? 1'b1 : 1'b0;
   assign epct2mif_rd            = mif_rd | pe2epct_hdrRd ; 
   assign mif_rd                 = zeroLen_pkt ? 1'b0 :(epct2mif_rd_r & pa2epct_ready && !last_req_acked)   ;
   assign epct2reg_descLenUpdt   = rem_bytes;
   assign epct2reg_enuActOut     =(rem_bytes   == {16{1'b0}}) ? 2'b00 : 2'b10 ;
   assign epct2eptd_rdPtrOut     = mifRdAddr  ; 
   assign epct2pe_epHalt         = epHalt_w /*| (!setup_zlp & setup_stall)*/; 
   assign epct2pe_bufEmpty       = (send_NAK || bufEmpty&&(epType != CONTROL))?1'b1 : 1'b0;
   assign epct2reg_bufEmpty      = bufEmpty;
   assign epct2pe_rdErr          = eptd2epct_reqErr   ;
   assign epct2pe_epType         = eptd2epct_epType     ;                                       
   assign epct2pe_expctDataPid   = curExpDataPid        ;


   always @(*) begin  
      case(currentPktHdr[1:0])
         2'b01:   dataBE = 4'b0001;
         2'b10:   dataBE = 4'b0011;
         2'b11:   dataBE = 4'b0111;
         2'b00:   dataBE = 4'b1111;
         default: dataBE = 4'b0001;
      endcase
   end
/*
   always @(*) begin  
      case( total_transLen[1:0]  )
         2'b01:   setupBE = 4'b0001;
         2'b10:   setupBE = 4'b0011;
         2'b11:   setupBE = 4'b0111;
         default: setupBE = 4'b1111;
      endcase
   end
 
*/
     always @(posedge core_clk, negedge uctl_rst_n) begin 
        if(!uctl_rst_n) begin
            total_transLen    <=    {16{1'b0}} ;   
         end
         else if(!uctl_rst_n) begin
            total_transLen    <=    {16{1'b0}} ;   
         end
         else if(reg2epct_EnuAct==2'b11) begin
            total_transLen    <= reg2epct_descLen;
         end
      end
 
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(!uctl_rst_n) begin
         rdEn_r          <= 1'b0;
      end
      else if(sw_rst) begin
         rdEn_r          <= 1'b0;
      end
      else if(!zeroLen_pkt)begin 
         rdEn_r          <= pe2epct_rdEn;
      end
   end

   generate begin
      if(REGISTER_EPDATA == 1) begin 
         always @(posedge core_clk, negedge uctl_rst_n) begin 
            if(!uctl_rst_n) begin
               startAddr      <= {ADDR_SIZE{1'b0}};
               endAddr        <= {ADDR_SIZE{1'b0}};
               exptDataPid    <= 4'b0             ;
               epHalt         <= 1'b0             ;
               epTrans        <= 2'b0             ;
               epType         <= 2'b0             ;
            end
            else if(sw_rst) begin
               startAddr      <= {ADDR_SIZE{1'b0}};
               endAddr        <= {ADDR_SIZE{1'b0}};
               exptDataPid    <= 4'b0             ;
               epHalt         <= 1'b0             ;
               epTrans        <= 2'b0             ;
               epType         <= 2'b0             ;
            end
            else if(rdPtrsRcvd) begin 
              startAddr      <= eptd2epct_startAddr      ;
              endAddr        <= eptd2epct_endAddr        ;
              exptDataPid    <= eptd2epct_exptDataPid    ;
              epHalt         <= eptd2epct_epHalt         ;
              epTrans        <= eptd2epct_epTrans        ;
              epType         <= eptd2epct_epType         ;
              rdPtr          <= rdPtr_nxt                ;
            end
         end
      end
      else begin 
         always@(*) begin
            startAddr       = eptd2epct_startAddr      ;
            endAddr         = eptd2epct_endAddr        ;
            exptDataPid     = eptd2epct_exptDataPid    ;
            epHalt          = eptd2epct_epHalt         ;
            epTrans         = eptd2epct_epTrans        ;
            epType          = eptd2epct_epType         ;
            rdPtr           = rdPtr_nxt                ;
         end
      end
   end
  endgenerate 


   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epct2reg_dpSend   <= 1'b0;   
         epct2reg_zlpSent  <= 1'b0;
      end
      else if(sw_rst ) begin
         epct2reg_dpSend   <= 1'b0;   
         epct2reg_zlpSent  <= 1'b0;
      end
      else if(set_pkt_sent) begin
         if(currentPkt_len == 16'h0000) begin
            epct2reg_dpSend   <= 1'b0;   
            epct2reg_zlpSent  <= 1'b1;
         end
         else begin
            epct2reg_dpSend   <= 1'b1;   
            epct2reg_zlpSent  <= 1'b0;
         end
      end
      else if(clr_pkt_sent) begin
         epct2reg_dpSend   <= 1'b0;   
         epct2reg_zlpSent  <= 1'b0;
      end
   end
         
            

 
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epct2eptd_reqData    <= 1'b0                   ;
         epct2eptd_epNum      <= 1'b0                 ;
      end
      else if(sw_rst) begin
         epct2eptd_reqData    <= 1'b0                   ;
         epct2eptd_epNum      <= 1'b0                 ;
      end
      else begin
         epct2eptd_epNum      <= epct2eptd_epNum_nxt  ;
         epct2eptd_reqData    <= epct2eptd_reqData_nxt;
      end
      end

      
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epct2eptd_nxtExpDataPid <= 4'b0000;        
      end
      else if(sw_rst) begin
         epct2eptd_nxtExpDataPid <= 4'b0000;        
      end
      else if(epct2pe_getRdPtrsDn) begin
         epct2eptd_nxtExpDataPid <= nxtExpDataPid;        
      end
   end

   //for control transfer, using registers count remaining transfer 
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         currentPkt_len   <= {16{1'b0}};         
      end
   // else if(!pe2epct_hdrRd  &&   addr_incr) begin 
      else if(pa2epct_ready && epct2pa_dataValid) begin 
         currentPkt_len   <= currentPkt_len + current_transSize;
      end
      else if(clr_pkt_size ) begin
         currentPkt_len   <= {16{1'b0}};         
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         clr_pkt_size            = 1'b0             ;
      end
      else if(   sw_rst   ) begin
         clr_pkt_size            = 1'b0             ;
      end
      else begin 
         clr_pkt_size           <= clr_pkt_size_nxt ;
      end
   end

   //generate memory address combinatorially
   always @(*) begin 
      if(addr_load) begin
         mifRdAddr_nxt        = eptd2epct_rdPtr ;
      end
      else if(regAddr_load) begin 
         mifRdAddr_nxt        = reg2epct_descAddr ;
      end   
      else if(addr_incr) begin
         if(mifRdAddr == endAddr) begin 
            mifRdAddr_nxt        = startAddr;
         end 
         else begin 
            mifRdAddr_nxt     = mifRdAddr +3'b100; 
         end
      end   
      else begin 
         mifRdAddr_nxt     = mifRdAddr;
      end
   end
   //calculate number of bytes transfer in current transfer
   always @(*)begin
      case(epct2pa_dataBE        )
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


   // MEMORY read  address
   //---------------------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         mifRdAddr         <={DATA_SIZE{1'b0}} ;
      end
      else if(sw_rst) begin
         mifRdAddr         <={DATA_SIZE{1'b0}} ;
      end
      else begin 
         mifRdAddr         <= mifRdAddr_nxt  ;
      end
   end      


   //generate transfer complete signal
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         last_req_acked <= 1'b0;
      end
      else if(sw_rst)begin
         last_req_acked <= 1'b0;
      end
      else if(set_last_req_acked) begin 
         last_req_acked <= 1'b1;
      end
      else if (clr_last_req_acked) begin 
         last_req_acked <= 1'b0;
      end
   end

  //register data from mif 
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
        mif2epct_data_h <= {32{1'b0}};
      end
      else if(mif2epct_dVal && !pa2epct_ready) begin 
         mif2epct_data_h<= mif2epct_data;
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         mif2epct_dVal_h  <= 1'b0;
      end
      else if(pe2epct_rdEn) begin 
         if(!pa2epct_ready && mif2epct_dVal&&clr_dval) begin
            mif2epct_dVal_h  <= 1'b1;
         end
         else if(pa2epct_ready  ) begin
            mif2epct_dVal_h  <= 1'b0;
         end
      end
   end
      
   //store header read from memory
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         currentPktHdr  <= {DATA_SIZE{1'b0}};
		end
      else if(currentPktHdr_ld) begin 
         currentPktHdr  <= mif2epct_data;
      end
   end

   always @(*) begin 
      if(! uctl_rst_n) begin
         rdPtr_nxt          = {ADDR_SIZE{1'b0}}             ;
         wrPtr_nxt          = {ADDR_SIZE{1'b0}}             ;
      end
      else if(sw_rst) begin
         rdPtr_nxt          = {ADDR_SIZE{1'b0}}             ;
         wrPtr_nxt          = {ADDR_SIZE{1'b0}}             ;
      end
      else if(regAddr_load)begin 
         rdPtr_nxt          = reg2epct_descAddr;
         wrPtr_nxt          = eptd2epct_wrPtr ;
      end
      else begin 
         rdPtr_nxt          = eptd2epct_rdPtr               ;
         wrPtr_nxt          = eptd2epct_wrPtr               ;
      end
   end
   // FSM sequential block
   // ---------------------------------------------------------------
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         current_state  <= IDLE;
      end
      else if(sw_rst) begin
         current_state  <= IDLE;
      end
      else if(pe2epc_idleState ) begin 
         current_state  <= IDLE;
      end
      else begin
         current_state <= next_state;
      end
   end
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         epct2mif_rd_r       <= 1'b0;
         
      end
      else begin 
         epct2mif_rd_r       <= epct2mif_rd_nxt;
      end
   end      


   // FSM combinational block
   // ---------------------------------------------------------------

   always @ * begin
      next_state              = current_state    ;
      //current_token_nxt       = current_token    ;
      //current_epNum_nxt       = current_epNum    ;
      epct2eptd_epNum_nxt     = epct2eptd_epNum  ;
      epct2eptd_reqData_nxt   = epct2eptd_reqData;       
      bufEmpty                 = 1'b0            ;     
      epct2pe_getRdPtrsDn     = 1'b0            ;
      rdPtrsRcvd              = 1'b0             ;
      epct2pe_hdrRdDn         = 1'b0             ;
      currentPktHdr_ld        = 1'b0             ;
      nxtExpDataPid           = DATA0            ;
      curExpDataPid           = DATA0            ;
      epct2pe_rdBufUpdtDn     = 1'b0             ; 
      rd_halt                 = 1'b0             ; 
      addr_load               = 1'b0             ;
      addr_incr               = 1'b0             ;
      regAddr_load            = 1'b0             ;
      set_last_req_acked   = 1'b0             ;
      epct2mif_rd_nxt         = epct2mif_rd      ;
      epct2pa_eot             = 1'b0             ;
      clr_dval                = 1'b0             ;
      epct2eptd_updtReq       = 1'b0             ;    
      epct2reg_enuCmdUpdt     = 1'b0             ;
      clr_last_req_acked      = 1'b0             ;
      send_NAK                = 1'b0             ;
      set_pkt_sent            = 1'b0             ;
      clr_pkt_sent            = 1'b0             ;
      clr_pkt_size_nxt        = clr_pkt_size     ;
      
    case(current_state)
       IDLE : begin   //default state
            clr_pkt_size_nxt        = 1'b0;
            clr_pkt_sent            = 1'b0             ;
            epct2eptd_epNum_nxt  = pe2epc_epNum  ;
            if(pe2epct_getRdPtrs) begin 
               epct2eptd_reqData_nxt= 1'b1          ;
               rdPtrsRcvd           = 1'b1          ; 
               next_state        = GETEPPTR         ;
            end
            else if(pe2epct_hdrRd) begin 
               next_state        = TXHDR;
               epct2mif_rd_nxt   = 1'b1 ;
            end
            if(pe2epct_updtRdBuf) begin 
               next_state        = TXUPDT;
            end
            if(pe2epct_rdEn) begin 
               if(zeroLen_pkt) begin
                  next_state     = EOT  ; 
               end
               else begin 
                  next_state     = TXDATA;
                  epct2mif_rd_nxt= 1'b1  ; 
               end
            end
         end
         GETEPPTR : begin
            if((epType == CONTROL)  && (reg2epct_enuCmdEn == 1'b1)) begin 
               if(reg2epct_EnuAct[1]!=1'b1) begin 
                  send_NAK        = 1'b1;
              end
               else if(reg2epct_stall== 1'b1) begin
                  rd_halt        = 1'b1; 
               end
               else if(reg2epct_EnuAct == 2'b11) begin 
                  regAddr_load   = 1'b1;
               end
               else begin 
                  addr_load         = 1'b1;
               end
            end
            else begin 
               addr_load         = 1'b1;
            end
   
            epct2pe_getRdPtrsDn  = 1'b1;  
            if((wrPtr_nxt == rdPtr_nxt) && (eptd2epct_lastOp== 1'b0)) begin
               bufEmpty          = 1'b1;     
            end
            //calculate next expected data token
            if(epType == BULK || epType == INTERRUPT || 
               epType == CONTROL) begin 
               if(exptDataPid == DATA0) begin
                  nxtExpDataPid = DATA1;
               end
               else if(exptDataPid == DATA1) begin
                  nxtExpDataPid = DATA0;
               end
               curExpDataPid    = exptDataPid;
            end
            if(epType == ISOCHRONOUS) begin
               case(epTrans)
                  2'b00: begin
                     nxtExpDataPid        = DATA0;
                     curExpDataPid        = DATA0;
                  end
                  
                  2'b01: begin
                     if(exptDataPid == DATA1) begin 
                        nxtExpDataPid     = DATA0;
                        curExpDataPid     = DATA1;
                     end
                     if(exptDataPid == DATA0) begin 
                        nxtExpDataPid     = DATA1;
                        curExpDataPid     = DATA0;
                     end
                  end
         
                  2'b10: begin 
                     if(exptDataPid == DATA2) begin 
                        nxtExpDataPid     = DATA1;
                        curExpDataPid     = DATA2;
                     end
                     if(exptDataPid == DATA1) begin 
                        nxtExpDataPid     = DATA0;
                        curExpDataPid     = DATA1;
                     end
                     if(exptDataPid == DATA0) begin 
                        nxtExpDataPid     = DATA2;
                        curExpDataPid     = DATA0;
                     end
                  end
                  default: begin
                     nxtExpDataPid        = DATA0;
                     curExpDataPid        = DATA0;
                  end
               endcase
            end
            next_state                 = IDLE; 
         end
         TXDATA : begin
            clr_dval             = 1;
            epct2mif_rd_nxt      = 1'b1  ;
            if((pe2epct_rdEn) ) begin
               if(!last_req_acked )begin 
                  if(mif2epct_ack) begin 
                     addr_incr      = 1'b1 ;
                     if(data_trans_completed) begin
                        set_last_req_acked = 1'b1;
                     end
                  end
               end
               else if(pa2epct_ready) begin 
                  next_state     = EOT  ; 
                  epct2mif_rd_nxt= 1'b0  ;

                  
               end
            end
         end

         EOT: begin 
            epct2pa_eot    =  1'b1 ;
            next_state     =  IDLE  ; 
            clr_last_req_acked = 1'b1;
         end


         TXHDR: begin
            if(mif2epct_ack) begin 
               epct2mif_rd_nxt  = 1'b0;
               addr_incr        = 1'b1 ;
            end
               
            if(mif2epct_dVal) begin 
               epct2pe_hdrRdDn  = 1'b1;
               currentPktHdr_ld = 1'b1;
               next_state       = IDLE;
            end
         end
         
         TXUPDT: begin
            epct2eptd_updtReq   = 1'b1              ;    
            clr_pkt_size_nxt    = 1'b1;
            set_pkt_sent        = 1'b1;
            if((reg2epct_enuCmdEn == 1) && (epType == CONTROL))begin 
               epct2reg_enuCmdUpdt  = 1'b1  ;
            end 
            if(eptd2epct_updtDn) begin
               epct2pe_rdBufUpdtDn  = 1'b1; 
               next_state           = IDLE;
            end
         end    
      endcase 
   end
endmodule 
