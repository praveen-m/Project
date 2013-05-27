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
// AUTHOR	      : Sunil Javaji
// AUTHOR EMAIL	: javaji.sunil@techvulcan.com 
// FILE NAME		: usb_controller
// Version no.    : 0.2
//-------------------------------------------------------------------


/*
   updates in 0.2

   new uctl_aon block has been added
*/



module usb_controller #(
   parameter EXT_AHBM_EN    = 1,
   parameter EXT_AHBS_EN    = 1,
   parameter EXT_AXIM_EN    = 0,
   parameter EXT_AXIS_EN    = 0,
   parameter GLITCH_CNTR_WD = 4
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
   input  wire                        uctl_PoRst_n       , //async reset signal - power-on reset
   // ***************************************************************************************************
   // Interrupt
   // ***************************************************************************************************
   output wire                        uctl_irq            , // level Interrupt
 
   // ***************************************************************************************************
   // UTMI interface
   // ***************************************************************************************************
   output wire                        uctl_UtmiReset      , //Reset for the Transceiver registers - active
                                                            // High signal
   output wire [2               -1:0] uctl_UtmiXcvrSelect , //Selects the LS/FS/HS transceiver
                                                            // 00 : HS transceiver selected
                                                            // 01 : FS transceiver selected
                                                            // 10 : LS transceiver selected
                                                            // 11 : Send or receive a LS packet on FS bus
   output wire                        uctl_UtmiTermSelect , //Termination select :
                                                            // 0 : HS termination enabled
                                                            // 1 : FS termination enabled
   output wire                        uctl_UtmiSuspend_N  , //Active low suspend signal to the Transceiver
   input  wire [2               -1:0] uctl_UtmiLineState  , //These signals reflect the current state of the
                                                            // single ended receiver
                                                            // 00 : SE0
                                                            // 01 : J state
                                                            // 10 : K state
                                                            // 11 : SE1

   output wire [2               -1:0] uctl_UtmiOpMode     , //Select the various operational modes
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
   output wire                        uctl_UtmiDataBus16_8N,//Selects between 8-bit and 16-bit transfer
                                                            // modes.
                                                            // 1 : 16-bit data path operation enabled
                                                            // 0 : 8-bit data path operation enabled
   output wire                        uctl_UtmiIdPullup   , //Enable sampling of the analog Id pin
                                                            // 0 : Sampling is disabled - IdDig is not valid
                                                            // 1 : Sampling of Id pin is enabled
   input  wire                        uctl_UtmiIdDig      , //Indicates whether the connected plug is a Aplug
                                                            // or B-plug.
                                                            // 0 : A-plug is connected and hence the
                                                            // device is an OTG A device
                                                            // 1 : B-plug is connected and hence the
                                                            // device is an OTG B device
   input  wire                        uctl_UtmiAvalid     , //Indicates if the session for an A-device is valid
                                                            // 0 : Vbus < 0.8V
                                                            // 1 : Vbus > 2V
   input  wire                        uctl_UtmiBvalid     , //Indicates if the session for a B-device is valid
                                                            // 0 : Vbus < 0.8V
                                                            // 1 : Vbus > 4V
   input  wire                        uctl_UtmiVbusValid  , //Indicates if the voltage on Vbus is at a valid 
                                                            // level for operation
                                                            // 0 : Vbus < 4.4V
                                                            // 1 : Vbus > 4.75V
   input  wire                        uctl_UtmiSessionEnd , //Indicates if the voltage on Vbus is below its
                                                            // B-device Session End threshold
                                                            // 1 : Vbus < 0.2V
                                                            // 0 : Vbus > 0.8V
   output wire                        uctl_UtmiDrvVbus    , //This enables the Transceiver to drive 5V on Vbus
                                                            // 0 : do not drive Vbus
                                                            // 1 : drive 5V on Vbus


   output wire                        uctl_UtmiDischrgVbus, //This signal enables discharging of Vbus
                                                            // prior to SRP
                                                            // 1 : discharge Vbus through a resistor (need
                                                            // at least 50ms)
                                                            // 0 : do not discharge Vbus
   output wire                        uctl_UtmiChrgVbus   , //This signal enables charging of Vbus prior to
                                                            // SRP
                                                            // 1 : charge Vbus through a resistor (need at
                                                            // least 30ms)
                                                            // 0 : do not charge Vbus
   output wire                        uctl_UtmiDpPulldown , //This signal enables the 15K pulldown
                                                            // resistor on the DP line
                                                            // 0 : Pull-down resistor not connected to DP
                                                            // 1 : Pull-down resistor connected to DP line
   output wire                        uctl_UtmiDmPulldown , //This signal enables the 15K pulldown
                                                            // resistor on the DM line
                                                            // 0 : Pull-down resistor not connected to DM
                                                            // 1 : Pull-down resistor connected to DM line
   input  wire                        uctl_UtmiHostDisconnect, //This indicates whether a peripheral
                                                            // connected to the host has been
                                                            // disconnected.
                                                            // 0 : A peripheral device is connected to the
                                                            // OTG host
                                                            // 1 : No device is connected
   output wire                        uctl_UtmiTxBitstuffEnable,//Indicates if data on TxData bus is to be 
                                                            // bitstuffed or not
                                                            // 0 : Bit-stuffing is disabled
                                                            // 1 : Bit-stuffing is enabled
   output wire                        uctl_UtmiTxBitstuffEnableH,//Indicates if data on TxDataH bus is to be 
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
                                                            // ……
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
                                                            // 0000 : Non-cache’able, non-buffer’able
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
                                                            // 
                                                            // 

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
                                                            // ……
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
                                                            // 0000 : Non-cache’able, non-buffer’able
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
   output wire                        uctl_Axim2BReady      //The ready signal from master in response to
                                                            // the Write Response phase signifying the
                                                            // acceptance of the Write Response.
                                                            // 
                                                            // 

);

   // -------------------------------------------------------------------------
   // Reg/wire declarations for connections to the memory subsystem
   // -------------------------------------------------------------------------
   wire                        uctl_MemUsbWrClk    ;       
   wire                        uctl_MemUsbWrCen    ; 
   wire [32              -1:0] uctl_MemUsbWrAddr   ; 
   wire [32              -1:0] uctl_MemUsbWrDin    ; 
   wire                        uctl_MemUsbWrDVld   ; 
   wire                        uctl_MemUsbWrAck    ;
   
   wire                        uctl_MemDmaWrClk    ; 
   wire                        uctl_MemDmaWrCen    ; 
   wire [32              -1:0] uctl_MemDmaWrAddr   ; 
   wire [32              -1:0] uctl_MemDmaWrDin    ; 
   wire                        uctl_MemDmaWrDVld   ; 
   wire                        uctl_MemDmaWrAck    ;
   
   wire                        uctl_MemUsbRdClk    ; 
   wire                        uctl_MemUsbRdCen    ; 
   wire [32              -1:0] uctl_MemUsbRdAddr   ; 
   wire [32              -1:0] uctl_MemUsbRdDout   ; 
   wire                        uctl_MemUsbRdAck    ; 
   wire                        uctl_MemUsbRdDVld   ; 
   
   wire                        uctl_MemDmaRdClk    ; 
   wire                        uctl_MemDmaRdCen    ; 
   wire [32              -1:0] uctl_MemDmaRdAddr   ; 
   wire [32              -1:0] uctl_MemDmaRdDout   ; 
   wire                        uctl_MemDmaRdAck    ; 
   wire                        uctl_MemDmaRdDVld   ; 
   //aon
   wire                        uctl_aonRst_n       ; 
   wire                        bus_activityIrq     ; 
   wire                        uctl_powerDown         ;
                                                       
   wire  [GLITCH_CNTR_WD -1:0] uctl_glitchFilterCount ;

   wire                        core_irq            ;



   assign uctl_irq   = (core_irq || bus_activityIrq) ? 1'b1 : 1'b0;
      
   uctl_reset_sync phy_rst (
      .clk                 (uctl_PhyClk         ),
      .uctl_PoRst_n        (uctl_PoRst_n        ),
      .rst_out_n           (uctl_PhyRst_n       ) 
   );

   uctl_reset_sync core_rst(
      .clk                 (uctl_CoreClk        ),
      .uctl_PoRst_n        (uctl_PoRst_n        ),
      .rst_out_n           (uctl_CoreRst_n      ) 
   );
            
   uctl_reset_sync sys_rst (
      .clk                 (uctl_SysClk         ),
      .uctl_PoRst_n        (uctl_PoRst_n        ),
      .rst_out_n           (uctl_SysRst_n       ) 
   );
            
   uctl_reset_sync aon_rst (
      .clk                 (uctl_aonClk         ),
      .uctl_PoRst_n        (uctl_PoRst_n        ),
      .rst_out_n           (uctl_aonRst_n       ) 
   );
            

   usb_controller_core #(
      .EXT_AHBM_EN  (EXT_AHBM_EN),
      .EXT_AHBS_EN  (EXT_AHBS_EN),
      .EXT_AXIM_EN  (EXT_AXIM_EN),
      .EXT_AXIS_EN  (EXT_AXIS_EN)
   ) i_usb_controller_core (
      // **********************************************************************
      // Global signals
      // **********************************************************************
      .uctl_PhyClk        (uctl_PhyClk         ), 
      .uctl_CoreClk       (uctl_CoreClk        ), 
      .uctl_SysClk        (uctl_SysClk         ), 
      .uctl_PhyRst_n      (uctl_PhyRst_n       ),    
      .uctl_CoreRst_n     (uctl_CoreRst_n      ),   
      .uctl_SysRst_n      (uctl_SysRst_n       ),   
      // **********************************************************************
      // Interrupt
      // **********************************************************************
      .uctl_irq           (core_irq            ), 
 
      // **********************************************************************
      // UTMI interface
      // **********************************************************************
      .uctl_UtmiReset      (uctl_UtmiReset      ),
      .uctl_UtmiXcvrSelect (uctl_UtmiXcvrSelect ),
      .uctl_UtmiTermSelect (uctl_UtmiTermSelect ),
      .uctl_UtmiSuspend_N  (uctl_UtmiSuspend_N  ),
      .uctl_UtmiLineState  (uctl_UtmiLineState  ),
      .uctl_UtmiOpMode     (uctl_UtmiOpMode     ),
      .uctl_UtmiTxData     (uctl_UtmiTxData     ),
      .uctl_UtmiTxDataH    (uctl_UtmiTxDataH    ),
      .uctl_UtmiTxValid    (uctl_UtmiTxValid    ),
      .uctl_UtmiTxValidH   (uctl_UtmiTxValidH   ),
      .uctl_UtmiTxReady    (uctl_UtmiTxReady    ),
      .uctl_UtmiRxData     (uctl_UtmiRxData     ),
      .uctl_UtmiRxDataH    (uctl_UtmiRxDataH    ),
      .uctl_UtmiRxValid    (uctl_UtmiRxValid    ),
      .uctl_UtmiRxValidH   (uctl_UtmiRxValidH   ),
      .uctl_UtmiRxActive   (uctl_UtmiRxActive   ),
      .uctl_UtmiRxError    (uctl_UtmiRxError    ),
      .uctl_UtmiDataBus16_8N(uctl_UtmiDataBus16_8N),
      .uctl_UtmiIdPullup   (uctl_UtmiIdPullup   ),
      .uctl_UtmiIdDig      (uctl_UtmiIdDig      ),
      .uctl_UtmiAvalid     (uctl_UtmiAvalid     ),
      .uctl_UtmiBvalid     (uctl_UtmiBvalid     ),
      .uctl_UtmiVbusValid  (uctl_UtmiVbusValid  ),
      .uctl_UtmiSessionEnd (uctl_UtmiSessionEnd ),
      .uctl_UtmiDrvVbus    (uctl_UtmiDrvVbus    ),
      .uctl_UtmiDischrgVbus(uctl_UtmiDischrgVbus),
      .uctl_UtmiChrgVbus   (uctl_UtmiChrgVbus   ),
      .uctl_UtmiDpPulldown (uctl_UtmiDpPulldown ),
      .uctl_UtmiDmPulldown (uctl_UtmiDmPulldown ),
      .uctl_UtmiHostDisconnect(uctl_UtmiHostDisconnect),
      .uctl_UtmiTxBitstuffEnable(uctl_UtmiTxBitstuffEnable),
      .uctl_UtmiTxBitstuffEnableH(uctl_UtmiTxBitstuffEnableH),

       // *********************************************************************
       // USB3.0 PIPE Interface
       // *********************************************************************
      .uctl_PipeTxData     (uctl_PipeTxData     ),
      .uctl_PipeTxDataK    (uctl_PipeTxDataK    ),
      .uctl_PipeRxData     (uctl_PipeRxData     ),
      .uctl_PipeRxDataK    (uctl_PipeRxDataK    ),
      .uctl_PipePhyMode    (uctl_PipePhyMode    ),
      .uctl_PipeElBufMode  (uctl_PipeElBufMode  ),
      .uctl_PipeTxDetRxLoop(uctl_PipeTxDetRxLoop),
      .uctl_PipeTxElcIdle  (uctl_PipeTxElcIdle  ),
      .uctl_PipeTxOnesZeros(uctl_PipeTxOnesZeros),
      .uctl_PipeRxPolarity (uctl_PipeRxPolarity ),
      .uctl_PipeRxEqTraining(uctl_PipeRxEqTraining),
      .uctl_PipeReset_N    (uctl_PipeReset_N    ),
      .uctl_PipePowerdown  (uctl_PipePowerdown  ),
      .uctl_PipeRate       (uctl_PipeRate       ),
      .uctl_PipeTxDemph    (uctl_PipeTxDemph    ),
      .uctl_PipeTxMargin   (uctl_PipeTxMargin   ),
      .uctl_PipeTxSwing    (uctl_PipeTxSwing    ),
      .uctl_PipeRxTermination(uctl_PipeRxTermination),
      .uctl_PipeRxValid    (uctl_PipeRxValid    ),
      .uctl_PipePhyStatus  (uctl_PipePhyStatus  ),
      .uctl_PipeRxElecIdle (uctl_PipeRxElecIdle ),
      .uctl_PipeRxStatus   (uctl_PipeRxStatus   ),
      .uctl_PipePowerPresent(uctl_PipePowerPresent),
      // **********************************************************************
      // AHB Slave Interface
      // **********************************************************************
      .uctl_AhbsHReset_N   (uctl_AhbsHReset_N   ),
      .uctl_AhbsHAddr      (uctl_AhbsHAddr      ),
      .uctl_AhbsHTrans     (uctl_AhbsHTrans     ),
      .uctl_AhbsHWrite     (uctl_AhbsHWrite     ),
      .uctl_AhbsHSize      (uctl_AhbsHSize      ),
      .uctl_AhbsHBurst     (uctl_AhbsHBurst     ),
      .uctl_AhbsHProt      (uctl_AhbsHProt      ),
      .uctl_AhbsHWdata     (uctl_AhbsHWdata     ),
      .uctl_AhbsHSel       (uctl_AhbsHSel       ),
      .uctl_AhbsHReadyI    (uctl_AhbsHReadyI    ),
      .uctl_AhbsHRdata     (uctl_AhbsHRdata     ),
      .uctl_AhbsHReady     (uctl_AhbsHReady     ),
      .uctl_AhbsHResp      (uctl_AhbsHResp      ),
      // **********************************************************************
      // AHB Master-1 Interface
      // **********************************************************************
      .uctl_Ahbm1HReset_N  (uctl_Ahbm1HReset_N  ),
      .uctl_Ahbm1HAddr     (uctl_Ahbm1HAddr     ),
      .uctl_Ahbm1HTrans    (uctl_Ahbm1HTrans    ),
      .uctl_Ahbm1HWrite    (uctl_Ahbm1HWrite    ),
      .uctl_Ahbm1HSize     (uctl_Ahbm1HSize     ),
      .uctl_Ahbm1HBurst    (uctl_Ahbm1HBurst    ),
      .uctl_Ahbm1HProt     (uctl_Ahbm1HProt     ),
      .uctl_Ahbm1HWdata    (uctl_Ahbm1HWdata    ),
      .uctl_Ahbm1HRdata    (uctl_Ahbm1HRdata    ),
      .uctl_Ahbm1HReady    (uctl_Ahbm1HReady    ),
      .uctl_Ahbm1HResp     (uctl_Ahbm1HResp     ),
      .uctl_Ahbm1HBusreq   (uctl_Ahbm1HBusreq   ),
      .uctl_Ahbm1HGrant    (uctl_Ahbm1HGrant    ),
      // **********************************************************************
      // AHB Master-2 Interface
      // **********************************************************************
      .uctl_Ahbm2HReset_N  (uctl_Ahbm2HReset_N  ),
      .uctl_Ahbm2HAddr     (uctl_Ahbm2HAddr     ),
      .uctl_Ahbm2HTrans    (uctl_Ahbm2HTrans    ),
      .uctl_Ahbm2HWrite    (uctl_Ahbm2HWrite    ),
      .uctl_Ahbm2HSize     (uctl_Ahbm2HSize     ),
      .uctl_Ahbm2HBurst    (uctl_Ahbm2HBurst    ),
      .uctl_Ahbm2HProt     (uctl_Ahbm2HProt     ),
      .uctl_Ahbm2HWdata    (uctl_Ahbm2HWdata    ),
      .uctl_Ahbm2HRdata    (uctl_Ahbm2HRdata    ),
      .uctl_Ahbm2HReady    (uctl_Ahbm2HReady    ),
      .uctl_Ahbm2HResp     (uctl_Ahbm2HResp     ),
      .uctl_Ahbm2HBusreq   (uctl_Ahbm2HBusreq   ),
      .uctl_Ahbm2HGrant    (uctl_Ahbm2HGrant    ),

      // **********************************************************************
      // AXI Slave Interface
      // **********************************************************************
      .uctl_AxisAReset_N   (uctl_AxisAReset_N   ),
      .uctl_AxisAValid     (uctl_AxisAValid     ),
      .uctl_AxisAddr       (uctl_AxisAddr       ),
      .uctl_AxisAWrite     (uctl_AxisAWrite     ),
      .uctl_AxisALen       (uctl_AxisALen       ),
      .uctl_AxisASize      (uctl_AxisASize      ),
      .uctl_AxisABurst     (uctl_AxisABurst     ),
      .uctl_AxisALock      (uctl_AxisALock      ),
      .uctl_AxisACache     (uctl_AxisACache     ),
      .uctl_AxisAProt      (uctl_AxisAProt      ),
      .uctl_AxisAId        (uctl_AxisAId        ),
      .uctl_AxisAReady     (uctl_AxisAReady     ),
      .uctl_AxisRValid     (uctl_AxisRValid     ),
      .uctl_AxisRLast      (uctl_AxisRLast      ),
      .uctl_AxisRData      (uctl_AxisRData      ),
      .uctl_AxisRResp      (uctl_AxisRResp      ),
      .uctl_AxisRId        (uctl_AxisRId        ),
      .uctl_AxisRReady     (uctl_AxisRReady     ),
      .uctl_AxisWValid     (uctl_AxisWValid     ),
      .uctl_AxisWLast      (uctl_AxisWLast      ),
      .uctl_AxisWData      (uctl_AxisWData      ),
      .uctl_AxisWStrb      (uctl_AxisWStrb      ),
      .uctl_AxisWId        (uctl_AxisWId        ),
      .uctl_AxisWReady     (uctl_AxisWReady     ),
      .uctl_AxisBValid     (uctl_AxisBValid     ),
      .uctl_AxisBResp      (uctl_AxisBResp      ),
      .uctl_AxisBId        (uctl_AxisBId        ),
      .uctl_AxisBReady     (uctl_AxisBReady     ),
      .uctl_AxisCActive    (uctl_AxisCActive    ),
      .uctl_AxisCSysReq    (uctl_AxisCSysReq    ),
      .uctl_AxisCSysAck    (uctl_AxisCSysAck    ),
      // **********************************************************************
      // AXI Master-1 Interface
      // **********************************************************************
      .uctl_Axim1AReset_N  (uctl_Axim1AReset_N  ),
      .uctl_Axim1AValid    (uctl_Axim1AValid    ),
      .uctl_Axim1Addr      (uctl_Axim1Addr      ),
      .uctl_Axim1AWrite    (uctl_Axim1AWrite    ),
      .uctl_Axim1ALen      (uctl_Axim1ALen      ),
      .uctl_Axim1ASize     (uctl_Axim1ASize     ),
      .uctl_Axim1ABurst    (uctl_Axim1ABurst    ),
      .uctl_Axim1ALock     (uctl_Axim1ALock     ),
      .uctl_Axim1ACache    (uctl_Axim1ACache    ),
      .uctl_Axim1AProt     (uctl_Axim1AProt     ),
      .uctl_Axim1AId       (uctl_Axim1AId       ),
      .uctl_Axim1AReady    (uctl_Axim1AReady    ),
      .uctl_Axim1RValid    (uctl_Axim1RValid    ),
      .uctl_Axim1RLast     (uctl_Axim1RLast     ),
      .uctl_Axim1RData     (uctl_Axim1RData     ),
      .uctl_Axim1RResp     (uctl_Axim1RResp     ),
      .uctl_Axim1RId       (uctl_Axim1RId       ),
      .uctl_Axim1RReady    (uctl_Axim1RReady    ),
      .uctl_Axim1WValid    (uctl_Axim1WValid    ),
      .uctl_Axim1WLast     (uctl_Axim1WLast     ),
      .uctl_Axim1WData     (uctl_Axim1WData     ),
      .uctl_Axim1WStrb     (uctl_Axim1WStrb     ),
      .uctl_Axim1WId       (uctl_Axim1WId       ),
      .uctl_Axim1WReady    (uctl_Axim1WReady    ),
      .uctl_Axim1BValid    (uctl_Axim1BValid    ),
      .uctl_Axim1BResp     (uctl_Axim1BResp     ),
      .uctl_Axim1BId       (uctl_Axim1BId       ),
      .uctl_Axim1BReady    (uctl_Axim1BReady    ),
      // **********************************************************************
      // AXI Master-2 Interface
      // **********************************************************************
      .uctl_Axim2AReset_N  (uctl_Axim2AReset_N  ),
      .uctl_Axim2AValid    (uctl_Axim2AValid    ),
      .uctl_Axim2Addr      (uctl_Axim2Addr      ),
      .uctl_Axim2AWrite    (uctl_Axim2AWrite    ),
      .uctl_Axim2ALen      (uctl_Axim2ALen      ),
      .uctl_Axim2ASize     (uctl_Axim2ASize     ),
      .uctl_Axim2ABurst    (uctl_Axim2ABurst    ),
      .uctl_Axim2ALock     (uctl_Axim2ALock     ),
      .uctl_Axim2ACache    (uctl_Axim2ACache    ),
      .uctl_Axim2AProt     (uctl_Axim2AProt     ),
      .uctl_Axim2AId       (uctl_Axim2AId       ),
      .uctl_Axim2AReady    (uctl_Axim2AReady    ),
      .uctl_Axim2RValid    (uctl_Axim2RValid    ),
      .uctl_Axim2RLast     (uctl_Axim2RLast     ),
      .uctl_Axim2RData     (uctl_Axim2RData     ),
      .uctl_Axim2RResp     (uctl_Axim2RResp     ),
      .uctl_Axim2RId       (uctl_Axim2RId       ),
      .uctl_Axim2RReady    (uctl_Axim2RReady    ),
      .uctl_Axim2WValid    (uctl_Axim2WValid    ),
      .uctl_Axim2WLast     (uctl_Axim2WLast     ),
      .uctl_Axim2WData     (uctl_Axim2WData     ),
      .uctl_Axim2WStrb     (uctl_Axim2WStrb     ),
      .uctl_Axim2WId       (uctl_Axim2WId       ),
      .uctl_Axim2WReady    (uctl_Axim2WReady    ),
      .uctl_Axim2BValid    (uctl_Axim2BValid    ),
      .uctl_Axim2BResp     (uctl_Axim2BResp     ),
      .uctl_Axim2BId       (uctl_Axim2BId       ),
      .uctl_Axim2BReady    (uctl_Axim2BReady    ),

   // *************************************************************************
   // Endpoint Buffer Interface -1  (Write Port - USB side)
   // *************************************************************************
      .uctl_Mem0Cen      (uctl_MemUsbWrCen      ),
      .uctl_Mem0Addr     (uctl_MemUsbWrAddr     ),
      .uctl_Mem0Dout     (uctl_MemUsbWrDin      ),
      .uctl_Mem0RdWrN    (/*Mem0RdWrN*/         ),
    //  .uctl_Mem0DVld     (uctl_MemUsbWrDVld     ),
      .uctl_Mem0Ack      (uctl_MemUsbWrAck      ),

   // *************************************************************************
   // Endpoint Buffer Interface -2  (Write Port - DMA side)
   // *************************************************************************
      .uctl_Mem1Cen      (uctl_MemDmaWrCen      ),
      .uctl_Mem1Addr     (uctl_MemDmaWrAddr     ),
      .uctl_Mem1Dout     (uctl_MemDmaWrDin      ),
      //.uctl_Mem1DVld     (uctl_MemDmaWrDVld     ),
      .uctl_Mem1RdWrN    (/*Mem1RdWrN*/             ),
      .uctl_Mem1Ack      (uctl_MemDmaWrAck      ),


   // *************************************************************************
   // Endpoint Buffer Interface - 3 (Read Port - USB side)
   // *************************************************************************
      .uctl_Mem2Cen      (uctl_MemUsbRdCen      ),
      .uctl_Mem2Addr     (uctl_MemUsbRdAddr     ),
      .uctl_Mem2Din      (uctl_MemUsbRdDout     ),
      .uctl_Mem2RdWrN    (                      ),
      .uctl_Mem2Ack      (uctl_MemUsbRdAck      ),
      .uctl_Mem2DVld     (uctl_MemUsbRdDVld     ),

   // *************************************************************************
   // Endpoint Buffer Interface - 4 (Read Port - DMA side)
   // **************************************************************************
      .uctl_Mem3Cen      (uctl_MemDmaRdCen      ),
      .uctl_Mem3Addr     (uctl_MemDmaRdAddr     ),
      .uctl_Mem3Din      (uctl_MemDmaRdDout     ),
      .uctl_Mem3RdWrN    (                      ),
      .uctl_Mem3Ack      (uctl_MemDmaRdAck      ),
      .uctl_Mem3DVld     (uctl_MemDmaRdDVld     )
   );

   usb_controller_memory

   i_usb_controller_memory (

       .uctl_coreClk         (uctl_CoreClk         ),
       .uctl_core_rst_n      (uctl_CoreRst_n       ),   
   // *************************************************************************
   // Endpoint Buffer Interface -1  (Write Port - USB side)
   // *************************************************************************
      .uctl_MemUsbWrCen      (uctl_MemUsbWrCen     ),
      .uctl_MemUsbWrAddr     (uctl_MemUsbWrAddr    ),
      .uctl_MemUsbWrDin      (uctl_MemUsbWrDin     ),
    //  .uctl_MemUsbWrDVld     (uctl_MemUsbWrDVld    ),
      .uctl_MemUsbWrAck      (uctl_MemUsbWrAck     ),

   // *************************************************************************
   // Endpoint Buffer Interface -2  (Write Port - DMA side)
   // *************************************************************************
      .uctl_MemDmaWrCen      (uctl_MemDmaWrCen     ),
      .uctl_MemDmaWrAddr     (uctl_MemDmaWrAddr    ),
      .uctl_MemDmaWrDin      (uctl_MemDmaWrDin     ),
     // .uctl_MemDmaWrDVld     (uctl_MemDmaWrDVld    ),
      .uctl_MemDmaWrAck      (uctl_MemDmaWrAck     ),


   // *************************************************************************
   // Endpoint Buffer Interface - 3 (Read Port - USB side)
   // *************************************************************************
      .uctl_MemUsbRdCen      (uctl_MemUsbRdCen     ),
      .uctl_MemUsbRdAddr     (uctl_MemUsbRdAddr    ),
      .uctl_MemUsbRdDout     (uctl_MemUsbRdDout    ),
      .uctl_MemUsbRdAck      (uctl_MemUsbRdAck     ),
      .uctl_MemUsbRdDVld     (uctl_MemUsbRdDVld    ),

   // *************************************************************************
   // Endpoint Buffer Interface - 4 (Read Port - DMA side)
   // **************************************************************************
      .uctl_MemDmaRdCen      (uctl_MemDmaRdCen     ),
      .uctl_MemDmaRdAddr     (uctl_MemDmaRdAddr    ),
      .uctl_MemDmaRdDout      (uctl_MemDmaRdDout   ),
      .uctl_MemDmaRdAck      (uctl_MemDmaRdAck     ),
      .uctl_MemDmaRdDVld     (uctl_MemDmaRdDVld    )

   );


   uctl_aon #(
      .GLITCH_CNTR_WD(GLITCH_CNTR_WD)
      )i_aon(
      .aon_clk          (uctl_aonClk               ),  
      .aon_rst_n        (uctl_aonRst_n             ),  
      .sw_rst           ( 1'b0                     ),  
      .ss_count         (uctl_glitchFilterCount    ),  
      .line_state       (uctl_UtmiLineState        ),  
      .power_down       (uctl_powerDown            ),  
      .bus_activityIrq  (bus_activityIrq           )            
   );

endmodule
