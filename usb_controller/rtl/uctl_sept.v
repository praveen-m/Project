`timescale 1ns / 1ps
//-------------------------------------------------------------------
// Copyright © 2012 TECHVULCAN, Inc. All rights reserved.     
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, nor    
// its contents          
// revealed in any manner to others without the express written    
// permission of TechVulcan         
// Licensed Material.         
// Program Property of TECHVULCAN Incorporated. 
// ------------------------------------------------------------------
// DATE           : Tue, 05 Feb 2013 18:00:30
// AUTHOR         : Darshan Naik
// AUTHOR EMAIL   : darshan.naik@techvulcan.com
// FILE NAME      : uctl_sept.v
// VERSION        : 0.6
//-------------------------------------------------------------------

// VERSION        : 0.6
//                   update buffer done signal is registerd and sent   
// VERSION        : 0.5
//                   dma done and cmd dn signal registered and sent
// VERSION        : 0.4
//                   list protocol implemented, 
// VERSION        : 0.3
//                   wrapping address of endpoint is implemented 
// VERSION        : 0.2
//                   sept2dmaTx_sRdWr signal is added and tied to 1
// VERSION        : 0.1
//                   intial release      





/*
TODO
when is the eptd2sept_reqErr signal high? yet to be included in the code
checking of full condition during ptr update?



*/

//-----------------------------------------------------------------------
//-----------------------------------------------------------------------

module uctl_sept #(
            parameter REGISTER_EN = 1, 
            parameter PKTCNTWD    = 9  
   )(
      //----------------------------------------------------------------
      // Global signals
      //----------------------------------------------------------------     
      input  wire                          uctl_rst_n                      ,// Resets the state machine to IDLE state
      input  wire                          core_clk                        ,//core clock
      input  wire                          sw_rst                          ,//resets the module          
      //---------------------------------------------------------------
      // Memory Interface
      //---------------------------------------------------------------   
      input  wire                          mif2sept_ack                    ,// ack signal for the sys endpoint controller
      output reg                           sept2mif_wr                     ,//write enable
      output wire [31                  :0] sept2mif_addr                   ,// address of the memory location in thlocal buffer
      output wire [31                  :0] sept2mif_wrData                 ,// write data
      //----------------------------------------------------------------
      //System Controller Interface      
      //----------------------------------------------------------------
      input  wire [3                   :0] sctrlTx2sept_epNum              ,//endpoint number
      input  wire [19                  :0] sctrlTx2sept_wrPktLength        ,//length of the current packet in bytes
      input  wire                          sctrlTx2sept_inIdle             ,//indicates when in IDLE state
      input  wire                          sctrlTx2sept_getWrPtrs          ,//signal used to get the current endpoint attributes 
      input  wire                          sctrlTx2sept_wr                 ,//write signal to endpoint controller for writing data to endpoint buffer
      input  wire                          sctrlTx2sept_hdrWr              ,//signal to write the header information of the current packet
      input  wire                          sctrlTx2sept_updtWrBuf          ,//update endpoint buffer for current transaction
      input  wire                          sctrlTx2sept_wrAddrEn           ,// when address to be loaded in sept to be given to dma  
      output wire [PKTCNTWD-1          :0] sept2sctrlTx_fullPktCnt         ,    
      output reg                           sept2sctrlTx_bufUpdtDn          ,//buffer update completion signal for write transaction
      output wire [10                  :0] sept2sctrlTx_eptBufSize         ,//buffer size in bytes for the endpoint
      output reg                           sept2sctrlTx_hdrWrDn            ,//header write completion signal for write
      output reg                           sept2sctrlTx_wrPtrsRecvd        ,//indicates when the endpoint controller has got the pointer
      output reg                           sept2sctrlTx_transferDn         ,//indicates the assigned data packet trasfer
      output reg                           sept2sctrlTx_transferErr        ,//indicates there was a error in thr transfer
      output reg                           sept2sctrlTx_bufFull            ,//endpoint buffer full
      
      //---------------------------------------------------------------
      //RegisterInterface                 
      //---------------------------------------------------------------
      input  wire  [2                  :0] reg2sept_dmaMode                ,//DMA selector
      input  wire  [31                 :0] reg2sept_sRdAddr                ,// system source address   
    
      //--------------------------------------------------------------
      //EndPoint Data Interface            
      //--------------------------------------------------------------
      // input  wire                          eptd2sept_reqErr       TODO  ,//request error indication
      input  wire [31                  :0] eptd2sept_startAddr             ,//endpoint start aaddress
      input  wire [31                  :0] eptd2sept_endAddr               ,//endpoint end address
      input  wire [31                  :0] eptd2sept_rdPtrs                ,//endpoint read pointer
      input  wire [31                  :0] eptd2sept_wrPtrs                ,//endpoint write pointer
      input  wire [10                  :0] eptd2sept_bSize                 ,//Max packet length
      input  wire                          eptd2sept_updtDn                ,
      input  wire                          eptd2sept_lastOp                ,// last opration write=1 ,read=0 
      input  wire [PKTCNTWD-1          :0] eptd2sept_fullPktCnt            ,    
      output wire [3                   :0] sept2eptd_epNum                 ,//endpoint number          
      output reg                           sept2eptd_reqData               ,//request signal to get all the endpoint attributes
      output reg                           sept2eptd_updtReq               ,//update request
      output wire [31                  :0] sept2eptd_wrPtrOut              ,//write pointer value to be updated

      //-------------------------------------------------------------
      //DMA Interface      
      //-------------------------------------------------------------
      output wire [31                  :0] sept2dmaTx_addrIn               ,//local buffer address
      output reg                           sept2dmaTx_wr                   ,//write signal
      output wire                          sept2dmaTx_sRdWr                ,
      output wire [19                  :0] sept2dmaTx_len                  ,//length of the packet
      output wire [31                  :0] sept2dmaTx_epStartAddr          ,//endpoint start address
      output wire [31                  :0] sept2dmaTx_epEndAddr            ,//endpoint end address
      input  wire                          dmaTx2sept_dn                   ,//dma transfer done
      output reg  [31                  :0] sept2dmaTx_sRdAddr              ,  
      
      //-------------------------------------------------------------
      //CMD Interface
      //--------------------------------------------------------------
      input  wire                          cmdIf2sept_dn                    ,
      output reg                           sept2cmdIf_wr                    , 
      output wire [2                   :0] sept2cmdIf_dmaMode               ,  
      output wire [31                  :0] sept2cmdIf_addr                  ,//local buffer address
      output wire [19                  :0] sept2cmdIf_len                   ,
      output wire [31                  :0] sept2cmdIf_epStartAddr           ,
      output wire [31                  :0] sept2cmdIf_epEndAddr            

      );

   localparam  SE_IDLE          = 3'b000,
               SE_GETPTR        = 3'b001,
               SE_DATA          = 3'b010,
               SE_HEADER        = 3'b011,
               SE_UPDATE        = 3'b100;

   localparam  LASTOP_WR        = 1'b1;

   reg   [2                   :0] current_state,next_state  ;
   reg   [31                  :0] startAddr                 ;
   reg   [31                  :0] endAddr                   ;
   reg   [10                  :0] maxPktLen                 ;
   reg   [31                  :0] current_wrPtrs            ;
   reg   [31                  :0] current_rdPtrs            ;
   wire                           bufFull                   ;
   wire                           nospace_wrgtrd            ;
   wire                           nospace_rdgtwr            ;
   reg                            ptrs_ld                   ;
   reg                            addr_ld                   ;
   reg                            buf_nearly_full           ;
   reg                            sept2mif_wr_nxt           ;
   reg  [31                   :0] data_wrPtr                ;
   reg  [31                   :0] data_wrPtr_nxt            ;
   reg  [31                   :0] hdr_wrPtr                 ;
   reg  [31                   :0] start_data_wrPtr          ;
   wire [31                   :0] lastBufSpace              ;
   wire [19                   :0] txLen                     ;
   wire [19                   :0] pktSpace                  ;
   wire [1                    :0] byteEn                    ;
   reg  [31                   :0] nxt_hdr                   ;
   reg                            sept2eptd_updtReq_nxt     ;
   reg  [31                   :0] nxt_hdr_last              ;            
   reg                            addr_incr_dma             ;
   reg                            nxt_hdr_last_ld           ;
   reg                            dma_dn_r                  ;
   reg                            cmd_dn_r                  ;
   reg                            eptdUpdtDn                ;    



   assign bufFull             = ((current_rdPtrs==current_wrPtrs)  && 
                                 (eptd2sept_lastOp == LASTOP_WR ) ) ? 
                                 1'b1 :1'b0                                ;



   assign nospace_wrgtrd      = (((eptd2sept_endAddr-current_wrPtrs)    +
                                  (current_rdPtrs-eptd2sept_startAddr)) <
                                    (sctrlTx2sept_wrPktLength ))        ?
                                 1'b1:1'b0                                 ;   //TODO



   assign nospace_rdgtwr      = ((current_rdPtrs-current_wrPtrs) < 
                                    sctrlTx2sept_wrPktLength )   ? 
                                 1'b1:1'b0                                 ;


   assign sept2eptd_epNum           = sctrlTx2sept_epNum                   ;
   
   assign sept2cmdIf_dmaMode        = reg2sept_dmaMode                     ;
   
   assign sept2sctrlTx_fullPktCnt   = eptd2sept_fullPktCnt                 ;   



   generate
      if(REGISTER_EN) begin
         always @(posedge core_clk or negedge uctl_rst_n) begin
            if(!uctl_rst_n) begin     
               startAddr          <={32{1'b0}};
               endAddr            <={32{1'b0}};
               current_rdPtrs     <={32{1'b0}};
               maxPktLen          <={11{1'b0}};
            end
            else begin
               if(ptrs_ld) begin 
                  startAddr          <=      eptd2sept_startAddr  ; 
                  endAddr            <=      eptd2sept_endAddr    ;
                  current_rdPtrs     <=      eptd2sept_rdPtrs     ;
                  maxPktLen          <=      eptd2sept_bSize      ;
               end
            end
         end
      end
      else begin
         always @(*) begin
            if(ptrs_ld) begin 
               startAddr          =        eptd2sept_startAddr; 
               endAddr            =        eptd2sept_endAddr  ;
               current_rdPtrs     =        eptd2sept_rdPtrs   ;
               maxPktLen          =        eptd2sept_bSize    ;
            end
         end
      end  
   endgenerate      
 
   assign sept2sctrlTx_eptBufSize   =  maxPktLen;
   assign sept2eptd_wrPtrOut        =  nxt_hdr  ;
   assign sept2dmaTx_sRdWr          =  1'b1     ; 
            
   // Buffer space available towards the end of the buffer
   // not considering the rdPtr
   assign lastBufSpace = (endAddr +3'b100) - (hdr_wrPtr +3'b100);   
      
  

   // TODO: Get next ptr from  DMA as the same logic is there
   //       in DMA too.
   always@(*) begin
      if(sctrlTx2sept_getWrPtrs ) begin
         if (lastBufSpace > sctrlTx2sept_wrPktLength) begin
            nxt_hdr = data_wrPtr_nxt + pktSpace;
         end
         else begin
            nxt_hdr = startAddr + (pktSpace - lastBufSpace);
         end
      end
      else begin
         nxt_hdr   = nxt_hdr_last;
      end
   end   
   always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         nxt_hdr_last <= {32{1'b0}};
      end
      else begin
         if(nxt_hdr_last_ld ) begin     
            nxt_hdr_last <= nxt_hdr;
         end
      end
   end

   always @(*) begin
      if(eptd2sept_wrPtrs  == endAddr )begin
         start_data_wrPtr  = startAddr;
      end
      else begin
         start_data_wrPtr = hdr_wrPtr + 3'b100;
      end
   end

    
   always@(*) begin  
      if(start_data_wrPtr > endAddr) begin
         data_wrPtr_nxt = startAddr;
      end
      else begin
         data_wrPtr_nxt = start_data_wrPtr;
      end
   end

   always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         data_wrPtr <= {32{1'b0}};
      end
      else begin
         if (addr_ld) begin
            data_wrPtr <= data_wrPtr_nxt;
         end
      end
   end
      
   
    always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         current_wrPtrs <= {32{1'b0}};
      end
      else begin
         if(ptrs_ld) begin
            current_wrPtrs <= eptd2sept_wrPtrs;
         end
      end
   end

   always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         hdr_wrPtr <= {32{1'b0}};
      end
      else begin
         if(ptrs_ld) begin
            hdr_wrPtr <= eptd2sept_wrPtrs;
         end
      end
   end


   always @(*) begin
      if(current_rdPtrs > current_wrPtrs) begin        // TODO 
         buf_nearly_full = nospace_rdgtwr;
      end                                            
      else begin                                     
         buf_nearly_full = nospace_wrgtrd; // rd <= wr
      end                                            
   end


   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         sept2mif_wr  <= 1'b0;
		end
      else begin 
         sept2mif_wr <= sept2mif_wr_nxt ;
      end
   end


   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         sept2eptd_updtReq  <= 1'b0;
		end
      else begin 
         sept2eptd_updtReq <= sept2eptd_updtReq_nxt ;
      end
   end

   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         sept2sctrlTx_bufUpdtDn  <= 1'b0;
		end
      else begin 
         if (eptdUpdtDn) begin
            sept2sctrlTx_bufUpdtDn <= 1'b1 ;
         end
         else begin
            sept2sctrlTx_bufUpdtDn <= 1'b0 ;
         end 
      end
   end
  
   // registering dma and cmd done signal  
   always @(posedge core_clk, negedge uctl_rst_n) begin 
      if(! uctl_rst_n) begin
         dma_dn_r  <= 1'b0;
         cmd_dn_r  <= 1'b0;
		end
      else begin 
         dma_dn_r <= dmaTx2sept_dn ;
         cmd_dn_r <= cmdIf2sept_dn ;
      end
   end

   assign byteEn                 = txLen[1:0]                       ;
  
   assign pktSpace               = (txLen[19:2]<<2'b10)           +  
                                   ((txLen[1] | txLen[0])<<2'b10)   ;

   assign sept2mif_wrData        = {nxt_hdr[31:2],byteEn}           ;
          
   assign sept2mif_addr          = hdr_wrPtr                        ;


   always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n) begin
         sept2dmaTx_sRdAddr <= {32{1'b0}};
      end
      else begin
         if (sctrlTx2sept_wrAddrEn) begin
            sept2dmaTx_sRdAddr <= reg2sept_sRdAddr    ;
         end
         else if (addr_incr_dma) begin
            sept2dmaTx_sRdAddr <= sept2dmaTx_sRdAddr + 
                                  pktSpace            ;
         end
      end
   end

   assign sept2dmaTx_addrIn      = data_wrPtr               ;
   assign sept2dmaTx_epStartAddr = startAddr                ;
   assign sept2dmaTx_epEndAddr   = endAddr                  ;
   assign sept2dmaTx_len         = sctrlTx2sept_wrPktLength ;
   assign txLen                  = sctrlTx2sept_wrPktLength ;

   // memory access through cmd If
   assign sept2cmdIf_epStartAddr = startAddr                ;   
   assign sept2cmdIf_epEndAddr   = endAddr                  ;
   assign sept2cmdIf_addr        = data_wrPtr               ;
   assign sept2cmdIf_len         = sctrlTx2sept_wrPktLength ;

   always @ (*) begin 
      next_state                 = current_state;       
      sept2sctrlTx_hdrWrDn       = 1'b0;
      sept2sctrlTx_wrPtrsRecvd   = 1'b0;
      sept2sctrlTx_transferDn    = 1'b0;
      sept2sctrlTx_transferErr   = 1'b0;
      sept2sctrlTx_bufFull       = 1'b0;
      sept2eptd_updtReq_nxt      = sept2eptd_updtReq;
      sept2eptd_reqData          = 1'b0;
      ptrs_ld                    = 1'b0;
      addr_ld                    = 1'b0;
      sept2dmaTx_wr              = 1'b0;
      sept2mif_wr_nxt            = sept2mif_wr;
      sept2cmdIf_wr              = 1'b0;
      nxt_hdr_last_ld            = 1'b0;
      addr_incr_dma              = 1'b0;
      eptdUpdtDn                 = 1'b0;

      case(current_state)
         SE_IDLE:begin
            if(sctrlTx2sept_getWrPtrs) begin
               ptrs_ld                 = 1'b1;
               sept2eptd_reqData       = 1'b1;
               next_state              = SE_GETPTR;
            end
            else if(sctrlTx2sept_wr) begin
               if(buf_nearly_full) begin                        // TODO                
                  sept2sctrlTx_transferDn      = 1'b0   ;                      
                  sept2sctrlTx_transferErr     = 1'b1   ;
                  next_state                   = SE_IDLE;       
               end
               else begin
                  if(reg2sept_dmaMode==3'b010) begin
                     next_state           = SE_DATA;
                     sept2dmaTx_wr        = 1'b1;
                  end
                  else if(reg2sept_dmaMode==3'b001 |
                          reg2sept_dmaMode==3'b000   )begin
                     next_state           = SE_DATA;
                     sept2cmdIf_wr        = 1'b1;      
                  end
               end   
            end
            else if(sctrlTx2sept_hdrWr) begin
               sept2mif_wr_nxt=1'b1;
               next_state              = SE_HEADER;
            end
            else if(sctrlTx2sept_updtWrBuf) begin
               sept2eptd_updtReq_nxt   = 1'b1      ;
               next_state              = SE_UPDATE ;
            end
         end

         SE_GETPTR:begin
            addr_ld                    = 1'b1    ;
            nxt_hdr_last_ld            = 1'b1;
            sept2sctrlTx_bufFull       = bufFull;
            sept2sctrlTx_wrPtrsRecvd   = 1'b1    ;
            next_state                 = SE_IDLE ;
         end

         SE_DATA:begin                        
            if(dma_dn_r ||cmd_dn_r ) begin
               addr_incr_dma           = 1'b1    ;      
               sept2sctrlTx_transferDn = 1'b1    ;
               next_state              = SE_IDLE ;
            end
         end      

         SE_HEADER:begin                          
            if(mif2sept_ack) begin               
               sept2mif_wr_nxt      = 1'b0   ;
               next_state           = SE_IDLE;   
               sept2sctrlTx_hdrWrDn = 1'b1   ;
            end
         end
   
         SE_UPDATE: begin
            if(eptd2sept_updtDn) begin
               sept2eptd_updtReq_nxt   = 1'b0   ; 
               eptdUpdtDn              = 1'b1   ;  
            end
            if(!sctrlTx2sept_updtWrBuf) begin
               next_state              = SE_IDLE;
            end
         end

         default : next_state = current_state;

      endcase        
   end

   always @(posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n )begin
         current_state  <= SE_IDLE;
      end
      else if  (sw_rst || sctrlTx2sept_inIdle) begin
         current_state  <= SE_IDLE;
      end
      else begin
         current_state  <= next_state;
      end
   end

endmodule                                             // system_endpoint_controller


