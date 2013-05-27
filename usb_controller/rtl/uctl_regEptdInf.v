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
// DATE		   	: Mon, 22 Apr 2013 10:14:58
// AUTHOR	      : Sanjeeva
// AUTHOR EMAIL	: sanjeeva.n@techvulcan.com
// FILE NAME		: uctl_regEptdInf.v
// VERSION        : 0.2
//-------------------------------------------------------------------
/*
//UPDATE version 0.2 fix
// for interrupt,Signals are added for register block
// pe2eptd_initIsoPid signal and related logic is added
*/
module uctl_regEptdInf
   #(parameter
   GLITCH_CNTR_WD = 4,
   `include "../rtl/uctl_top.vh",
   `include "../rtl/uctl_core.vh"
   )
   (

   /********************************************************************/
   // register block interface
   /********************************************************************/
   // ---------------------------------------------
   // Global Signal
   // ---------------------------------------------
   input wire                 core_clk                 ,//Core clock 
   input wire                 uctl_rst_n               ,//Core Reset
   input wire                 uctl_SysClk              ,//System clock 
   input wire                 uctl_SysRst_n            ,//System Reset
   input wire                 uctl_PhyClk              ,//Phy Clock
   input wire                 uctl_PhyRst_n            ,//Phy Reset

   //----------------------------------------------
   // cmd interface
   //----------------------------------------------
   
   input  wire                cmdIf_trEn               ,
   input  wire                cmdIf_req                ,
   input  wire [31       :0]  cmdIf_addr               ,
   input  wire                cmdIf_wrRd               ,
   output wire                cmdIf_ack                ,

   input  wire                cmdIf_wrData_req         ,
   input  wire [31       :0]  cmdIf_wrData             ,
   output wire                cmdIf_wrData_ack         ,

   input  wire                cmdIf_rdData_req         ,
   output wire                cmdIf_rdData_ack         ,
   output wire [31       :0]  cmdIf_rdData             ,
   output wire                intrReq                  ,

   // ----------------------------------------------
   // Dma system memory
   // ----------------------------------------------
   output wire[32-1:0]        reg2sepr_sWrAddr         ,//32 bit write address in system memory
   output wire[32-1:0]        reg2sept_sRdAddr         ,//32 bit read address in system memory

   // ---------------------------------------------
   // AON Interface
   // ---------------------------------------------
   output wire                       uctl_powerDown         , //0: device is in not power down,  //TODO ASYCN PATH NEED TO ADD
                                                              //1: device is in power down mode           
   output wire [GLITCH_CNTR_WD -1:0] uctl_glitchFilterCount , //number of aon clock cycle for which linse state  //TODO ASYCN PATH NEED TO ADD
                                                                // should be stable to dtect a change

   // ---------------------------------------------
   // EPCR (endpoint controller rx)     
   // ---------------------------------------------
   output wire                reg2epcr_enuCmdEn        ,//Enumeration done using ENU_CMD_REG  //TODO as per suresh this bit is connected to 1'b1 should be removed
   output wire[1          :0] reg2epcr_EnuAct          ,//Active status:
   output wire[15         :0] reg2epcr_descLen         ,//Length of descriptor data requested  
   output wire[32-1:0]        reg2epcr_descAddr        ,//Starting address for the descriptor
   output wire                reg2epcr_stall           ,//enable stall for request 
   output wire                reg2epcr_rwCtlrType      ,//0: control read, 1: control write
   output wire[15         :0] reg2epc_setupLen         ,

   input wire [1          :0] epcr2reg_enuActOut       ,//Update value for the ACT field from endpoint
   input wire                 epcr2reg_enuCmdUpdt      ,//Strobe signal to update ENU_CMD_REG
   input wire [15         :0] epcr2reg_descLenUpdt     ,//length of remaing transfer update cmd reg
   input wire [32       -1:0] epcr2reg_setupData       ,        
   input wire                 epcr2reg_setupRegIndex   ,
   input wire                 epcr2reg_setupWrReq      , 
   input wire                 epcr2reg_bufFull         ,
   input wire                 epcr2reg_zlpRcvd         ,
   input wire                 epcr2reg_setupRcvd       ,
   input wire                 epcr2reg_dpRcvd          ,

   // ---------------------------------------------
   // EPCT (endpoint controller tx)       
   // ---------------------------------------------
   output wire                reg2epct_enuCmdEn        ,//Enumeration done using ENU_CMD_REG //TODO as per suresh this bit is connected to 1'b1 should be removedG
   output wire[1          :0] reg2epct_EnuAct          ,//Active status:
   output wire[15         :0] reg2epct_descLen         ,//Length of descriptor data requested    
   output wire[32-1       :0] reg2epct_descAddr        ,//Starting address for the descriptor
   output wire                reg2epct_stall           ,//enable stall for request 
   output wire                reg2epct_rwCtlrType      ,//0: control read, 1: control write
                                                     
   input wire [1          :0] epct2reg_enuActOut       ,//Update value for the ACT field from endpoint
   input wire                 epct2reg_enuCmdUpdt      ,//Strobe signal to update ENU_CMD_REG
   input wire [15         :0] epct2reg_descLenUpdt     ,//update this value of length
   input wire                 epct2reg_bufEmpty        ,
   input wire                 epct2reg_zlpSent         ,
   input wire                 epct2reg_dpSend          ,

   // ---------------------------------------------
   // protocol engine
   // ---------------------------------------------
   output wire                reg2pe_enHost            ,//0	: device mode, 1:host mode
   output wire                reg2pe_enOTGTrans        ,//OTG transfer started
   output wire[3          :0] reg2pe_epNum             ,//endpoint number in usb_trans_contrl register
   output wire                reg2pe_devHalt           ,//Device is halted if set
   output wire[3          :0] reg2pe_tokenType         ,//token type in usb_trans_contrl register  //TODO change to 4bit
   output wire[2          :0] reg2pe_usbMode           ,//usb mode (LS,HS,FS,SS)
   input  wire                pe2reg_transSent         ,
   input  wire               pe2reg_clrCmdReg,

   // -------------------------------------------
   // system controller rx
   // -------------------------------------------
   output wire                reg2sctrlRx_rd           ,//Read enable from register block interface
   output wire[3          :0] reg2sctrlRx_epNum        ,//Endpoint number
   output wire[3          :0] reg2sctrlRx_rdCount      ,//Number of packets to be read
   input  wire                sctrlRx2reg_updtRdBuf    ,//Update signal to update the register values
   input  wire[3          :0] sctrlRx2reg_rdCnt        ,//read counter for number of packets
   input  wire[1          :0] sctrlRx2reg_status       ,
   input  wire [4         :0] sctrlRx2reg_fullPktCnt   ,
   output wire                reg2sctrlRx_listMode     ,
   output wire [2        :0]  reg2sepr_dmaMode         ,
   input wire                 sctrlRx2reg_empty        ,

   //---------------------------------------------- 
   // system controller tx              
   //----------------------------------------------     
   output wire [2         :0] reg2sept_dmaMode         ,
   output wire [19        :0] reg2sctrlTx_wrPktLength  ,//lenght of the pkt to transfered
   output wire [3         :0] reg2sctrlTx_epNum        ,//end Point number
   output wire                reg2sctrlTx_wr           ,//signal from system to write
   output wire                reg2sctrlTx_disFrag      ,//will disable fragmentation 
   input wire  [1         :0] sctrlTx2reg_status       ,
   input wire  [19        :0] sctrlTx2reg_length       ,//length of the orginal data pending
   input wire  [4         :0] sctrlTx2reg_fragCnt      ,//fragmentation count to be updated in register 
   input wire                 sctrlTx2reg_updt         ,//update signal to update the register values
   input wire  [4        :0]  sctrlTx2reg_fullPktCnt   ,
   output wire                reg2sctrlTx_listMode     ,
   input wire                 sctrlTx2reg_full         ,
   output wire  [21        :0] reg2cmdIf_memSegAddr    ,
   //----------------------------------------------
   // packet decoder        
   //----------------------------------------------  
   output wire                reg2pd_dataBus16_8       ,//8 or 16 bit mode indication 
   output wire [6         :0] reg2pd_devId             ,//device address
 
   //----------------------------------------------
   // packet assembler        
   //----------------------------------------------  
   output wire                reg2pa_tokenValid        ,
   output wire                reg2pa_dataBus16_8       , 
   output wire [3         :0] reg2pa_tokenType         ,
   output wire [3         :0] reg2pa_epNum             ,
   output wire [6         :0] reg2pa_devID             , 
   output wire [10        :0] reg2pa_frameNum          ,

   //----------------------------------------------
   // power on reset interface
   //----------------------------------------------  
   input wire                por2reg_fsmIntr           ,//TODO async path not done 
   input wire                por2reg_resumeCompleted   ,
   input wire                por2reg_resumeDetected    ,
   input wire                por2reg_resetCompleted    ,
   input wire                por2reg_resetDetected     ,
   input wire                por2reg_susDetected       , 
   input wire                pe2reg_lpmRcvd            ,
   input  wire               pe2reg_remoteWakeUp       , 

   /********************************************************************/
   // endpoint data block interface
   /********************************************************************/
  // -----------------------------------------------
  // packet decoder
  // -----------------------------------------------
   input wire                 pd2eptd_statusStrobe     ,
   input wire                 pd2eptd_crc5             ,
   input wire                 pd2eptd_pid              ,
   input wire                 pd2eptd_err              ,
   input wire[4           :0] pd2eptd_epNum            ,

   //----------------------------------------------
   // pe interface
   //----------------------------------------------
   input wire                 pe2eptd_intPid           ,
   input wire                 pe2eptd_initIsoPid       ,
   output wire                eptd2pe_noTransPending   ,

   //----------------------------------------------
   // frame counter interface
   //----------------------------------------------
   output wire [20     -1:0]  reg2frmCntr_upCntMax     ,//TODO async path not done 
   output wire [4      -1:0]  reg2frmCntr_timerCorr    , 
   output wire [10     -1:0]  reg2frmCntr_eof1         , 
   output wire [8      -1:0]  reg2frmCntr_eof2         , 
   output wire                reg2frmCntr_enAutoSof    , 
   output wire                reg2frmCntr_autoLd       , 
   output wire [20     -1:0]  reg2frmCntr_timerStVal   ,   
   output wire                reg2frmCntr_ldTimerStVal ,  
   input  wire [11     -1:0]  frmCntr2reg_frameCount   , 
   input  wire                frmCntr2reg_sofSent      , 
   input  wire                frmCntr2reg_sofRcvd      , 
   input  wire                frmCntr2reg_frameCntVl   , 
   input  wire                frmCntr2reg_eof1Hit      ,

  // -----------------------------------------------
  // EPC Write Interface
  // -----------------------------------------------
   input wire [3     :0]      epcr2eptd_epNum          ,//Physical Endpoint number
   input wire                 epcr2eptd_reqData        ,//Request signal 
   input wire                 epcr2eptd_updtReq        ,//Update request 
   input wire [32       -1:0] epcr2eptd_wrPtrOut       ,//Write pointer value to be updated
   input wire [3     :0]      epcr2eptd_nxtDataPid     ,//The expected data PID for that EP  //TODO only 2 bits assigned
   input  wire                epcr2eptd_setEphalt      ,
   input wire                 epcr2eptd_dataFlush      ,
    
   output wire                eptd2epcr_wrReqErr       ,//OUT Request error indication //TODO all request error to be updated
   output wire [32       -1:0]eptd2epcr_startAddr      ,//Endpoint Start Address
   output wire [32       -1:0]eptd2epcr_endAddr        ,//Endpoint End Address
   output wire [32       -1:0]eptd2epcr_rdPtr          ,//Endpoint Read pointer
   output wire [32       -1:0]eptd2epcr_wrPtr          ,//Endpoint Write pointer
   output wire                eptd2epcr_lastOp         ,//Last operation
   output wire [3     :0]     eptd2epcr_exptDataPid    ,//The expected data PID for that EP
   output wire                eptd2epcr_updtDn         ,//Return status signal 
   output wire [10    :0]     eptd2epcr_wMaxPktSize    ,//Endpoint max buffer size
   output wire [1     :0]     eptd2epcr_epType         ,//Endpoint Type
   output wire [1     :0]     eptd2epcr_epTrans        ,//High BW # transfers per frame
   output wire                eptd2epcr_epHalt         ,//Endpoint Halt

  // -----------------------------------------------
  // EPC Read Interface 
  // -----------------------------------------------
   input wire [3     :0]      epct2eptd_epNum          ,//Physical Endpoint number
   input wire                 epct2eptd_reqData        ,//Request signal
   input wire                 epct2eptd_updtReq        ,//Update request
   input wire [32       -1:0] epct2eptd_rdPtrOut       ,//Read pointer value to be updated
   input wire [3     :0]      epct2eptd_nxtExpDataPid  ,//The expected data PID for that EP   //TODO only 2 bits assigned
   
   output wire                eptd2epct_reqErr         ,//OUT Request error indication //TODO all request error to be updated
   output wire                eptd2epct_zLenPkt        ,//zero length pkt
   output wire [32       -1:0]eptd2epct_startAddr      ,//Endpoint Start Address
   output wire [32       -1:0]eptd2epct_endAddr        ,//Endpoint End Address
   output wire [32       -1:0]eptd2epct_rdPtr          ,//Endpoint Read pointer
   output wire [32       -1:0]eptd2epct_wrPtr          ,//Endpoint Write pointer
   output wire                eptd2epct_lastOp         ,//Last operation
   output wire [3     :0]     eptd2epct_exptDataPid    ,//The expected data PID for that EP
   output wire                eptd2epct_updtDn         ,//Return status signal 
   output wire [1     :0]     eptd2epct_epType         ,//Endpoint Type
   output wire [1     :0]     eptd2epct_epTrans        ,//High BW # transfers per frame
   output wire                eptd2epct_epHalt         ,//Endpoint Halt

  // -----------------------------------------------
  //  Sys_EPC Write Interface
  // -----------------------------------------------
   input wire [3     :0]      sept2eptd_epNum          ,//Physical Endpoint number
   input wire                 sept2eptd_reqData        ,//Request signal
   input wire                 sept2eptd_updtReq        ,//Update request
   input wire [32      -1:0]  sept2eptd_wrPtrOut       ,//Wirte pointer value to be updated

   output wire                eptd2sept_reqErr         ,//OUT Request error indication //TODO all request error to be updated
   output wire [32       -1:0]eptd2sept_startAddr      ,//Endpoint Start Address
   output wire [32       -1:0]eptd2sept_endAddr        ,//Endpoint End Address
   output wire [32       -1:0]eptd2sept_rdPtr          ,//Endpoint Read pointer
   output wire [32       -1:0]eptd2sept_wrPtr          ,//Endpoint Write pointer
   output wire                eptd2sept_updtDn         ,//Return status signal
   output wire [10    :0]     eptd2sept_bSize          ,//Endpoint max buffer size
   output wire                eptd2sept_lastOp         ,//Last operation
   output wire [PKTCNTWD-1 :0]eptd2sept_fullPktCnt     ,
   

  // -----------------------------------------------
  //  Sys_EPC Read Interface
  // -----------------------------------------------
   input wire [3     :0]      sepr2eptd_epNum          ,//Physical Endpoint number
   input wire                 sepr2eptd_reqData        ,//Request signal
   input wire                 sepr2eptd_updtReq        ,//Update request
   input wire [32       -1:0] sepr2eptd_rdPtr          ,//Wirte pointer value to be updated
   
   
   output wire                eptd2sepr_ReqErr         ,//OUT Request error indication //TODO all request error to be updated
   output wire [32       -1:0]eptd2sepr_startAddr      ,//Endpoint Start Address
   output wire [32       -1:0]eptd2sepr_endAddr        ,//Endpoint End Address
   output wire [32       -1:0]eptd2sepr_rdPtr          ,//Endpoint Read pointer
   output wire [32       -1:0]eptd2sepr_wrPtr          ,//Endpoint Write pointer
   output wire                eptd2sepr_lastOp         ,//Last operation
   output wire                eptd2sepr_updtDn         ,//Return status signal
   output wire [PKTCNTWD-1 :0]eptd2sepr_fullPktCnt    

   );
   
         wire [32-1             :0] eptd2cmd_rdData_1        ;
         wire                       cmdIf_ack_1              ;
         wire                       cmdIf_ack_2              ;
         wire                       epcrCmdUpdt              ;
         wire       [17         :0] epcrDataIn               ;
         wire       [17         :0] epcrDataOut              ;
         wire                       epctCmdUpdt              ;
         wire       [17         :0] epctDataIn               ;
         wire       [17         :0] epctDataOut              ;
         wire                       epcrEnuCmdEn             ;
         wire                       epcrStall                ;
         wire                       epcrRwCtlrType           ;
         wire                       epctEnuCmdEn             ;
         wire                       epctStall                ;
         wire                       epctRwCtlrType           ;
         wire                       peEnHost                 ;
         wire                       peEnOTGTrans             ;
         wire                       peDevHalt                ;
         wire                       seprRead                 ;
         wire                       seprUpdt                 ;
         wire      [11          :0] seprDataIn               ;
         wire      [11          :0] seprDataOut              ;
         wire                       septWrite                ;
         wire                       septDisFrag              ;
         wire                       septUpdt                 ;
         wire       [30         :0] septDataIn               ;
         wire       [30         :0] septDataOut              ;
         wire                       pdDataBus                ;
         wire                       paTokenValid             ;
         wire                       paDataBus                ;
         wire [31               :0] reg2cmd_rdData           ; 
         wire                       cmd2reg_wrReq            ; 
         wire                       cmd2reg_rdReq            ;
         wire [31               :0] cmd2reg_wrData           ; 
         wire [31               :0] cmd2reg_addr             ; 
         wire [32-1             :0] cmd2eptd_addr            ; 
         wire [32-1             :0] cmd2eptd_wrData          ; 
         wire                       cmd2eptd_wrReq           ; 
         wire                       cmdIf_wrData_ack_2       ;
         wire                       cmdIf_wrData_ack_1       ;
         wire                       cmdIf_rdData_ack_1       ;
         wire                       cmdIf_rdData_ack_2       ;
         wire  [31              :0] cmdIf_rdData_2           ;
         wire  [31              :0] cmdIf_rdData_1           ;
         wire  [15              :0] epcrDescLen              ;
         wire  [1               :0] epcrACTOut               ; 
         wire  [15              :0] epctDescLen              ;
         wire  [1               :0] epctACTOut               ; 
         wire  [1               :0] seprTStatus              ;
         wire  [3               :0] seprReadCount            ;
         wire                       sctrltxlistMode          ;
         wire  [4               :0] sctrlRxfullPktCnt        ; 
         wire  [4               :0] sctrlTxfullPktCnt        ; 
         wire                       sctrlrxlistMode          ;
         wire  [19              :0] septLen                  ;
         wire  [1               :0] septTStatus              ;
         wire  [3               :0] septFragcnt              ;
         wire  [31              :0] epcrsetupData            ; 
         wire                       epcrsetupRegIndex        ; 
         wire                       epcrsetupWrReq           ; 
         wire[32                :0] epcrsetupDataIn          ;
         wire[32                :0] epcrsetupDataOut         ;
         wire                       epcrBufFull              ;
         wire                       epcrZlpRcvd              ;
         wire                       epcrSetpRcvd             ;
         wire                       epcrDpRcvd               ;
         wire                       epctBufEmpty             ; 
         wire                       epctZlpSent              ; 
         wire                       epctDpSend               ; 
         wire                       petransSent              ;
         wire                       peclrCmdReg              ;
         wire                       sctrlRxempty             ;
         wire                       sctrlTxfull              ;
         wire                       porfsmIntr               ; 
         wire                       porresumeCompleted       ; 
         wire                       porresumeDetected        ; 
         wire                       porresetCompleted        ; 
         wire                       porresetDetected         ; 
         wire                       porsusDetected           ; 
         wire [20     -1:0]         regtimerStVal            ; 
         wire                       regldTimerStVal          ;
         wire [11     -1:0]         frmCntrframeCount        ;
         wire                       frmCntrsofSent           ;
         wire                       frmCntrsofRcvd           ;
         wire                       frmCntrframeCntVl        ;
         wire                       frmCntreof1Hit           ;

   generate begin
      if ( SYS_CORE_SYNC == 0) begin

      assign cmdIf_ack        = ((cmdIf_addr >= START_EPT_HADDR) && (cmdIf_addr <=END_EPT_HADDR)) ? cmdIf_ack_2        : cmdIf_ack_1        ;   
      assign cmdIf_wrData_ack = ((cmdIf_addr >= START_EPT_HADDR) && (cmdIf_addr <=END_EPT_HADDR)) ? cmdIf_wrData_ack_2 : cmdIf_wrData_ack_1 ;
      assign cmdIf_rdData_ack = ((cmdIf_addr >= START_EPT_HADDR) && (cmdIf_addr <=END_EPT_HADDR)) ? cmdIf_rdData_ack_2 : cmdIf_rdData_ack_1 ;
      assign cmdIf_rdData     = ((cmdIf_addr >= START_EPT_HADDR) && (cmdIf_addr <=END_EPT_HADDR)) ? cmdIf_rdData_2     : cmdIf_rdData_1     ;



      /********************************************************************/
      // register block interface
      /********************************************************************/

         uctl_cmdIfReg i_cmdIfReg    (
            .sys_clk                   (uctl_SysClk                ),
            .sysRst_n                  (uctl_SysRst_n              ),
            .sw_rst                    (1'b0                       ),
            .cmdIf_trEn			         (cmdIf_trEn			          ),
            .cmdIf_req			         (cmdIf_req			          ),
            .cmdIf_addr			         (cmdIf_addr			          ),
            .cmdIf_wrRd			         (cmdIf_wrRd			          ),
            .cmdIf_ack			         (cmdIf_ack_1 		          ),
            .cmdIf_wrData_req	         (cmdIf_wrData_req	          ),
            .cmdIf_wrData		         (cmdIf_wrData		          ),
            .cmdIf_wrData_ack	         (cmdIf_wrData_ack_1         ),
            .cmdIf_rdData_req	         (cmdIf_rdData_req	          ),
            .cmdIf_rdData_ack	         (cmdIf_rdData_ack_1         ),
            .cmdIf_rdData		         (cmdIf_rdData_1             ),
            .reg2cmd_rdData	         (reg2cmd_rdData	          ),
            .cmd2reg_wrReq		         (cmd2reg_wrReq		          ),
            .cmd2reg_rdReq		         (cmd2reg_rdReq		          ),
            .cmd2reg_wrData	         (cmd2reg_wrData	          ),
            .cmd2reg_addr		         (cmd2reg_addr		          )
         );

         uctl_registerBlock #(
           .ADDR_SIZE                   (32                        ), 
           .DATA_SIZE                   (32                        )
           )i_registerBlock (   
           .uctl_SysClk                 (uctl_SysClk               ),
           .uctl_SysRst_n               (uctl_SysRst_n             ),  
           .cmd2reg_addr                (cmd2reg_addr              ),  
           .cmd2reg_wrData              (cmd2reg_wrData            ),  
           .cmd2reg_wrReq               (cmd2reg_wrReq             ),  
           .cmd2reg_rdReq               (cmd2reg_rdReq             ),  
           .reg2cmd_rdData              (reg2cmd_rdData            ),  
           .reg2sepr_sWrAddr            (reg2sepr_sWrAddr          ), 
           .reg2sepr_dmaMode            (reg2sepr_dmaMode          ),
           .reg2sept_dmaMode            (reg2sept_dmaMode          ), 
           .reg2cmdIf_memSegAddr        (reg2cmdIf_memSegAddr      ),
           .reg2epc_setupLen            (reg2epc_setupLen          ),
           .reg2sept_sRdAddr            (reg2sept_sRdAddr          ),  
           .reg2epcr_enuCmdEn           (epcrEnuCmdEn              ),    
           .reg2epcr_EnuAct             (reg2epcr_EnuAct           ),    
           .reg2epcr_descLen            (reg2epcr_descLen          ),    
           .reg2epcr_descAddr           (reg2epcr_descAddr         ),    
           .reg2epcr_stall              (epcrStall                 ),    
           .reg2epcr_rwCtlrType         (epcrRwCtlrType            ),    
           .epcr2reg_enuActOut          (epcrACTOut                ),    
           .epcr2reg_enuCmdUpdt         (epcrCmdUpdt               ),    
           .epcr2reg_descLenUpdt        (epcrDescLen               ),
           .epcr2reg_setupData          (epcrsetupData             ),
           .epcr2reg_setupRegIndex      (epcrsetupRegIndex         ), 
           .epcr2reg_setupWrReq         (epcrsetupWrReq            ),
           .epcr2reg_bufFull            (epcrBufFull               ), 
           .epcr2reg_zlpRcvd            (epcrZlpRcvd               ), 
           .epcr2reg_setupRcvd          (epcrSetpRcvd              ), 
           .epcr2reg_dpRcvd             (epcrDpRcvd                ),     
           .reg2epct_enuCmdEn           (epctEnuCmdEn              ),    
           .reg2epct_EnuAct             (reg2epct_EnuAct           ),    
           .reg2epct_descLen            (reg2epct_descLen          ),    
           .reg2epct_descAddr           (reg2epct_descAddr         ),    
           .reg2epct_stall              (epctStall                 ),    
           .reg2epct_rwCtlrType         (epctRwCtlrType            ),    
           .epct2reg_enuActOut          (epctACTOut                ),    
           .epct2reg_enuCmdUpdt         (epctCmdUpdt               ),    
           .epct2reg_descLenUpdt        (epctDescLen               ),
           .epct2reg_bufEmpty           (epctBufEmpty              ), 
           .epct2reg_zlpSent            (epctZlpSent               ), 
           .epct2reg_dpSend             (epctDpSend                ),    
           .reg2pe_enHost               (peEnHost                  ),    
           .reg2pe_enOTGTrans           (peEnOTGTrans              ),    
           .reg2pe_epNum                (reg2pe_epNum              ),    
           .reg2pe_devHalt              (peDevHalt                 ),    
           .reg2pe_usbMode              (reg2pe_usbMode            ),
           .por2reg_fsmIntr             (porfsmIntr                ), 
           .por2reg_resumeCompleted     (porresumeCompleted        ), 
           .por2reg_resumeDetected      (porresumeDetected         ), 
           .por2reg_resetCompleted      (porresetCompleted         ), 
           .por2reg_resetDetected       (porresetDetected          ), 
           .por2reg_susDetected         (porsusDetected            ), 
           .reg2pe_tokenType            (reg2pe_tokenType          ),  
           .pe2reg_clrCmdReg            (peclrCmdReg               ), 
           .pe2reg_transSent            (petransSent               ),  
           .reg2sctrlRx_rd              (seprRead                  ),    
           .reg2sctrlRx_epNum           (reg2sctrlRx_epNum         ),    
           .sctrlRx2reg_status          (seprTStatus               ),
           .sctrlRx2reg_rdCnt           (seprReadCount             ),
           .reg2sctrlRx_rdCount         (reg2sctrlRx_rdCount       ),
           .sctrlRx2reg_updtRdBuf       (seprUpdt                  ),
           .reg2sctrlTx_wrPktLength     (reg2sctrlTx_wrPktLength   ), 
           .reg2sctrlTx_epNum           (reg2sctrlTx_epNum         ),
           .reg2sctrlTx_wr              (septWrite                 ),
           .reg2sctrlTx_disFrag         (septDisFrag               ),    
           .sctrlTx2reg_length          (septLen                   ),
           .sctrlTx2reg_status          (septTStatus               ),      
           .sctrlTx2reg_fragCnt         (septFragcnt               ),      
           .sctrlTx2reg_updt            (septUpdt                  ),      
           .reg2pd_dataBus16_8          (pdDataBus                 ),      
           .reg2pd_devId                (reg2pd_devId              ),      
           .reg2pa_tokenValid           (paTokenValid              ), 
           .reg2pa_tokenType            (reg2pa_tokenType          ), 
           .reg2pa_epNum                (reg2pa_epNum              ), 
           .reg2pa_devID                (reg2pa_devID              ), 
           .reg2pa_frameNum             (reg2pa_frameNum           ), 
           .reg2pa_dataBus16_8          (paDataBus                 ),
           .sctrlRx2reg_fullPktCnt      (sctrlRxfullPktCnt         ),
           .reg2sctrlRx_listMode        (sctrlrxlistMode           ),
           .sctrlTx2reg_fullPktCnt      (sctrlTxfullPktCnt         ),
           .reg2sctrlTx_listMode        (sctrltxlistMode           ),
           .sctrlRx2reg_empty           (sctrlRxempty              ),
           .sctrlTx2reg_full            (sctrlTxfull               ),
           .reg2frmCntr_upCntMax        (reg2frmCntr_upCntMax      ), 
           .reg2frmCntr_timerCorr       (reg2frmCntr_timerCorr     ),
           .frmCntr2reg_frameCount      (frmCntrframeCount         ),
           .frmCntr2reg_sofSent         (frmCntrsofSent            ),
           .frmCntr2reg_sofRcvd         (frmCntrsofRcvd            ),
           .reg2frmCntr_eof1            (reg2frmCntr_eof1          ),
           .reg2frmCntr_eof2            (reg2frmCntr_eof2          ),
           .reg2frmCntr_enAutoSof       (reg2frmCntr_enAutoSof     ),
           .reg2frmCntr_autoLd          (reg2frmCntr_autoLd        ),
           .reg2frmCntr_timerStVal      (regtimerStVal             ),
           .reg2frmCntr_ldTimerStVal    (regldTimerStVal           ),
           .frmCntr2reg_eof1Hit         (frmCntreof1Hit            ),
           .frmCntr2reg_frameCntVl      (frmCntrframeCntVl         ),
           .pe2reg_remoteWakeUp         (pe2reg_remoteWakeUp       ),            
           .uctl_powerDown              (uctl_powerDown            ),
           .uctl_glitchFilterCount      (uctl_glitchFilterCount    ),
           .pe2reg_lpmRcvd              (pe2reg_lpmRcvd            ),
           .intrReq                     (intrReq                   )
         );

   // pulse stretcher and synchronizer
   //epcr
         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (18                          ) 
           ) i_epcrCmdUpdt (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseIn                   ( epcr2reg_enuCmdUpdt        ), 
           .pulseOut                  ( epcrCmdUpdt                ),
           .dataIn                    ( epcrDataIn                 ),
           .dataOut                   ( epcrDataOut                ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_epcrZlpRcvd (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseIn                   ( epcr2reg_zlpRcvd           ), 
           .pulseOut                  ( epcrZlpRcvd                ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );
         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_epcrSetpRcvd (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseIn                   ( epcr2reg_setupRcvd         ), 
           .pulseOut                  ( epcrSetpRcvd               ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     )  
         );
         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_epcrDpRcvd (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseIn                   ( epcr2reg_dpRcvd            ), 
           .pulseOut                  ( epcrDpRcvd                 ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_synchronizer i_epcrEnuCmdEn(
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataOut                  ( reg2epcr_enuCmdEn          ),       
            .dataIn                   ( epcrEnuCmdEn               )
           );

         uctl_synchronizer i_epcrBufFul(
            .clk                      ( uctl_SysClk                ), 
            .reset                    ( uctl_SysRst_n              ), 
            .dataOut                  ( epcrBufFull                ),       
            .dataIn                   ( epcr2reg_bufFull           )
           );

         uctl_synchronizer i_epcrStall(
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataOut                  ( reg2epcr_stall             ),       
            .dataIn                   ( epcrStall                  )
           );

         uctl_synchronizer i_epcrRwCtlrType(
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataOut                  ( reg2epcr_rwCtlrType        ),       
            .dataIn                   ( epcrRwCtlrType             )
           );

   assign epcrDataIn     =  {epcr2reg_enuActOut , epcr2reg_descLenUpdt}; 
   assign {epcrACTOut,epcrDescLen}          = epcrDataOut ;

         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (33                          ) 
           ) i_epcrSetupCmd (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseIn                   ( epcr2reg_setupWrReq        ), 
           .pulseOut                  ( epcrsetupWrReq             ),
           .dataIn                    ( epcrsetupDataIn            ),
           .dataOut                   ( epcrsetupDataOut           ) 
         );

   assign epcrsetupDataIn ={epcr2reg_setupData,epcr2reg_setupRegIndex};
   assign {epcrsetupData,epcrsetupRegIndex} = epcrsetupDataOut       ;

   //epct

         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_epctZlpSent (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseIn                   ( epct2reg_zlpSent           ), 
           .pulseOut                  ( epctZlpSent                ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_epctDpSend (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseIn                   ( epct2reg_dpSend            ), 
           .pulseOut                  ( epctDpSend                 ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );
         uctl_synchronizer i_epctBufEmpty(
            .clk                      ( uctl_SysClk                ), 
            .reset                    ( uctl_SysRst_n              ), 
            .dataOut                  ( epctBufEmpty               ),       
            .dataIn                   ( epct2reg_bufEmpty          )
           );

         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (18                          ) 
           ) i_epctCmdUpdt (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseIn                   ( epct2reg_enuCmdUpdt        ), 
           .pulseOut                  ( epctCmdUpdt                ),
           .dataIn                    ( epctDataIn                 ),
           .dataOut                   ( epctDataOut                ) 
         );

   assign epctDataIn  =  {epct2reg_enuActOut , epct2reg_descLenUpdt}; 
   assign {epctACTOut,epctDescLen}          = epctDataOut           ;

         uctl_synchronizer i_epctEnuCmdEn(
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataOut                  ( reg2epct_enuCmdEn          ),       
            .dataIn                   ( epctEnuCmdEn               )
           );

         uctl_synchronizer i_epctStall(
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataOut                  ( reg2epct_stall             ),       
            .dataIn                   ( epctStall                  )
           );

         uctl_synchronizer i_epctRwCtlrType(
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataOut                  ( reg2epct_rwCtlrType        ),       
            .dataIn                   ( epctRwCtlrType             )
           );

   // protocol engine
         uctl_synchronizer i_peEnHost(
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataOut                  ( reg2pe_enHost              ),       
            .dataIn                   ( peEnHost                   )
           );

         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_peEnOTGTrans (
           .clock1Rst_n               ( uctl_SysRst_n              ), 
           .clock1                    ( uctl_SysClk                ), 
           .clock2                    ( core_clk                   ), 
           .clock2Rst_n               ( uctl_rst_n                 ), 
           .pulseOut                  ( reg2pe_enOTGTrans          ), 
           .pulseIn                   ( peEnOTGTrans               ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_peclrCmdReg (
           .clock1Rst_n               ( uctl_SysRst_n              ), 
           .clock1                    ( uctl_SysClk                ), 
           .clock2                    ( core_clk                   ), 
           .clock2Rst_n               ( uctl_rst_n                 ), 
           .pulseOut                  ( peclrCmdReg                ), 
           .pulseIn                   ( pe2reg_clrCmdReg           ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_synchronizer i_peDevHalt(
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataOut                  ( reg2pe_devHalt             ),       
            .dataIn                   ( peDevHalt                  )
           );

         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_petransSent (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseIn                   ( pe2reg_transSent           ), 
           .pulseOut                  ( petransSent                ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

   //system controller Rx
         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_seprRead (
           .clock1Rst_n               ( uctl_SysRst_n              ), 
           .clock1                    ( uctl_SysClk                ), 
           .clock2                    ( core_clk                   ), 
           .clock2Rst_n               ( uctl_rst_n                 ), 
           .pulseOut                  ( reg2sctrlRx_rd             ), 
           .pulseIn                   ( seprRead                   ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );


         uctl_synchronizer i_sctrlRxlistMode (
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataIn                   ( sctrlrxlistMode            ),       
            .dataOut                  ( reg2sctrlRx_listMode       )
           );


         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (11                          ) 
           ) i_seprUpdt (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseIn                   ( sctrlRx2reg_updtRdBuf      ), 
           .pulseOut                  ( seprUpdt                   ),
           .dataIn                    ( seprDataIn                 ),
           .dataOut                   ( seprDataOut                ) 
         );

        uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_sctrlRxempty (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseOut                  ( sctrlRxempty               ), 
           .pulseIn                   ( sctrlRx2reg_empty          ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

   assign seprDataIn  = {sctrlRx2reg_status , sctrlRx2reg_rdCnt,sctrlRx2reg_fullPktCnt};
   assign {seprTStatus,seprReadCount,sctrlRxfullPktCnt}       = seprDataOut ;

   // system controller tx              

         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_septWrite (
           .clock1Rst_n               ( uctl_SysRst_n              ), 
           .clock1                    ( uctl_SysClk                ), 
           .clock2                    ( core_clk                   ), 
           .clock2Rst_n               ( uctl_rst_n                 ), 
           .pulseOut                  ( reg2sctrlTx_wr             ), 
           .pulseIn                   ( septWrite                  ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_synchronizer i_sctrlTxlistMode (
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataIn                   ( sctrltxlistMode            ),       
            .dataOut                  ( reg2sctrlTx_listMode       )
           );

         uctl_synchronizer i_septDisFrag(
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataOut                  ( reg2sctrlTx_disFrag        ),       
            .dataIn                   ( septDisFrag                )
           );


         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_sctrlTxfull (
          .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseOut                  ( sctrlTxfull                ), 
           .pulseIn                   ( sctrlTx2reg_full           ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (31                          ) 
           ) i_septUpdt (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseIn                   ( sctrlTx2reg_updt           ), 
           .pulseOut                  ( septUpdt                   ),
           .dataIn                    ( septDataIn                 ),
           .dataOut                   ( septDataOut                ) 
         );
   assign septDataIn  = {sctrlTx2reg_length,sctrlTx2reg_status,sctrlTx2reg_fragCnt,sctrlTx2reg_fullPktCnt};
   assign {septLen,septTStatus,septFragcnt,sctrlTxfullPktCnt} = septDataOut ;

   // packet decoder        
         uctl_synchronizer i_pdDataBus(
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataOut                  ( reg2pd_dataBus16_8         ),       
            .dataIn                   ( pdDataBus                  )
           );
         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_pdlpmRcvd (
           .clock1                    ( core_clk                   ), 
           .clock1Rst_n               ( uctl_rst_n                 ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .clock2                    ( uctl_SysClk                ), 
           .pulseOut                  ( pdlpmRcvd                  ), 
           .pulseIn                   ( pe2reg_lpmRcvd             ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );
   //  packet assembler 

         uctl_pulsestretch #(
           .BYPASS                    (SYS_CORE_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_paTokenValid (
           .clock1Rst_n               ( uctl_SysRst_n              ), 
           .clock1                    ( uctl_SysClk                ), 
           .clock2                    ( core_clk                   ), 
           .clock2Rst_n               ( uctl_rst_n                 ), 
           .pulseOut                  ( reg2pa_tokenValid          ), 
           .pulseIn                   ( paTokenValid               ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_synchronizer i_paDataBus(
            .clk                      ( core_clk                   ), 
            .reset                    ( uctl_rst_n                 ), 
            .dataOut                  ( reg2pa_dataBus16_8         ),       
            .dataIn                   ( paDataBus                  )
           );

   // power on reset interrupt signals
   
         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porresumeCompleted (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porresumeCompleted         ), 
           .pulseIn                   ( por2reg_resumeCompleted    ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porresumeDetected (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porresumeDetected          ), 
           .pulseIn                   ( por2reg_resumeDetected     ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porresetCompleted (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porresetCompleted          ), 
           .pulseIn                   ( por2reg_resetCompleted     ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porfsmIntr (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porfsmIntr                 ), 
           .pulseIn                   ( por2reg_fsmIntr            ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porresetDetectedr (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porresetDetected           ), 
           .pulseIn                   ( por2reg_resetDetected      ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porsusDetected (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porsusDetected             ), 
           .pulseIn                   ( por2reg_susDetected        ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );
  
   // sof interface      

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_frmCntrsofSent (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( frmCntrsofSent             ), 
           .pulseIn                   ( frmCntr2reg_sofSent        ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_frmCntrsofRcvd (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( frmCntrsofRcvd             ), 
           .pulseIn                   ( frmCntr2reg_sofRcvd        ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_frmCntreof1Hit (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( frmCntreof1Hit             ), 
           .pulseIn                   ( frmCntr2reg_eof1Hit        ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );


         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (11                          ) 
           ) i_frmCntrframeCntVl (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( frmCntrframeCntVl          ), 
           .pulseIn                   ( frmCntr2reg_frameCntVl     ),
           .dataIn                    ( frmCntr2reg_frameCount     ),
           .dataOut                   ( frmCntrframeCount          ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (20                          ) 
           ) i_regldTimerStVal (
           .clock2Rst_n               ( uctl_PhyRst_n              ), 
           .clock2                    ( uctl_PhyClk                ), 
           .clock1                    ( uctl_SysClk                ), 
           .clock1Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( reg2frmCntr_ldTimerStVal   ), 
           .pulseIn                   ( regldTimerStVal            ),
           .dataIn                    ( regtimerStVal              ),
           .dataOut                   ( reg2frmCntr_timerStVal     ) 
         );

        uctl_cmd2eptdinf i_cmd2eptdinf(
           .sysRst_n                  ( uctl_SysRst_n              ), 
           .sys_clk                   ( uctl_SysClk                ), 
           .core_clk                  ( core_clk                   ), 
           .uctl_rst_n                ( uctl_rst_n                 ), 
           .cmdIf_trEn                ( cmdIf_trEn                 ), 
           .cmdIf_req                 ( cmdIf_req                  ), 
           .cmdIf_addr                ( cmdIf_addr                 ), 
           .cmdIf_wrRd                ( cmdIf_wrRd                 ), 
           .cmdIf_ack                 ( cmdIf_ack_2                ), 
           .cmdIf_wrData_req          ( cmdIf_wrData_req           ), 
           .cmdIf_wrData              ( cmdIf_wrData               ), 
           .cmdIf_wrData_ack          ( cmdIf_wrData_ack_2         ), 
           .cmdIf_rdData_req          ( cmdIf_rdData_req           ), 
           .cmdIf_rdData_ack          ( cmdIf_rdData_ack_2         ), 
           .cmdIf_rdData              ( cmdIf_rdData_2             ), 
           .eptd2cmd_rdData           ( eptd2cmd_rdData_1          ), 
           .cmd2eptd_wrReq            ( cmd2eptd_wrReq             ), 
           .cmd2eptd_wrData           ( cmd2eptd_wrData            ), 
           .cmd2eptd_addr             ( cmd2eptd_addr              ) 
        );

         uctl_eptd #(
         .ADDR_SIZE          (32),
         .DATA_SIZE          (32)
          )i_endpointdata           (
            .sw_rst                    (1'b0                       ),
            .core_clk                  (core_clk                   ),
            .uctl_rst_n                (uctl_rst_n                 ),
            .cmd2eptd_addr             (cmd2eptd_addr              ), 
            .cmd2eptd_wrData           (cmd2eptd_wrData            ), 
            .cmd2eptd_wrReq            (cmd2eptd_wrReq             ), 
            .eptd2cmd_rdData           (eptd2cmd_rdData_1          ), 
            .epcr2eptd_epNum           (epcr2eptd_epNum            ), 
            .epcr2eptd_reqData         (epcr2eptd_reqData          ), 
            .epcr2eptd_updtReq         (epcr2eptd_updtReq          ), 
            .epcr2eptd_wrPtrOut        (epcr2eptd_wrPtrOut         ), 
            .epcr2eptd_nxtDataPid      (epcr2eptd_nxtDataPid       ), 
            .eptd2epcr_wrReqErr        (eptd2epcr_wrReqErr         ), 
            .eptd2epcr_startAddr       (eptd2epcr_startAddr        ), 
            .pe2eptd_intPid            (pe2eptd_intPid             ), 
            .eptd2epcr_endAddr         (eptd2epcr_endAddr          ), 
            .eptd2epcr_rdPtr           (eptd2epcr_rdPtr            ), 
            .eptd2epcr_wrPtr           (eptd2epcr_wrPtr            ), 
            .eptd2epcr_lastOp          (eptd2epcr_lastOp           ), 
            .eptd2epcr_exptDataPid     (eptd2epcr_exptDataPid      ), 
            .eptd2epcr_updtDn          (eptd2epcr_updtDn           ), 
            .eptd2epcr_wMaxPktSize     (eptd2epcr_wMaxPktSize      ), 
            .eptd2epcr_epType          (eptd2epcr_epType           ),
            .eptd2epcr_epTrans         (eptd2epcr_epTrans          ), 
            .eptd2epcr_epHalt          (eptd2epcr_epHalt           ), 
            .epct2eptd_epNum           (epct2eptd_epNum            ), 
            .epct2eptd_reqData         (epct2eptd_reqData          ), 
            .epct2eptd_updtReq         (epct2eptd_updtReq          ), 
            .epct2eptd_rdPtrOut        (epct2eptd_rdPtrOut         ), 
            .epct2eptd_nxtExpDataPid   (epct2eptd_nxtExpDataPid    ), 
            .eptd2epct_reqErr          (eptd2epct_reqErr           ), 
            .eptd2epct_zLenPkt         (eptd2epct_zLenPkt          ), 
            .eptd2epct_startAddr       (eptd2epct_startAddr        ), 
            .eptd2epct_endAddr         (eptd2epct_endAddr          ), 
            .eptd2epct_rdPtr           (eptd2epct_rdPtr            ), 
            .eptd2epct_wrPtr           (eptd2epct_wrPtr            ), 
            .eptd2epct_lastOp          (eptd2epct_lastOp           ), 
            .eptd2epct_exptDataPid     (eptd2epct_exptDataPid      ), 
            .eptd2epct_updtDn          (eptd2epct_updtDn           ), 
            .eptd2epct_epTrans         (eptd2epct_epTrans          ), 
            .eptd2epct_epType          (eptd2epct_epType           ),
            .eptd2epct_epHalt          (eptd2epct_epHalt           ), 
            .sept2eptd_epNum           (sept2eptd_epNum            ), 
            .sept2eptd_reqData         (sept2eptd_reqData          ), 
            .sept2eptd_updtReq         (sept2eptd_updtReq          ), 
            .sept2eptd_wrPtrOut        (sept2eptd_wrPtrOut         ), 
            .eptd2sept_reqErr          (eptd2sept_reqErr           ), 
            .eptd2sept_startAddr       (eptd2sept_startAddr        ), 
            .eptd2sept_endAddr         (eptd2sept_endAddr          ), 
            .eptd2sept_rdPtr           (eptd2sept_rdPtr            ), 
            .eptd2sept_wrPtr           (eptd2sept_wrPtr            ), 
            .eptd2sept_updtDn          (eptd2sept_updtDn           ), 
            .eptd2sept_bSize           (eptd2sept_bSize            ), 
            .eptd2sept_lastOp          (eptd2sept_lastOp           ), 
            .sepr2eptd_epNum           (sepr2eptd_epNum            ),
            .sepr2eptd_reqData         (sepr2eptd_reqData          ),
            .sepr2eptd_updtReq         (sepr2eptd_updtReq          ),
          //.epcr2eptd_setEphalt      (epcr2eptd_setEphalt         ),
            .sepr2eptd_rdPtr           (sepr2eptd_rdPtr            ),
            .eptd2sepr_startAddr       (eptd2sepr_startAddr        ),
            .eptd2sepr_endAddr         (eptd2sepr_endAddr          ),
            .eptd2sepr_rdPtr           (eptd2sepr_rdPtr            ),
            .eptd2sepr_wrPtr           (eptd2sepr_wrPtr            ),
            .eptd2sepr_lastOp          (eptd2sepr_lastOp           ),
            .eptd2sepr_updtDn          (eptd2sepr_updtDn           ),  
            .eptd2sepr_ReqErr          (eptd2sepr_ReqErr           ),
            .pd2eptd_statusStrobe      (pd2eptd_statusStrobe       ),
            .pd2eptd_crc5              (pd2eptd_crc5               ),
            .pd2eptd_pid               (pd2eptd_pid                ),
            .pe2eptd_initIsoPid        (pe2eptd_initIsoPid         ),
            .pd2eptd_err               (pd2eptd_err                ),      
            .pd2eptd_epNum             (pd2eptd_epNum              ),
            .eptd2pe_noTransPending    (eptd2pe_noTransPending     ),
            .eptd2sept_fullPktCnt      (eptd2sept_fullPktCnt       ),
            .eptd2sepr_fullPktCnt      (eptd2sepr_fullPktCnt       )
         );

      end
      else begin

   // power on reset interrupt signals
   
         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porresumeCompleted (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porresumeCompleted         ), 
           .pulseIn                   ( por2reg_resumeCompleted    ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porresumeDetected (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porresumeDetected          ), 
           .pulseIn                   ( por2reg_resumeDetected     ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porresetCompleted (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porresetCompleted          ), 
           .pulseIn                   ( por2reg_resetCompleted     ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porfsmIntr (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porfsmIntr                 ), 
           .pulseIn                   ( por2reg_fsmIntr            ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porresetDetectedr (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porresetDetected           ), 
           .pulseIn                   ( por2reg_resetDetected      ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_porsusDetected (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( porsusDetected             ), 
           .pulseIn                   ( por2reg_susDetected        ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

   // sof interface      

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_frmCntrsofSent (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( frmCntrsofSent             ), 
           .pulseIn                   ( frmCntr2reg_sofSent        ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_frmCntrsofRcvd (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( frmCntrsofRcvd             ), 
           .pulseIn                   ( frmCntr2reg_sofRcvd        ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (1                           ) 
           ) i_frmCntreof1Hit (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( frmCntreof1Hit             ), 
           .pulseIn                   ( frmCntr2reg_eof1Hit        ),
           .dataIn                    ( 1'b0                       ),
           .dataOut                   ( /*nc*/                     ) 
         );


         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (11                          ) 
           ) i_frmCntrframeCntVl (
           .clock1Rst_n               ( uctl_PhyRst_n              ), 
           .clock1                    ( uctl_PhyClk                ), 
           .clock2                    ( uctl_SysClk                ), 
           .clock2Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( frmCntrframeCntVl          ), 
           .pulseIn                   ( frmCntr2reg_frameCntVl     ),
           .dataIn                    ( frmCntr2reg_frameCount     ),
           .dataOut                   ( frmCntrframeCount          ) 
         );

         uctl_pulsestretch #(
           .BYPASS                    (CORE_PHY_SYNC               ),
           .DATA_WD                   (20                          ) 
           ) i_regldTimerStVal (
           .clock2Rst_n               ( uctl_PhyRst_n              ), 
           .clock2                    ( uctl_PhyClk                ), 
           .clock1                    ( uctl_SysClk                ), 
           .clock1Rst_n               ( uctl_SysRst_n              ), 
           .pulseOut                  ( reg2frmCntr_ldTimerStVal   ), 
           .pulseIn                   ( regldTimerStVal            ),
           .dataIn                    ( regtimerStVal              ),
           .dataOut                   ( reg2frmCntr_timerStVal     ) 
         );

         uctl_cmdIfReg i_cmdIfReg    (
            .sys_clk                   (uctl_SysClk                ),                                                       
            .sysRst_n                  (uctl_SysRst_n              ), 
            .sw_rst                    (1'b0                       ),                       
            .cmdIf_trEn			         (cmdIf_trEn			          ),            
            .cmdIf_req			         (cmdIf_req			          ),
            .cmdIf_addr			         (cmdIf_addr			          ),
            .cmdIf_wrRd			         (cmdIf_wrRd			          ),
            .cmdIf_ack			         (cmdIf_ack  		          ),
            .cmdIf_wrData_req	         (cmdIf_wrData_req	          ),
            .cmdIf_wrData		         (cmdIf_wrData		          ),
            .cmdIf_wrData_ack	         (cmdIf_wrData_ack           ),
            .cmdIf_rdData_req	         (cmdIf_rdData_req	          ),
            .cmdIf_rdData_ack	         (cmdIf_rdData_ack           ),
            .cmdIf_rdData		         (cmdIf_rdData               ),
            .reg2cmd_rdData	         (reg2cmd_rdData	          ),
            .cmd2reg_wrReq		         (cmd2reg_wrReq		          ),
            .cmd2reg_rdReq		         (cmd2reg_rdReq		          ),
            .cmd2reg_wrData	         (cmd2reg_wrData	          ),
            .cmd2reg_addr		         (cmd2reg_addr		          ),
            .eptd2cmd_rdData	         (eptd2cmd_rdData_1          ),
            .cmd2eptd_wrReq	         (cmd2eptd_wrReq	          ),
            .cmd2eptd_wrData	         (cmd2eptd_wrData	          ),
            .cmd2eptd_addr             (cmd2eptd_addr              )
         );

         uctl_registerBlock #(
            .ADDR_SIZE                   (32                       ),        
            .DATA_SIZE                   (32                       )
            )i_registerBlock (   
            .uctl_SysClk                 (uctl_SysClk              ),
            .uctl_SysRst_n               (uctl_SysRst_n            ),  
            .cmd2reg_addr                (cmd2reg_addr             ),  
            .reg2sepr_dmaMode            (reg2sepr_dmaMode         ),
            .reg2sept_dmaMode            (reg2sept_dmaMode         ),
            .cmd2reg_wrData              (cmd2reg_wrData           ),  
            .cmd2reg_wrReq               (cmd2reg_wrReq            ),  
            .cmd2reg_rdReq               (cmd2reg_rdReq            ),  
            .reg2cmd_rdData              (reg2cmd_rdData           ),  
            .reg2sepr_sWrAddr            (reg2sepr_sWrAddr         ),  
            .sctrlRx2reg_empty           (sctrlRx2reg_empty        ),
            .sctrlTx2reg_full            (sctrlTx2reg_full         ),
            .reg2sept_sRdAddr            (reg2sept_sRdAddr         ),  
            .reg2epcr_enuCmdEn           (reg2epcr_enuCmdEn        ),    
            .reg2epcr_EnuAct             (reg2epcr_EnuAct          ),    
            .reg2epcr_descLen            (reg2epcr_descLen         ),    
            .epcr2reg_epNum              (epcr2eptd_epNum          ),//TODO async path not done need to confrom logic
            .reg2cmdIf_memSegAddr        (reg2cmdIf_memSegAddr     ),
            .reg2epcr_descAddr           (reg2epcr_descAddr        ),    
            .reg2epcr_stall              (reg2epcr_stall           ),    
            .reg2epcr_rwCtlrType         (reg2epcr_rwCtlrType      ), 
            .epcr2reg_bufFull            (epcr2reg_bufFull         ), 
            .epcr2reg_zlpRcvd            (epcr2reg_zlpRcvd         ), 
            .epcr2reg_setupRcvd          (epcr2reg_setupRcvd       ), 
            .epcr2reg_dpRcvd             (epcr2reg_dpRcvd          ),        
            .epcr2reg_enuActOut          (epcr2reg_enuActOut       ),    
            .epcr2reg_enuCmdUpdt         (epcr2reg_enuCmdUpdt      ),    
            .epcr2reg_descLenUpdt        (epcr2reg_descLenUpdt     ), 
            .epcr2reg_setupData          (epcr2reg_setupData       ),
            .epcr2reg_setupRegIndex      (epcr2reg_setupRegIndex   ), 
            .epcr2reg_setupWrReq         (epcr2reg_setupWrReq      ),   
            .reg2epct_enuCmdEn           (reg2epct_enuCmdEn        ),    
            .reg2epct_EnuAct             (reg2epct_EnuAct          ),    
            .reg2epct_descLen            (reg2epct_descLen         ),    
            .reg2epct_descAddr           (reg2epct_descAddr        ),    
            .reg2epct_stall              (reg2epct_stall           ),    
            .reg2epct_rwCtlrType         (reg2epct_rwCtlrType      ),    
            .epct2reg_epNum              (epct2eptd_epNum          ), //TODO async path not done need to confrom logic
            .reg2epc_setupLen            (reg2epc_setupLen         ),
            .epct2reg_enuActOut          (epct2reg_enuActOut       ),    
            .epct2reg_enuCmdUpdt         (epct2reg_enuCmdUpdt      ),    
            .epct2reg_descLenUpdt        (epct2reg_descLenUpdt     ),
            .epct2reg_bufEmpty           (epct2reg_bufEmpty        ), 
            .epct2reg_zlpSent            (epct2reg_zlpSent         ), 
            .epct2reg_dpSend             (epct2reg_dpSend          ),      
            .reg2pe_enHost               (reg2pe_enHost            ),    
            .reg2pe_enOTGTrans           (reg2pe_enOTGTrans        ),    
            .reg2pe_epNum                (reg2pe_epNum             ),    
            .reg2pe_devHalt              (reg2pe_devHalt           ),    
            .reg2pe_usbMode              (reg2pe_usbMode           ),
            .reg2pe_tokenType            (reg2pe_tokenType         ),    
            .pe2reg_clrCmdReg            (pe2reg_clrCmdReg         ),
            .pe2reg_transSent            (pe2reg_transSent         ),  
            .reg2sctrlRx_rd              (reg2sctrlRx_rd           ),     
            .reg2sctrlRx_epNum           (reg2sctrlRx_epNum        ),   
            .sctrlRx2reg_status          (sctrlRx2reg_status       ),
            .sctrlRx2reg_rdCnt           (sctrlRx2reg_rdCnt        ),
            .reg2sctrlRx_rdCount         (reg2sctrlRx_rdCount      ),
            .sctrlRx2reg_updtRdBuf       (sctrlRx2reg_updtRdBuf    ),
            .reg2sctrlTx_wrPktLength     (reg2sctrlTx_wrPktLength  ), 
            .reg2sctrlTx_epNum           (reg2sctrlTx_epNum        ),
            .reg2sctrlTx_wr              (reg2sctrlTx_wr           ),
            .reg2sctrlTx_disFrag         (reg2sctrlTx_disFrag      ),    
            .sctrlTx2reg_length          (sctrlTx2reg_length       ),
            .sctrlTx2reg_status          (sctrlTx2reg_status       ),      
            .sctrlTx2reg_fragCnt         (sctrlTx2reg_fragCnt      ),      
            .sctrlTx2reg_updt            (sctrlTx2reg_updt         ),      
            .reg2pd_dataBus16_8          (reg2pd_dataBus16_8       ),      
            .reg2pd_devId                (reg2pd_devId             ),      
            .reg2pa_tokenValid           (reg2pa_tokenValid        ), 
            .reg2pa_tokenType            (reg2pa_tokenType         ), 
            .reg2pa_epNum                (reg2pa_epNum             ), 
            .reg2pa_devID                (reg2pa_devID             ), 
            .reg2pa_frameNum             (reg2pa_frameNum          ), 
            .reg2pa_dataBus16_8          (reg2pa_dataBus16_8       ),
            .sctrlRx2reg_fullPktCnt      (sctrlRx2reg_fullPktCnt   ),
            .reg2sctrlRx_listMode        (reg2sctrlRx_listMode     ),
            .sctrlTx2reg_fullPktCnt      (sctrlTx2reg_fullPktCnt   ),
            .reg2sctrlTx_listMode        (reg2sctrlTx_listMode     ),
            .intrReq                     (intrReq                  ),
            .por2reg_fsmIntr             (porfsmIntr               ), 
            .por2reg_resumeCompleted     (porresumeCompleted       ), 
            .por2reg_resumeDetected      (porresumeDetected        ), 
            .por2reg_resetCompleted      (porresetCompleted        ), 
            .por2reg_resetDetected       (porresetDetected         ), 
            .por2reg_susDetected         (porsusDetected           ), 
            .reg2frmCntr_upCntMax        (reg2frmCntr_upCntMax     ), 
            .reg2frmCntr_timerCorr       (reg2frmCntr_timerCorr    ),
            .frmCntr2reg_frameCount      (frmCntrframeCount        ),
            .frmCntr2reg_sofSent         (frmCntrsofSent           ),
            .frmCntr2reg_sofRcvd         (frmCntrsofRcvd           ),
            .reg2frmCntr_eof1            (reg2frmCntr_eof1         ),
            .reg2frmCntr_eof2            (reg2frmCntr_eof2         ),
            .reg2frmCntr_enAutoSof       (reg2frmCntr_enAutoSof    ),
            .reg2frmCntr_autoLd          (reg2frmCntr_autoLd       ),
            .reg2frmCntr_timerStVal      (regtimerStVal            ),
            .reg2frmCntr_ldTimerStVal    (regldTimerStVal          ),
            .frmCntr2reg_eof1Hit         (frmCntreof1Hit           ),
            .frmCntr2reg_frameCntVl      (frmCntrframeCntVl        ),
            .uctl_powerDown              (uctl_powerDown           ),
            .uctl_glitchFilterCount      (uctl_glitchFilterCount   ),
            .pe2reg_remoteWakeUp         (pe2reg_remoteWakeUp      ),
            .pe2reg_lpmRcvd              (pe2reg_lpmRcvd           )
          
         );
         uctl_eptd #(
            .ADDR_SIZE                   (32                       ),
            .DATA_SIZE                   (32                       )
             )i_endpointdata             (
            .sw_rst                      (1'b0                     ),
            .core_clk                    (core_clk                 ),
            .uctl_rst_n                  (uctl_rst_n               ),
            .cmd2eptd_addr               (cmd2eptd_addr            ), 
            .cmd2eptd_wrData             (cmd2eptd_wrData          ), 
            .cmd2eptd_wrReq              (cmd2eptd_wrReq           ), 
            .eptd2cmd_rdData             (eptd2cmd_rdData_1        ), 
            .epcr2eptd_epNum             (epcr2eptd_epNum          ), 
            .epcr2eptd_reqData           (epcr2eptd_reqData        ), 
            .epcr2eptd_updtReq           (epcr2eptd_updtReq        ), 
            .epcr2eptd_wrPtrOut          (epcr2eptd_wrPtrOut       ), 
            .epcr2eptd_nxtDataPid        (epcr2eptd_nxtDataPid     ), 
            .epcr2eptd_dataFlush         (epcr2eptd_dataFlush      ), 
            .eptd2epcr_wrReqErr          (eptd2epcr_wrReqErr       ), 
            .eptd2epcr_startAddr         (eptd2epcr_startAddr      ),
            .pe2eptd_intPid              (pe2eptd_intPid           ), 
            .eptd2epcr_endAddr           (eptd2epcr_endAddr        ), 
            .eptd2epcr_rdPtr             (eptd2epcr_rdPtr          ), 
            .eptd2epcr_wrPtr             (eptd2epcr_wrPtr          ), 
            .eptd2epcr_lastOp            (eptd2epcr_lastOp         ), 
            .eptd2epcr_exptDataPid       (eptd2epcr_exptDataPid    ), 
            .eptd2epcr_updtDn            (eptd2epcr_updtDn         ), 
            .eptd2epcr_wMaxPktSize       (eptd2epcr_wMaxPktSize    ), 
            .eptd2epcr_epType            (eptd2epcr_epType         ),
            .eptd2epcr_epTrans           (eptd2epcr_epTrans        ), 
            .eptd2epcr_epHalt            (eptd2epcr_epHalt         ), 
            .epct2eptd_epNum             (epct2eptd_epNum          ), 
            .epct2eptd_reqData           (epct2eptd_reqData        ), 
            .epct2eptd_updtReq           (epct2eptd_updtReq        ), 
            .epct2eptd_rdPtrOut          (epct2eptd_rdPtrOut       ), 
            .epct2eptd_nxtExpDataPid     (epct2eptd_nxtExpDataPid  ), 
            .eptd2epct_reqErr            (eptd2epct_reqErr         ), 
            .epcr2eptd_setEphalt         (epcr2eptd_setEphalt      ),
            .eptd2epct_zLenPkt           (eptd2epct_zLenPkt        ), 
            .eptd2epct_startAddr         (eptd2epct_startAddr      ), 
            .eptd2epct_endAddr           (eptd2epct_endAddr        ), 
            .eptd2epct_rdPtr             (eptd2epct_rdPtr          ), 
            .eptd2epct_wrPtr             (eptd2epct_wrPtr          ), 
            .eptd2epct_lastOp            (eptd2epct_lastOp         ), 
            .eptd2epct_exptDataPid       (eptd2epct_exptDataPid    ), 
            .eptd2epct_updtDn            (eptd2epct_updtDn         ), 
            .eptd2epct_epTrans           (eptd2epct_epTrans        ), 
            .eptd2epct_epType            (eptd2epct_epType         ),
            .eptd2epct_epHalt            (eptd2epct_epHalt         ), 
            .sept2eptd_epNum             (sept2eptd_epNum          ), 
            .sept2eptd_reqData           (sept2eptd_reqData        ), 
            .sept2eptd_updtReq           (sept2eptd_updtReq        ), 
            .sept2eptd_wrPtrOut          (sept2eptd_wrPtrOut       ), 
            .eptd2sept_reqErr            (eptd2sept_reqErr         ), 
            .eptd2sept_startAddr         (eptd2sept_startAddr      ), 
            .eptd2sept_endAddr           (eptd2sept_endAddr        ), 
            .eptd2sept_rdPtr             (eptd2sept_rdPtr          ), 
            .pe2eptd_initIsoPid          (pe2eptd_initIsoPid       ),
            .eptd2sept_wrPtr             (eptd2sept_wrPtr          ), 
            .eptd2sept_updtDn            (eptd2sept_updtDn         ), 
            .eptd2sept_bSize             (eptd2sept_bSize          ), 
            .eptd2sept_lastOp            (eptd2sept_lastOp         ), 
            .sepr2eptd_epNum             (sepr2eptd_epNum          ),
            .sepr2eptd_reqData           (sepr2eptd_reqData        ),
            .sepr2eptd_updtReq           (sepr2eptd_updtReq        ),
            .sepr2eptd_rdPtr             (sepr2eptd_rdPtr          ),
            .eptd2sepr_startAddr         (eptd2sepr_startAddr      ),
            .eptd2sepr_endAddr           (eptd2sepr_endAddr        ),
            .eptd2sepr_rdPtr             (eptd2sepr_rdPtr          ),
            .eptd2sepr_wrPtr             (eptd2sepr_wrPtr          ),
            .eptd2sepr_lastOp            (eptd2sepr_lastOp         ),
            .eptd2sepr_updtDn            (eptd2sepr_updtDn         ),  
            .eptd2sepr_ReqErr            (eptd2sepr_ReqErr         ),
            .pd2eptd_statusStrobe        (pd2eptd_statusStrobe     ),
            .pd2eptd_crc5                (pd2eptd_crc5             ),
            .pd2eptd_pid                 (pd2eptd_pid              ),
            .pd2eptd_err                 (pd2eptd_err              ),      
            .pd2eptd_epNum               (pd2eptd_epNum            ),
            .eptd2pe_noTransPending      (eptd2pe_noTransPending   ),
            .eptd2sept_fullPktCnt        (eptd2sept_fullPktCnt     ),
            .eptd2sepr_fullPktCnt        (eptd2sepr_fullPktCnt     )
         );
	   end
   end
   endgenerate


endmodule
