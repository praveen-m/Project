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
// DATE		   	: Fri, 01 Mar 2013 12:31:06
// AUTHOR	      : Sanjeeva
// AUTHOR EMAIL	: sanjeeva.n@techvulcan.com
// FILE NAME		: uctl_registerBlock.v
// VERSION        : 0.4
//-------------------------------------------------------------------
/*//TODO
* Input reg2epcr_rwCtlrType to be updated
* reg2pe_enOTGTrans to be updated
* pd2reg_err to be updated.
*/
/* UPDATE 0.2
* all register have changed to 0.4 usb spec.
* all address is changed and parameterized.
* length of descripter is changed to 16-bits
* update 0.3
* added list mode for sept and sepr.
* interrupt signal added
* reg2cmdIf_memSegAddr signal added
* update 0.4
* interrupt status bits updated
*/
module  uctl_registerBlock 
#(   parameter      
   GLITCH_CNTR_WD = 4,
   `include "../rtl/uctl_regConfig.vh" 
   ) 
(
   // ---------------------------------------------
   // Global Signal
   // ---------------------------------------------
   input wire                uctl_SysClk              ,//System clock 
   input wire                uctl_SysRst_n            ,//System Reset

   // ---------------------------------------------
   // command interface
   // ---------------------------------------------
   input wire [ADDR_SIZE-1:0]cmd2reg_addr             ,//Address bus 
   input wire [DATA_SIZE-1:0]cmd2reg_wrData           ,//Data Input
   input wire                cmd2reg_wrReq            ,//Register write enable signal
   input wire                cmd2reg_rdReq            ,//Register read enable signal

   output reg [DATA_SIZE-1:0]reg2cmd_rdData           ,//Data out

   // ---------------------------------------------
   // AON Interface
   // ---------------------------------------------
   output wire                       uctl_powerDown         , //0: device is in not power down, 
                                                              //1: device is in power down mode           
   output wire [GLITCH_CNTR_WD -1:0] uctl_glitchFilterCount , //number of aon clock cycle for which linse state 
                                                                // should be stable to dtect a change
   // ---------------------------------------------
   // EPCR (endpoint controller rx)     
   // ---------------------------------------------
   output wire               reg2epcr_enuCmdEn        ,//Enumeration done using ENU_CMD_REG
   output wire[1          :0]reg2epcr_EnuAct          ,//Active status:
   output wire[15         :0]reg2epcr_descLen         ,//Length of descriptor data requested  
   output wire[ADDR_SIZE-1:0]reg2epcr_descAddr        ,//Starting address for the descriptor
   output wire               reg2epcr_stall           ,//enable stall for request 
   output wire               reg2epcr_rwCtlrType      ,//0: control read, 1: control write
   output wire[15         :0]reg2epc_setupLen         ,

   input wire [1          :0]epcr2reg_enuActOut       ,//Update value for the ACT field from endpoint
   input wire                epcr2reg_enuCmdUpdt      ,//Strobe signal to update ENU_CMD_REG
   input wire [15         :0]epcr2reg_descLenUpdt     ,//length of remaing transfer update cmd reg
   input wire [32       -1:0]epcr2reg_setupData       ,        
   input wire                epcr2reg_setupRegIndex   ,
   input wire                epcr2reg_setupWrReq      , 
   input wire                epcr2reg_bufFull         ,
   input wire                epcr2reg_zlpRcvd         ,
   input wire                epcr2reg_setupRcvd       ,
   input wire                epcr2reg_dpRcvd          ,
   input wire [3          :0]epcr2reg_epNum           ,
   // ---------------------------------------------
   // EPCT (endpoint controller tx)       
   // ---------------------------------------------
   output wire               reg2epct_enuCmdEn        ,//Enumeration done using ENU_CMD_REG
   output wire[1          :0]reg2epct_EnuAct          ,//Active status:
   output wire[15         :0]reg2epct_descLen         ,//Length of descriptor data requested    
   output wire[ADDR_SIZE-1:0]reg2epct_descAddr        ,//Starting address for the descriptor
   output wire               reg2epct_stall           ,//enable stall for request 
   output wire               reg2epct_rwCtlrType      ,//0: control read, 1: control write
                                                    
   input wire [1          :0]epct2reg_enuActOut       ,//Update value for the ACT field from endpoint
   input wire                epct2reg_enuCmdUpdt      ,//Strobe signal to update ENU_CMD_REG
   input wire [15         :0]epct2reg_descLenUpdt     ,//update this value of length
   input wire                epct2reg_bufEmpty        ,
   input wire                epct2reg_zlpSent         ,
   input wire                epct2reg_dpSend          ,
   input wire [3          :0]epct2reg_epNum           ,
   // ---------------------------------------------
   // protocol engine
   // ---------------------------------------------
   output wire               reg2pe_enHost            ,//0	: device mode, 1:host mode
   output reg                reg2pe_enOTGTrans        ,//OTG transfer started
   output wire[3          :0]reg2pe_epNum             ,//endpoint number in usb_trans_contrl register
   output wire               reg2pe_devHalt           ,//Device is halted if set
   output wire[3          :0]reg2pe_tokenType         ,//token type in usb_trans_contrl register  //TODO change to 4bit
   output wire[2          :0]reg2pe_usbMode           ,//usb mode (LS,HS,FS,SS)
   input  wire               pe2reg_transSent         ,
   input  wire               pe2reg_clrCmdReg         ,

   //----------------------------------------------
   // frame counter interface
   //----------------------------------------------
   output wire [20     -1:0] reg2frmCntr_upCntMax     , 
   output wire [4      -1:0] reg2frmCntr_timerCorr    , 
   output wire [10     -1:0] reg2frmCntr_eof1         , 
   output wire [8      -1:0] reg2frmCntr_eof2         , 
   output wire               reg2frmCntr_enAutoSof    , 
   output wire               reg2frmCntr_autoLd       , 
   output wire [20     -1:0] reg2frmCntr_timerStVal   ,   
   output reg                reg2frmCntr_ldTimerStVal ,  
   input  wire [11     -1:0] frmCntr2reg_frameCount   , 
   input  wire               frmCntr2reg_sofSent      , 
   input  wire               frmCntr2reg_sofRcvd      , 
   input  wire               frmCntr2reg_frameCntVl   , 
   input  wire               frmCntr2reg_eof1Hit      ,

   // -------------------------------------------
   // system controller rx
   // -------------------------------------------
   output reg                reg2sctrlRx_rd           ,//Read enable from register block interface
   output wire[3          :0]reg2sctrlRx_epNum        ,//Endpoint number
   output wire[3          :0]reg2sctrlRx_rdCount      ,//Number of packets to be read
   input  wire               sctrlRx2reg_updtRdBuf    ,//Update signal to update the register values
   input  wire[3          :0]sctrlRx2reg_rdCnt        ,//read counter for number of packets
   input  wire[1          :0]sctrlRx2reg_status       ,
   output wire[ADDR_SIZE-1:0]reg2sepr_sWrAddr         ,//32 bit write address in system memory
   input  wire [4       :0]  sctrlRx2reg_fullPktCnt   ,
   output wire               reg2sctrlRx_listMode     ,
   output wire [2        :0] reg2sepr_dmaMode         ,
   input wire                sctrlRx2reg_empty        ,

   //----------------------------------------------
   // system controller tx              
   //----------------------------------------------     

   output wire [19        :0]reg2sctrlTx_wrPktLength  ,//lenght of the pkt to transfered
   output wire [3         :0]reg2sctrlTx_epNum        ,//end Point number
   output reg                reg2sctrlTx_wr           ,//signal from system to write
   output wire               reg2sctrlTx_disFrag      ,//will disable fragmentation 
   input wire  [1         :0]sctrlTx2reg_status       ,
   input wire  [19        :0]sctrlTx2reg_length       ,//length of the orginal data pending
   input wire  [4         :0]sctrlTx2reg_fragCnt      ,//fragmentation count to be updated in register 
   input wire                sctrlTx2reg_updt         ,//update signal to update the register values
   output wire[ADDR_SIZE-1:0]reg2sept_sRdAddr         ,//32 bit read address in system memory
   input wire  [4       :0]  sctrlTx2reg_fullPktCnt   ,
   output wire               reg2sctrlTx_listMode     ,
   output wire [2        :0] reg2sept_dmaMode         ,
   input wire                sctrlTx2reg_full         ,

   //----------------------------------------------
   // packet decoder        
   //----------------------------------------------  
   output wire               reg2pd_dataBus16_8       ,//8 or 16 bit mode indication 
   output wire [6         :0]reg2pd_devId             ,//device address
   output wire [21        :0]reg2cmdIf_memSegAddr     ,

   //----------------------------------------------
   // packet assembler        
   //----------------------------------------------  
   output reg                reg2pa_tokenValid        ,
   output wire [3         :0]reg2pa_tokenType         ,
   output wire [3         :0]reg2pa_epNum             ,
   output wire [6         :0]reg2pa_devID             , 
   output wire [10        :0]reg2pa_frameNum          ,
   output wire               reg2pa_dataBus16_8       ,
   output reg                intrReq                  ,
   //----------------------------------------------
   // power on reset interface
   //----------------------------------------------  
   input wire                por2reg_fsmIntr          , 
   input wire                por2reg_resumeCompleted  ,
   input wire                por2reg_resumeDetected   ,
   input wire                por2reg_resetCompleted   ,
   input wire                por2reg_resetDetected    ,
   input wire                por2reg_susDetected      , 
   input wire                pe2reg_lpmRcvd           , 
   input wire                pe2reg_remoteWakeUp      
 
);

   //--------------------------------------------------
   // Local wires and registers
   //--------------------------------------------------

   reg                       wren_sus                 ;
   reg                       wren_devCtrl1            ;
   reg                       wren_devCtrl2            ;
   reg                       wren_devStat1            ;
   reg                       wren_devStat2            ;
   reg                       wren_cEpCmd              ;
   reg                       wren_cEpRdAddr           ;
   reg                       wren_dmaTxAddr           ;
   reg                       wren_cEpWrAddr           ;
   reg                       wren_eBufTxCtrl1         ;
   reg                       wren_eBufTxCtrl2         ;
   reg                       wren_dmaRxAddr           ;
   reg                       wren_eBufRxCtrl1         ;
   reg                       wren_eBufRxCtrl2         ;
   reg                       wren_intrPriMask         ;
   reg                       wren_intrSecMask         ;
   reg                       wren_intrPriStat         ;
   reg                       wren_intrSecStat         ;
   reg                       wren_intrPriData1        ;
   reg                       wren_intrPriData2        ;
   reg                       wren_intrSecData1        ;
   reg                       wren_intrSecData2        ;
   reg                       wren_testCtrl            ;
   reg                       wren_usbTransctrl        ;
   reg                       wren_usbTransTxData1     ;
   reg                       wren_usbTransTxData2     ;
   reg                       wren_usbTransTxData3     ;
   reg                       wren_usbTransRxData1     ;
   reg                       wren_usbTransRxData2     ;
   reg                       wren_usbTransRxData3     ;
   reg                       wren_tmrCtrl1            ; 
   reg                       wren_tmrCtrl2            ; 
   reg                       wren_tmrCtrl3            ; 
   reg                       wren_tmrCtrl4            ; 
   reg                       wren_tmrCtrl5            ; 
   reg                       wren_tmrCtrl6            ; 
   reg                       wren_tmrCtrl7            ; 
   reg                       wren_tmrCtrl8            ; 
   reg                       wren_tmrCtrl9            ; 
   reg                       wren_tmrCtrl10           ; 
   reg                       wren_tmrCtrl11           ; 
   reg                       wren_tmrCtrl12           ; 
   reg                       wren_tmrCtrl13           ; 
   reg                       wren_tmrCtrl14           ; 
   reg                       wren_tmrCtrl15           ; 
   reg                       wren_tmrCtrl16           ; 
   reg                       wren_tmrCtrl17           ; 
   reg                       wren_tmrCtrl18           ; 
   reg                       wren_tmrCtrl19           ; 
   reg                       wren_tmrCtrl20           ; 
   reg                       wren_sofCnt              ; 
   reg                       wren_sofCtrl             ; 
   reg                       wren_sofTmrEn            ; 
   reg                       wren_setupCmd1           ; 
   reg                       wren_setupCmd2           ; 
   reg                       wren_rst                 ;  
   reg                       wren_memSegAddr          ; 

   reg                       rden_sus                 ;
   reg                       rden_devCtrl1            ;
   reg                       rden_devCtrl2            ;
   reg                       rden_devStat1            ;
   reg                       rden_devStat2            ;
   reg                       rden_cEpCmd              ;
   reg                       rden_cEpRdAddr           ;
   reg                       rden_dmaTxAddr           ;
   reg                       rden_cEpWrAddr           ;
   reg                       rden_eBufTxCtrl1         ;
   reg                       rden_eBufTxCtrl2         ;
   reg                       rden_dmaRxAddr           ;
   reg                       rden_eBufRxCtrl1         ;
   reg                       rden_eBufRxCtrl2         ;
   reg                       rden_intrPriMask         ;
   reg                       rden_intrSecMask         ;
   reg                       rden_intrPriStat         ;
   reg                       rden_intrSecStat         ;
   reg                       rden_intrPriData1        ;
   reg                       rden_intrPriData2        ;
   reg                       rden_intrSecData1        ;
   reg                       rden_intrSecData2        ;
   reg                       rden_testCtrl            ;
   reg                       rden_usbTransctrl        ;
   reg                       rden_usbTransTxData1     ;
   reg                       rden_usbTransTxData2     ;
   reg                       rden_usbTransTxData3     ;
   reg                       rden_usbTransRxData1     ;
   reg                       rden_usbTransRxData2     ;
   reg                       rden_usbTransRxData3     ;
   reg                       rden_tmrCtrl1            ; 
   reg                       rden_tmrCtrl2            ; 
   reg                       rden_tmrCtrl3            ; 
   reg                       rden_tmrCtrl4            ; 
   reg                       rden_tmrCtrl5            ; 
   reg                       rden_tmrCtrl6            ; 
   reg                       rden_tmrCtrl7            ; 
   reg                       rden_tmrCtrl8            ; 
   reg                       rden_tmrCtrl9            ; 
   reg                       rden_tmrCtrl10           ; 
   reg                       rden_tmrCtrl11           ; 
   reg                       rden_tmrCtrl12           ; 
   reg                       rden_tmrCtrl13           ; 
   reg                       rden_tmrCtrl14           ; 
   reg                       rden_tmrCtrl15           ; 
   reg                       rden_tmrCtrl16           ; 
   reg                       rden_tmrCtrl17           ; 
   reg                       rden_tmrCtrl18           ; 
   reg                       rden_tmrCtrl19           ; 
   reg                       rden_tmrCtrl20           ; 
   reg                       rden_sofCnt              ; 
   reg                       rden_sofCtrl             ; 
   reg                       rden_sofTmrEn            ; 
   reg                       rden_setupCmd1           ; 
   reg                       rden_setupCmd2           ; 
   reg                       rden_rst                 ; 
   reg                       rden_memSegAddr          ; 


   reg    [DATA_SIZE-1:0]    reg_sus                  ; 
   reg    [DATA_SIZE-1:0]    reg_devCtrl1             ; 
   reg    [DATA_SIZE-1:0]    reg_devCtrl2             ; 
   reg    [DATA_SIZE-1:0]    reg_devStat1             ; 
   reg    [DATA_SIZE-1:0]    reg_devStat2             ; 
   reg    [DATA_SIZE-1:0]    reg_cEpCmd               ; 
   reg    [DATA_SIZE-1:0]    reg_cEpRdAddr            ; 
   reg    [DATA_SIZE-1:0]    reg_dmaTxAddr            ; 
   reg    [DATA_SIZE-1:0]    reg_cEpWrAddr            ; 
   reg    [DATA_SIZE-1:0]    reg_eBufTxCtrl1          ; 
   reg    [DATA_SIZE-1:0]    reg_eBufTxCtrl2          ; 
   reg    [DATA_SIZE-1:0]    reg_dmaRxAddr            ; 
   reg    [DATA_SIZE-1:0]    reg_eBufRxCtrl1          ; 
   reg    [DATA_SIZE-1:0]    reg_eBufRxCtrl2          ; 
   reg    [DATA_SIZE-1:0]    reg_intrPriMask          ; 
   reg    [DATA_SIZE-1:0]    reg_intrSecMask          ; 
   reg    [DATA_SIZE-1:0]    reg_intrPriStat          ; 
   reg    [DATA_SIZE-1:0]    reg_intrSecStat          ; 
   reg    [DATA_SIZE-1:0]    reg_intrPriData1         ; 
   reg    [DATA_SIZE-1:0]    reg_intrPriData2         ; 
   reg    [DATA_SIZE-1:0]    reg_intrSecData1         ; 
   reg    [DATA_SIZE-1:0]    reg_intrSecData2         ; 
   reg    [DATA_SIZE-1:0]    reg_testCtrl             ; 
   reg    [DATA_SIZE-1:0]    reg_usbTransctrl         ; 
   reg    [DATA_SIZE-1:0]    reg_usbTransTxData1      ;
   reg    [DATA_SIZE-1:0]    reg_usbTransTxData2      ;
   reg    [DATA_SIZE-1:0]    reg_usbTransTxData3      ;
   reg    [DATA_SIZE-1:0]    reg_usbTransRxData1      ;
   reg    [DATA_SIZE-1:0]    reg_usbTransRxData2      ;
   reg    [DATA_SIZE-1:0]    reg_usbTransRxData3      ;
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl1             ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl2             ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl3             ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl4             ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl5             ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl6             ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl7             ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl8             ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl9             ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl10            ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl11            ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl12            ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl13            ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl14            ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl15            ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl16            ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl17            ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl18            ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl19            ; 
   reg    [DATA_SIZE-1:0]    reg_tmrCtrl20            ; 
   reg    [DATA_SIZE-1:0]    reg_sofCnt               ; 
   reg    [DATA_SIZE-1:0]    reg_sofCtrl              ; 
   reg    [DATA_SIZE-1:0]    reg_sofTmrEn             ; 
   reg    [DATA_SIZE-1:0]    reg_setupCmd1            ; 
   reg    [DATA_SIZE-1:0]    reg_setupCmd2            ; 
   reg    [DATA_SIZE-1:0]    reg_rst                  ; 
   reg    [DATA_SIZE-1:0]    reg_memSegAddr           ;
   reg                       eBufRxCtrl2_ld           ;
   reg                       eBufTxCtrl2_ld           ;
   wire                      sysBufEmtyFull           ;
   wire                      usbBufEmtyFull           ;
   wire   [DATA_SIZE-1:0]    intrPriMaskNStat         ; 
   wire   [DATA_SIZE-1:0]    intrSecMaskNStat         ;  
   wire                      intrPriOR                ;
   wire                      intrSecOR                ;
   wire                      intr_nxt                 ;

   //---------------------------------------------------
   // Code Starts From Here
   //---------------------------------------------------
   always @(*)begin

   //---------------------------------------------------
   // writing data from AHB
   //---------------------------------------------------
      wren_sus              = 1'b0          ;
      wren_rst              = 1'b0          ;
      wren_devCtrl1         = 1'b0          ;
      wren_devCtrl2         = 1'b0          ;
      wren_devStat1         = 1'b0          ;
      wren_devStat2         = 1'b0          ;
      wren_cEpCmd           = 1'b0          ;
      wren_cEpRdAddr        = 1'b0          ;
      wren_memSegAddr       = 1'b0          ;
      wren_dmaTxAddr        = 1'b0          ;
      wren_cEpWrAddr        = 1'b0          ;
      wren_eBufTxCtrl1      = 1'b0          ;
      wren_eBufTxCtrl2      = 1'b0          ;
      wren_dmaRxAddr        = 1'b0          ;
      wren_eBufRxCtrl1      = 1'b0          ;
      wren_eBufRxCtrl2      = 1'b0          ;
      wren_sofCnt           = 1'b0          ;
      wren_sofCtrl          = 1'b0          ;
      wren_sofTmrEn         = 1'b0          ;
      wren_setupCmd1        = 1'b0          ;
      wren_setupCmd2        = 1'b0          ;
      wren_tmrCtrl1         = 1'b0          ;
      wren_tmrCtrl2         = 1'b0          ;
      wren_tmrCtrl3         = 1'b0          ;
      wren_tmrCtrl4         = 1'b0          ;
      wren_tmrCtrl5         = 1'b0          ;
      wren_tmrCtrl6         = 1'b0          ;
      wren_tmrCtrl7         = 1'b0          ;
      wren_tmrCtrl8         = 1'b0          ;
      wren_tmrCtrl9         = 1'b0          ;
      wren_tmrCtrl10        = 1'b0          ;
      wren_tmrCtrl11        = 1'b0          ;
      wren_tmrCtrl12        = 1'b0          ;
      wren_tmrCtrl13        = 1'b0          ;
      wren_tmrCtrl14        = 1'b0          ;
      wren_tmrCtrl15        = 1'b0          ;
      wren_tmrCtrl16        = 1'b0          ;
      wren_tmrCtrl17        = 1'b0          ;
      wren_tmrCtrl18        = 1'b0          ;
      wren_tmrCtrl19        = 1'b0          ;
      wren_tmrCtrl20        = 1'b0          ;
      wren_intrPriMask      = 1'b0          ;
      wren_intrSecMask      = 1'b0          ;
      wren_intrPriStat      = 1'b0          ;
      wren_intrSecStat      = 1'b0          ;
      wren_intrPriData1     = 1'b0          ;
      wren_intrPriData2     = 1'b0          ;
      wren_intrSecData1     = 1'b0          ;
      wren_intrSecData2     = 1'b0          ;
      wren_testCtrl         = 1'b0          ;
      wren_usbTransctrl     = 1'b0          ;
      wren_usbTransTxData1  = 1'b0          ;
      wren_usbTransTxData2  = 1'b0          ;
      wren_usbTransTxData3  = 1'b0          ;
      wren_usbTransRxData1  = 1'b0          ;
      wren_usbTransRxData2  = 1'b0          ;
      wren_usbTransRxData3  = 1'b0          ;
  
      rden_sus              = 1'b0          ;
      rden_rst              = 1'b0          ;
      rden_devCtrl1         = 1'b0          ;
      rden_devCtrl2         = 1'b0          ;
      rden_devStat1         = 1'b0          ;
      rden_devStat2         = 1'b0          ;
      rden_cEpCmd           = 1'b0          ;
      rden_cEpRdAddr        = 1'b0          ;
      rden_memSegAddr       = 1'b0          ;
      rden_dmaTxAddr        = 1'b0          ;
      rden_cEpWrAddr        = 1'b0          ;
      rden_eBufTxCtrl1      = 1'b0          ;
      rden_eBufTxCtrl2      = 1'b0          ;
      rden_dmaRxAddr        = 1'b0          ;
      rden_eBufRxCtrl1      = 1'b0          ;
      rden_eBufRxCtrl2      = 1'b0          ;
      rden_sofCnt           = 1'b0          ;
      rden_sofCtrl          = 1'b0          ;
      rden_sofTmrEn         = 1'b0          ;
      rden_setupCmd1        = 1'b0          ;
      rden_setupCmd2        = 1'b0          ;
      rden_tmrCtrl1         = 1'b0          ;
      rden_tmrCtrl2         = 1'b0          ;
      rden_tmrCtrl3         = 1'b0          ;
      rden_tmrCtrl4         = 1'b0          ;
      rden_tmrCtrl5         = 1'b0          ;
      rden_tmrCtrl6         = 1'b0          ;
      rden_tmrCtrl7         = 1'b0          ;
      rden_tmrCtrl8         = 1'b0          ;
      rden_tmrCtrl9         = 1'b0          ;
      rden_tmrCtrl10        = 1'b0          ;
      rden_tmrCtrl11        = 1'b0          ;
      rden_tmrCtrl12        = 1'b0          ;
      rden_tmrCtrl13        = 1'b0          ;
      rden_tmrCtrl14        = 1'b0          ;
      rden_tmrCtrl15        = 1'b0          ;
      rden_tmrCtrl16        = 1'b0          ;
      rden_tmrCtrl17        = 1'b0          ;
      rden_tmrCtrl18        = 1'b0          ;
      rden_tmrCtrl19        = 1'b0          ;
      rden_tmrCtrl20        = 1'b0          ;
      rden_intrPriMask      = 1'b0          ;
      rden_intrSecMask      = 1'b0          ;
      rden_intrPriStat      = 1'b0          ;
      rden_intrSecStat      = 1'b0          ;
      rden_intrPriData1     = 1'b0          ;
      rden_intrPriData2     = 1'b0          ;
      rden_intrSecData1     = 1'b0          ;
      rden_intrSecData2     = 1'b0          ;
      rden_testCtrl         = 1'b0          ;
      rden_usbTransctrl     = 1'b0          ;
      rden_usbTransTxData1  = 1'b0          ;
      rden_usbTransTxData2  = 1'b0          ;
      rden_usbTransTxData3  = 1'b0          ;
      rden_usbTransRxData1  = 1'b0          ;
      rden_usbTransRxData2  = 1'b0          ;
      rden_usbTransRxData3  = 1'b0          ;
      case(cmd2reg_addr)
         SUSP_CTRL :  begin
            wren_sus         = cmd2reg_wrReq;
            rden_sus         = cmd2reg_rdReq;
         end
         RESET_CTRL:  begin
            wren_rst         = cmd2reg_wrReq;
            rden_rst         = cmd2reg_rdReq;
         end
         DEV_CTRL1 :  begin
            wren_devCtrl1    = cmd2reg_wrReq;
            rden_devCtrl1    = cmd2reg_rdReq;
         end
         DEV_CTRL2 :  begin
            wren_devCtrl2    = cmd2reg_wrReq;
            rden_devCtrl2    = cmd2reg_rdReq;
         end
         DEV_STAT1 :  begin
            wren_devStat1    = cmd2reg_wrReq;
            rden_devStat1    = cmd2reg_rdReq;
         end
         DEV_STAT2 :  begin
            wren_devStat2    = cmd2reg_wrReq;
            rden_devStat2    = cmd2reg_rdReq;
         end
         CTRL_EP_CMD_REG :  begin
            wren_cEpCmd      = cmd2reg_wrReq;
            rden_cEpCmd      = cmd2reg_rdReq;
         end
         CTRL_EP_RD_ADDR :  begin
            wren_cEpRdAddr   = cmd2reg_wrReq;
            rden_cEpRdAddr   = cmd2reg_rdReq;
         end
         MEM_SEG_ADDR :  begin
            wren_memSegAddr  = cmd2reg_wrReq;
            rden_memSegAddr  = cmd2reg_rdReq;
         end
         DMA_TX_ADDR :  begin
            wren_dmaTxAddr   = cmd2reg_wrReq;
            rden_dmaTxAddr   = cmd2reg_rdReq;
         end
         EP_WR_ADDR :  begin
            wren_cEpWrAddr   = cmd2reg_wrReq;
            rden_cEpWrAddr   = cmd2reg_rdReq;
         end
         EBUF_TX_CTRL1 :  begin
            wren_eBufTxCtrl1 = cmd2reg_wrReq;
            rden_eBufTxCtrl1 = cmd2reg_rdReq;
         end
         EBUF_TX_CTRL2 :  begin
            wren_eBufTxCtrl2 = cmd2reg_wrReq;
            rden_eBufTxCtrl2 = cmd2reg_rdReq;
         end
         DMA_RX_ADDR :  begin
            wren_dmaRxAddr   = cmd2reg_wrReq;
            rden_dmaRxAddr   = cmd2reg_rdReq;
         end
         EBUF_RX_CTRL1 :  begin
            wren_eBufRxCtrl1 = cmd2reg_wrReq;
            rden_eBufRxCtrl1 = cmd2reg_rdReq;
         end
         EBUF_RX_CTRL2 :  begin
            wren_eBufRxCtrl2 = cmd2reg_wrReq;
            rden_eBufRxCtrl2 = cmd2reg_rdReq;
         end
         SOF_COUNT :  begin
            wren_sofCnt      = cmd2reg_wrReq;
            rden_sofCnt      = cmd2reg_rdReq;
         end
         SOF_CTRL :  begin
            wren_sofCtrl     = cmd2reg_wrReq;
            rden_sofCtrl     = cmd2reg_rdReq;
         end
         SOF_TIMER_SET :  begin
            wren_sofTmrEn    = cmd2reg_wrReq;
            rden_sofTmrEn    = cmd2reg_rdReq;
         end
         SETUP_CMD1 :  begin
            wren_setupCmd1   = cmd2reg_wrReq;
            rden_setupCmd1   = cmd2reg_rdReq;
         end
         SETUP_CMD2 :  begin
            wren_setupCmd2   = cmd2reg_wrReq;
            rden_setupCmd2   = cmd2reg_rdReq;
         end
         TIMER_CTRL1 :  begin       
            wren_tmrCtrl1    = cmd2reg_wrReq;
            rden_tmrCtrl1    = cmd2reg_rdReq;
         end
         TIMER_CTRL2 :  begin
            wren_tmrCtrl2    = cmd2reg_wrReq;
            rden_tmrCtrl2    = cmd2reg_rdReq;
         end
         TIMER_CTRL3 :  begin
            wren_tmrCtrl3    = cmd2reg_wrReq;
            rden_tmrCtrl3    = cmd2reg_rdReq;
         end
         TIMER_CTRL4 :  begin
            wren_tmrCtrl4    = cmd2reg_wrReq;
            rden_tmrCtrl4    = cmd2reg_rdReq;
         end
         TIMER_CTRL5 :  begin
            wren_tmrCtrl5    = cmd2reg_wrReq;
            rden_tmrCtrl5    = cmd2reg_rdReq;
         end
         TIMER_CTRL6 :  begin
            wren_tmrCtrl6    = cmd2reg_wrReq;
            rden_tmrCtrl6    = cmd2reg_rdReq;
         end
         TIMER_CTRL7 :  begin
            wren_tmrCtrl7    = cmd2reg_wrReq;
            rden_tmrCtrl7    = cmd2reg_rdReq;
         end
         TIMER_CTRL8 :  begin
            wren_tmrCtrl8    = cmd2reg_wrReq;
            rden_tmrCtrl8    = cmd2reg_rdReq;
         end
         TIMER_CTRL9 :  begin
            wren_tmrCtrl9    = cmd2reg_wrReq;
            rden_tmrCtrl9    = cmd2reg_rdReq;
         end
         TIMER_CTRL10 :  begin
            wren_tmrCtrl10   = cmd2reg_wrReq;
            rden_tmrCtrl10   = cmd2reg_rdReq;
         end
         TIMER_CTRL11 :  begin
            wren_tmrCtrl11   = cmd2reg_wrReq;
            rden_tmrCtrl11   = cmd2reg_rdReq;
         end
         TIMER_CTRL12 :  begin
            wren_tmrCtrl12   = cmd2reg_wrReq;
            rden_tmrCtrl12   = cmd2reg_rdReq;
         end
         TIMER_CTRL13 :  begin
            wren_tmrCtrl13   = cmd2reg_wrReq;
            rden_tmrCtrl13   = cmd2reg_rdReq;
         end
         TIMER_CTRL14 :  begin
            wren_tmrCtrl14   = cmd2reg_wrReq;
            rden_tmrCtrl14   = cmd2reg_rdReq;
         end
         TIMER_CTRL15 :  begin
            wren_tmrCtrl15   = cmd2reg_wrReq;
            rden_tmrCtrl15   = cmd2reg_rdReq;
         end
         TIMER_CTRL16 :  begin
            wren_tmrCtrl16   = cmd2reg_wrReq;
            rden_tmrCtrl16   = cmd2reg_rdReq;
         end
         TIMER_CTRL17 :  begin
            wren_tmrCtrl17   = cmd2reg_wrReq;
            rden_tmrCtrl17   = cmd2reg_rdReq;
         end
         TIMER_CTRL18 :  begin
            wren_tmrCtrl18   = cmd2reg_wrReq;
            rden_tmrCtrl18   = cmd2reg_rdReq;
         end
         TIMER_CTRL19 :  begin
            wren_tmrCtrl19   = cmd2reg_wrReq;
            rden_tmrCtrl19   = cmd2reg_rdReq;
         end
         TIMER_CTRL20 :  begin
            wren_tmrCtrl20   = cmd2reg_wrReq;
            rden_tmrCtrl20   = cmd2reg_rdReq;
         end
         INTR_MASK_PRI :  begin
            wren_intrPriMask = cmd2reg_wrReq;
            rden_intrPriMask = cmd2reg_rdReq;
         end
         INTR_MASK_SEC :  begin
            wren_intrSecMask = cmd2reg_wrReq;
            rden_intrSecMask = cmd2reg_rdReq;
         end

         INTR_STATUS_PRI :  begin
            wren_intrPriStat = cmd2reg_wrReq;
            rden_intrPriStat = cmd2reg_rdReq;
         end
         INTR_STATUS_SEC :  begin
            wren_intrSecStat = cmd2reg_wrReq;
            rden_intrSecStat = cmd2reg_rdReq;
         end
         INTR_DATA1_PRI :  begin
            wren_intrPriData1= cmd2reg_wrReq;
            rden_intrPriData1= cmd2reg_rdReq;
         end
         INTR_DATA2_PRI :  begin
            wren_intrPriData2= cmd2reg_wrReq;
            rden_intrPriData2= cmd2reg_rdReq;
         end
         INTR_DATA1_SEC :  begin
            wren_intrSecData1= cmd2reg_wrReq;
            rden_intrSecData1= cmd2reg_rdReq;
         end
         INTR_DATA2_SEC :  begin
            wren_intrSecData2= cmd2reg_wrReq;
            rden_intrSecData2= cmd2reg_rdReq;
         end
         TEST_CTRL :  begin
            wren_testCtrl    = cmd2reg_wrReq;
            rden_testCtrl    = cmd2reg_rdReq;
         end
         USB_TRANS_CTRL :  begin
            wren_usbTransctrl= cmd2reg_wrReq;
            rden_usbTransctrl= cmd2reg_rdReq;
         end
         USB_TX_TRANS_DATA1 :  begin
            wren_usbTransTxData1= cmd2reg_wrReq;
            rden_usbTransTxData1= cmd2reg_rdReq;
         end
         USB_TX_TRANS_DATA2 :  begin
            wren_usbTransTxData2= cmd2reg_wrReq;
            rden_usbTransTxData2= cmd2reg_rdReq;
         end
         USB_TX_TRANS_DATA3 :  begin
            wren_usbTransTxData3= cmd2reg_wrReq;
            rden_usbTransTxData3= cmd2reg_rdReq;
         end
         USB_RX_TRANS_DATA1 :  begin
            wren_usbTransRxData1= cmd2reg_wrReq;
            rden_usbTransRxData1= cmd2reg_rdReq;
         end
         USB_RX_TRANS_DATA2 :  begin
            wren_usbTransRxData2= cmd2reg_wrReq;
            rden_usbTransRxData2= cmd2reg_rdReq;
         end
         USB_RX_TRANS_DATA3 :  begin
            wren_usbTransRxData3= cmd2reg_wrReq;
            rden_usbTransRxData3= cmd2reg_rdReq;
         end
         default :  begin
            wren_sus              = 1'b0;
            wren_rst              = 1'b0;
            wren_devCtrl1         = 1'b0;
            wren_devCtrl2         = 1'b0;
            wren_devStat1         = 1'b0;
            wren_devStat2         = 1'b0;
            wren_cEpCmd           = 1'b0;
            wren_cEpRdAddr        = 1'b0;
            wren_memSegAddr       = 1'b0;
            wren_dmaTxAddr        = 1'b0;
            wren_cEpWrAddr        = 1'b0;
            wren_eBufTxCtrl1      = 1'b0;
            wren_eBufTxCtrl2      = 1'b0;
            wren_dmaRxAddr        = 1'b0;
            wren_eBufRxCtrl1      = 1'b0;
            wren_eBufRxCtrl2      = 1'b0;
            wren_sofCnt           = 1'b0;
            wren_sofCtrl          = 1'b0;
            wren_sofTmrEn         = 1'b0;
            wren_setupCmd1        = 1'b0;
            wren_setupCmd2        = 1'b0;
            wren_tmrCtrl1         = 1'b0;
            wren_tmrCtrl2         = 1'b0;
            wren_tmrCtrl3         = 1'b0;
            wren_tmrCtrl4         = 1'b0;
            wren_tmrCtrl5         = 1'b0;
            wren_tmrCtrl6         = 1'b0;
            wren_tmrCtrl7         = 1'b0;
            wren_tmrCtrl8         = 1'b0;
            wren_tmrCtrl9         = 1'b0;
            wren_tmrCtrl10        = 1'b0;
            wren_tmrCtrl11        = 1'b0;
            wren_tmrCtrl12        = 1'b0;
            wren_tmrCtrl13        = 1'b0;
            wren_tmrCtrl14        = 1'b0;
            wren_tmrCtrl15        = 1'b0;
            wren_tmrCtrl16        = 1'b0;
            wren_tmrCtrl17        = 1'b0;
            wren_tmrCtrl18        = 1'b0;
            wren_tmrCtrl19        = 1'b0;
            wren_tmrCtrl20        = 1'b0;
            wren_intrPriMask      = 1'b0;
            wren_intrSecMask      = 1'b0;
            wren_intrPriStat      = 1'b0;
            wren_intrSecStat      = 1'b0;
            wren_intrPriData1     = 1'b0;
            wren_intrPriData2     = 1'b0;
            wren_intrSecData1     = 1'b0;
            wren_intrSecData2     = 1'b0;
            wren_testCtrl         = 1'b0;
            wren_usbTransctrl     = 1'b0;
            wren_usbTransTxData1  = 1'b0;
            wren_usbTransTxData2  = 1'b0;
            wren_usbTransTxData3  = 1'b0;
            wren_usbTransRxData1  = 1'b0;
            wren_usbTransRxData2  = 1'b0;
            wren_usbTransRxData3  = 1'b0;

            rden_sus              = 1'b0;
            rden_rst              = 1'b0;
            rden_devCtrl1         = 1'b0;
            rden_devCtrl2         = 1'b0;
            rden_devStat1         = 1'b0;
            rden_devStat2         = 1'b0;
            rden_cEpCmd           = 1'b0;
            rden_cEpRdAddr        = 1'b0;
            rden_memSegAddr       = 1'b0;
            rden_dmaTxAddr        = 1'b0;
            rden_cEpWrAddr        = 1'b0;
            rden_eBufTxCtrl1      = 1'b0;
            rden_eBufTxCtrl2      = 1'b0;
            rden_dmaRxAddr        = 1'b0;
            rden_eBufRxCtrl1      = 1'b0;
            rden_eBufRxCtrl2      = 1'b0;
            rden_sofCnt           = 1'b0;
            rden_sofCtrl          = 1'b0;
            rden_sofTmrEn         = 1'b0;
            rden_setupCmd1        = 1'b0;
            rden_setupCmd2        = 1'b0;
            rden_tmrCtrl1         = 1'b0;
            rden_tmrCtrl2         = 1'b0;
            rden_tmrCtrl3         = 1'b0;
            rden_tmrCtrl4         = 1'b0;
            rden_tmrCtrl5         = 1'b0;
            rden_tmrCtrl6         = 1'b0;
            rden_tmrCtrl7         = 1'b0;
            rden_tmrCtrl8         = 1'b0;
            rden_tmrCtrl9         = 1'b0;
            rden_tmrCtrl10        = 1'b0;
            rden_tmrCtrl11        = 1'b0;
            rden_tmrCtrl12        = 1'b0;
            rden_tmrCtrl13        = 1'b0;
            rden_tmrCtrl14        = 1'b0;
            rden_tmrCtrl15        = 1'b0;
            rden_tmrCtrl16        = 1'b0;
            rden_tmrCtrl17        = 1'b0;
            rden_tmrCtrl18        = 1'b0;
            rden_tmrCtrl19        = 1'b0;
            rden_tmrCtrl20        = 1'b0;
            rden_intrPriMask      = 1'b0;
            rden_intrSecMask      = 1'b0;
            rden_intrPriStat      = 1'b0;
            rden_intrSecStat      = 1'b0;
            rden_intrPriData1     = 1'b0;
            rden_intrPriData2     = 1'b0;
            rden_intrSecData1     = 1'b0;
            rden_intrSecData2     = 1'b0;
            rden_testCtrl         = 1'b0;
            rden_usbTransctrl     = 1'b0;
            rden_usbTransTxData1  = 1'b0;
            rden_usbTransTxData2  = 1'b0;
            rden_usbTransTxData3  = 1'b0;
            rden_usbTransRxData1  = 1'b0;
            rden_usbTransRxData2  = 1'b0;
            rden_usbTransRxData3  = 1'b0;
         end
      endcase
   end

   // --------------------------------------------------
   // registered inputs
   // --------------------------------------------------

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_sus              <= {32{1'b0}};
      end
      else begin
         if(wren_sus == 1'b1)begin
            reg_sus           <= cmd2reg_wrData;
         end
         else begin
            reg_sus           <= reg_sus;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_rst              <= 32'hFFF4FFFF;
      end
      else begin
         if(wren_rst == 1'b1)begin
            reg_rst           <= cmd2reg_wrData;
         end
         else begin
            reg_rst           <= reg_rst;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_devCtrl1         <= {32{1'b0}};
      end
      else begin
         if(wren_devCtrl1 == 1'b1)begin
            reg_devCtrl1      <= cmd2reg_wrData;
         end
         else begin
            reg_devCtrl1      <= reg_devCtrl1;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_devCtrl2         <= {32{1'b0}};
      end
      else begin
         if(wren_devCtrl2 == 1'b1)begin
            reg_devCtrl2      <= cmd2reg_wrData;
         end
         else begin
            reg_devCtrl2      <= reg_devCtrl2;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_devStat1         <= {32{1'b0}};
      end
      else begin
         if(wren_devStat1 == 1'b1)begin
            reg_devStat1      <= cmd2reg_wrData;
         end
         else begin
            reg_devStat1      <= reg_devStat1;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_devStat2         <= {32{1'b0}};
      end
      else begin
         if(wren_devStat2 == 1'b1)begin
            reg_devStat2      <= cmd2reg_wrData;
         end
         else begin
            reg_devStat2      <= reg_devStat2;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_cEpCmd           <= {32{1'b0}};
      end
      else begin
         if(wren_cEpCmd == 1'b1)begin
            reg_cEpCmd        <= cmd2reg_wrData;
         end
         else if(epcr2reg_enuCmdUpdt == 1'b1) begin
            reg_cEpCmd        <= {epcr2reg_descLenUpdt,reg_cEpCmd[15:2],epcr2reg_enuActOut};
         end 
         else if(epct2reg_enuCmdUpdt == 1'b1) begin
            reg_cEpCmd        <= {epct2reg_descLenUpdt,reg_cEpCmd[15:2],epct2reg_enuActOut};
         end
         else if(pe2reg_clrCmdReg) begin 
            reg_cEpCmd           <= {32{1'b0}};
         end
         else begin
            reg_cEpCmd        <= reg_cEpCmd;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_cEpRdAddr        <= {32{1'b0}};
      end
      else begin
         if(wren_cEpRdAddr == 1'b1)begin
            reg_cEpRdAddr     <= cmd2reg_wrData;
         end
         else begin
            reg_cEpRdAddr     <= reg_cEpRdAddr;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_dmaTxAddr        <= {32{1'b0}};
      end
      else begin
         if(wren_dmaTxAddr == 1'b1)begin
            reg_dmaTxAddr     <= cmd2reg_wrData;
         end
         else begin
            reg_dmaTxAddr     <= reg_dmaTxAddr;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_cEpWrAddr        <= {32{1'b0}};
      end
      else begin
         if(wren_cEpWrAddr == 1'b1)begin
            reg_cEpWrAddr     <= cmd2reg_wrData;
         end
         else begin
            reg_cEpWrAddr     <= reg_cEpWrAddr;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_eBufTxCtrl1      <= {32{1'b0}};
      end
      else begin
         if(wren_eBufTxCtrl1 == 1'b1)begin
            reg_eBufTxCtrl1   <= cmd2reg_wrData;
         end
         else if(sctrlTx2reg_updt == 1'b1) begin
            reg_eBufTxCtrl1   <= {reg_eBufTxCtrl1[31:20],sctrlTx2reg_length};
         end
         else begin
            reg_eBufTxCtrl1   <= reg_eBufTxCtrl1;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         eBufTxCtrl2_ld       <= 1'b0;
         reg_eBufTxCtrl2      <= {32{1'b0}};
      end
      else begin
         if(wren_eBufTxCtrl2 == 1'b1)begin
            eBufTxCtrl2_ld    <= 1'b1;
            reg_eBufTxCtrl2   <= cmd2reg_wrData;
         end
         else if(sctrlTx2reg_updt == 1'b1) begin
            eBufTxCtrl2_ld    <= 1'b0;
            reg_eBufTxCtrl2   <= {reg_eBufTxCtrl2[31:12],sctrlTx2reg_fullPktCnt,sctrlTx2reg_fragCnt,sctrlTx2reg_status}; 
         end
         else begin
            eBufTxCtrl2_ld    <= 1'b0;
            reg_eBufTxCtrl2   <= reg_eBufTxCtrl2;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_dmaRxAddr        <= {32{1'b0}};
      end
      else begin
         if(wren_dmaRxAddr == 1'b1)begin
            reg_dmaRxAddr     <= cmd2reg_wrData;
         end
         else begin
            reg_dmaRxAddr     <= reg_dmaRxAddr;
         end
      end
   end
  
   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_eBufRxCtrl1      <= {32{1'b0}};
      end
      else begin
         if(wren_eBufRxCtrl1 == 1'b1)begin
            reg_eBufRxCtrl1   <= cmd2reg_wrData;
         end
         else if(sctrlRx2reg_updtRdBuf== 1'b1)begin
            reg_eBufRxCtrl1   <= {reg_eBufRxCtrl1[31:4],sctrlRx2reg_rdCnt};
         end
         else begin
            reg_eBufRxCtrl1   <= reg_eBufRxCtrl1; 
         end
      end
   end
  
   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         eBufRxCtrl2_ld       <= 1'b0;
         reg_eBufRxCtrl2      <= {32{1'b0}};
      end
      else begin
         if(wren_eBufRxCtrl2 == 1'b1)begin
            eBufRxCtrl2_ld    <= 1'b1;
            reg_eBufRxCtrl2   <= cmd2reg_wrData;
         end
         else if(sctrlRx2reg_updtRdBuf== 1'b1)begin
            eBufRxCtrl2_ld    <= 1'b0;
            reg_eBufRxCtrl2   <= {reg_eBufRxCtrl2[31:12],sctrlRx2reg_fullPktCnt,reg_eBufRxCtrl2[6:2],sctrlRx2reg_status};
         end
         else begin
            eBufRxCtrl2_ld    <= 1'b0;
            reg_eBufRxCtrl2   <= reg_eBufRxCtrl2;
         end
      end
   end


   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_intrPriMask      <= {32{1'b0}};
      end
      else begin
         if(wren_intrPriMask == 1'b1)begin
            reg_intrPriMask   <= cmd2reg_wrData;
         end
         else begin
            reg_intrPriMask   <= reg_intrPriMask;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_intrSecMask      <= {32{1'b0}};
      end
      else begin
         if(wren_intrSecMask == 1'b1)begin
            reg_intrSecMask   <= cmd2reg_wrData;
         end
         else begin
            reg_intrSecMask   <= reg_intrSecMask;
         end
      end
   end

   assign sysBufEmtyFull       = (((sctrlTx2reg_updt ) && (sctrlTx2reg_full) ) || ((sctrlRx2reg_updtRdBuf) && (sctrlRx2reg_empty)) ) ? 1'b1 : 1'b0 ;
   assign usbBufEmtyFull       = epcr2reg_bufFull  || epct2reg_bufEmpty;

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_intrPriStat            <= {32{1'b0}};
      end
      else begin

         reg_intrPriStat[31]        <= intrSecOR;
         if((sctrlTx2reg_updt == 1'b1) && (sctrlTx2reg_status == 2'b00) ) begin
            reg_intrPriStat[9]      <= 1'b1 ;
         end
         if((sctrlRx2reg_updtRdBuf == 1'b1) && (sctrlRx2reg_status == 2'b00))begin
            reg_intrPriStat[8]      <= 1'b1 ;
         end
         if(sysBufEmtyFull)begin
            reg_intrPriStat[7]      <= 1'b1 ;
         end
         if(usbBufEmtyFull)begin
            reg_intrPriStat[6]      <= 1'b1 ;
         end
         if(pe2reg_transSent)begin
            reg_intrPriStat[5]      <= 1'b1 ;
         end
         if(epct2reg_zlpSent)begin
            reg_intrPriStat[4]      <= 1'b1 ;
         end
         if(epct2reg_dpSend)begin
            reg_intrPriStat[3]      <= 1'b1 ;
         end
         if(epcr2reg_zlpRcvd)begin
            reg_intrPriStat[2]      <= 1'b1 ;
         end
         if(epcr2reg_setupRcvd)begin
            reg_intrPriStat[1]      <= 1'b1 ;
         end
         if(epcr2reg_dpRcvd)begin
            reg_intrPriStat[0]      <= 1'b1 ;
         end
         if(por2reg_fsmIntr)begin
            reg_intrPriStat[22]      <= 1'b1 ;
         end
         if(por2reg_resumeCompleted)begin
            reg_intrPriStat[16]      <= 1'b1 ;
         end
         if(por2reg_resumeDetected)begin
            reg_intrPriStat[15]      <= 1'b1 ;
         end
         if(por2reg_resetCompleted)begin
            reg_intrPriStat[14]      <= 1'b1 ;
         end
         if(por2reg_resetDetected)begin
            reg_intrPriStat[13]      <= 1'b1 ;
         end
         if(por2reg_susDetected)begin
            reg_intrPriStat[12]      <= 1'b1 ;
         end
         if(pe2reg_lpmRcvd)begin
            reg_intrPriStat[24]      <= 1'b1 ;
         end
         if(wren_intrPriStat == 1'b1)begin
            if(cmd2reg_wrData[0] == 1'b1)begin
               reg_intrPriStat[0]   <= 1'b0;
            end
            if(cmd2reg_wrData[1] == 1'b1) begin
               reg_intrPriStat[1]   <= 1'b0;
            end
            if(cmd2reg_wrData[2] == 1'b1) begin
               reg_intrPriStat[2]   <= 1'b0;
            end
            if(cmd2reg_wrData[3] == 1'b1) begin
               reg_intrPriStat[3]   <= 1'b0;
            end
            if(cmd2reg_wrData[4] == 1'b1) begin
               reg_intrPriStat[4]   <= 1'b0;
            end
            if(cmd2reg_wrData[5] == 1'b1) begin
               reg_intrPriStat[5]   <= 1'b0;
            end
            if(cmd2reg_wrData[6] == 1'b1) begin
               reg_intrPriStat[6]   <= 1'b0;
            end
            if(cmd2reg_wrData[7] == 1'b1) begin
               reg_intrPriStat[7]   <= 1'b0;
            end
            if(cmd2reg_wrData[8] == 1'b1) begin
               reg_intrPriStat[8]   <= 1'b0;
            end
            if(cmd2reg_wrData[9] == 1'b1) begin
               reg_intrPriStat[9]   <= 1'b0;
            end
            if(cmd2reg_wrData[10] == 1'b1) begin
               reg_intrPriStat[10]  <= 1'b0;
            end
            if(cmd2reg_wrData[11] == 1'b1) begin
               reg_intrPriStat[11]  <= 1'b0;
            end
            if(cmd2reg_wrData[12] == 1'b1) begin
               reg_intrPriStat[12]  <= 1'b0;
            end
            if(cmd2reg_wrData[13] == 1'b1) begin
               reg_intrPriStat[13]  <= 1'b0;
            end
            if(cmd2reg_wrData[14] == 1'b1) begin
               reg_intrPriStat[14]  <= 1'b0;
            end
            if(cmd2reg_wrData[15] == 1'b1) begin
               reg_intrPriStat[15]  <= 1'b0;
            end
            if(cmd2reg_wrData[16] == 1'b1) begin
               reg_intrPriStat[16]  <= 1'b0;
            end
            if(cmd2reg_wrData[17] == 1'b1) begin
               reg_intrPriStat[17]  <= 1'b0;
            end
            if(cmd2reg_wrData[18] == 1'b1) begin
               reg_intrPriStat[18]  <= 1'b0;
            end
            if(cmd2reg_wrData[19] == 1'b1) begin
               reg_intrPriStat[19]  <= 1'b0;
            end
            if(cmd2reg_wrData[20] == 1'b1) begin
               reg_intrPriStat[20]  <= 1'b0;
            end
            if(cmd2reg_wrData[21] == 1'b1) begin
               reg_intrPriStat[21]  <= 1'b0;
            end
            if(cmd2reg_wrData[22] == 1'b1) begin
               reg_intrPriStat[22]  <= 1'b0;
            end
            if(cmd2reg_wrData[23] == 1'b1) begin
               reg_intrPriStat[23]  <= 1'b0;
            end
            if(cmd2reg_wrData[24] == 1'b1) begin
               reg_intrPriStat[24]  <= 1'b0;
            end
            if(cmd2reg_wrData[25] == 1'b1) begin
               reg_intrPriStat[25]  <= 1'b0;
            end
            if(cmd2reg_wrData[26] == 1'b1) begin
               reg_intrPriStat[26]  <= 1'b0;
            end
            if(cmd2reg_wrData[27] == 1'b1) begin
               reg_intrPriStat[27]  <= 1'b0;
            end
            if(cmd2reg_wrData[28] == 1'b1) begin
               reg_intrPriStat[28]  <= 1'b0;
            end
            if(cmd2reg_wrData[29] == 1'b1) begin
               reg_intrPriStat[29]  <= 1'b0;
            end
            if(cmd2reg_wrData[30] == 1'b1) begin
               reg_intrPriStat[30]  <= 1'b0;
            end
            if(cmd2reg_wrData[31] == 1'b1) begin
               reg_intrPriStat[31]  <= 1'b0;
            end
         end
      end
   end  

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_intrSecStat            <= {32{1'b0}};
      end
      else begin
         if(frmCntr2reg_sofSent == 1'b1)begin
            reg_intrSecStat[20]     <= 1'b1;
         end
         else if(frmCntr2reg_sofRcvd == 1'b1) begin
            reg_intrSecStat[17]     <= 1'b1;
         end
         else if(frmCntr2reg_eof1Hit == 1'b1)begin
            reg_intrSecStat[21]     <= 1'b1;
         end
         else if(wren_intrSecStat == 1'b1)begin
            if(cmd2reg_wrData[0] == 1'b1)begin
               reg_intrSecStat[0]   <= 1'b0;
            end
            else if(cmd2reg_wrData[1] == 1'b1) begin
               reg_intrSecStat[1]   <= 1'b0;
            end
            else if(cmd2reg_wrData[2] == 1'b1) begin
               reg_intrSecStat[2]   <= 1'b0;
            end
            else if(cmd2reg_wrData[3] == 1'b1) begin
               reg_intrSecStat[3]   <= 1'b0;
            end
            else if(cmd2reg_wrData[4] == 1'b1) begin
               reg_intrSecStat[4]   <= 1'b0;
            end
            else if(cmd2reg_wrData[5] == 1'b1) begin
               reg_intrSecStat[5]   <= 1'b0;
            end
            else if(cmd2reg_wrData[6] == 1'b1) begin
               reg_intrSecStat[6]   <= 1'b0;
            end
            else if(cmd2reg_wrData[7] == 1'b1) begin
               reg_intrSecStat[7]   <= 1'b0;
            end
            else if(cmd2reg_wrData[8] == 1'b1) begin
               reg_intrSecStat[8]   <= 1'b0;
            end
            else if(cmd2reg_wrData[9] == 1'b1) begin
               reg_intrSecStat[9]   <= 1'b0;
            end
            else if(cmd2reg_wrData[10] == 1'b1) begin
               reg_intrSecStat[10]  <= 1'b0;
            end
            else if(cmd2reg_wrData[11] == 1'b1) begin
               reg_intrSecStat[11]  <= 1'b0;
            end
            else if(cmd2reg_wrData[12] == 1'b1) begin
               reg_intrSecStat[12]  <= 1'b0;
            end
            else if(cmd2reg_wrData[13] == 1'b1) begin
               reg_intrSecStat[13]  <= 1'b0;
            end
            else if(cmd2reg_wrData[14] == 1'b1) begin
               reg_intrSecStat[14]  <= 1'b0;
            end
            else if(cmd2reg_wrData[15] == 1'b1) begin
               reg_intrSecStat[15]  <= 1'b0;
            end
            else if(cmd2reg_wrData[16] == 1'b1) begin
               reg_intrSecStat[16]  <= 1'b0;
            end
            else if(cmd2reg_wrData[17] == 1'b1) begin
               reg_intrSecStat[17]  <= 1'b0;
            end
            else if(cmd2reg_wrData[18] == 1'b1) begin
               reg_intrSecStat[18]  <= 1'b0;
            end
            else if(cmd2reg_wrData[19] == 1'b1) begin
               reg_intrSecStat[19]  <= 1'b0;
            end
            else if(cmd2reg_wrData[20] == 1'b1) begin
               reg_intrSecStat[20]  <= 1'b0;
            end
            else if(cmd2reg_wrData[21] == 1'b1) begin
               reg_intrSecStat[21]  <= 1'b0;
            end
            else if(cmd2reg_wrData[22] == 1'b1) begin
               reg_intrSecStat[22]  <= 1'b0;
            end
            else if(cmd2reg_wrData[23] == 1'b1) begin
               reg_intrSecStat[23]  <= 1'b0;
            end
            else if(cmd2reg_wrData[24] == 1'b1) begin
               reg_intrSecStat[24]  <= 1'b0;
            end
            else if(cmd2reg_wrData[25] == 1'b1) begin
               reg_intrSecStat[25]  <= 1'b0;
            end
            else if(cmd2reg_wrData[26] == 1'b1) begin
               reg_intrSecStat[26]  <= 1'b0;
            end
            else if(cmd2reg_wrData[27] == 1'b1) begin
               reg_intrSecStat[27]  <= 1'b0;
            end
            else if(cmd2reg_wrData[28] == 1'b1) begin
               reg_intrSecStat[28]  <= 1'b0;
            end
            else if(cmd2reg_wrData[29] == 1'b1) begin
               reg_intrSecStat[29]  <= 1'b0;
            end
            else if(cmd2reg_wrData[30] == 1'b1) begin
               reg_intrSecStat[30]  <= 1'b0;
            end
            else if(cmd2reg_wrData[31] == 1'b1) begin
               reg_intrSecStat[31]  <= 1'b0;
            end
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_intrPriData1           <= {32{1'b0}};
      end
      else begin
         if(wren_intrPriData1 == 1'b1)begin
            reg_intrPriData1        <= cmd2reg_wrData ;
         end
         else if(epct2reg_zlpSent)begin
            reg_intrPriData1[23:20] <= epct2reg_epNum ;
         end
         else if(epct2reg_dpSend)begin
            reg_intrPriData1[19:16] <= epct2reg_epNum ;
         end
         else if(epcr2reg_zlpRcvd)begin
            reg_intrPriData1[11:8]  <= epcr2reg_epNum ;
         end
         else if(epcr2reg_setupRcvd)begin
            reg_intrPriData1[7:4]   <= epcr2reg_epNum ;
         end
         else if(epcr2reg_dpRcvd)begin
            reg_intrPriData1[3:0]   <= epcr2reg_epNum ;
         end
         else begin
            reg_intrPriData1        <= reg_intrPriData1;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_intrPriData2           <= {32{1'b0}};
      end
      else begin
         if(wren_intrPriData2 == 1'b1)begin
            reg_intrPriData2        <= cmd2reg_wrData;
         end
         else if(pe2reg_remoteWakeUp) begin        //TODO added by Lalit for LPM remote wakeup, 20/05/2013
            reg_intrPriData2[22]    <= 1'b1;
         end
         else begin
            reg_intrPriData2        <= reg_intrPriData2;
         end
      end
   end
  
   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_intrSecData1           <= {32{1'b0}};
      end
      else begin
         if(wren_intrSecData1 == 1'b1)begin
            reg_intrSecData1        <= cmd2reg_wrData;
         end
         else begin
            reg_intrSecData1        <= reg_intrSecData1;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_intrSecData2           <= {32{1'b0}};
      end
      else begin
         if(wren_intrSecData2 == 1'b1)begin
            reg_intrSecData2        <= cmd2reg_wrData;
         end
         else begin
            reg_intrSecData2        <= reg_intrSecData2;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_testCtrl               <= {32{1'b0}};
      end
      else begin
         if(wren_testCtrl == 1'b1)begin
            reg_testCtrl            <= cmd2reg_wrData;
         end
         else begin
            reg_testCtrl            <= reg_testCtrl;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_usbTransctrl           <= {32{1'b0}};
         reg2pe_enOTGTrans          <= 1'b0;
         reg2pa_tokenValid          <= 1'b0;
      end
      else begin
         if(wren_usbTransctrl == 1'b1)begin
            reg_usbTransctrl        <= cmd2reg_wrData;
            reg2pe_enOTGTrans       <= 1'b1;
            reg2pa_tokenValid       <= 1'b1;
         end
         else begin
            reg_usbTransctrl        <= reg_usbTransctrl;
            reg2pe_enOTGTrans       <= 1'b0;
            reg2pa_tokenValid       <= 1'b0;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_usbTransTxData1        <= {32{1'b0}};
      end
      else begin
         if(wren_usbTransTxData1 == 1'b1)begin
            reg_usbTransTxData1     <=cmd2reg_wrData;
         end
         else begin
            reg_usbTransTxData1     <= reg_usbTransTxData1;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_usbTransTxData2        <= {32{1'b0}};
      end
      else begin
         if(wren_usbTransTxData2 == 1'b1)begin
            reg_usbTransTxData2     <= cmd2reg_wrData;
         end
         else begin
            reg_usbTransTxData2     <= reg_usbTransTxData2;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_usbTransTxData3        <= {32{1'b0}};
      end
      else begin
         if(wren_usbTransTxData3 == 1'b1)begin
            reg_usbTransTxData3     <= cmd2reg_wrData;
         end
         else begin
            reg_usbTransTxData3     <=   reg_usbTransTxData3;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_usbTransRxData1        <= {32{1'b0}};
      end
      else begin
         if(wren_usbTransRxData1 == 1'b1)begin
            reg_usbTransRxData1     <= cmd2reg_wrData;
         end
         else begin
            reg_usbTransRxData1     <= reg_usbTransRxData1;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_usbTransRxData2        <= {32{1'b0}};
      end
      else begin
         if(wren_usbTransRxData2 == 1'b1)begin
            reg_usbTransRxData2     <= cmd2reg_wrData;
         end
         else begin
            reg_usbTransRxData2     <= reg_usbTransRxData2;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_usbTransRxData3        <= {32{1'b0}};
      end
      else begin
         if(wren_usbTransRxData3 == 1'b1)begin
            reg_usbTransRxData3     <= cmd2reg_wrData;
         end
         else begin
            reg_usbTransRxData3     <= reg_usbTransRxData3;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl1               <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl1 == 1'b1)begin
            reg_tmrCtrl1            <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl1            <= reg_tmrCtrl1;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl2               <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl2 == 1'b1)begin
            reg_tmrCtrl2            <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl2            <= reg_tmrCtrl2;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl3               <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl3 == 1'b1)begin
            reg_tmrCtrl3            <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl3            <= reg_tmrCtrl3;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl4               <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl4 == 1'b1)begin
            reg_tmrCtrl4            <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl4            <= reg_tmrCtrl4;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl5               <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl5 == 1'b1)begin
            reg_tmrCtrl5            <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl5            <= reg_tmrCtrl5;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl6               <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl6 == 1'b1)begin
            reg_tmrCtrl6            <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl6            <= reg_tmrCtrl6;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl7               <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl7 == 1'b1)begin
            reg_tmrCtrl7            <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl7            <= reg_tmrCtrl7;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl8               <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl8 == 1'b1)begin
            reg_tmrCtrl8            <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl8            <= reg_tmrCtrl8;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl9               <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl9 == 1'b1)begin
            reg_tmrCtrl9            <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl9            <= reg_tmrCtrl9;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl10              <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl10 == 1'b1)begin
            reg_tmrCtrl10           <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl10           <= reg_tmrCtrl10;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl11              <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl11 == 1'b1)begin
            reg_tmrCtrl11           <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl11           <= reg_tmrCtrl11;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl12              <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl12 == 1'b1)begin
            reg_tmrCtrl12           <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl12           <= reg_tmrCtrl12;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl13              <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl13 == 1'b1)begin
            reg_tmrCtrl13           <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl13           <= reg_tmrCtrl13;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl14              <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl14 == 1'b1)begin
            reg_tmrCtrl14           <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl14           <= reg_tmrCtrl14;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl15              <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl15 == 1'b1)begin
            reg_tmrCtrl15           <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl15           <= reg_tmrCtrl15;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl16              <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl16 == 1'b1)begin
            reg_tmrCtrl16           <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl16           <= reg_tmrCtrl16;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl17              <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl17 == 1'b1)begin
            reg_tmrCtrl17           <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl17           <= reg_tmrCtrl17;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl18              <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl18 == 1'b1)begin
            reg_tmrCtrl18           <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl18           <= reg_tmrCtrl18;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl19              <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl19 == 1'b1)begin
            reg_tmrCtrl19           <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl19           <= reg_tmrCtrl19;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_tmrCtrl20              <= {32{1'b0}};
      end
      else begin
         if(wren_tmrCtrl20 == 1'b1)begin
            reg_tmrCtrl20           <= cmd2reg_wrData;
         end
         else begin
            reg_tmrCtrl20           <= reg_tmrCtrl20;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_sofCnt                 <= {32{1'b0}};
      end
      else begin
         if(wren_sofCnt == 1'b1)begin
            reg_sofCnt              <= cmd2reg_wrData;
         end
         else if(frmCntr2reg_frameCntVl == 1'b1)begin
            reg_sofCnt              <= {reg_sofCnt[31:27],frmCntr2reg_frameCount,reg_sofCnt[15:0]};
         end
         else begin
            reg_sofCnt              <= reg_sofCnt;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_sofCtrl                <= {32{1'b0}};
      end
      else begin
         if(wren_sofCtrl == 1'b1)begin
            reg_sofCtrl             <= cmd2reg_wrData;
         end
         else begin
            reg_sofCtrl             <= reg_sofCtrl;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg2frmCntr_ldTimerStVal   <= 1'b0      ;
         reg_sofTmrEn               <= {32{1'b0}};
      end
      else begin
         if(wren_sofTmrEn == 1'b1)begin
            reg_sofTmrEn               <= cmd2reg_wrData;
            reg2frmCntr_ldTimerStVal   <= 1'b1      ;
         end
         else begin
            reg_sofTmrEn               <= reg_sofTmrEn;
            reg2frmCntr_ldTimerStVal   <= 1'b0      ;
         end
      end
   end     

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_setupCmd1              <= {32{1'b0}};
      end
      else begin
         if(wren_setupCmd1 == 1'b1)begin
            reg_setupCmd1           <= cmd2reg_wrData;
         end
         else if((epcr2reg_setupWrReq == 1'b1)&&(epcr2reg_setupRegIndex == 1'b0))begin
            reg_setupCmd1           <= epcr2reg_setupData;
         end
         else begin
            reg_setupCmd1           <= reg_setupCmd1;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_setupCmd2              <= {32{1'b0}};
      end
      else begin
         if(wren_setupCmd2 == 1'b1)begin
            reg_setupCmd2           <= cmd2reg_wrData;
         end
         else if((epcr2reg_setupWrReq == 1'b1)&&(epcr2reg_setupRegIndex == 1'b1))begin
            reg_setupCmd2           <=epcr2reg_setupData;
         end
         else begin
            reg_setupCmd2           <= reg_setupCmd2;
         end
      end
   end

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg_memSegAddr             <= {32{1'b0}};
      end
      else begin
         if(wren_memSegAddr == 1'b1)begin
            reg_memSegAddr          <= cmd2reg_wrData;
         end
         else begin
            reg_memSegAddr          <= reg_memSegAddr;
         end
      end
   end

   // --------------------------------------------------
   //  output data registered
   // --------------------------------------------------
   always @(*) begin
         if(rden_sus == 1'b1)begin
            reg2cmd_rdData       = reg_sus            ;
         end
         
         else if(rden_devCtrl1 == 1'b1)begin
            reg2cmd_rdData       = reg_devCtrl1       ;
         end
         
         else if(rden_devCtrl2 == 1'b1)begin
            reg2cmd_rdData       = reg_devCtrl2       ;
         end
         
         else if(rden_devStat1 == 1'b1)begin
            reg2cmd_rdData       = reg_devStat1       ;
         end

         else if(rden_devStat2 == 1'b1)begin
            reg2cmd_rdData       = reg_devStat2       ;
         end
         
         else if(rden_cEpCmd == 1'b1)begin
            reg2cmd_rdData       = reg_cEpCmd         ;
         end
         
         else if(rden_cEpRdAddr == 1'b1)begin
            reg2cmd_rdData       = reg_cEpRdAddr      ;
         end

         else if(rden_dmaTxAddr == 1'b1)begin
            reg2cmd_rdData       = reg_dmaTxAddr      ;
         end
         
         else if(rden_cEpWrAddr == 1'b1)begin
            reg2cmd_rdData       = reg_cEpWrAddr      ;
         end
         
         else if(rden_eBufTxCtrl1 == 1'b1)begin
            reg2cmd_rdData       = reg_eBufTxCtrl1    ;
         end
         
         else if(rden_eBufTxCtrl2 == 1'b1)begin
            reg2cmd_rdData       = reg_eBufTxCtrl2    ;
         end
         
         else if(rden_dmaRxAddr == 1'b1)begin
            reg2cmd_rdData       = reg_dmaRxAddr      ;
         end
         
         else if(rden_eBufRxCtrl1 == 1'b1)begin
            reg2cmd_rdData       = reg_eBufRxCtrl1    ;
         end
         
         else if(rden_eBufRxCtrl2 == 1'b1)begin
            reg2cmd_rdData       = reg_eBufRxCtrl2    ;
         end
         
         else if(rden_intrPriMask == 1'b1)begin
            reg2cmd_rdData       = reg_intrPriMask    ;
         end
         
         else if(rden_intrSecMask == 1'b1)begin
            reg2cmd_rdData       = reg_intrSecMask    ;
         end
         
         else if(rden_intrPriStat == 1'b1)begin
            reg2cmd_rdData       = reg_intrPriStat    ;
         end
         
         else if(rden_intrSecStat == 1'b1)begin
            reg2cmd_rdData       = reg_intrSecStat    ;
         end
         
         else if(rden_intrPriData1 == 1'b1)begin
            reg2cmd_rdData       = reg_intrPriData1   ;
         end
         
         else if(rden_intrPriData2 == 1'b1)begin
            reg2cmd_rdData       = reg_intrPriData2   ;
         end
         
         else if(rden_intrSecData1 == 1'b1)begin
            reg2cmd_rdData       = reg_intrSecData1   ;
         end
         
         else if(rden_intrSecData2 == 1'b1)begin
            reg2cmd_rdData       = reg_intrSecData2   ;
         end
         
         else if(rden_testCtrl == 1'b1)begin
            reg2cmd_rdData       = reg_testCtrl       ;
         end
         
         else if(rden_usbTransctrl == 1'b1)begin
            reg2cmd_rdData       = reg_usbTransctrl   ;
         end
         
         else if(rden_usbTransTxData1 == 1'b1)begin
            reg2cmd_rdData       = reg_usbTransTxData1;
         end
         
         else if(rden_usbTransTxData2 == 1'b1)begin
            reg2cmd_rdData       = reg_usbTransTxData2;
         end
         
         else if(rden_usbTransTxData3 == 1'b1)begin
            reg2cmd_rdData       = reg_usbTransTxData3;
         end
         
         else if(rden_usbTransRxData1 == 1'b1)begin
            reg2cmd_rdData       =reg_usbTransRxData1 ;
         end
         
         else if(rden_usbTransRxData2 == 1'b1)begin
            reg2cmd_rdData       = reg_usbTransRxData2;
         end
         
         else if(rden_usbTransRxData3 == 1'b1)begin
            reg2cmd_rdData       = reg_usbTransRxData3;
         end
  
         else if(rden_tmrCtrl1 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl1       ;
         end
         
         else if(rden_tmrCtrl2 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl2       ;
         end
         
         else if(rden_tmrCtrl3 == 1'b1)begin
            reg2cmd_rdData       =reg_tmrCtrl3        ;
         end
         
         else if(rden_tmrCtrl4 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl4       ;
         end
         
         else if(rden_tmrCtrl5 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl5       ;
         end
         else if(rden_tmrCtrl6 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl6       ;
         end
         
         else if(rden_tmrCtrl7 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl7       ;
         end
         
         else if(rden_tmrCtrl8 == 1'b1)begin
            reg2cmd_rdData       =reg_tmrCtrl8        ;
         end
         
         else if(rden_tmrCtrl9 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl9       ;
         end
         
         else if(rden_tmrCtrl10 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl10      ;
         end
         else if(rden_tmrCtrl11 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl11      ;
         end
         
         else if(rden_tmrCtrl12 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl12      ;
         end
         
         else if(rden_tmrCtrl13 == 1'b1)begin
            reg2cmd_rdData       =reg_tmrCtrl13       ;
         end
         
         else if(rden_tmrCtrl14 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl14      ;
         end
         
         else if(rden_tmrCtrl15 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl15      ;
         end

         else if(rden_tmrCtrl16 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl16      ;
         end
         
         else if(rden_tmrCtrl17 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl17      ;
         end
         
         else if(rden_tmrCtrl18 == 1'b1)begin
            reg2cmd_rdData       =reg_tmrCtrl18       ;
         end
         
         else if(rden_tmrCtrl19 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl19      ;
         end
         
         else if(rden_tmrCtrl20 == 1'b1)begin
            reg2cmd_rdData       = reg_tmrCtrl20      ;
         end

         else if(rden_sofCnt == 1'b1)begin
            reg2cmd_rdData       = reg_sofCnt         ;
         end
         
         else if(rden_sofCtrl == 1'b1)begin
            reg2cmd_rdData       = reg_sofCtrl        ;
         end
         
         else if(rden_sofTmrEn == 1'b1)begin
            reg2cmd_rdData       =reg_sofTmrEn        ;
         end
         
         else if(rden_setupCmd1 == 1'b1)begin
            reg2cmd_rdData       = reg_setupCmd1      ;
         end
         
         else if(rden_setupCmd2 == 1'b1)begin
            reg2cmd_rdData       = reg_setupCmd2      ;
         end

         else if(rden_rst == 1'b1)begin
            reg2cmd_rdData       = reg_rst            ;
         end
         
         else if(rden_memSegAddr == 1'b1)begin
            reg2cmd_rdData       = reg_memSegAddr     ;
         end
       else begin
                reg2cmd_rdData ={32{1'b0}};
        end
      end


   /********************************************************************/
   // Interrupt logic
   /********************************************************************/
   assign  intrSecMaskNStat   = reg_intrSecStat & ~(reg_intrSecMask) ;
   assign  intrSecOR          = |intrSecMaskNStat                    ;
   assign  intrPriMaskNStat   = reg_intrPriStat & ~(reg_intrPriMask) ; 
   assign  intrPriOR          = |intrPriMaskNStat                    ;
   assign  intr_nxt           = intrPriOR  | intrSecOR               ;

   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         intrReq               <= 1'b0     ;
      end
      else begin
         intrReq               <= intr_nxt ;
      end
   end

   // --------------------------------------------------
   //  dma output
   // --------------------------------------------------
   assign reg2sepr_sWrAddr     = reg_dmaRxAddr             ;
   assign reg2sept_sRdAddr     = reg_dmaTxAddr             ;

   // ----------------------------------------------
   // EPCR (endpoint controller rx)     
   // ----------------------------------------------
   assign   reg2epcr_enuCmdEn   = 1'b1                      ; //TODO to be asked this bit is missing as per suresh it should be 1 all time
   assign   reg2epcr_EnuAct     = reg_cEpCmd[1:0]           ;
   assign   reg2epcr_descLen    = reg_cEpCmd[31:16]         ; 
   assign   reg2epcr_descAddr   = reg_cEpWrAddr             ;
   assign   reg2epcr_stall      = reg_cEpCmd[2]             ;
   assign   reg2epcr_rwCtlrType = reg_cEpCmd[3]             ; 
   assign   reg2epc_setupLen    = reg_setupCmd2[31:16]      ;

   // ---------------------------------------------
   // EPCT (endpoint controller tx)       
   // ---------------------------------------------
   assign  reg2epct_enuCmdEn    = 1'b1                      ; //TODO to be asked this bit is missing as per suresh it should be 1 all time
   assign  reg2epct_EnuAct      = reg_cEpCmd[1:0]           ;
   assign  reg2epct_descLen     = reg_cEpCmd[31:16]         ; 
   assign  reg2epct_descAddr    = reg_cEpRdAddr             ;
   assign  reg2epct_stall       = reg_cEpCmd[2]             ;
   assign  reg2epct_rwCtlrType  = reg_cEpCmd[3]             ; 

   // -----------------------------------------------------------------
   // protocol engine
   // -----------------------------------------------------------------
   assign   reg2pe_enHost       = reg_devCtrl1[30]          ;
   assign   reg2pe_epNum        = reg_usbTransctrl[31:28]   ; 
   assign   reg2pe_devHalt      = reg_devCtrl1[31]          ; //TODO need to check if it is endpoint halt bit missing from devctrl it should be removed
   assign   reg2pe_tokenType    = reg_usbTransctrl[26:22]   ; 
   assign   reg2pe_usbMode      = reg_devCtrl1[29:27]       ;

   // -------------------------------------------
   // system controller rx
   // -------------------------------------------
   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg2sctrlRx_rd        <= 1'b0;
      end
      else if((reg_eBufRxCtrl2[1:0] == 2'b11) && (eBufRxCtrl2_ld == 1'b1))begin
         reg2sctrlRx_rd         <= 1'b1;
      end
      else begin
         reg2sctrlRx_rd         <= 1'b0;
      end 
   end
   assign   reg2sctrlRx_listMode    = reg_eBufRxCtrl1[24]       ;
   assign   reg2sctrlRx_rdCount     = reg_eBufRxCtrl1[3:0]      ;
   assign   reg2sctrlRx_epNum       = reg_eBufRxCtrl1[31:28]    ;
   assign   reg2sepr_dmaMode        = reg_eBufRxCtrl1[23:21]    ;

   //----------------------------------------------
   // system controller tx              
   //----------------------------------------------      
   always @(posedge uctl_SysClk, negedge uctl_SysRst_n) begin
      if(!uctl_SysRst_n) begin
         reg2sctrlTx_wr        <= 1'b0;
      end
      else if((reg_eBufTxCtrl2[1:0] == 2'b11) && (eBufTxCtrl2_ld == 1'b1))begin
         reg2sctrlTx_wr         <= 1'b1;
      end
      else begin
         reg2sctrlTx_wr         <= 1'b0;
      end 
   end    
   assign   reg2sctrlTx_listMode    = reg_eBufTxCtrl1[24]       ;
   assign   reg2sctrlTx_wrPktLength = reg_eBufTxCtrl1[19:0]     ;
   assign   reg2sctrlTx_epNum       = reg_eBufTxCtrl1[31:28]    ;
   assign   reg2sctrlTx_disFrag     = reg_eBufTxCtrl1[20]       ;
   assign   reg2sept_dmaMode        = reg_eBufTxCtrl1[23:21]    ;

   //----------------------------------------------
   // frame counter interface       
   //----------------------------------------------   
   assign reg2frmCntr_upCntMax      =  reg_sofCtrl[31:12]       ; 
   assign reg2frmCntr_timerCorr     =  reg_sofCtrl[11:8]        ; 
   assign reg2frmCntr_eof1          =  reg_sofTmrEn[29:20]      ; 
   assign reg2frmCntr_eof2          =  reg_sofCtrl[7:0]         ; 
   assign reg2frmCntr_enAutoSof     =  reg_sofTmrEn[31]         ; 
   assign reg2frmCntr_autoLd        =  reg_sofTmrEn[30]         ; 
   assign reg2frmCntr_timerStVal    =  reg_sofTmrEn[19:0]       ; 

   //----------------------------------------------
   // packet decoder        
   //----------------------------------------------   
   assign   reg2pd_dataBus16_8      =  reg_devCtrl1[17]         ;
   assign   reg2pd_devId            =  reg_devCtrl1[7:1]        ;

   //----------------------------------------------  
   // packet assembler        
   //----------------------------------------------    
   assign   reg2pa_tokenType        = reg_usbTransctrl[25:22]   ;
   assign   reg2pa_epNum            = reg_usbTransctrl[31:28]   ;
   assign   reg2pa_devID            = reg_devCtrl1[7:1]         ;
   assign   reg2pa_frameNum         = reg_sofCnt[26:16]         ; 
   assign   reg2pa_dataBus16_8      = reg_devCtrl1[17]          ;
   assign   reg2cmdIf_memSegAddr    = reg_memSegAddr[31:10]     ;
endmodule
