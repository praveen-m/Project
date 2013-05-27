`timescale 1ns / 1ps
//-------------------------------------------------------------------
// Copyright � 2013 TECHVULCAN, Inc. All rights reserved.		   
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, nor	   
// its contents							   
// revealed in any manner to others without the express written	   
// permission	of TechVulcan 					   
// Licensed Material.						   
// Program Property of TECHVULCAN Incorporated.	
// ------------------------------------------------------------------
// DATE		   	: Thu, 07 Mar 2013 11:31:50
// AUTHOR	      : Lalit Kumar 
// AUTHOR EMAIL	: lalit.kumar@techvulcan.com 
// FILE NAME		: usb_controller_core
// Version no.    : 0.5
//-------------------------------------------------------------------


/*
updates and fixes in 0.5
   register interface has been added
updates and fixes in 0.4

updates and fixes in 0.4
1. new uctl_frameCounter block
   has been added
2. signals for  initialization of data PID on 
   SOF boundary have been added.
 
fixes in  0.3
 signals between PE-register block,
 epcr-eptd have been added 
 some signals(core reset & clk, fifo_avail_space) are added on ahbMaster and DmaRx instantiations

fixes in 0.2
 new signal is added epcr2pe_hwStall         


`include "uctl_packet_decoder.v"
`include "uctl_protocol_engine.v" 
`include "uctl_epcr.v"            
`include "uctl_epct.v"            
`include "uctl_eptd.v"            
`include "uctl_sept.v"            
`include "uctl_sysControllerTx.v" 
`include "uctl_sepr.v"            
`include "uctl_sysControllerRx.v" 
`include "uctl_dmaRx.v"           
`include "uctl_registerBlock.v"   
`include "uctl_packet_assembler.v" 
`include "uctl_cmdIfReg.v"          
`include "uctl_cmdIfMif.v"          
`include "uctl_ahbMaster.v"       
`include "uctl_dmaTx.v"           
`include "syncFifo.v"
`include "async_fifo.v"
`include "uctl_ahbCore.v"
`include "ctrl_ahbRx.v" 
`include "ctrl_ahbTx.v" 
`include "uctl_ahbSlave.v"
`include "uctl_crc5Gen.v"
`include "crc5_chkr.v"
`include "uctl_sysCmdMemRW.v"
*/

module usb_controller_core #(
   parameter   EXT_AHBM_EN          = 1 ,
               EXT_AHBS_EN          = 1 ,
               EXT_AXIM_EN          = 0 ,
               EXT_AXIS_EN          = 0 ,
               ADDR_SIZE            = 32,
               CNTR_WD              = 20,                               
               REGISTER_EPDATA      = 0 ,           
               DATA_SIZE            = 32,
               SOF_DNCOUNTER_WD     = 16,
               GLITCH_CNTR_WD       = 4 ,
               SOF_UPCOUNTER_WD     = 20
)(
   // ***************************************************************************************************
   // Global signals
   // ***************************************************************************************************
   input  wire                        uctl_PhyClk         , //The transceiver clock used to run the logic
                                                            // close to the USB Phy interface
   input  wire                        uctl_CoreClk        , //The core clock used to clock most of the logic
                                                            // inside the controller
   input  wire                        uctl_SysClk         , //System clock - used to clock the AXI/AHB 
                                                            // interfaces
   input wire                         uctl_PhyRst_n       ,
   input wire                         uctl_CoreRst_n      ,
   input wire                         uctl_SysRst_n       ,
   // ***************************************************************************************************
   // Interrupt
   // ***************************************************************************************************
   output wire                        uctl_irq            , // level Interrupt  TODO
 

   // ***************************************************************************************************
   // register  
   // ***************************************************************************************************
   output  wire                        uctl_powerDown         , //0: device is in not power down, 
                                                                //1: device is in power down mode           
   output  wire  [GLITCH_CNTR_WD -1:0] uctl_glitchFilterCount , // umber of aon clock cycle for which linse state 
                                                                // should be stable to dtect a change


   // ***************************************************************************************************
   // UTMI interface
   // ***************************************************************************************************
   output wire                        uctl_UtmiReset      , //Reset for the Transceiver registers - active TODO
                                                            // High signal
   output wire [2               -1:0] uctl_UtmiXcvrSelect , //Selects the LS/FS/HS transceiver TODO
                                                            // 00 : HS transceiver selected
                                                            // 01 : FS transceiver selected
                                                            // 10 : LS transceiver selected
                                                            // 11 : Send or receive a LS packet on FS bus
   output wire                        uctl_UtmiTermSelect , //Termination select :     TODO
                                                            // 0 : HS termination enabled
                                                            // 1 : FS termination enabled
   output wire                        uctl_UtmiSuspend_N  , //Active low suspend signal to the Transceiver TODO
   input  wire [2               -1:0] uctl_UtmiLineState  , //These signals reflect the current state of the   TODO
                                                            // single ended receiver
                                                            // 00 : SE0
                                                            // 01 : J state
                                                            // 10 : K state
                                                            // 11 : SE1

   output wire [2               -1:0] uctl_UtmiOpMode     , //Select the various operational modes    TODO
                                                            // 00 : Normal operation
                                                            // 01 : Non driving
                                                            // 10 : Disable bit stuffing and NRZI coding
                                                            // 11 : Normal operation without automatic
                                                            // generation of SYNC and EOP. NRZI is
                                                            // enabled and bit stuffing depends on
                                                            // TxBitstuffEnable and TxBitstuffEnableH. This
                                                            // mode is valid only when XcvrSelect = 00.
   output wire [8               -1:0] uctl_UtmiTxData     , //8-bit parallel transmit data into the
                                                            // Transceiver
   output wire [8               -1:0] uctl_UtmiTxDataH    , //Upper byte of the transmit data when
                                                            // enabled (DataBus16_8 = 1). This along with
                                                            // the TxData bus form the complete data in
                                                            // the 16-bit mode.
   output wire                        uctl_UtmiTxValid    , //This active high signal indicates that the
                                                            // data on the TxData bus is valid. The
                                                            // transceiver starts the SYNC transmission
                                                            // when this signal is HIGH
   output wire                        uctl_UtmiTxValidH   , //This active high signal indicates that the
                                                            // data on the TxDataH bus is valid. This is
                                                            // used for 16-bit data transfer
   input  wire                        uctl_UtmiTxReady    , //When this signal is sampled high on a clock
                                                            // edge, it means that the data on the TxData
                                                            // busses has been latched into the Transceiver
   input  wire [8               -1:0] uctl_UtmiRxData     , //The 8-bit receive data during a USB receive
                                                            // transmission. This will be the lower byte
                                                            // when operating in the 16-bit mode.
   input  wire [8               -1:0] uctl_UtmiRxDataH    , //The upper byte of the receive data when the
                                                            // 16-bit transfer mode is enabled
   input  wire                        uctl_UtmiRxValid    , //WHen active high, the RxData bus has a
                                                            // valid 8-bit data.
   input  wire                        uctl_UtmiRxValidH   , //WHen active high, the RxDataH bus has a
                                                            // valid 8-bit data that forms the upper byte in
                                                            // the 16-bit transfer mode



   input  wire                        uctl_UtmiRxActive   , //This active high signal indicates that a
                                                            // SYNC has been detected at the USB bus. It
                                                            // stays high during the entire packet and goes
                                                            // low when a EOP or bit-stuff error is
                                                            // encountered.
   input  wire                        uctl_UtmiRxError    , //0: No receive error
                                                            // 1: Receive error detected
   output wire                        uctl_UtmiDataBus16_8N,//Selects between 8-bit and 16-bit transfer //TODO  from pd or reg block 
                                                            // modes.
                                                            // 1 : 16-bit data path operation enabled
                                                            // 0 : 8-bit data path operation enabled
   output wire                        uctl_UtmiIdPullup   , //Enable sampling of the analog Id pin TODO
                                                            // 0 : Sampling is disabled - IdDig is not valid
                                                            // 1 : Sampling of Id pin is enabled
   input  wire                        uctl_UtmiIdDig      , //Indicates whether the connected plug is a Aplug TODO
                                                            // or B-plug.
                                                            // 0 : A-plug is connected and hence the
                                                            // device is an OTG A device
                                                            // 1 : B-plug is connected and hence the
                                                            // device is an OTG B device
   input  wire                        uctl_UtmiAvalid     , //Indicates if the session for an A-device is valid TODO
                                                            // 0 : Vbus < 0.8V
                                                            // 1 : Vbus > 2V
   input  wire                        uctl_UtmiBvalid     , //Indicates if the session for a B-device is valid TODO
                                                            // 0 : Vbus < 0.8V
                                                            // 1 : Vbus > 4V
   input  wire                        uctl_UtmiVbusValid  , //Indicates if the voltage on Vbus is at a valid  TODO
                                                            // level for operation
                                                            // 0 : Vbus < 4.4V
                                                            // 1 : Vbus > 4.75V
   input  wire                        uctl_UtmiSessionEnd , //Indicates if the voltage on Vbus is below its TODO
                                                            // B-device Session End threshold
                                                            // 1 : Vbus < 0.2V
                                                            // 0 : Vbus > 0.8V
   output wire                        uctl_UtmiDrvVbus    , //This enables the Transceiver to drive 5V on Vbus TODO
                                                            // 0 : do not drive Vbus
                                                            // 1 : drive 5V on Vbus


   output wire                        uctl_UtmiDischrgVbus, //This signal enables discharging of Vbus TODO
                                                            // prior to SRP
                                                            // 1 : discharge Vbus through a resistor (need
                                                            // at least 50ms)
                                                            // 0 : do not discharge Vbus
   output wire                        uctl_UtmiChrgVbus   , //This signal enables charging of Vbus prior to TODO
                                                            // SRP
                                                            // 1 : charge Vbus through a resistor (need at
                                                            // least 30ms)
                                                            // 0 : do not charge Vbus
   output wire                        uctl_UtmiDpPulldown , //This signal enables the 15K pulldown TODO
                                                            // resistor on the DP line
                                                            // 0 : Pull-down resistor not connected to DP
                                                            // 1 : Pull-down resistor connected to DP line
   output wire                        uctl_UtmiDmPulldown , //This signal enables the 15K pulldown TODO
                                                            // resistor on the DM line
                                                            // 0 : Pull-down resistor not connected to DM
                                                            // 1 : Pull-down resistor connected to DM line
   input  wire                        uctl_UtmiHostDisconnect, //This indicates whether a peripheral TODO
                                                            // connected to the host has been
                                                            // disconnected.
                                                            // 0 : A peripheral device is connected to the
                                                            // OTG host
                                                            // 1 : No device is connected
   output wire                        uctl_UtmiTxBitstuffEnable,//Indicates if data on TxData bus is to be TODO 
                                                            // bitstuffed or not
                                                            // 0 : Bit-stuffing is disabled
                                                            // 1 : Bit-stuffing is enabled
   output wire                        uctl_UtmiTxBitstuffEnableH,//Indicates if data on TxDataH bus is to be  TODO
                                                            // bitstuffed or not
                                                            // 0 : Bit-stuffing is disabled
                                                            // 1 : Bit-stuffing is enabled


   // ***************************************************************************************************
   // USB3.0 PIPE Interface
   // ***************************************************************************************************
   input  wire [32              -1:0] uctl_PipeTxData     , //The parallel USB SS Transmit data bus. This
                                                            // could be 8bit, 16bit or 32bit.

   input  wire [4               -1:0] uctl_PipeTxDataK    , //The byte enable signals for each byte lane of
                                                            // the 32-bit Tx data bus.
   output wire [32              -1:0] uctl_PipeRxData     , //The parallel USB SS Receive data bus. This
                                                            // could be 8bit, 16bit or 32bit.
   output wire [4               -1:0] uctl_PipeRxDataK    , //The byte enable signals for each byte lane of
                                                            // the 32-bit Rx data bus.
   input  wire [2               -1:0] uctl_PipePhyMode    , //This will be tied to 01 to indicate USB
                                                            // operation
   input  wire                        uctl_PipeElBufMode  , //Selects the elasticity buffer mode
                                                            // 0 : Nominal Half full buffer mode
                                                            // 1 : Nominal Empty Buffer Mode
   input  wire                        uctl_PipeTxDetRxLoop, //Active high signal to enable Rx detection and
                                                            // loopback
   output wire                        uctl_PipeTxElcIdle  , //
   input  wire                        uctl_PipeTxOnesZeros, //Used to pass USB SS compliance patterns
   input  wire                        uctl_PipeRxPolarity , //Enables the Phy to do polarity inversion of 
                                                            // received data
                                                            // 0 : Phy does no polarity inversion
                                                            // 1 : Phy does polarity inversion
   input  wire                        uctl_PipeRxEqTraining,//Tells the transceiver to bypass normal
                                                            // operation and do equalization training
   input  wire                        uctl_PipeReset_N    , //Asynchronous reset to the transmitter and
                                                            // receiver
   input  wire [2               -1:0] uctl_PipePowerdown  , //00 : Normal operation P0
                                                            // 01 : P1 powerdown state - short recovery time
                                                            // 10 : P2 powerdown state - longer recovery
                                                            // 11 : P3 lowest powerdown state
   input  wire                        uctl_PipeRate       , //Signaling rate :
                                                            // 0 : Not supported
                                                            // 1 : 5.0 GT/s
   input  wire [2               -1:0] uctl_PipeTxDemph    , //Transmitter de-emphasis value
                                                            // 00 : -6dB de-emphasis
                                                            // 01 : -3.5dB de-emphasis
                                                            // 10 : No de-emphasis
                                                            // 11 : Reserved

   input  wire [3               -1:0] uctl_PipeTxMargin   , //Transmitter margin
                                                            // 000 : Normal operating range
                                                            // others not supported
   input  wire                        uctl_PipeTxSwing    , //Transmitter voltage swing value
                                                            // 0 : Full swing
                                                            // 1 : Not supported
   input  wire                        uctl_PipeRxTermination,//Controls the presence of receiver terminations
                                                            // 0 : Terminations removed
                                                            // 1 : Terminations present
   output wire                        uctl_PipeRxValid    , //Indicates symbol lock and valid data on
                                                            // RxData and RxDataK
   output wire                        uctl_PipePhyStatus  , //indicates the completion of several Phy
                                                            // functions like stable clk after reset, transitions
                                                            // from/to power down states etc
   output wire                        uctl_PipeRxElecIdle , //Indicates the detection of an electrical idle at
                                                            // the receiver. De-assertion indicates the
                                                            // detection of LFPS signal
   output wire [3               -1:0] uctl_PipeRxStatus   , //Encodes receiver status and error codes for
                                                            // the received data
                                                            // 000 : Received data OK
                                                            // 001 : 1 SKP ordered set added
                                                            // 010 : 1 SKP ordered set removed
                                                            // 011 : Receiver detected
                                                            // 100 : 8B/10B decode error
                                                            // 101 : Elastic buffer overflow
                                                            // 110 : Elastic buffer underflow
                                                            // 111 : Receive disparity error
   output wire                        uctl_PipePowerPresent, //Indicates the presence of Vbus

   // ***************************************************************************************************
   // AHB Slave Interface
   // ***************************************************************************************************

   input  wire                        uctl_AhbsHReset_N   , //Active low reset signal - resets the AHB
                                                            // interface
   input  wire [32              -1:0] uctl_AhbsHAddr      , //The 32-bit system address bus
   input  wire [2               -1:0] uctl_AhbsHTrans     , //Indicates the type of the current transfer -
                                                            // SEQUENTIAL, NONSEQUENTIAL, IDLE or
                                                            // BUSY
   input  wire                        uctl_AhbsHWrite     , //Write/Read signal
                                                            // 0 : Read transfer - reading the slave data
                                                            // 1 : Write transfer - writing into the slave
                                                            // registers
   input  wire [3               -1:0] uctl_AhbsHSize      , //Size of the transfer - 8b, 16b or 32b
                                                            // 000 : 8 bits - byte transfer
                                                            // 001 : 16 bits - half-word transfer
                                                            // 010 : 32 bits - Word transfer
                                                            // Others not supported
   input  wire [3               -1:0] uctl_AhbsHBurst     , //Type of burst
                                                            // 000 : Single transfer
                                                            // 001 : INCR - unspecified length
                                                            // 011 : INCR4 - 4-beat incrementing burst
                                                            // 101 : INCR8 - 8-beat incrementing burst
                                                            // 111 : INCR16 - 16-beat incrementing burst
                                                            // Others not supported
   input  wire [4               -1:0] uctl_AhbsHProt      , //Protection control signal. Unused by the slave.
   input  wire [32              -1:0] uctl_AhbsHWdata     , //The write data bus
   input  wire                        uctl_AhbsHSel       , //AHB slave select signal
   input  wire                        uctl_AhbsHReadyI    , //Hready from decoder to detect end of previous 
                                                            //slave's data phase
   output wire [32              -1:0] uctl_AhbsHRdata     , //The read data bus
   output wire                        uctl_AhbsHReady     , //Indication by the slave that the current transfer
                                                            // on the bus has been successfully done - Active
                                                            // High
   output wire [2               -1:0] uctl_AhbsHResp      , //The transfer response indicating the status of
                                                            // the transfer
                                                            // 00 : Transfer OKAY
                                                            // 01 : ERROR in transfer
                                                            // 1x : Not supported
                                                            // 

   // ***************************************************************************************************
   // AHB Master-1 Interface
   // ***************************************************************************************************
   input  wire                        uctl_Ahbm1HReset_N  , //Active low reset signal - resets the AHB
                                                            // interface
   output wire [32              -1:0] uctl_Ahbm1HAddr     , //The 32-bit system address bus driven by the
                                                            // master
   output wire [2               -1:0] uctl_Ahbm1HTrans    , //Indicates the type of the current transfer -
                                                            // SEQUENTIAL, NONSEQUENTIAL, IDLE or
                                                            // BUSY
   output wire                        uctl_Ahbm1HWrite    , //Write/Read signal
                                                            // 0 : Read transfer - reading the slave data
                                                            // 1 : Write transfer - writing into the slave
                                                            // registers
   output wire [3               -1:0] uctl_Ahbm1HSize     , //Size of the transfer - 8b, 16b or 32b
                                                            // 000 : 8 bits - byte transfer
                                                            // 001 : 16 bits - half-word transfer
                                                            // 010 : 32 bits - Word transfer
                                                            // Others not supported
   output wire [3               -1:0] uctl_Ahbm1HBurst    , //Type of burst
                                                            // 000 : Single transfer
                                                            // 001 : INCR - unspecified length
                                                            // 011 : INCR4 - 4-beat incrementing burst
                                                            // 101 : INCR8 - 8-beat incrementing burst
                                                            // 111 : INCR16 - 16-beat incrementing burst
                                                            // Others not supported
   output wire [4               -1:0] uctl_Ahbm1HProt     , //Protection control signal. The bus tied-off to
                                                            // ‘0001’ which is the protection level for normal
                                                            // data access operations
   output wire [32              -1:0] uctl_Ahbm1HWdata    , //The write data bus
   input  wire [32              -1:0] uctl_Ahbm1HRdata    , //The read data bus
   input  wire                        uctl_Ahbm1HReady    , //Indication by the slave that the current transfer
                                                            // on the bus has been successfully done - Active
                                                            // High
   input  wire [2               -1:0] uctl_Ahbm1HResp     , //The transfer response indicating the status of
                                                            // the transfer
                                                            // 00 : Transfer OKAY
                                                            // 01 : ERROR in transfer
                                                            // 1x : Not supported
                                                            // 
   output wire                        uctl_Ahbm1HBusreq   , //Bus request signal to the bus arbiter
   input  wire                        uctl_Ahbm1HGrant    , //Bus grant signal from the arbiter. Master gets
                                                            // the ownership when the current transaction
                                                            // ends with HReady asserted

   // ***************************************************************************************************
   // AHB Master-2 Interface
   // ***************************************************************************************************
   input  wire                        uctl_Ahbm2HReset_N  , //Active low reset signal - resets the AHB
                                                            // interface
   output wire [32              -1:0] uctl_Ahbm2HAddr     , //The 32-bit system address bus driven by the
                                                            // master
   output wire [2               -1:0] uctl_Ahbm2HTrans    , //Indicates the type of the current transfer -
                                                            // SEQUENTIAL, NONSEQUENTIAL, IDLE or
                                                            // BUSY
   output wire                        uctl_Ahbm2HWrite    , //Write/Read signal
                                                            // 0 : Read transfer - reading the slave data
                                                            // 1 : Write transfer - writing into the slave
                                                            // registers
   output wire [3               -1:0] uctl_Ahbm2HSize     , //Size of the transfer - 8b, 16b or 32b
                                                            // 000 : 8 bits - byte transfer
                                                            // 001 : 16 bits - half-word transfer
                                                            // 010 : 32 bits - Word transfer
                                                            // Others not supported
   output wire [3               -1:0] uctl_Ahbm2HBurst    , //Type of burst
                                                            // 000 : Single transfer
                                                            // 001 : INCR - unspecified length
                                                            // 011 : INCR4 - 4-beat incrementing burst
                                                            // 101 : INCR8 - 8-beat incrementing burst
                                                            // 111 : INCR16 - 16-beat incrementing burst
                                                            // Others not supported
   output wire [4               -1:0] uctl_Ahbm2HProt     , //Protection control signal. The bus tied-off to
                                                            // ‘0001’ which is the protection level for normal
                                                            // data access operations
   output wire [32              -1:0] uctl_Ahbm2HWdata    , //The write data bus
   input  wire [32              -1:0] uctl_Ahbm2HRdata    , //The read data bus
   input  wire                        uctl_Ahbm2HReady    , //Indication by the slave that the current transfer
                                                            // on the bus has been successfully done - Active
                                                            // High
   input  wire [2               -1:0] uctl_Ahbm2HResp     , //The transfer response indicating the status of
                                                            // the transfer
                                                            // 00 : Transfer OKAY
                                                            // 01 : ERROR in transfer
                                                            // 1x : Not supported
                                                            // 
   output wire                        uctl_Ahbm2HBusreq   , //Bus request signal to the bus arbiter
   input  wire                        uctl_Ahbm2HGrant    , //Bus grant signal from the arbiter. Master gets
                                                            // the ownership when the current transaction
                                                            // ends with HReady asserted


   // ***************************************************************************************************
   // AXI Slave Interface
   // ***************************************************************************************************
   input  wire                        uctl_AxisAReset_N   , //Active low reset signal - resets the AXI
                                                            // interface
   input  wire                        uctl_AxisAValid     , //Indicates that the address and control
                                                            // information are valid.
                                                            // 0 : Address/Control not valid or available
                                                            // 1 : Address/Control valid on the bus
   input  wire [32              -1:0] uctl_AxisAddr       , //Address for the current transfer or the first transfer in a burst
   input  wire                        uctl_AxisAWrite     , //Write/Read signal
                                                            // 0 : Read transfer - reading the slave data
                                                            // 1 : Write transfer - writing into the slave
                                                            // registers
   input  wire [4               -1:0] uctl_AxisALen       , //Burst Length. Indicates the number of transfers in a burst
                                                            // 0000 : 1 data transfer
                                                            // 0001 : 2 data transfers
                                                            // ……
                                                            // 1111 : 16 data transfers
   input  wire [3               -1:0] uctl_AxisASize      , //Size of each transfer in a burst
                                                            // 000 : 1 byte
                                                            // 001 : 2 bytes (half word)
                                                            // 010 : 4 bytes (Word)
   input  wire [2               -1:0] uctl_AxisABurst     , //The type of burst
                                                            // 00 : FIXED - Fixed address burst
                                                            // 01 : INCR - Incrementing address
                                                            // Others not supported
   input  wire [2               -1:0] uctl_AxisALock      , //Lock type.
                                                            // 00 : Normal access
                                                            // Others not supported
                                                            // 
                                                            // 
   input  wire [4               -1:0] uctl_AxisACache     , //Cache access type
                                                            // 0000 : Non-cache’able, non-buffer’able
                                                            // Others not supported
   input  wire [3               -1:0] uctl_AxisAProt      , //Protection level
                                                            // 010 : Normal transfer
                                                            // Others not supported
   input  wire [4               -1:0] uctl_AxisAId        , //Id tag for the Read/Write transaction
   output wire                        uctl_AxisAReady     , //This signal indicates that the slave is ready to
                                                            // accept an address
                                                            // 0 : Slave not ready
                                                            // 1 : Slave is ready
   output wire                        uctl_AxisRValid     , //Indicates that the valid Read Data is available
                                                            // on the Read bus
   output wire                        uctl_AxisRLast      , //Indicates the last transfer in a Read burst
   output wire [32              -1:0] uctl_AxisRData      , //The Read data bus
   output wire [2               -1:0] uctl_AxisRResp      , //Read response indicating the status of the
                                                            // read transfer
                                                            // 00 : OKAY
                                                            // 01 : EXOKAY (not supported)
                                                            // 10 : SLVERR
                                                            // 11 : DECERR
   output wire [4               -1:0] uctl_AxisRId        , //Id tag for the Read transaction -must match with AID
   input  wire                        uctl_AxisRReady     , //Active high signal from master indicating that it
                                                            // is ready to accept data
   input  wire                        uctl_AxisWValid     , //Active high signal indicates that the Write data
                                                            // and strobes are available on the bus
   input  wire                        uctl_AxisWLast      , //Indicates the last transfer in a Write burst
   input  wire [32              -1:0] uctl_AxisWData      , //The Write data bus
   input  wire [4               -1:0] uctl_AxisWStrb      , //Write strobes indicating which byte lane to
                                                            // update
                                                            // WStrb[n] corresponds to WData[8n+7 : 8n]
   input  wire [4               -1:0] uctl_AxisWId        , //Id tag for the Write transaction -must match with AID
   output wire                        uctl_AxisWReady     , //Write ready signal from slave signifying the
                                                            // acceptance of the Write Data
   output wire                        uctl_AxisBValid     , //Indicates that a valid Write response is present
                                                            // on the bus
   output wire [2               -1:0] uctl_AxisBResp      , //Write response indicating the status of the
                                                            // write transfer
                                                            // 00 : OKAY
                                                            // 01 : EXOKAY (not supported)
                                                            // 10 : SLVERR
                                                            // 11 : DECERR
   output wire [4               -1:0] uctl_AxisBId        , //Id tag for the Write Response transaction - must match with AID
   input  wire                        uctl_AxisBReady     , //The ready signal from master in response to
                                                            // the Write Response phase signifying the
                                                            // acceptance of the Write Response.
   output wire                        uctl_AxisCActive    , //Indication to restart the clock to the slave.
   input  wire                        uctl_AxisCSysReq    , //Request to enter the low power mode
   output wire                        uctl_AxisCSysAck    , //Acknowledgement from the slave to the low
                                                            // power request

   // ***************************************************************************************************
   // AXI Master-1 Interface
   // ***************************************************************************************************
   input  wire                        uctl_Axim1AReset_N  , //Active low reset signal - resets the AXI
                                                            // interface
   output wire                        uctl_Axim1AValid    , //Indicates that the address and control
                                                            // information are valid.
                                                            // 0 : Address/Control not valid or available
                                                            // 1 : Address/Control valid on the bus
   output wire [32              -1:0] uctl_Axim1Addr      , //Address for the current transfer or the first
                                                            // transfer in a burst
   output wire                        uctl_Axim1AWrite    , //Write/Read signal
                                                            // 0 : Read transfer - reading the slave data
                                                            // 1 : Write transfer - writing into the slave
                                                            // registers
                                                            // 
                                                            // 
   output wire [4               -1:0] uctl_Axim1ALen      , //Burst Length. Indicates the number of transfers
                                                            // in a burst
                                                            // 0000 : 1 data transfer
                                                            // 0001 : 2 data transfers
                                                            // ,, ,, 
                                                            // 1111 : 16 data transfers
   output wire [3               -1:0] uctl_Axim1ASize     , //Size of each transfer in a burst
                                                            // 000 : 1 byte
                                                            // 001 : 2 bytes (half word)
                                                            // 010 : 4 bytes (Word)
   output wire [2               -1:0] uctl_Axim1ABurst    , //The type of burst
                                                            // 00 : FIXED - Fixed address burst
                                                            // 01 : INCR - Incrementing address
                                                            // Others not supported
   output wire [2               -1:0] uctl_Axim1ALock     , //Lock type.
                                                            // 00 : Normal access
                                                            // Others not supported
   output wire [4               -1:0] uctl_Axim1ACache    , //Cache access type
                                                            // 0000 : Non-cacheable, non-bufferable
                                                            // Others not supported
   output wire [3               -1:0] uctl_Axim1AProt     , //Protection level
                                                            // 010 : Normal transfer
                                                            // Others not supported
   output wire [4               -1:0] uctl_Axim1AId       , //Id tag for the Read/Write transaction
   input  wire                        uctl_Axim1AReady    , //This signal indicates that the slave is ready to
                                                            // accept an address
                                                            // 0 : Slave not ready
                                                            // 1 : Slave is ready
   input  wire                        uctl_Axim1RValid    , //Indicates that the valid Read Data is available
                                                            // on the Read bus
   input  wire                        uctl_Axim1RLast     , //Indicates the last transfer in a Read burst
   input  wire [32              -1:0] uctl_Axim1RData     , //The Read data bus
   input  wire [2               -1:0] uctl_Axim1RResp     , //Read response indicating the status of the
                                                            // read transfer
                                                            // 00 : OKAY
                                                            // 01 : EXOKAY (not supported)
                                                            // 10 : SLVERR
                                                            // 11 : DECERR
                                                            // 
   input  wire [4               -1:0] uctl_Axim1RId       , //Id tag for the Read transaction -must match with AID
   output wire                        uctl_Axim1RReady    , //Active high signal from master indicating that it
                                                            // is ready to accept data
   output wire                        uctl_Axim1WValid    , //Active high signal indicates that the Write data
                                                            // and strobes are available on the bus
   output wire                        uctl_Axim1WLast     , //Indicates the last transfer in a Write burst
   output wire [32              -1:0] uctl_Axim1WData     , //The Write data bus
   output wire [4               -1:0] uctl_Axim1WStrb     , //Write strobes indicating which byte lane to
                                                            // update
                                                            // WStrb[n] corresponds to WData[8n+7 : 8n]
   output wire [4               -1:0] uctl_Axim1WId       , //Id tag for the Write transaction -must match with AID
   input  wire                        uctl_Axim1WReady    , //Write ready signal from slave signifying the
                                                            // acceptance of the Write Data
   input  wire                        uctl_Axim1BValid    , //Indicates that a valid Write response is present
                                                            // on the bus
   input  wire [2               -1:0] uctl_Axim1BResp     , //Write response indicating the status of the
                                                            // write transfer
                                                            // 00 : OKAY
                                                            // 01 : EXOKAY (not supported)
                                                            // 10 : SLVERR
                                                            // 11 : DECERR
   input  wire [4               -1:0] uctl_Axim1BId       , //Id tag for the Write Response transaction - must match with AID
   output wire                        uctl_Axim1BReady    , //The ready signal from master in response to
                                                            // the Write Response phase signifying the
                                                            // acceptance of the Write Response.

   // ***************************************************************************************************
   // AXI Master-2 Interface
   // ***************************************************************************************************
   input  wire                        uctl_Axim2AReset_N  , //Active low reset signal - resets the AXI
                                                            // interface
   output wire                        uctl_Axim2AValid    , //Indicates that the address and control
                                                            // information are valid.
                                                            // 0 : Address/Control not valid or available
                                                            // 1 : Address/Control valid on the bus
   output wire [32              -1:0] uctl_Axim2Addr      , //Address for the current transfer or the first
                                                            // transfer in a burst
   output wire                        uctl_Axim2AWrite    , //Write/Read signal
                                                            // 0 : Read transfer - reading the slave data
                                                            // 1 : Write transfer - writing into the slave
                                                            // registers
                                                            // 
                                                            // 
   output wire [4               -1:0] uctl_Axim2ALen      , //Burst Length. Indicates the number of transfers
                                                            // in a burst
                                                            // 0000 : 1 data transfer
                                                            // 0001 : 2 data transfers
                                                            // - - -
                                                            // 1111 : 16 data transfers
   output wire [3               -1:0] uctl_Axim2ASize     , //Size of each transfer in a burst
                                                            // 000 : 1 byte
                                                            // 001 : 2 bytes (half word)
                                                            // 010 : 4 bytes (Word)
   output wire [2               -1:0] uctl_Axim2ABurst    , //The type of burst
                                                            // 00 : FIXED - Fixed address burst
                                                            // 01 : INCR - Incrementing address
                                                            // Others not supported
   output wire [2               -1:0] uctl_Axim2ALock     , //Lock type.
                                                            // 00 : Normal access
                                                            // Others not supported
   output wire [4               -1:0] uctl_Axim2ACache    , //Cache access type
                                                            // 0000 : Non-cacheable, non-bufferable
                                                            // Others not supported
   output wire [3               -1:0] uctl_Axim2AProt     , //Protection level
                                                            // 010 : Normal transfer
                                                            // Others not supported
   output wire [4               -1:0] uctl_Axim2AId       , //Id tag for the Read/Write transaction
   input  wire                        uctl_Axim2AReady    , //This signal indicates that the slave is ready to
                                                            // accept an address
                                                            // 0 : Slave not ready
                                                            // 1 : Slave is ready
   input  wire                        uctl_Axim2RValid    , //Indicates that the valid Read Data is available
                                                            // on the Read bus
   input  wire                        uctl_Axim2RLast     , //Indicates the last transfer in a Read burst
   input  wire [32              -1:0] uctl_Axim2RData     , //The Read data bus
   input  wire [2               -1:0] uctl_Axim2RResp     , //Read response indicating the status of the
                                                            // read transfer
                                                            // 00 : OKAY
                                                            // 01 : EXOKAY (not supported)
                                                            // 10 : SLVERR
                                                            // 11 : DECERR
                                                            // 
   input  wire [4               -1:0] uctl_Axim2RId       , //Id tag for the Read transaction -must match with AID
   output wire                        uctl_Axim2RReady    , //Active high signal from master indicating that it
                                                            // is ready to accept data
   output wire                        uctl_Axim2WValid    , //Active high signal indicates that the Write data
                                                            // and strobes are available on the bus
   output wire                        uctl_Axim2WLast     , //Indicates the last transfer in a Write burst
   output wire [32              -1:0] uctl_Axim2WData     , //The Write data bus
   output wire [4               -1:0] uctl_Axim2WStrb     , //Write strobes indicating which byte lane to
                                                            // update
                                                            // WStrb[n] corresponds to WData[8n+7 : 8n]
   output wire [4               -1:0] uctl_Axim2WId       , //Id tag for the Write transaction -must match with AID
   input  wire                        uctl_Axim2WReady    , //Write ready signal from slave signifying the
                                                            // acceptance of the Write Data
   input  wire                        uctl_Axim2BValid    , //Indicates that a valid Write response is present
                                                            // on the bus
   input  wire [2               -1:0] uctl_Axim2BResp     , //Write response indicating the status of the
                                                            // write transfer
                                                            // 00 : OKAY
                                                            // 01 : EXOKAY (not supported)
                                                            // 10 : SLVERR
                                                            // 11 : DECERR
   input  wire [4               -1:0] uctl_Axim2BId       , //Id tag for the Write Response transaction - must match with AID
   output wire                        uctl_Axim2BReady    , //The ready signal from master in response to
                                                            // the Write Response phase signifying the
                                                            // acceptance of the Write Response.

   // ***************************************************************************************************
   // Endpoint Buffer Interface -1  (Write Port)
   // ***************************************************************************************************
   output wire                        uctl_Mem0Cen      , //Chip enable signal for the SRAM memory
                                                          // module
   output wire [32              -1:0] uctl_Mem0Addr     , //The address bus into the memory
   output wire [32              -1:0] uctl_Mem0Dout     , //Write data bus for data being written into the
                                                          // memory
   output wire                        uctl_Mem0RdWrN    , //Read/Write signal into the memory
                                                          // 1 : No op
                                                          // 0 : Write into memory
   input  wire                        uctl_Mem0Ack      , //Ack for mem access

   // ***************************************************************************************************
   // Endpoint Buffer Interface -2  (Write Port)
   // ***************************************************************************************************
   output wire                        uctl_Mem1Cen      , //Chip enable signal for the SRAM memory
                                                            // module
   output wire [32              -1:0] uctl_Mem1Addr     , //The address bus into the memory
   output wire [32              -1:0] uctl_Mem1Dout     , //Write data bus for data being written into the
                                                            // memory
   output wire                        uctl_Mem1RdWrN    , //Read/Write signal into the memory
                                                            // 1 : No op
                                                            // 0 : Write into memory
   input  wire                        uctl_Mem1Ack      , //Ack for mem access


   // ***************************************************************************************************
   // Endpoint Buffer Interface - 1 (Read Port)
   // ***************************************************************************************************
   output wire                        uctl_Mem2Cen      , //Chip enable signal for the SRAM memory
                                                            // module
   output wire [32              -1:0] uctl_Mem2Addr     , //The address bus into the memory
   input  wire [32              -1:0] uctl_Mem2Din      , //Read data bus for data being read from the
                                                            // memory
   output wire                        uctl_Mem2RdWrN    ,   // uctl_MemRxRdWrN
                                                            // OUT Read/Write signal into the memory
                                                            // 1 : Read from memory
                                                            // 0 : No Op
   input  wire                        uctl_Mem2Ack      , //Ack for mem access
   input  wire                        uctl_Mem2DVld     , // Validates Data in/rd data there could be
                                                            // more than 1 cycle delay from Ack.

   // ***************************************************************************************************
   // Endpoint Buffer Interface - 2 (Read Port)
   // ***************************************************************************************************
   output wire                        uctl_Mem3Cen      , //Chip enable signal for the SRAM memory
                                                            // module
   output wire [32              -1:0] uctl_Mem3Addr     , //The address bus into the memory
   input  wire [32              -1:0] uctl_Mem3Din      , //Read data bus for data being read from the
                                                            // memory
   output wire                        uctl_Mem3RdWrN    ,   // uctl_MemRxRdWrN
                                                            // OUT Read/Write signal into the memory
                                                            // 1 : Read from memory
                                                            // 0 : No Op
   input  wire                        uctl_Mem3Ack      , //Ack for mem access
   input  wire                        uctl_Mem3DVld       // Validates Data in/rd data there could be
                                                            // more than 1 cycle delay from Ack.
  

);

/*  instantiated module
1.  uctl_packet_decoder          //mahmood
2.  uctl_protocol_engine         //Lalit
3.  uctl_epcr                    //Lalit
4.  uctl_epct                    //Lalit
5.  uctl_regEptdInf             //Sanjeeva
6.  uctl_sept                    //Darshan
7.  uctl_sysControllerTx         //Darshan
8.  uctl_sepr                    //Sanjeeva
9.  uctl_sysControllerRx         //Sanjeeva
10. uctl_dmaRx                   //Anuj
11. uctl_registerBlock           //sanjeeva
12. uctl_packet_assembler        //mahmood
13. uctl_cmdIfReg                //Darshan     
14. uctl_cmdIfMif                //Darshan
15. uctl_ahbMaster               //anuj
16. uctl_dmaTx                   //anuj
17. usb_controller_memory        //Lalit
18. uctl_frameCounter            //Lalit
*/
   ////////////////////////////////////////////////////////////////////////////
   //internal wire declaration
   ////////////////////////////////////////////////////////////////////////////
   //1. pd   
   wire [3          :0]    pd2pe_epNum                  ;
   wire                    pd2pe_tokenValid             ;       
   wire                    pd2pe_lpmValid               ; 
   wire [10        :0]     pd2pe_lpmData                ; 
   wire [3          :0]    pd2pe_tokenType              ;  
   
   wire                    pd2epcr_dataValid            ;  
   wire [31         :0]    pd2epcr_data                 ;  
   wire [3          :0]    pd2epcr_dataBE               ;  
   wire [15         :0]    pd2crc16_crc                 ;  

   wire                    pd2eptd_statusStrobe         ;  
   wire                    pd2eptd_crc5                 ;  
   wire                    pd2eptd_pid                  ;  
   wire                    pd2eptd_err                  ;  
   wire [4          :0]    pd2eptd_epNum                ;  

   //2. pe
   wire                    pe2epcr_getWrPtrs            ;      
   wire                    pe2epcr_wrEn                 ;      
   wire                    pe2epcr_rxHdrWr              ;      
   wire                    pe2epcr_updtWrBuf            ;      
   wire                    epcr2pe_ready                ;
   wire                    pe2epct_rdEn                 ;      
   wire                    pe2epct_hdrRd                ;      
   wire                    pe2epct_updtRdBuf            ;      
   wire                    pe2epct_getRdPtrs            ;      
   wire                    pe2pa_tokenValid             ;
   wire [3  		  :0]    pe2pa_tokenType              ;
   wire                    pe2epc_idleState             ;
   wire [3          :0]    pe2epc_epNum                 ;
 //wire [3          :0]    pe2epc_tokenType             ;

   //3. epcr
   wire                    epcr2pe_ctrlNAK              ; 
   wire                    epcr2pe_setupStall           ; 
   wire                    epcr2pd_ready                ;  
   wire                    epcr2pe_epHalt               ;
   wire                    epcr2pe_bufFull              ;
   wire                    epcr2pe_bufNearlyFull        ;
   wire                    epcr2pe_wrErr                ;
 //wire                    epcr2pe_epDir                ;
   wire [1			  :0]    epcr2pe_epType               ;  
   wire [3			  :0]    epcr2pe_expctDataPid         ; 
   wire [1          :0]    eptd2epcr_epTrans            ;
   wire [1          :0]    eptd2epcr_epType             ;
   wire                    epcr2pe_hdrWrDn              ;
   wire                    epcr2pe_wrBufUpdtDn          ;
 //wire                    epcr2pe_eot                  ;
   wire [1:          0]    epcr2reg_enuActOut           ;
   wire                    epcr2reg_enuCmdUpdt          ;
   wire [15         :0]    epcr2reg_descLenUpdt         ;
   wire [3:	   	   0]    epcr2eptd_epNum              ;  
   wire                    epcr2eptd_reqData            ;
   wire                    epcr2eptd_updtReq            ;
   wire                    epcr2eptd_dataFlush          ;
   wire [3			  :0]    epcr2eptd_nxtDataPid         ;

   //4. epct
   wire                    epct2pa_dataValid            ; 
   wire [DATA_SIZE-1:0]    epct2pa_data                 ;
   wire [3			  :0]    epct2pa_dataBE               ;
   wire                    epct2pa_eot                  ;
   wire                    epct2pa_zeroLen              ;
   wire                    epct2pe_epHalt               ;
   wire [1			  :0]    epct2pe_epType               ;
   wire [3			  :0]    epct2pe_expctDataPid         ;
   wire                    epct2pe_hdrRdDn              ;
   wire                    epct2pe_rdBufUpdtDn          ;
 //wire                    epct2pe_eot                  ;
   wire [1:          0]    epct2reg_enuActOut           ;
   wire                    epct2reg_enuCmdUpdt          ;
   wire [15:          0]   epct2reg_descLenUpdt         ;
   wire [3:				0]    epct2eptd_epNum              ;
   wire                    epct2eptd_reqData            ;          
   wire                    epct2eptd_updtReq            ;
   wire [ADDR_SIZE-1:0]    epct2eptd_rdPtrOut           ;
   wire [3			  :0]    epct2eptd_nxtExpDataPid      ;

   //5. eptd
   wire [31         :0]   eptd2epcr_startAddr           ;  
   wire [31         :0]   eptd2epcr_endAddr             ;  
   wire [31         :0]   eptd2epcr_rdPtr               ;  
   wire [31         :0]   eptd2epcr_wrPtr               ;  
   wire                   eptd2epcr_lastOp              ;  
   wire [3          :0]   eptd2epcr_exptDataPid         ;  
   wire                   eptd2epcr_updtDn              ;  
   wire [10          :0]   eptd2epcr_wMaxPktSize        ;  
 //wire                   eptd2epcr_dir                 ;  
   wire                   eptd2epcr_epHalt              ; 
   wire [31         :0]   eptd2sepr_startAddr           ; 
   wire [31         :0]   eptd2sepr_endAddr             ; 
   wire [31         :0]   eptd2sepr_rdPtr               ; 
   wire [31         :0]   eptd2sepr_wrPtr               ; 
   wire                   eptd2sepr_lastOp              ; 
   wire                   eptd2sepr_updtDn              ; 

   //7. sept
   wire  [3         :0]   sept2eptd_epNum               ;   
   wire                   sept2eptd_reqData             ;   
   wire                   sept2eptd_updtReq             ;   
   wire  [31        :0]   sept2eptd_wrPtrOut            ;   
   wire  [31        :0]   sept2dmaTx_addrIn             ;   
   wire                   sept2dmaTx_wr                 ;   
   wire  [31        :0]   sept2dmaTx_epStartAddr        ;   
   wire  [31        :0]   sept2dmaTx_epEndAddr          ;   
      
   //8. sys_controller_rx
   wire                   sctrlRx2sepr_inIdle           ;
   wire  [3         :0]   reg2sctrlRx_rdCount           ;
   wire  [3         :0]   sctrlRx2reg_rdCnt             ;
   wire                   sctrlRx2sepr_getRdPtrs        ;
   wire  [1         :0]   sctrlRx2reg_status            ;
   wire                   sctrlRx2sepr_hdrRd            ;
   wire                   sctrlRx2sepr_rd               ;
   wire                   sctrlRx2sepr_updtRdBuf        ;
   wire [2          :0]   reg2sept_dmaMode              ; 
   wire [2          :0]   reg2sepr_dmaMode              ;
   //9. sepr
   wire                   sepr2sctrlRx_rdPtrsRcvd       ;     
   wire                   sepr2sctrlRx_bufEmpty         ;     
   wire                   sepr2sctrlRx_hdrRdDn          ;     
   wire                   sepr2sctrlRx_transferDn       ;     
   wire                   sepr2sctrlRx_bufUpdtDn        ;     
   wire [31         :0]   sepr2dmaRx_laddrIn            ;     
   wire  		           sepr2dmaRx_dmaStart           ;     
   wire [19         :0]   sepr2dmaRx_len                ;     
   wire [31         :0]   sepr2dmaRx_epStartAddr        ;     
   wire [31         :0]   sepr2dmaRx_epEndAddr          ;     
   wire [3          :0]   sepr2eptd_epNum               ;     
   wire                   sepr2eptd_reqData             ;     
   wire                   sepr2eptd_updtReq             ;     
   wire [31         :0]   sepr2eptd_rdPtr               ;     
   wire                   sctrlRx2sepr_wrAddrEn         ;
   //9. dmaRx	
   wire                   dmaRx2sepr_dn                 ; 
   wire   [31         :0] dmaRx2mif_Addr                ;
   wire                   dmaRx2mif_rdReq               ;
   wire                   dmaRx2ahbm_sRdWr              ;
   wire   [CNTR_WD  -1:0] dmaRx2ahbm_len                ;
   wire                   dmaRx2ahbm_stransEn           ;
 //wire   [4            -1:0] dmaRx2ahbm_BE             ;

   //dmaTx
   wire                   dmaTx2sept_dn                 ;
 //wire  [ADDR_SIZE -1:0] sept2dmaTx_offsetAddr         ;    
   wire  [ADDR_SIZE -1:0] dmaTx2mif_wrAddr              ;
   wire                   dmaTx2mif_wrReq               ;
   wire  [DATA_SIZE -1:0] dmaTx2mif_wrData              ;
   wire  [CNTR_WD   -1:0] dmaTx2ahbm_len                ;
   wire                   dmaTx2ahbm_stransEn           ;
   wire  [21 :0]reg2cmdIf_memSegAddr;
   //reg block
   wire [2			  :0]   reg2pe_usbMode                ;    
   wire                   reg2epcr_enuCmdEn             ;   
   wire [1          :0]   reg2epcr_EnuAct               ;   
   wire [15         :0]   reg2epcr_descLen              ;   
   wire [31         :0]   reg2epcr_descAddr             ;   
   wire                   reg2epcr_rwCtlrType           ;   
   wire                   reg2epct_enuCmdEn             ;   
   wire [1          :0]   reg2epct_EnuAct               ;   
   wire [15         :0]   reg2epct_descLen              ;   
   wire [31         :0]   reg2epct_descAddr             ;   
   wire                   reg2epct_rwCtlrType           ;   
   wire                   reg2pe_enHost                 ;   
   wire                   reg2pe_enOTGTrans             ;   
   wire [3          :0]   reg2pe_epNum                  ;   
   wire                   reg2pe_devHalt                ;   
   wire [3          :0]   reg2pe_tokenType              ;   
   wire                   pe2reg_transSent              ;
   wire                   reg2pd_dataBus16_8            ;     
   wire [6          :0]   reg2pd_devId                  ;     

   wire [19          :0]  reg2sctrlTx_wrPktLength       ;
   wire [3           :0]  reg2sctrlTx_epNum             ;
   wire                   reg2sctrlTx_wr                ;
   wire                   reg2sctrlTx_disFrag           ;
   //pa
   wire                   uctl_Mem1Wr_en                ; 

   //* *
   wire                   cmdIf_rdData_ack_1            ; 
   wire                   cmdIf_rdData_ack_2            ; 
   wire [DATA_SIZE-1:0]   cmdIf_rdData_1                ; 
   wire [DATA_SIZE-1:0]   cmdIf_rdData_2                ; 
   wire                   cmdIf_wrData_ack_1            ; 
   wire                   cmdIf_wrData_ack_2            ; 
   wire                   cmdIf_ack_1                   ; 
   wire                   cmdIf_ack_2                   ; 
   //ahbMaster
   wire                   ahbm2dmaTx_dataDn             ; 
   wire                   ahbm2dmaTx_ready              ; 
   wire [31           :0] ahbm2dmaTx_wrData             ;  
   wire                   ahbm2dmaRx_dn                 ; 
   wire [4            :0] ahbm2dmaRx_availSpace         ; 
   
   //ahbSlave
   wire                   cmdIf_req                     ;
   wire  [31          :0] cmdIf_addr                    ;
   wire                   cmdIf_wrRd                    ;
   wire                   cmdIf_wrData_req              ;
   wire  [31          :0] cmdIf_wrData                  ;
   wire                   cmdIf_rdData_req              ;
   wire                   cmdIf_trEn                    ;     
   
   //sysCmdMem_rw
   wire                   mem_ack                       ;
   wire                   mem_rdVal                     ;
   wire [DATA_SIZE-1 :0]  mem_rdData                    ;
   wire [DATA_SIZE-1  :0] mif2sepr_rdData               ;
   wire		              mif2sepr_ack                  ;
   wire                   mif2sepr_rdVal                ;
   wire                   mif2sept_ack                  ;
   wire                   mif2dmaTx_ack                 ;
   wire [DATA_SIZE -1:0]  mif2dmaRx_data                ;
   wire                   mif2dmaRx_ack                 ;
   wire                   mif2dmaRx_rdVal               ;

   //uctl_cmdIfMif
   wire                   cmdIf_ack                     ;
   wire                   cmdIf_wrData_ack              ;
   wire                   cmdIf_rdData_ack              ;
   wire   [31     :0]     cmdIf_rdData                  ;
   wire                   mem_req                       ;
   wire                   mem_wrRd                      ;
   wire  [31      :0]     mem_addr                      ;
   wire  [31      :0]     mem_wrData                    ;

   //uctl_cmdIfReg

   wire [3           :0]  eptd2epct_exptDataPid         ;
   wire [1           :0]  eptd2epct_epTrans             ;
   wire [1           :0]  eptd2epct_epType              ;  

   wire [ADDR_SIZE -1:0]  eptd2sept_rdPtr               ;

   wire [ADDR_SIZE -1:0]  eptd2sept_wrPtr               ;
  
   wire [11			 -1:0]  eptd2sept_bSize               ;
   wire [ADDR_SIZE -1:0]  sept2mif_addr                 ;
   wire [32			 -1:0]  sept2mif_wrData               ;
   wire [20			 -1:0]  sctrlTx2sept_wrPktLength      ;
   wire [2			 -1:0]  sctrlTx2reg_status            ;
   wire [11			 -1:0]  sept2sctrlTx_eptBufSize       ;
   wire [ADDR_SIZE -1:0]  eptd2sept_startAddr           ;
   wire [ADDR_SIZE -1:0]  eptd2sept_endAddr             ;
   wire [4			 -1:0]  sctrlTx2sept_epNum            ;
   
   wire [20			 -1:0]  sctrlTx2reg_length            ;
   wire [5			 -1:0]  sctrlTx2reg_fragCnt           ;
   wire [4			 -1:0]  sctrlRx2sepr_epNum            ;
   wire [4			 -1:0]  reg2sctrlRx_epNum             ;
   wire [ADDR_SIZE -1:0]  dmaRx2ahbm_sWrAddr            ;
   wire [20			 -1:0]  sept2dmaTx_len                ;
   wire [ADDR_SIZE -1:0]  dmaTx2ahbm_sRdAddr            ;
   wire [4			 -1:0]  reg2pa_tokenType              ;
   wire [11			 -1:0]  reg2pa_frameNum               ;
   wire [7			 -1:0]  reg2pa_devID                  ;
   wire [16			 -1:0]  crc2pa_crc                    ;
   wire [32			 -1:0]  dmaRx2ahbm_data               ;
   wire [32			 -1:0]  sepr2mif_addr                 ;
   wire [ADDR_SIZE-1:0]   epcr2eptd_wrPtrOut            ;                       
   wire [ADDR_SIZE-1:0]   eptd2epct_startAddr           ;
   wire [ADDR_SIZE-1:0]   eptd2epct_endAddr             ;
   wire [ADDR_SIZE-1:0]   eptd2epct_rdPtr               ;
   wire [ADDR_SIZE-1:0]   eptd2epct_wrPtr               ;
   wire [3          :0]   reg2pa_epNum                  ;
   wire                   Mem2RdWrN                     ;
   wire                   Mem3RdWrN                     ;
   wire                   crc_dataValid                 ; 
   wire [31         :0]   crc_Data                      ; 
   wire                   crcValid                      ,  
                          crc_match                     ;
   wire                   eptd2sept_updtDn              ; 
   wire                   sepr2dmaRx_sRdWr              ;
   wire                   uctl_Mem0WrN                  ; 
   wire                   sept2sctrlTx_transferErr      ; 
   wire                   epct2pe_epZeroLenEn           ; 
   wire                   pe2epct_ctrlZlp               ;
   wire                   epct2pe_bufEmpty              ;
   wire                   sept2dmaTx_sRdWr              ;
   wire                   epcr2pe_hwStall               ; 
   wire                   epcr2eptd_setEphalt           ;
   wire                   sctrlTx2sept_wrAddrEn         ;
   wire [ADDR_SIZE-1:0]   sepr2dmaRx_sWrAddr            ;
   wire [ADDR_SIZE-1:0]   reg2sepr_sWrAddr              ;
   wire [ADDR_SIZE-1:0]   reg2sept_sRdAddr              ;
   wire [ADDR_SIZE-1:0]   sept2dmaTx_sRdAddr            ;
   wire [9        -1:0]   sepr2sctrlRx_fullPktCnt       ;
   wire [9        -1:0]   sept2sctrlTx_fullPktCnt       ;
   wire                   reg2sctrlTx_listMode          ;
   wire                   reg2sctrlRx_listMode          ;
   wire [31         :0]   sept2cmdIf_addr               ;
   wire [19         :0]   sept2cmdIf_len                ;
   wire [31         :0]   sept2cmdIf_epStartAddr        ;          
   wire [31         :0]   sept2cmdIf_epEndAddr          ; 
   wire [31         :0]   sepr2cmdIf_addr               ;
   wire [19         :0]   sepr2cmdIf_len                ;
   wire [31         :0]   sepr2cmdIf_epStartAddr        ;
   wire [31         :0]   sepr2cmdIf_epEndAddr          ;          
   wire [2          :0]   sepr2cmdIf_dmaMode            ;
   wire [2          :0]   sept2cmdIf_dmaMode            ;
   wire [5        -1:0]   sctrlRx2reg_fullPktCnt        ,
                          sctrlTx2reg_fullPktCnt        ;
   wire [9        -1:0]   eptd2sept_fullPktCnt          ,
                          eptd2sepr_fullPktCnt          ;
   wire                   eot                           ;
   wire [4        -1:0]   dataBE                        ; 
   wire                   pe2epcr_regWr                 ; 
   wire [32       -1:0]   epcr2reg_setupData            ;        
   wire                   epcr2reg_setupRegIndex        ;
   wire                   epcr2reg_setupWrReq           ;
   wire [16       -1:0]   reg2epc_setupLen              ;
   wire                   epcr2pe_packetDroped          ;
   wire [2        -1:0]   epcr2pe_enuAct            ;
   wire [3        -1:0]   epcr2pe_ctlTransStage         ;

   wire                   por2reg_fsmIntr               ; 
   wire                   por2reg_resumeCompleted       ; 
   wire                   por2reg_resumeDetected        ; 
   wire                   por2reg_resetCompleted        ; 
   wire                   por2reg_resetDetected         ; 
   wire                   por2reg_susDetected           ; 
   wire                   pe2reg_lpmRcvd                ; 
   wire                   pe2reg_remoteWakeUp           ;
   wire                   eptd2pe_noTransPending        ;
   wire                   epct2reg_bufEmpty             ; 
   wire                   epct2reg_zlpSent              ; 
   wire                   epct2reg_dpSend               ; 

   wire                   epcr2reg_bufFull              ; 
   wire                   epcr2reg_zlpRcvd              ; 
   wire                   epcr2reg_setupRcvd            ; 
   wire                   pe2eptd_intPid                ; 
   wire                   pe2reg_clrCmdReg              ; 
   //uctl_frameCounter
   wire                  pd2frmCntrr_frmNumValid        ;
   wire [11       -1:0]  pd2frmCntrr_FrameNum           ;
   wire                  frmCntr2pe_frmBndry            ;
   wire [20       -1:0]  reg2frmCntr_upCntMax           ;
   wire [4        -1:0]  reg2frmCntr_timerCorr          ;
   wire [11       -1:0]  frmCntr2reg_frameCount         ;
   wire                  frmCntr2reg_frameCntVl         ;
   wire                  frmCntr2reg_sofRcvd            ;
   wire                  frmCntr2reg_sofSent            ;
   wire [10       -1:0]  reg2frmCntr_eof1               ;
   wire [8        -1:0]  reg2frmCntr_eof2               ;
   wire                  reg2frmCntr_enAutoSof          ;
   wire                  reg2frmCntr_autoLd             ;
   wire [20       -1:0]  reg2frmCntr_timerStVal         ;  
   wire                  reg2frmCntr_ldTimerStVal       ;   

   assign cmdIf_rdData_ack      =  cmdIf_rdData_ack_1 | cmdIf_rdData_ack_2;
   assign cmdIf_rdData          = (cmdIf_rdData_ack_1 == 1'b1) ? cmdIf_rdData_1 : cmdIf_rdData_2;                                                                     

   assign cmdIf_wrData_ack      =  cmdIf_wrData_ack_1 | cmdIf_wrData_ack_2;
   assign cmdIf_ack             =  cmdIf_ack_1 | cmdIf_ack_2;
   assign uctl_UtmiDataBus16_8N =  reg2pd_dataBus16_8 ;
      

    assign uctl_UtmiReset     = uctl_PhyRst_n              ;         //TODO
    assign uctl_Mem0RdWrN     = ~uctl_Mem0WrN              ;   
    assign uctl_Mem0Cen       = uctl_Mem0WrN               ;
    assign uctl_Mem1Cen       = uctl_Mem1Wr_en             ;                                      
    assign uctl_Mem1RdWrN     = ~uctl_Mem1Wr_en            ;
    assign uctl_Mem2Cen       = Mem2RdWrN                  ;
    assign uctl_Mem2RdWrN     = Mem2RdWrN                  ;            
    assign uctl_Mem3RdWrN     = Mem3RdWrN                  ;
    assign uctl_Mem3Cen       = Mem3RdWrN                  ;              
   // paket decoder instance
   uctl_packet_decoder #( 
    .PD_DATASIZE                 ( 25                       ),
    .PD_ADDRSIZE                 ( 3                        )
    )i_usb_packet_decoder(
      .coreClk                   (uctl_CoreClk              ),
      .phyClk                    (uctl_PhyClk               ),        
      .phyRst_n                  (uctl_PhyRst_n             ), 
      .coreRst_n                 (uctl_CoreRst_n            ), 
      .swRst                     (1'b0                      ),
      .utmi2pd_rxActive          (uctl_UtmiRxActive         ),      
      .utmi2pd_rxError           (uctl_UtmiRxError          ),
      .utmi2pd_rxValid           (uctl_UtmiRxValid          ),
      .utmi2pd_rxValidH          (uctl_UtmiRxValidH         ),
      .utmi2pd_rxData            (uctl_UtmiRxData           ),
      .utmi2pd_rxDataH           (uctl_UtmiRxDataH          ),
      .pd2pe_tokenValid          (pd2pe_tokenValid          ),       
      .pd2pe_lpmValid            (pd2pe_lpmValid            ),     
      .pd2pe_lpmData             (pd2pe_lpmData             ),     
      .pd2pe_tokenType           (pd2pe_tokenType           ), 
      .pd2pe_epNum               (pd2pe_epNum               ), 
      .pd2frmCntrr_frmNumValid   (pd2frmCntrr_frmNumValid   ) ,
      .pd2frmCntrr_FrameNum      (pd2frmCntrr_FrameNum      ) ,
      .pd2epcr_eot               (pd2epcr_eot               ),
     // .pd2pe_zeroLenPkt        (pd2pe_zeroLenPkt          ), //TODO
      .epcr2pd_ready             (epcr2pd_ready             ),
      .pd2epcr_dataValid         (pd2epcr_dataValid         ),    
      .pd2epcr_data              (pd2epcr_data              ),
      .pd2epcr_dataBE            (pd2epcr_dataBE            ),
      .pd2crc16_crcValid         (pd2crc16_crcValid         ),      
      .pd2crc16_crc              (pd2crc16_crc              ),
      .reg2pd_dataBus16_8        (reg2pd_dataBus16_8        ),         
      .reg2pd_devID              (reg2pd_devId              ),
      .pd2eptd_statusStrobe      (pd2eptd_statusStrobe      ),
      .pd2eptd_crc5              (pd2eptd_crc5              ),
      .pd2eptd_pid               (pd2eptd_pid               ),
      .pd2eptd_err               (pd2eptd_err               ),      
      .pd2eptd_epNum             (pd2eptd_epNum             )

   );

   uctl_protocol_engine  i_protocol_engine ( 
      .uctl_rst_n                (uctl_CoreRst_n            ),
      .core_clk                  (uctl_CoreClk              ),
      .sw_rst                    (1'b0                      ),              
      .pd2pe_tokenValid          (pd2pe_tokenValid          ), 
      .pd2pe_tokenType           (pd2pe_tokenType           ), 
      .pd2pe_lpmValid            (pd2pe_lpmValid            ),     
      .pd2pe_lpmData             (pd2pe_lpmData             ),     
      .pd2pe_epNum               (pd2pe_epNum               ), 
      .pd2pe_eot                 (pd2epcr_eot               ), 
      .epcr2pe_epHalt            (epcr2pe_epHalt            ), 
      .epcr2pe_bufFull           (epcr2pe_bufFull           ), 
      .epcr2pe_ctrlNAK           (epcr2pe_ctrlNAK           ), 
      .epcr2pe_setupStall        (epcr2pe_setupStall        ), 
      .epcr2pe_bufNearlyFull     (epcr2pe_bufNearlyFull     ), 
      .epcr2pe_wrErr             (epcr2pe_wrErr             ), 
      .epcr2pe_getWrPtrsDn       (epcr2pe_getWrPtrsDn       ), 
      .epcr2pe_epType            (epcr2pe_epType            ), 
      .epcr2pe_expctDataPid      (epcr2pe_expctDataPid      ), 
      .epcr2pe_hdrWrDn           (epcr2pe_hdrWrDn           ), 
      .epcr2pe_wrBufUpdtDn       (epcr2pe_wrBufUpdtDn       ), 
      .epcr2pe_hwStall           (epcr2pe_hwStall           ),
      .epcr2pe_packetDroped      (epcr2pe_packetDroped      ),
      .epcr2pe_ready             (epcr2pe_ready             ), 
      .epcr2pe_enuAct        (epcr2pe_enuAct        ),
      .epcr2pe_ctlTransStage     (epcr2pe_ctlTransStage     ),
      .pe2epcr_getWrPtrs         (pe2epcr_getWrPtrs         ), 
      .pe2epcr_wrEn              (pe2epcr_wrEn              ), 
      .pe2epcr_rxHdrWr           (pe2epcr_rxHdrWr           ), 
      .pe2epcr_updtWrBuf         (pe2epcr_updtWrBuf         ), 
      .pe2epcr_regWr             (pe2epcr_regWr             ),
      .pe2eptd_initIsoPid        (pe2eptd_initIsoPid        ),
      .crc2pe_statusValid        (crcValid                  ), 
      .crc2pe_status             (crc_match                 ), 
      .epct2pe_rdErr             (epct2pe_rdErr             ), 
      .epct2pe_getRdPtrsDn       (epct2pe_getRdPtrsDn       ), 
      .epct2pe_epType            (epct2pe_epType            ), 
      .epct2pe_expctDataPid      (epct2pe_expctDataPid      ), 
      .epct2pe_hdrRdDn           (epct2pe_hdrRdDn           ), 
      .epct2pe_rdBufUpdtDn       (epct2pe_rdBufUpdtDn       ), 
      .epct2pe_epHalt            (epct2pe_epHalt            ), 
      .epct2pe_epZeroLenEn       (epct2pe_epZeroLenEn       ), 
      .epct2pe_bufEmpty          (epct2pe_bufEmpty          ), 
      .pe2epct_rdEn              (pe2epct_rdEn              ), 
      .pe2epct_hdrRd             (pe2epct_hdrRd             ), 
      .pe2epct_updtRdBuf         (pe2epct_updtRdBuf         ), 
      .pe2epct_getRdPtrs         (pe2epct_getRdPtrs         ), 
      .pe2epct_ctrlZlp           (pe2epct_ctrlZlp           ),
      .pe2eptd_intPid            (pe2eptd_intPid            ),
      .pe2reg_clrCmdReg          (pe2reg_clrCmdReg          ),
      .pa2pe_eot                 (epct2pa_eot               ), 
      .pe2pa_tokenValid          (pe2pa_tokenValid          ), 
      .pe2pa_tokenType           (pe2pa_tokenType           ), 
      .pe2epc_idleState          (pe2epc_idleState          ), 
      .pe2epc_epNum              (pe2epc_epNum              ), 
     // .pe2epc_tokenType        (pe2epc_tokenType          ), 
      .reg2pe_enHost             (reg2pe_enHost             ),
      .reg2pe_enOTGTrans         (reg2pe_enOTGTrans         ),
      .reg2pe_epNum              (reg2pe_epNum              ),
      .reg2pe_devHalt            (reg2pe_devHalt            ),
      .reg2pe_usbMode            (reg2pe_usbMode            ),
      .reg2pe_tokenType          (reg2pe_tokenType          ),
      .pe2reg_transSent          (pe2reg_transSent          ),  
      .eptd2pe_noTransPending    (eptd2pe_noTransPending    ),
      .pe2reg_remoteWakeUp       (pe2reg_remoteWakeUp       ),
      .pe2reg_lpmRcvd            (pe2reg_lpmRcvd            ),
      .frmCntr2pe_frmBndry       (frmCntr2pe_frmBndry       ) 

   );


   uctl_epcr #(
      .ADDR_SIZE                 (ADDR_SIZE                 ),
      .DATA_SIZE                 (DATA_SIZE                 ),
      .REGISTER_EPDATA           (REGISTER_EPDATA           )
   ) i_end_point_controller_rx   (
      .uctl_rst_n                (uctl_CoreRst_n            ),
      .core_clk                  (uctl_CoreClk              ),
      .sw_rst                    (1'b0                      ),
      .pd2epcr_dataValid         (pd2epcr_dataValid         ),
      .pd2epcr_data              (pd2epcr_data              ),
      .pd2epcr_dataBE            (pd2epcr_dataBE            ),
      .pd2epcr_eot               (pd2epcr_eot               ),
      //.pd2epcr_zeroLen         (pd2epcr_zeroLen           ),
      .epcr2pd_ready             (epcr2pd_ready             ),
      .pe2epcr_getWrPtrs         (pe2epcr_getWrPtrs         ),
      .pe2epcr_wrEn              (pe2epcr_wrEn              ),
      .pe2epcr_rxHdrWr           (pe2epcr_rxHdrWr           ),
      .pe2epcr_updtWrBuf         (pe2epcr_updtWrBuf         ),
      .pe2epcr_regWr             (pe2epcr_regWr             ),
      .pe2epc_epNum              (pe2epc_epNum              ),
      //.pe2epc_tokenType        (pe2epc_tokenType          ),
      .epcr2pe_ready             (epcr2pe_ready             ), 
      .epcr2pe_epHalt            (epcr2pe_epHalt            ),
      .epcr2pe_bufFull           (epcr2pe_bufFull           ),
      .epcr2pe_ctrlNAK           (epcr2pe_ctrlNAK           ), 
      .epcr2pe_setupStall        (epcr2pe_setupStall        ), 
      .epcr2pe_bufNearlyFull     (epcr2pe_bufNearlyFull     ),
      .epcr2pe_wrErr             (epcr2pe_wrErr             ),
      .epcr2pe_getWrPtrsDn       (epcr2pe_getWrPtrsDn       ), 
    //.epcr2pe_epDir             (epcr2pe_epDir             ),
      .epcr2pe_epType            (epcr2pe_epType            ),
      .epcr2pe_expctDataPid      (epcr2pe_expctDataPid      ),
      .epcr2pe_hdrWrDn           (epcr2pe_hdrWrDn           ),
      .epcr2pe_wrBufUpdtDn       (epcr2pe_wrBufUpdtDn       ),
      .epcr2pe_hwStall           (epcr2pe_hwStall           ),
      .epcr2pe_packetDroped      (epcr2pe_packetDroped      ),
      .epcr2pe_enuAct       (epcr2pe_enuAct         ),
      .epcr2pe_ctlTransStage     (epcr2pe_ctlTransStage     ),
    //.epcr2pe_eot               (epcr2pe_eot               ),
      .reg2epcr_enuCmdEn         (reg2epcr_enuCmdEn         ),
      .reg2epcr_EnuAct           (reg2epcr_EnuAct           ),
      .reg2epcr_descLen          (reg2epcr_descLen          ),
      .reg2epcr_descAddr         (reg2epcr_descAddr         ),
      .reg2epcr_stall            (reg2epcr_stall            ),
      .reg2epcr_rwCtlrType       (reg2epcr_rwCtlrType       ),
      .reg2epc_setupLen          (reg2epc_setupLen          ),
      .epcr2reg_enuActOut        (epcr2reg_enuActOut        ),
      .epcr2reg_enuCmdUpdt       (epcr2reg_enuCmdUpdt       ),
      .epcr2reg_descLenUpdt      (epcr2reg_descLenUpdt      ),
      .epcr2reg_setupData        (epcr2reg_setupData        ),
      .epcr2reg_setupRegIndex    (epcr2reg_setupRegIndex    ), 
      .epcr2reg_setupWrReq       (epcr2reg_setupWrReq       ),
      .epcr2reg_bufFull          (epcr2reg_bufFull          ),
      .epcr2reg_dpRcvd           (epcr2reg_dpRcvd           ), 
      .epcr2reg_zlpRcvd          (epcr2reg_zlpRcvd          ), 
      .epcr2reg_setupRcvd        (epcr2reg_setupRcvd        ),
      .epcr2eptd_setEphalt       (epcr2eptd_setEphalt       ),
      .eptd2epcr_wrReqErr        (eptd2epcr_wrReqErr        ),
      .eptd2epcr_startAddr       (eptd2epcr_startAddr       ),
      .eptd2epcr_endAddr         (eptd2epcr_endAddr         ),
      .eptd2epcr_rdPtr           (eptd2epcr_rdPtr           ), 
      .eptd2epcr_wrPtr           (eptd2epcr_wrPtr           ), 
      .eptd2epcr_lastOp          (eptd2epcr_lastOp          ),
      .eptd2epcr_exptDataPid     (eptd2epcr_exptDataPid     ),
      .eptd2epcr_updtDn          (eptd2epcr_updtDn          ),
      .eptd2epcr_epHalt          (eptd2epcr_epHalt          ),
      .eptd2epcr_epTrans         (eptd2epcr_epTrans         ),
      .eptd2epcr_wMaxPktSize     (eptd2epcr_wMaxPktSize     ),
      //.eptd2epcr_dir           (eptd2epcr_dir             ),
      .eptd2epcr_epType          (eptd2epcr_epType          ),
      .epcr2eptd_epNum           (epcr2eptd_epNum           ),
      .epcr2eptd_reqData         (epcr2eptd_reqData         ),
      .epcr2eptd_updtReq         (epcr2eptd_updtReq         ),
      .epcr2eptd_dataFlush       (epcr2eptd_dataFlush       ),
      .epcr2eptd_wrPtrOut        (epcr2eptd_wrPtrOut        ),
      .epcr2eptd_nxtDataPid      (epcr2eptd_nxtDataPid      ),
      .epcr2mif_addr             (uctl_Mem0Addr             ),
      .epcr2mif_data             (uctl_Mem0Dout             ),
      .epcr2mif_wr               (uctl_Mem0WrN              ),
      .mif2epcr_ack              (uctl_Mem0Ack              ) 

   );


   uctl_epct #(
      .ADDR_SIZE                 (ADDR_SIZE                 ),
      .DATA_SIZE                 (DATA_SIZE                 ),
      .REGISTER_EPDATA           (REGISTER_EPDATA           )
   ) i_end_point_controller_tx   (
      .uctl_rst_n                (uctl_CoreRst_n            ),
      .core_clk                  (uctl_CoreClk              ),
      .sw_rst                    (1'b0                      ),
      .pa2epct_ready             (pa2epct_ready             ),
      .epct2pa_dataValid         (epct2pa_dataValid         ),
      .epct2pa_data              (epct2pa_data              ),
      .epct2pa_dataBE            (epct2pa_dataBE            ),
      .epct2pa_zeroLen           (epct2pa_zeroLen           ),
      .epct2pa_eot               (epct2pa_eot               ),                       
      .pe2epct_getRdPtrs         (pe2epct_getRdPtrs         ),
      .pe2epct_ctrlZlp           (pe2epct_ctrlZlp           ),
      .pe2epct_rdEn              (pe2epct_rdEn              ),
      .pe2epct_hdrRd             (pe2epct_hdrRd             ), 
      .pe2epct_updtRdBuf         (pe2epct_updtRdBuf         ),
      .pe2epc_idleState          (pe2epc_idleState          ),
      .pe2epc_epNum              (pe2epc_epNum              ),
      //.pe2epc_tokenType        (pe2epc_tokenType          ),
      .epct2pe_epHalt            (epct2pe_epHalt            ),
      .epct2pe_epZeroLenEn       (epct2pe_epZeroLenEn       ), 
      .epct2pe_bufEmpty          (epct2pe_bufEmpty          ), 
      .epct2pe_rdErr             (epct2pe_rdErr             ),
      .epct2pe_getRdPtrsDn       (epct2pe_getRdPtrsDn       ), 
      .epct2pe_epType            (epct2pe_epType            ),
      .epct2pe_expctDataPid      (epct2pe_expctDataPid      ),
      .epct2pe_hdrRdDn           (epct2pe_hdrRdDn           ),
      .epct2pe_rdBufUpdtDn       (epct2pe_rdBufUpdtDn       ),
      //.epct2pePa_eot           (epct2pe_eot               ),
      .reg2epct_enuCmdEn         (reg2epct_enuCmdEn         ),
      .reg2epct_EnuAct           (reg2epct_EnuAct           ),
      .reg2epct_descLen          (reg2epct_descLen          ),
      .reg2epct_descAddr         (reg2epct_descAddr         ),
      .reg2epct_stall            (reg2epct_stall            ),
      .reg2epct_rwCtlrType       (reg2epct_rwCtlrType       ),
      .reg2epc_setupLen          (reg2epc_setupLen          ),
      .epct2reg_enuActOut        (epct2reg_enuActOut        ),
      .epct2reg_enuCmdUpdt       (epct2reg_enuCmdUpdt       ),
      .epct2reg_descLenUpdt      (epct2reg_descLenUpdt      ),
      .epct2reg_dpSend           (epct2reg_dpSend           ),            
      .epct2reg_zlpSent          (epct2reg_zlpSent          ),
      .epct2reg_bufEmpty         (epct2reg_bufEmpty         ),
      .eptd2epct_reqErr          (eptd2epct_reqErr          ),
      .eptd2epct_startAddr       (eptd2epct_startAddr       ),
      .eptd2epct_endAddr         (eptd2epct_endAddr         ),
      .eptd2epct_rdPtr           (eptd2epct_rdPtr           ),
      .eptd2epct_wrPtr           (eptd2epct_wrPtr           ),
      .eptd2epct_lastOp          (eptd2epct_lastOp          ),
      .eptd2epct_exptDataPid     (eptd2epct_exptDataPid     ),
      .eptd2epct_updtDn          (eptd2epct_updtDn          ),
      .eptd2epct_epHalt          (eptd2epct_epHalt          ),
      .eptd2epct_epTrans         (eptd2epct_epTrans         ),
      //.eptd2epct_dir           (eptd2epct_dir             ),
      .eptd2epct_epType          (eptd2epct_epType          ),
      .eptd2epct_zLenPkt         (eptd2epct_zLenPkt         ),
      .epct2eptd_epNum           (epct2eptd_epNum           ),
      .epct2eptd_reqData         (epct2eptd_reqData         ),
      .epct2eptd_updtReq         (epct2eptd_updtReq         ),
      .epct2eptd_rdPtrOut        (epct2eptd_rdPtrOut        ),
      .epct2eptd_nxtExpDataPid   (epct2eptd_nxtExpDataPid   ), 
      .epct2mif_addr             (uctl_Mem2Addr             ),
      .epct2mif_rd               (Mem2RdWrN                 ), 
      .mif2epct_ack              (uctl_Mem2Ack              ),
      .mif2epct_data             (uctl_Mem2Din              ),
      .mif2epct_dVal             (uctl_Mem2DVld             )

   );


   uctl_regEptdInf i_regEptdInf(
      .core_clk                (uctl_CoreClk                ),
      .uctl_rst_n              (uctl_CoreRst_n              ),
      .uctl_SysClk             (uctl_SysClk                 ),
      .uctl_SysRst_n           (uctl_SysRst_n               ),
      .uctl_PhyClk             (uctl_PhyClk                 ), 
      .uctl_PhyRst_n           (uctl_PhyRst_n               ), 
      .cmdIf_trEn              (cmdIf_trEn                  ),
      .cmdIf_req               (cmdIf_req                   ),
      .cmdIf_addr              (cmdIf_addr                  ),
      .cmdIf_wrRd              (cmdIf_wrRd                  ),
      .cmdIf_ack               (cmdIf_ack_1                 ),
    //  .uctl_powerDown          (uctl_powerDown              ),
    //  .uctl_glitchFilterCount  (uctl_glitchFilterCount      ),
      .reg2cmdIf_memSegAddr    (reg2cmdIf_memSegAddr        ),
      .cmdIf_wrData_req        (cmdIf_wrData_req            ),
      .reg2sepr_dmaMode        (reg2sepr_dmaMode            ),
      .reg2sept_dmaMode        (reg2sept_dmaMode            ),
      .cmdIf_wrData            (cmdIf_wrData                ),
      .cmdIf_wrData_ack        (cmdIf_wrData_ack_1          ),
      .cmdIf_rdData_req        (cmdIf_rdData_req            ),
      .cmdIf_rdData_ack        (cmdIf_rdData_ack_1          ),
      .cmdIf_rdData            (cmdIf_rdData_1              ),
      .reg2sepr_sWrAddr        (reg2sepr_sWrAddr            ),
      .reg2sept_sRdAddr        (reg2sept_sRdAddr            ),
      .reg2epcr_enuCmdEn       (reg2epcr_enuCmdEn           ),
      .reg2epcr_EnuAct         (reg2epcr_EnuAct             ),
      .reg2epcr_descLen        (reg2epcr_descLen            ),
      .reg2epcr_descAddr       (reg2epcr_descAddr           ),
      .reg2epcr_stall          (reg2epcr_stall              ),
      .reg2epcr_rwCtlrType     (reg2epcr_rwCtlrType         ),
      .epcr2reg_enuActOut      (epcr2reg_enuActOut          ),
      .epcr2reg_enuCmdUpdt     (epcr2reg_enuCmdUpdt         ),
      .epcr2reg_descLenUpdt    (epcr2reg_descLenUpdt        ),
      .epcr2reg_setupData      (epcr2reg_setupData          ),
      .epcr2reg_setupRegIndex  (epcr2reg_setupRegIndex      ), 
      .epcr2reg_setupWrReq     (epcr2reg_setupWrReq         ),
      .epcr2reg_bufFull        (epcr2reg_bufFull            ),
      .epcr2reg_zlpRcvd        (epcr2reg_zlpRcvd            ), 
      .epcr2reg_dpRcvd         (epcr2reg_dpRcvd             ),   
      .epcr2reg_setupRcvd      (epcr2reg_setupRcvd          ),
      .reg2epct_enuCmdEn       (reg2epct_enuCmdEn           ),
      .reg2epct_EnuAct         (reg2epct_EnuAct             ),
      .reg2epct_descLen        (reg2epct_descLen            ),
      .reg2epct_descAddr       (reg2epct_descAddr           ),
      .reg2epct_stall          (reg2epct_stall              ),
      .reg2epct_rwCtlrType     (reg2epct_rwCtlrType         ),
      .reg2epc_setupLen        (reg2epc_setupLen            ),
      .epct2reg_enuActOut      (epct2reg_enuActOut          ),
      .epct2reg_enuCmdUpdt     (epct2reg_enuCmdUpdt         ),
      .epct2reg_descLenUpdt    (epct2reg_descLenUpdt        ),
      .epct2reg_dpSend         (epct2reg_dpSend             ),            
      .epct2reg_zlpSent        (epct2reg_zlpSent            ),
      .epct2reg_bufEmpty       (epct2reg_bufEmpty           ),
      .epcr2eptd_setEphalt     (epcr2eptd_setEphalt         ),
      .intrReq                 (uctl_irq                    ),
      .reg2pe_enHost           (reg2pe_enHost               ),
      .reg2pe_enOTGTrans       (reg2pe_enOTGTrans           ),
      .reg2pe_epNum            (reg2pe_epNum                ),   
      .reg2pe_devHalt          (reg2pe_devHalt              ),
      .reg2pe_tokenType        (reg2pe_tokenType            ),   
      .reg2pe_usbMode          (reg2pe_usbMode              ),
      .pe2reg_transSent        (pe2reg_transSent            ),  
      .pe2eptd_initIsoPid      (pe2eptd_initIsoPid          ),
      .reg2sctrlRx_rd          (reg2sctrlRx_rd              ),
      .reg2sctrlRx_epNum       (reg2sctrlRx_epNum           ),
      .reg2sctrlRx_rdCount     (reg2sctrlRx_rdCount         ),
      .sctrlRx2reg_updtRdBuf   (sctrlRx2reg_updtRdBuf       ),
      .sctrlRx2reg_rdCnt       (sctrlRx2reg_rdCnt           ),
      .sctrlRx2reg_status      (sctrlRx2reg_status          ),
      .sctrlRx2reg_fullPktCnt  (sctrlRx2reg_fullPktCnt      ),
      .reg2sctrlRx_listMode    (reg2sctrlRx_listMode        ),
      .reg2sctrlTx_wrPktLength (reg2sctrlTx_wrPktLength     ),
      .pe2eptd_intPid          (pe2eptd_intPid              ),
      .pe2reg_clrCmdReg        (pe2reg_clrCmdReg            ),
      .reg2sctrlTx_epNum       (reg2sctrlTx_epNum           ),
      .reg2sctrlTx_wr          (reg2sctrlTx_wr              ),
      .reg2sctrlTx_disFrag     (reg2sctrlTx_disFrag         ),
      .sctrlTx2reg_status      (sctrlTx2reg_status          ),
      .sctrlTx2reg_length      (sctrlTx2reg_length          ),
      .sctrlTx2reg_fragCnt     (sctrlTx2reg_fragCnt         ),
      .sctrlTx2reg_updt        (sctrlTx2reg_updt            ),
      .sctrlTx2reg_fullPktCnt  (sctrlTx2reg_fullPktCnt      ),
      .reg2sctrlTx_listMode    (reg2sctrlTx_listMode        ),
      .reg2pd_dataBus16_8      (reg2pd_dataBus16_8          ),
      .reg2pd_devId            (reg2pd_devId                ),
      .reg2pa_tokenValid       (reg2pa_tokenValid           ),
      .reg2pa_dataBus16_8      (reg2pa_dataBus16_8          ),
      .reg2pa_tokenType        (reg2pa_tokenType            ),
      .reg2pa_epNum            (reg2pa_epNum                ),
      .reg2pa_devID            (reg2pa_devID                ),
      .reg2pa_frameNum         (reg2pa_frameNum             ),
      .pd2eptd_statusStrobe    (pd2eptd_statusStrobe        ),
      .pd2eptd_crc5            (pd2eptd_crc5                ),
      .pd2eptd_pid             (pd2eptd_pid                 ),
      .pd2eptd_err             (pd2eptd_err                 ),
      .pd2eptd_epNum           (pd2eptd_epNum               ),
      .epcr2eptd_epNum         (epcr2eptd_epNum             ),
      .epcr2eptd_reqData       (epcr2eptd_reqData           ),
      .epcr2eptd_updtReq       (epcr2eptd_updtReq           ),
      .epcr2eptd_dataFlush     (epcr2eptd_dataFlush         ),
      .epcr2eptd_wrPtrOut      (epcr2eptd_wrPtrOut          ),
      .epcr2eptd_nxtDataPid    (epcr2eptd_nxtDataPid        ),
      .eptd2epcr_wrReqErr      (eptd2epcr_wrReqErr          ),
      .eptd2epcr_startAddr     (eptd2epcr_startAddr         ),
      .eptd2epcr_endAddr       (eptd2epcr_endAddr           ),
      .eptd2epcr_rdPtr         (eptd2epcr_rdPtr             ),
      .eptd2epcr_wrPtr         (eptd2epcr_wrPtr             ),
      .eptd2epcr_lastOp        (eptd2epcr_lastOp            ),
      .eptd2epcr_exptDataPid   (eptd2epcr_exptDataPid       ),
      .eptd2epcr_updtDn        (eptd2epcr_updtDn            ),
      .eptd2epcr_wMaxPktSize   (eptd2epcr_wMaxPktSize       ),
      .eptd2epcr_epType        (eptd2epcr_epType            ),
      .eptd2epcr_epTrans       (eptd2epcr_epTrans           ),
      .eptd2epcr_epHalt        (eptd2epcr_epHalt            ),
      .epct2eptd_epNum         (epct2eptd_epNum             ),
      .epct2eptd_reqData       (epct2eptd_reqData           ),
      .epct2eptd_updtReq       (epct2eptd_updtReq           ),
      .epct2eptd_rdPtrOut      (epct2eptd_rdPtrOut          ),
      .epct2eptd_nxtExpDataPid (epct2eptd_nxtExpDataPid     ),
      .eptd2epct_reqErr        (eptd2epct_reqErr            ),
      .eptd2epct_zLenPkt       (eptd2epct_zLenPkt           ),
      .eptd2epct_startAddr     (eptd2epct_startAddr         ),
      .eptd2epct_endAddr       (eptd2epct_endAddr           ),
      .eptd2epct_rdPtr         (eptd2epct_rdPtr             ),
      .eptd2epct_wrPtr         (eptd2epct_wrPtr             ),
      .eptd2epct_lastOp        (eptd2epct_lastOp            ),
      .eptd2epct_exptDataPid   (eptd2epct_exptDataPid       ),
      .eptd2epct_updtDn        (eptd2epct_updtDn            ),
      .eptd2epct_epType        (eptd2epct_epType            ),
      .eptd2epct_epTrans       (eptd2epct_epTrans           ),
      .eptd2epct_epHalt        (eptd2epct_epHalt            ),
      .eptd2pe_noTransPending  (eptd2pe_noTransPending      ),
      .sept2eptd_epNum         (sept2eptd_epNum             ),
      .sept2eptd_reqData       (sept2eptd_reqData           ),
      .sept2eptd_updtReq       (sept2eptd_updtReq           ),
      .sept2eptd_wrPtrOut      (sept2eptd_wrPtrOut          ),
    //.eptd2sept_reqErr        (eptd2sept_reqErr            ),
      .eptd2sept_startAddr     (eptd2sept_startAddr         ),
      .eptd2sept_endAddr       (eptd2sept_endAddr           ),
      .eptd2sept_rdPtr         (eptd2sept_rdPtr             ),
      .eptd2sept_wrPtr         (eptd2sept_wrPtr             ),
      .eptd2sept_updtDn        (eptd2sept_updtDn            ),
      .eptd2sept_bSize         (eptd2sept_bSize             ),
      .eptd2sept_lastOp        (eptd2sept_lastOp            ),
      .eptd2sept_fullPktCnt    (eptd2sept_fullPktCnt        ),
      .sepr2eptd_epNum         (sepr2eptd_epNum             ),
      .sepr2eptd_reqData       (sepr2eptd_reqData           ),
      .sepr2eptd_updtReq       (sepr2eptd_updtReq           ),
      .eptd2sepr_startAddr     (eptd2sepr_startAddr         ),
      .eptd2sepr_endAddr       (eptd2sepr_endAddr           ),
      .eptd2sepr_rdPtr         (eptd2sepr_rdPtr             ),
      .eptd2sepr_wrPtr         (eptd2sepr_wrPtr             ),
      .eptd2sepr_lastOp        (eptd2sepr_lastOp            ),
      .eptd2sepr_updtDn        (eptd2sepr_updtDn            ),  
      .sepr2eptd_rdPtr         (sepr2eptd_rdPtr             ),
      .eptd2sepr_fullPktCnt    (eptd2sepr_fullPktCnt        ),
    //.eptd2sepr_ReqErr        (eptd2sepr_ReqErr            ) 
      .por2reg_fsmIntr         (por2reg_fsmIntr             ), //TODO por signals working on phy clock need to connect asyn path not done.
      .por2reg_resumeCompleted (por2reg_resumeCompleted     ), 
      .por2reg_resumeDetected  (por2reg_resumeDetected      ), 
      .por2reg_resetCompleted  (por2reg_resetCompleted      ), 
      .por2reg_resetDetected   (por2reg_resetDetected       ), 
      .por2reg_susDetected     (por2reg_susDetected         ), 
      .pe2reg_lpmRcvd          (pe2reg_lpmRcvd              ),
      .pe2reg_remoteWakeUp     (pe2reg_remoteWakeUp         ),
      .reg2frmCntr_upCntMax    (reg2frmCntr_upCntMax        ),
      .reg2frmCntr_timerCorr   (reg2frmCntr_timerCorr       ),
      .frmCntr2reg_frameCount  (frmCntr2reg_frameCount      ),
      .frmCntr2reg_frameCntVl  (frmCntr2reg_frameCntVl      ),
      .frmCntr2reg_sofSent     (frmCntr2reg_sofSent         ),
      .frmCntr2reg_sofRcvd     (frmCntr2reg_sofRcvd         ),
      .reg2frmCntr_eof1        (reg2frmCntr_eof1            ),
      .reg2frmCntr_eof2        (reg2frmCntr_eof2            ),
      .reg2frmCntr_enAutoSof   (reg2frmCntr_enAutoSof       ),
      .reg2frmCntr_autoLd      (reg2frmCntr_autoLd          ),
      .reg2frmCntr_timerStVal  (reg2frmCntr_timerStVal      ),
      .reg2frmCntr_ldTimerStVal(reg2frmCntr_ldTimerStVal    ),
      .sctrlRx2reg_empty       (sctrlRx2reg_empty           ),
      .sctrlTx2reg_full        (sctrlTx2reg_full            ), 
      .frmCntr2reg_eof1Hit     (frmCntr2reg_eof1Hit         )


   );
    uctl_sept i_system_endpoint_controller_tx (
      .sw_rst                    (1'b0                      ),
      .core_clk                  (uctl_CoreClk              ),
      .uctl_rst_n                (uctl_CoreRst_n            ),
      .mif2sept_ack              (mif2sept_ack              ),
      .sept2mif_wr               (sept2mif_wr               ),
      .sept2mif_addr             (sept2mif_addr             ),
      .sept2mif_wrData           (sept2mif_wrData           ),
      //.sctrlTx2sept_offsetAddr   (sctrlTx2sept_offsetAddr ),
      .sctrlTx2sept_epNum        (sctrlTx2sept_epNum        ),
      .sctrlTx2sept_wrPktLength  (sctrlTx2sept_wrPktLength  ),
      .sctrlTx2sept_inIdle       (sctrlTx2sept_inIdle       ),
      .sctrlTx2sept_getWrPtrs    (sctrlTx2sept_getWrPtrs    ),
      .sctrlTx2sept_wr           (sctrlTx2sept_wr           ),
      .reg2sept_dmaMode          (reg2sept_dmaMode          ),
      .sctrlTx2sept_wrAddrEn     (sctrlTx2sept_wrAddrEn     ),
      .sctrlTx2sept_hdrWr        (sctrlTx2sept_hdrWr        ),
      .sctrlTx2sept_updtWrBuf    (sctrlTx2sept_updtWrBuf    ),
      .sept2sctrlTx_bufUpdtDn    (sept2sctrlTx_bufUpdtDn    ),
      .sept2sctrlTx_eptBufSize   (sept2sctrlTx_eptBufSize   ),
      .sept2sctrlTx_hdrWrDn      ( sept2sctrlTx_hdrWrDn     ),
      .sept2sctrlTx_wrPtrsRecvd  (sept2sctrlTx_wrPtrsRecvd  ),
      .sept2sctrlTx_transferDn   (sept2sctrlTx_transferDn   ),
      .sept2sctrlTx_transferErr  (sept2sctrlTx_transferErr  ),
      .sept2sctrlTx_bufFull      (sept2sctrlTx_bufFull      ),
      .eptd2sept_startAddr       (eptd2sept_startAddr       ),
      .reg2sept_sRdAddr          (reg2sept_sRdAddr          ) ,
      .sept2dmaTx_sRdAddr        (sept2dmaTx_sRdAddr        ),
      .eptd2sept_fullPktCnt      (eptd2sept_fullPktCnt      ) ,
      .eptd2sept_endAddr         (eptd2sept_endAddr         ),
      .eptd2sept_rdPtrs          (eptd2sept_rdPtr           ),
      .eptd2sept_updtDn          (eptd2sept_updtDn          ), 
      .eptd2sept_wrPtrs          (eptd2sept_wrPtr           ),
      .eptd2sept_bSize           (eptd2sept_bSize           ),
      .eptd2sept_lastOp          (eptd2sept_lastOp          ),
      .cmdIf2sept_dn             (cmdIf2sept_dn             ) ,  
      .sept2cmdIf_wr             (sept2cmdIf_wr             ) ,  
      .sept2cmdIf_dmaMode        (sept2cmdIf_dmaMode        ) ,  
      .sept2cmdIf_addr           (sept2cmdIf_addr           ) ,  
      .sept2cmdIf_len            (sept2cmdIf_len            ) ,  
      .sept2cmdIf_epStartAddr    (sept2cmdIf_epStartAddr    ) ,  
      .sept2cmdIf_epEndAddr      (sept2cmdIf_epEndAddr      ) ,  
      .sept2eptd_epNum           (sept2eptd_epNum           ),
      .sept2eptd_reqData         (sept2eptd_reqData         ),
      .sept2eptd_updtReq         (sept2eptd_updtReq         ),
      .sept2eptd_wrPtrOut        (sept2eptd_wrPtrOut        ),
      .sept2dmaTx_addrIn         (sept2dmaTx_addrIn         ),
      .sept2dmaTx_sRdWr          (sept2dmaTx_sRdWr          ),        
      .sept2dmaTx_wr             (sept2dmaTx_wr             ),        
      .sept2dmaTx_len            (sept2dmaTx_len            ),
      .sept2dmaTx_epStartAddr    (sept2dmaTx_epStartAddr    ),
      .sept2dmaTx_epEndAddr      (sept2dmaTx_epEndAddr      ),
      .sept2sctrlTx_fullPktCnt   (sept2sctrlTx_fullPktCnt   ),  
      .dmaTx2sept_dn             (dmaTx2sept_dn             )
   );



   uctl_sysControllerTx
       i_system_controller_tx    (
      .sw_rst                    (1'b0                      ),
      .coreClk                   (uctl_CoreClk              ),
      .uctl_rst_n                (uctl_CoreRst_n            ),
      .sept2sctrlTx_bufFull      ( sept2sctrlTx_bufFull     ),
      .sept2sctrlTx_wrPtrsRecvd  ( sept2sctrlTx_wrPtrsRecvd ),
      .sept2sctrlTx_transferDn   ( sept2sctrlTx_transferDn  ),
      .sept2sctrlTx_transferErr  ( sept2sctrlTx_transferErr ),
      .sept2sctrlTx_hdrWrDn      ( sept2sctrlTx_hdrWrDn     ),
      .reg2sctrlTx_listMode      (reg2sctrlTx_listMode ) ,
      .sept2sctrlTx_bufUpdtDn    ( sept2sctrlTx_bufUpdtDn   ),
      .sept2sctrlTx_eptBufSize   ( sept2sctrlTx_eptBufSize  ),
      .sctrlTx2sept_wrAddrEn     (sctrlTx2sept_wrAddrEn     ),
      .sctrlTx2sept_epNum        ( sctrlTx2sept_epNum       ),
      .sctrlTx2sept_wrPktLength  ( sctrlTx2sept_wrPktLength ),

      .sctrlTx2reg_full          (sctrlTx2reg_full          ),
      .sctrlTx2sept_updtWrBuf    ( sctrlTx2sept_updtWrBuf   ),
      .sctrlTx2sept_inIdle       ( sctrlTx2sept_inIdle      ),
   // .sctrlTx2sept_offsetAddr   ( sctrlTx2sept_offsetAddr  ),
      .sctrlTx2sept_getWrPtrs    ( sctrlTx2sept_getWrPtrs   ),
      .sctrlTx2sept_wr           ( sctrlTx2sept_wr          ),
      .sctrlTx2reg_status        (sctrlTx2reg_status        ),
      .sctrlTx2sept_hdrWr        ( sctrlTx2sept_hdrWr       ),
      .reg2sctrlTx_wrPktLength   ( reg2sctrlTx_wrPktLength  ), 
      .reg2sctrlTx_epNum         ( reg2sctrlTx_epNum        ),
      .reg2sctrlTx_wr            ( reg2sctrlTx_wr           ),
      .reg2sctrlTx_disFrag       ( reg2sctrlTx_disFrag      ),
      .sctrlTx2reg_length        ( sctrlTx2reg_length       ),
      .sctrlTx2reg_fragCnt       ( sctrlTx2reg_fragCnt      ),
      .sctrlTx2reg_fullPktCnt    (sctrlTx2reg_fullPktCnt    ) ,
      .sept2sctrlTx_fullPktCnt   (sept2sctrlTx_fullPktCnt   ),  
      .sctrlTx2reg_updt          ( sctrlTx2reg_updt         ) 
   );                                                         
                                                              
                                                              
                                                              
   uctl_sepr#(                           
      .REGISTER_EN               (1                         ),
      .ADDR_SIZE                 (32                        ),
      .DATA_SIZE                 (32                        ) 
   )i_system_endpoint_controller_rx (                        
      .sw_rst                    (1'b0                      ),
      .uctl_rst_n                (uctl_CoreRst_n            ),
      .core_clk                  (uctl_CoreClk              ),
      .sctrlRx2sepr_epNum        (sctrlRx2sepr_epNum        ),
      .sctrlRx2sepr_inIdle       (sctrlRx2sepr_inIdle       ),
      .sctrlRx2sepr_hdrRd        (sctrlRx2sepr_hdrRd        ),
      .sctrlRx2sepr_getRdPtrs    (sctrlRx2sepr_getRdPtrs    ),
      .sctrlRx2sepr_rd           (sctrlRx2sepr_rd           ),
      .sctrlRx2sepr_updtRdBuf    (sctrlRx2sepr_updtRdBuf    ),
      .reg2sepr_dmaMode          (reg2sepr_dmaMode          ),
      .sepr2sctrlRx_rdPtrsRcvd   (sepr2sctrlRx_rdPtrsRcvd   ),
      .sepr2sctrlRx_bufEmpty     (sepr2sctrlRx_bufEmpty     ),
      .sepr2sctrlRx_hdrRdDn      (sepr2sctrlRx_hdrRdDn      ),
      .sepr2sctrlRx_transferDn   (sepr2sctrlRx_transferDn   ),
      .sepr2sctrlRx_bufUpdtDn    (sepr2sctrlRx_bufUpdtDn    ),
      .dmaRx2sepr_dn             (dmaRx2sepr_dn             ),
      .sepr2dmaRx_laddrIn        (sepr2dmaRx_laddrIn        ),
      .sepr2dmaRx_dmaStart       (sepr2dmaRx_dmaStart       ),
      .sepr2dmaRx_len            (sepr2dmaRx_len            ),
      .sepr2dmaRx_sRdWr          (sepr2dmaRx_sRdWr          ),
      .sepr2dmaRx_epStartAddr    (sepr2dmaRx_epStartAddr    ),
      .sepr2dmaRx_epEndAddr      (sepr2dmaRx_epEndAddr      ),
      .mif2sepr_rdData           (mif2sepr_rdData           ),
      .mif2sepr_ack              (mif2sepr_ack              ),
      .mif2sepr_dVal             (mif2sepr_rdVal            ),
      .sepr2mif_addr             (sepr2mif_addr             ),
      .sepr2mif_rd               (sepr2mif_rd               ),
      .sctrlRx2sepr_wrAddrEn     (sctrlRx2sepr_wrAddrEn     ),
      .sepr2sctrlRx_fullPktCnt   (sepr2sctrlRx_fullPktCnt   ),  
      .eptd2sepr_startAddr       (eptd2sepr_startAddr       ),
      .eptd2sepr_endAddr         (eptd2sepr_endAddr         ),
      .eptd2sepr_rdPtr           (eptd2sepr_rdPtr           ),
      .eptd2sepr_wrPtr           (eptd2sepr_wrPtr           ),
      .eptd2sepr_lastOp          (eptd2sepr_lastOp          ),
      .reg2sepr_sWrAddr          (reg2sepr_sWrAddr          ),
      .eptd2sepr_updtDn          (eptd2sepr_updtDn          ),  
      .eptd2sepr_fullPktCnt      (eptd2sepr_fullPktCnt      ),
      .sepr2dmaRx_sWrAddr        (sepr2dmaRx_sWrAddr        ), 
      .cmdIf2sepr_dn             (cmdIf2sepr_dn             ),    
      .sepr2cmdIf_dmaMode        (sepr2cmdIf_dmaMode        ),    
      .sepr2cmdIf_rd             (sepr2cmdIf_rd             ),    
      .sepr2cmdIf_addr           (sepr2cmdIf_addr           ),    
      .sepr2cmdIf_len            (sepr2cmdIf_len            ),    
      .sepr2cmdIf_epStartAddr    (sepr2cmdIf_epStartAddr    ),    
      .sepr2cmdIf_epEndAddr      (sepr2cmdIf_epEndAddr      ),    
      .sepr2eptd_epNum           (sepr2eptd_epNum           ),
      .sepr2eptd_reqData         (sepr2eptd_reqData         ),
      .sepr2eptd_updtReq         (sepr2eptd_updtReq         ),
      .sepr2eptd_rdPtr           (sepr2eptd_rdPtr           ) 
   );



   uctl_sysControllerRx i_system_controller_rx (
      .sw_rst                    (1'b0                      ),
      .uctl_rst_n                (uctl_CoreRst_n            ),
      .coreClk                   (uctl_CoreClk              ),
      .reg2sctrlRx_rd            (reg2sctrlRx_rd            ),
      .reg2sctrlRx_epNum         (reg2sctrlRx_epNum         ),
      .reg2sctrlRx_rdCount       (reg2sctrlRx_rdCount       ), 
      .sctrlRx2reg_rdCnt         (sctrlRx2reg_rdCnt         ), 
      .sctrlRx2reg_updtRdBuf     (sctrlRx2reg_updtRdBuf     ),
      .sctrlRx2reg_status        (sctrlRx2reg_status        ),
      .sepr2sctrlRx_bufEmpty     (sepr2sctrlRx_bufEmpty     ),
      .sepr2sctrlRx_rdPtrsRcvd   (sepr2sctrlRx_rdPtrsRcvd   ),
      .reg2sctrlRx_listMode      (reg2sctrlRx_listMode      ) ,
      .sepr2sctrlRx_transferDn   (sepr2sctrlRx_transferDn   ),
      .sctrlRx2sepr_wrAddrEn     (sctrlRx2sepr_wrAddrEn     ),
      .sepr2sctrlRx_fullPktCnt   (sepr2sctrlRx_fullPktCnt   ),  
      .sepr2sctrlRx_hdrRdDn      (sepr2sctrlRx_hdrRdDn      ),            
      .sctrlRx2reg_empty         (sctrlRx2reg_empty         ),
      .sctrlRx2reg_fullPktCnt    (sctrlRx2reg_fullPktCnt    ) ,
      .sepr2sctrlRx_bufUpdtDn    (sepr2sctrlRx_bufUpdtDn    ),
      .sctrlRx2sepr_inIdle       (sctrlRx2sepr_inIdle       ),
      .sctrlRx2sepr_epNum        (sctrlRx2sepr_epNum        ),
      .sctrlRx2sepr_getRdPtrs    (sctrlRx2sepr_getRdPtrs    ),
      .sctrlRx2sepr_hdrRd        (sctrlRx2sepr_hdrRd        ),
      .sctrlRx2sepr_rd           (sctrlRx2sepr_rd           ),
      .sctrlRx2sepr_updtRdBuf    (sctrlRx2sepr_updtRdBuf    ) 

   );

   uctl_dmaRx #(
      .CNTR_WD                   (CNTR_WD                   ),                     
      .MEM_ADD_WD                (32                        )
   )i_dmaRx (
      .uctl_rst_n                (uctl_CoreRst_n            ),
      .core_clk                  (uctl_CoreClk              ),
      .sw_rst                    (1'b0                      ),
      .sepr2dmaRx_laddrIn        (sepr2dmaRx_laddrIn        ),
      .sepr2dmaRx_dmaStart       (sepr2dmaRx_dmaStart       ),
      .sepr2dmaRx_len            (sepr2dmaRx_len            ),
      .sepr2dmaRx_epStartAddr    (sepr2dmaRx_epStartAddr    ),
      .sepr2dmaRx_epEndAddr      (sepr2dmaRx_epEndAddr      ),
      .sepr2dmaRx_sRdWr          (sepr2dmaRx_sRdWr          ),
      .dmaRx2sepr_dn             (dmaRx2sepr_dn             ),
      .mif2dmaRx_data            (mif2dmaRx_data            ),
      .dmaRx2mif_Addr            (dmaRx2mif_Addr            ),
      .dmaRx2mif_rdReq           (dmaRx2mif_rdReq           ),
      .mif2dmaRx_ack             (mif2dmaRx_ack             ), //TODO
      .mif2dmaRx_rdVal           (mif2dmaRx_rdVal           ),
      .dmaRx2ahbm_sWrAddr        (dmaRx2ahbm_sWrAddr        ),        
      .dmaRx2ahbm_sRdWr          (dmaRx2ahbm_sRdWr          ),
      .dmaRx2ahbm_len            (dmaRx2ahbm_len            ),
      .dmaRx2ahbm_stransEn       (dmaRx2ahbm_stransEn       ),
      .ahbm2dmaRx_dn             (ahbm2dmaRx_dn             ),           
      .ahbm2dmaRx_availSpace     (ahbm2dmaRx_availSpace     ), 
      .dmaRx2ahbm_data           (dmaRx2ahbm_data           ),
      .sepr2dmaRx_sWrAddr        (sepr2dmaRx_sWrAddr        ), 
      .dmaRx2ahbm_wr             (dmaRx2ahbm_wr             ) 

   );


   uctl_dmaTx #(
             .CNTR_WD     ( 20) ,                               
             .DATA_SIZE   ( 32) ,          
             .ADDR_SIZE   ( 32)
   )i_dmaTx (
    .uctl_reset_n             (uctl_CoreRst_n               ),           
    .core_Clk                 (uctl_CoreClk                 ),
  //.reg2dmaTx_sBusIntf       (reg2dmaTx_sBusIntf           ),
    .sw_rst                   (1'b0                         ),
    .sept2dmaTx_addrIn        (sept2dmaTx_addrIn            ),
    .sept2dmaTx_dmaStart      (sept2dmaTx_wr                ),
    .sept2dmaTx_len           (sept2dmaTx_len               ),
    .sept2dmaTx_epStartAddr   (sept2dmaTx_epStartAddr       ),
    .sept2dmaTx_epEndAddr     (sept2dmaTx_epEndAddr         ),
 // .sept2dmaTx_offsetAddr    (sept2dmaTx_offsetAddr        ),   
    .sept2dmaTx_sRdWr         (sept2dmaTx_sRdWr             ),        
    .dmaTx2sept_dn            (dmaTx2sept_dn                ),
    .mif2dmaTx_ack            (mif2dmaTx_ack                ),
    .dmaTx2mif_wrAddr         (dmaTx2mif_wrAddr             ),
    .dmaTx2mif_wrReq          (dmaTx2mif_wrReq              ),
    .dmaTx2mif_wrData         (dmaTx2mif_wrData             ),
    .dmaTx2ahbm_sRdAddr       (dmaTx2ahbm_sRdAddr           ),
    .dmaTx2ahbm_len           (dmaTx2ahbm_len               ),
    .dmaTx2ahbm_stransEn      (dmaTx2ahbm_stransEn          ),
    .dmaTx2ahbm_sRdWr         (dmaTx2ahbm_sRdWr             ),        
    .ahbm2dmaTx_dataDn        (ahbm2dmaTx_dataDn            ),
    .ahbm2dmaTx_ready         (ahbm2dmaTx_ready             ),
    .ahbm2dmaTx_wrData        (ahbm2dmaTx_wrData            ),
    .dmaTx2ahbm_rd            (dmaTx2ahbm_rd                ),
    .sept2dmaTx_sRdAddr       (sept2dmaTx_sRdAddr           )
   );

   
   uctl_packet_assembler #(
     
    .PA_DATASIZE                 ( 18                       ),
    .PA_ADDRSIZE                 ( 3                        )
    )i_packet_assembler          (
    .coreClk                     (uctl_CoreClk              ),            
    .phyClk                      (uctl_PhyClk               ),       
    .coreRst_n                   (uctl_CoreRst_n            ),       
    .phyRst_n                    (uctl_PhyRst_n             ),       
    .swRst                       (1'b0                      ),
    .pa2utmi_txData              (uctl_UtmiTxData           ),       
    .pa2utmi_txDataH             (uctl_UtmiTxDataH          ),                       
    .pa2utmi_txValid             (uctl_UtmiTxValid          ),                       
    .pa2utmi_txValidH            (uctl_UtmiTxValidH         ),                       
    .utmi2pa_txReady             (uctl_UtmiTxReady          ),       
    .pe2pa_tokenValid            (pe2pa_tokenValid          ),                       
    .pe2pa_tokenType             (pe2pa_tokenType           ),                       
    .epct2pa_eot                 (epct2pa_eot               ),                       
  //.pa2pe_eot                   (pa2pe_eot                 ), 
    .epct2pa_dataValid           (epct2pa_dataValid         ),       
    .epct2pa_data                (epct2pa_data              ),                       
    .epct2pa_dataBE              (epct2pa_dataBE            ),                       
    .epct2pa_zeroLentPkt         (epct2pa_zeroLen           ),//TODO
    .pa2epct_ready               (pa2epct_ready             ),      
    .reg2pa_tokenValid           (reg2pa_tokenValid         ),      
    .reg2pa_tokenType            (reg2pa_tokenType          ),      
    .reg2pa_epNum                (reg2pa_epNum              ),      
    .reg2pa_devID                (reg2pa_devID              ),      
    .reg2pa_frameNum             (reg2pa_frameNum           ),      
    .reg2pa_dataBus16_8          (reg2pa_dataBus16_8        ),      
    .crc2pa_crcValid             (crcValid                  ),      
    .crc2pa_crc                  (crc2pa_crc                )      
   );

   uctl_cmdInfMem i_cmdInfMem(
      .sys_clk                 ( uctl_SysClk            ),       
      .sysRst_n                ( uctl_SysRst_n          ), 
      .core_clk                ( uctl_CoreClk           ), 
      .uctl_rst_n              ( uctl_CoreRst_n         ), 
      .sw_rst                  ( 1'b0                   ), 
      .cmdIf_trEn              ( cmdIf_trEn             ), 
      .cmdIf_req               ( cmdIf_req              ), 
      .cmdIf_addr              ( cmdIf_addr             ), 
      .cmdIf_wrRd              ( cmdIf_wrRd             ), 
      .reg2cmdIf_memSegAddr    (reg2cmdIf_memSegAddr    ),
      .cmdIf_ack               ( cmdIf_ack_2            ), 
      .cmdIf_wrData_req        ( cmdIf_wrData_req       ), 
      .cmdIf_wrData            ( cmdIf_wrData           ), 
      .cmdIf_wrData_ack        ( cmdIf_wrData_ack_2     ), 
      .cmdIf_rdData_req        ( cmdIf_rdData_req       ), 
      .cmdIf_rdData_ack        ( cmdIf_rdData_ack_2     ), 
      .cmdIf_rdData            ( cmdIf_rdData_2         ), 
      .mem_req                 ( mem_req                ),      
      .mem_wrRd                ( mem_wrRd               ), 
      .mem_addr                ( mem_addr               ),      
      .mem_wrData              ( mem_wrData             ),    
      .mem_ack                 ( mem_ack                ), 
      .mem_rdVal               ( mem_rdVal              ), 
      .mem_rdData              ( mem_rdData             ), 
      .cmdIf2sept_dn           ( cmdIf2sept_dn          ),
      .sept2cmdIf_wr           ( sept2cmdIf_wr          ),
      .sept2cmdIf_dmaMode      ( sept2cmdIf_dmaMode     ),
      .sept2cmdIf_addr         ( sept2cmdIf_addr        ),
      .sept2cmdIf_len          ( sept2cmdIf_len         ),
      .sept2cmdIf_epStartAddr  ( sept2cmdIf_epStartAddr ),
      .sept2cmdIf_epEndAddr    ( sept2cmdIf_epEndAddr   ),
      .cmdIf2sepr_dn           ( cmdIf2sepr_dn          ),
      .sepr2cmdIf_rd           ( sepr2cmdIf_rd          ),
      .sepr2cmdIf_dmaMode      ( sepr2cmdIf_dmaMode     ),
      .sepr2cmdIf_addr         ( sepr2cmdIf_addr        ),
      .sepr2cmdIf_len          ( sepr2cmdIf_len         ),
      .sepr2cmdIf_epStartAddr  ( sepr2cmdIf_epStartAddr ),
      .sepr2cmdIf_epEndAddr    ( sepr2cmdIf_epEndAddr   )
   );
   // ahb read controller 
   uctl_ahbMaster i_ahbMaster    (
    .uctl_sysClk                 (uctl_SysClk               ),               
    .sw_rst                      (1'b0                      ),
    .coreRst_n                   (uctl_CoreRst_n            ),//TODO
    .core_clk                    (uctl_CoreClk              ), 
    .uctl_sysRst_n               (uctl_SysRst_n             ),
    .dmaTx2ahbm_sRdAddr          (dmaTx2ahbm_sRdAddr        ),                                                                                      
    .dmaTx2ahbm_len              (dmaTx2ahbm_len            ),                                                                                      
    .dmaTx2ahbm_stransEn         (dmaTx2ahbm_stransEn       ),                                                                                       
    .dmaTx2ahbm_sRdWr            (dmaTx2ahbm_sRdWr          ),
    .ahbm2dmaTx_dataDn           (ahbm2dmaTx_dataDn         ), 
    .dmaTx2ahbm_rd               (dmaTx2ahbm_rd             ),  
    .ahbm2dmaTx_ready            (ahbm2dmaTx_ready          ),  
    .ahbm2dmaTx_wrData           (ahbm2dmaTx_wrData         ),  
    .dmaRx2ahbm_sWrAddr          (dmaRx2ahbm_sWrAddr        ), 
    .dmaRx2ahbm_sRdWr            (dmaRx2ahbm_sRdWr          ),
    .dmaRx2ahbm_len              (dmaRx2ahbm_len            ), 
    .dmaRx2ahbm_stransEn         (dmaRx2ahbm_stransEn       ),   
  //.dmaRx2ahbm_BE               (dmaRx2ahbm_BE             ),    
    .ahbm2dmaRx_dn               (ahbm2dmaRx_dn             ), 
    .dmaRx2ahbm_data             (dmaRx2ahbm_data           ), 
    .dmaRx2ahbm_wr               (dmaRx2ahbm_wr             ), 
    .ahbm2dmaRx_availSpace       (ahbm2dmaRx_availSpace     ), 
    .hrdata                      (uctl_Ahbm1HRdata          ), 
    .hgrant                      (uctl_Ahbm1HGrant          ), 
    .hready                      (uctl_Ahbm1HReady          ), 
    .hresp                       (uctl_Ahbm1HResp           ), 
    .hbusreq                     (uctl_Ahbm1HBusreq         ),
    .hwrite                      (uctl_Ahbm1HWrite          ), 
    .htrans                      (uctl_Ahbm1HTrans          ), 
    .haddr                       (uctl_Ahbm1HAddr           ), 
    .hwdata                      (uctl_Ahbm1HWdata          ),
    .hsize                       (uctl_Ahbm1HSize           ), 
    .hburst                      (uctl_Ahbm1HBurst          )  
   );
   
   uctl_ahbSlave i_ahbSlave      (
   .hClk                         (uctl_SysClk               ),        
   .hReset_n                     (uctl_AhbsHReset_N         ),    
   .swRst                        (1'b0                      ),                        
   .haddr                        (uctl_AhbsHAddr            ),        
   .htrans                       (uctl_AhbsHTrans           ),        
   .hwrite                       (uctl_AhbsHWrite           ),                             
   .hsize                        (uctl_AhbsHSize            ),                             
   .hwdata                       (uctl_AhbsHWdata           ),        
   .hsel                         (uctl_AhbsHSel             ),                            
   .hready_in                    (uctl_AhbsHReadyI          ),                            
   .hrdata                       (uctl_AhbsHRdata           ),                              
   .hready_out                   (uctl_AhbsHReady           ),        
   .hresp                        (uctl_AhbsHResp            ),                            
 //.hburst                       (uctl_AhbsHBurst           ), 
 //.hprot                        (uctl_AhbsHProt            ), 
   .cmdIf_ack                    (cmdIf_ack                 ),                                                    
   .cmdIf_wrData_ack             (cmdIf_wrData_ack          ),                                                    
   .cmdIf_rdData                 (cmdIf_rdData              ),                                                    
   .cmdIf_req                    (cmdIf_req                 ),                                                    
   .cmdIf_addr                   (cmdIf_addr                ),                                                    
   .cmdIf_wrRd                   (cmdIf_wrRd                ),                                                    
   .cmdIf_wrData_req             (cmdIf_wrData_req          ),                                                    
   .cmdIf_wrData                 (cmdIf_wrData              ),                                                    
   .cmdIf_rdData_req             (cmdIf_rdData_req          ),                                                    
   .cmdIf_rdData_ack             (cmdIf_rdData_ack          ),                                
   .cmdIf_trEn                   (cmdIf_trEn                )                                

   );
      
   uctl_sysCmdMemRW i_sysCmdMem_rw   (
   .coreRst_n                    (uctl_CoreRst_n            ),            
   .coreClk                      (uctl_CoreClk              ),            
   .mem_req                      (mem_req                   ),
   .mem_wrRd                     (mem_wrRd                  ), 
   .mem_addr                     (mem_addr                  ), 
   .mem_wrData                   (mem_wrData                ), 
   .mem_ack                      (mem_ack                   ), 
   .mem_rdVal                    (mem_rdVal                 ), 
   .mem_rdData                   (mem_rdData                ), 
   .mif2sepr_rdData              (mif2sepr_rdData           ), 
   .mif2sepr_ack                 (mif2sepr_ack              ), 
   .mif2sepr_rdVal               (mif2sepr_rdVal            ), 
   .sepr2mif_addr                (sepr2mif_addr             ), 
   .sepr2mif_rd                  (sepr2mif_rd               ), 
   .mif2sept_ack                 (mif2sept_ack              ), 
   .sept2mif_wr                  (sept2mif_wr               ), 
   .sept2mif_addr                (sept2mif_addr             ), 
   .sept2mif_wrData              (sept2mif_wrData           ), 
   .mif2dmaTx_ack                (mif2dmaTx_ack             ), 
   .dmaTx2mif_wrAddr             (dmaTx2mif_wrAddr          ), 
   .dmaTx2mif_wrReq              (dmaTx2mif_wrReq           ), 
   .dmaTx2mif_wrData             (dmaTx2mif_wrData          ), 
   .mif2dmaRx_data               (mif2dmaRx_data            ),  
   .mif2dmaRx_ack                (mif2dmaRx_ack             ), 
   .mif2dmaRx_rdVal              (mif2dmaRx_rdVal           ), 
   .dmaRx2mif_Addr               (dmaRx2mif_Addr            ), 
   .dmaRx2mif_rdReq              (dmaRx2mif_rdReq           ),    
   .mem0_addr                    (uctl_Mem1Addr             ),      
   .mem0_dataIn                  (uctl_Mem1Dout             ),   
   .mem0_ackOut                  (uctl_Mem1Ack              ),   
   .mem0_wr                      (uctl_Mem1Wr_en            ),     
   //.  mem0_rd         
   .mem1_addr                    (uctl_Mem3Addr             ),     
   .mem1_ackOut                  (uctl_Mem3Ack              ),    
   //. mem1_wr                   
   .mem1_rd                      (Mem3RdWrN                 ),    
   .mem1_dataOut                 (uctl_Mem3Din              ),    
   .mem1_dataVld                 (uctl_Mem3DVld             )
   );
   

   assign crc_dataValid  =  epct2pa_dataValid | pd2epcr_dataValid;                      
   assign crc_Data       =  epct2pa_dataValid ?  epct2pa_data : pd2epcr_data;                           
   assign eot            =  epct2pa_eot;                       
   assign dataBE         =  epct2pa_dataValid ? epct2pa_dataBE:pd2epcr_dataBE  ;                    

   uctl_crc16Gen i_crc16_gen     (
    .core_clk                (uctl_CoreClk                  ),  
    .uctl_rst_n              (uctl_CoreRst_n                ),
    .sw_rst                  (1'b0                          ),
    .crc_DataBE              (dataBE                        ),
    .crc_Data                (crc_Data                      ),                       
    .crc_lastData            (eot                           ),
    .crc_dataValid           (crc_dataValid                 ),
    .crc_in                  (pd2crc16_crc                  ),
    .crc_validIn             (pd2crc16_crcValid             ),
    .crc_out                 (crc2pa_crc                    ), 
    .crc_match               (crc_match                     ),
    .crc_valid_out           (crcValid                      )
   );

uctl_frameCounter#(
   .SOF_DNCOUNTER_WD          (SOF_DNCOUNTER_WD          ),
   .SOF_UPCOUNTER_WD          (SOF_UPCOUNTER_WD          )
   )i_frameCounter(
   .clk                       (uctl_PhyClk               ), 
   .phy_rst_n                 (uctl_PhyRst_n             ), 
   .sw_rst                    (1'b0                      ),    
   .pd2frmCntrr_frmNumValid   (pd2frmCntrr_frmNumValid   ),
   .pd2frmCntrr_FrameNum      (pd2frmCntrr_FrameNum      ),
   .frmCntr2pe_frmBndry       (frmCntr2pe_frmBndry       ),
   .reg2frmCntr_upCntMax      (reg2frmCntr_upCntMax      ),
   .reg2frmCntr_timerCorr     (reg2frmCntr_timerCorr     ),
   .frmCntr2reg_frameCount    (frmCntr2reg_frameCount    ),
   .frmCntr2reg_frameCntVl    (frmCntr2reg_frameCntVl    ),
   .frmCntr2reg_sofSent       (frmCntr2reg_sofSent       ),
   .frmCntr2reg_sofRcvd       (frmCntr2reg_sofRcvd       ),
   .reg2frmCntr_eof1          (reg2frmCntr_eof1          ),
   .reg2frmCntr_eof2          (reg2frmCntr_eof2          ),
   .reg2frmCntr_enAutoSof     (reg2frmCntr_enAutoSof     ),
   .reg2frmCntr_autoLd        (reg2frmCntr_autoLd        ),
   .reg2frmCntr_timerStVal    (reg2frmCntr_timerStVal    ),
   .frmCntr2reg_eof1Hit       (frmCntr2reg_eof1Hit       ),
   .reg2frmCntr_ldTimerStVal  (reg2frmCntr_ldTimerStVal  )
   );


endmodule







