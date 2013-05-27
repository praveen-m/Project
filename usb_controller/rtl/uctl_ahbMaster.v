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
// DATE		   	: Mon, 04 Mar 2013 15:19:31
// AUTHOR		   : Anuj Pandey
// AUTHOR EMAIL	: anuj.pandey@techvulcan.com
// FILE NAME		: ahbMaster.v
// VERSION No.    : 0.5
//-------------------------------------------------------------------

// TODO fixes in 0.5
// 1. instead of using ahbm2dmaRx_ready signal, now we are using numOfFreeLocs signal 
//    coming from sync fifo and connected to ahbm2dmaRx_availSpace signal. 
// 2. file name of uctl_fifo_syn is changed to uctl_fifo_syn_asyn now.


// TODO fixes in 0.4
// have made is compatible with async path also

// TODO fixes in 0.3
// rdWrd signal is now we are giving based on trnsEn signal conditions.

// TODO fixes in 0.2
// syncFifo is giving nearlyFull signal to DmaRx now. Earlier it was giving full signal.


module uctl_ahbMaster#(

      parameter FIFO_DATA_SIZE = 32 ,
                DATA_SIZE      = 32 ,
                ADDR_SIZE      = 32 ,
                CNTR_WORD      = 20 ,   
                ADD_WIDTH      = 4  ,
                DMA_WR_FIFO_ADR= 4  ,
                DMA_RD_FIFO_ADR= 4  ,
                `include "../rtl/uctl_top.vh"
      ) (
   //system clock and syn reset
      input  wire                         uctl_sysClk           ,
      input  wire                         sw_rst                ,
      input  wire                         coreRst_n             ,//TODO added
      input  wire                         core_clk              ,

   //global async reset
      input  wire                         uctl_sysRst_n         ,   
   
   //dmatx interface signals
      //control logic 
      input  wire [ADDR_SIZE        -1:0] dmaTx2ahbm_sRdAddr    ,
      input  wire [CNTR_WORD        -1:0] dmaTx2ahbm_len        ,
      input  wire                         dmaTx2ahbm_stransEn   ,
      input  wire                         dmaTx2ahbm_sRdWr      ,// rd or write operation
      output wire                         ahbm2dmaTx_dataDn     ,

      //fifo interface
      input  wire                          dmaTx2ahbm_rd        ,
      output wire                          ahbm2dmaTx_ready     ,
      output wire  [DATA_SIZE        -1:0] ahbm2dmaTx_wrData    , //TODO similar to dma tx     
 
   //dmaRx inreface signals
      //control logic
      
      input  wire [ADDR_SIZE        -1:0] dmaRx2ahbm_sWrAddr    ,// System memory address
      input  wire                         dmaRx2ahbm_sRdWr      ,
      input  wire [CNTR_WORD        -1:0] dmaRx2ahbm_len        ,// Length of transfer in Bytes
      input  wire                         dmaRx2ahbm_stransEn   ,
      //input  wire  [3                 :0] dmaRx2ahbm_BE       , //TODO
      output wire                         ahbm2dmaRx_dn         ,

      //fifo signals
      input  wire [DATA_SIZE        -1:0] dmaRx2ahbm_data       ,
      input  wire                         dmaRx2ahbm_wr         ,
      output wire [4                  :0] ahbm2dmaRx_availSpace ,            

   //ahb inreface
      input  wire [DATA_SIZE        -1:0] hrdata                , 
      input  wire                         hgrant                ,
      input  wire                         hready                ,
      input  wire [1                  :0] hresp                 ,

      output wire                         hbusreq               ,
      output wire                         hwrite                ,  
      output wire [1                  :0] htrans                ,
      output wire [ADDR_SIZE        -1:0] haddr                 ,
      output wire [DATA_SIZE        -1:0] hwdata                ,
      output wire [2                  :0] hsize                 ,   
      output wire [2                  :0] hburst             
            
   );


   wire                        ctrl2ahbc_trEn_1       ; 
   wire                        ctrl2ahbc_trEn_2       ;
   wire                        ctrl2ahbc_trEn         ;
   wire [4                 :0] ctrl2ahbc_beats_1      ;    
   wire [4                 :0] ctrl2ahbc_beats_2      ;
   wire [4                 :0] ctrl2ahbc_beats        ;
   wire [2                 :0] ctrl2ahbc_hSize_1      ; 
   wire [2                 :0] ctrl2ahbc_hSize_2      ;
   wire [2                 :0] ctrl2ahbc_hSize        ;
   wire                        ctrl2ahbc_sRdWr_1      ;
   wire                        ctrl2ahbc_sRdWr_2      ;
   wire                        wrfifo2ahbc_full       ;
   wire                        wrfifo2ahbc_nfull      ;
   wire                        rdfifo2ahbc_empty      ;
   wire [DATA_SIZE       -1:0] rdfifo2ahbc_rdData     ; 
   wire [ADDR_SIZE       -1:0] ctrl2ahbc_sRdAddr      ; 
   wire [ADDR_SIZE       -1:0] ctrl2ahbc_sWrAddr      ; 
   wire [DATA_SIZE         :0] ahbc2wrfifo_wrData     ;      
   wire [DATA_SIZE         :0] tx_wrData              ;      
   wire [4                 :0] words_inFifoTx         ;             
   wire [4                 :0] words_inFifoRx         ;             
   wire [1                 :0] hsize1                 ;
   wire                        tx_dataDn              ;
   wire                        wrfifo_empty           ;
   wire                        rdfifo_full            ;
   wire [31                :0] ahbc2ctrl_sWrAddr      ;
   

   wire [52                :0] dataInRx               ;
   wire [52                :0] dataOutRx              ;
   wire [31                :0] dmaRx2ahbm_sWrAddr_ps  ;
   wire                        dmaRx2ahbm_sRdWr_ps    ;
   wire [19                :0] dmaRx2ahbm_len_ps      ;

   wire [52                :0] dataInTx               ;
   wire [52                :0] dataOutTx              ;
   wire [31                :0] dmaTx2ahbm_sRdAddr_ps  ;
   wire                        dmaTx2ahbm_sRdWr_ps    ;
   wire [19                :0] dmaTx2ahbm_len_ps      ;

   assign ctrl2ahbc_trEn   = ctrl2ahbc_trEn_1 | ctrl2ahbc_trEn_2;                              
   assign ctrl2ahbc_beats  = ctrl2ahbc_trEn_1 ? ctrl2ahbc_beats_1 : ctrl2ahbc_beats_2;         
   assign ctrl2ahbc_hSize  = ctrl2ahbc_trEn_1 ? ctrl2ahbc_hSize_1 : ctrl2ahbc_hSize_2;   
   assign ctrl2ahbc_sRdWr  = ctrl2ahbc_trEn_1 ? ctrl2ahbc_sRdWr_1 : ctrl2ahbc_sRdWr_2;       
   //assign hsize            = {1'b0,hsize1};

   //------------------------------------------------------
   //ctrl_ahbTx signals
   //------------------------------------------------------
   uctl_ctrlAhbTx i_ctrl_ahbTx(
      //dmaTx interface signals
      .dmaTx2ctrl_sRdAddr     (dmaTx2ahbm_sRdAddr_ps     ),
      .dmaTx2ctrl_len         (dmaTx2ahbm_len_ps         ),                         
      .dmaTx2ctrl_stransEn    (pulseOutTx_stransEn       ),
      .dmaTx2ctrl_sRdWr       (dmaTx2ahbm_sRdWr_ps       ),
      .ctrl2dmaTx_dataDn      (ctrl2dmaTx_dn_ps          ),
   
      //ahb core interface
      .ahbc2ctrl_ack          (ahbc2ctrl_ack             ),
      .ahbc2ctrl_addrDn       (ahbc2ctrl_addrDn          ),
      .ahbc2ctrl_dataDn       (tx_dataDn                 ),
      .ahbc2ctrl_sWrAddr      (ahbc2ctrl_sWrAddr         ),
      .ctrl2ahbc_trEn         (ctrl2ahbc_trEn_1          ),
      .ctrl2ahbc_beats        (ctrl2ahbc_beats_1         ),
      .ctrl2ahbc_hSize        (ctrl2ahbc_hSize_1         ), 
      .ctrl2ahbc_sRdAddr      (ctrl2ahbc_sRdAddr         ), 
      .ctrl2ahbc_sRdWr        (ctrl2ahbc_sRdWr_1         ), 

      //fifo interface 
      .words_inFifo           (words_inFifoTx            ),

      //system clk and sync rst
      .uctl_sysClk            (uctl_sysClk               ),
      .uctl_sysRst_n          (uctl_sysRst_n             )
      
      //global async rst
   );

   //TODO: both tr ens can come at the same time                                               
   //------------------------------------------------------                                    
   //ctrl_ahbRx signal                                                                         
   //------------------------------------------------------                                    
   uctl_ctrlAhbRx i_ctrl_ahbRx(                                                                    
      //dmaRx interface                                                                        
      .dmaRx2ctrl_sWrAddr     (dmaRx2ahbm_sWrAddr_ps     ),
      .dmaRx2ctrl_sRdWr       (dmaRx2ahbm_sRdWr_ps       ),
      .dmaRx2ctrl_len         (dmaRx2ahbm_len_ps         ),
      .dmaRx2ctrl_stransEn    (pulseOutRx_stransEn       ),
      .ctrl2dmaRx_dn          (ctrl2dmaRx_dn_ps          ),

      //ahb core interface
      .ahbc2ctrl_ack          (ahbc2ctrl_ack             ),
      .ahbc2ctrl_addrDn       (ahbc2ctrl_addrDn          ),
      .ahbc2ctrl_dataDn       (ahbc2ctrl_dataDn          ),
      .ahbc2ctrl_sWrAddr      (ahbc2ctrl_sWrAddr         ),
      .ctrl2ahbc_trEn         (ctrl2ahbc_trEn_2          ),
      .ctrl2ahbc_beats        (ctrl2ahbc_beats_2         ),
      .ctrl2ahbc_hSize        (ctrl2ahbc_hSize_2         ),
      .ctrl2ahbc_sWrAddr      (ctrl2ahbc_sWrAddr         ),
      .ctrl2ahbc_sRdWr        (ctrl2ahbc_sRdWr_2         ),
      

      //fifo interface 
      .words_inFifo           (words_inFifoRx            ),

      //system clk and sync rst
      .uctl_sysClk            (uctl_sysClk               ),
      .uctl_sysRst_n          (uctl_sysRst_n             )          
      
      //global async rst
      
   );





   //------------------------------------------------------
   //AHB CORE SIGNALS
   //------------------------------------------------------
   uctl_ahbCore i_ahbCore(
      //global async rst
      .uctl_sysRst_n          (uctl_sysRst_n            ),

      //system clk and soft rst
      .sw_rst                 (sw_rst                   ),
      .uctl_sysClk            (uctl_sysClk              ),

      //ctrl interface
      .ctrl2ahbc_trEn         (ctrl2ahbc_trEn           ),    
      .ctrl2ahbc_beats        (ctrl2ahbc_beats          ),  //TODO change today  
      .ctrl2ahbc_hSize        (ctrl2ahbc_hSize          ),  
      .ctrl2ahbc_sRdAddr      (ctrl2ahbc_sRdAddr        ),
      .ctrl2ahbc_sWrAddr      (ctrl2ahbc_sWrAddr        ),
      .ctrl2ahbc_sRdWr        (ctrl2ahbc_sRdWr          ),
      .ahbc2ctrl_ack          (ahbc2ctrl_ack            ),
      .ahbc2ctrl_addrDn       (ahbc2ctrl_addrDn         ),
      .ahbc2ctrl_dataDn       (ahbc2ctrl_dataDn         ),
      .ahbc2ctrl_sWrAddr      (ahbc2ctrl_sWrAddr        ),

      //ahb slave interface signals
      .hbusreq               (hbusreq                   ), 
      .hwrite                (hwrite                    ), 
      .htrans                (htrans                    ), 
      .haddr                 (haddr                     ), 
      .hwdata                (hwdata                    ),
      .hsize                 (hsize                    ), 
      .hburst                (hburst                    ),
      .hrdata                (hrdata                    ),
      .hgrant                (hgrant                    ),
      .hready                (hready                    ),
      .hresp                 (hresp                     ),

      //fifo interface signals
      .rdfifo2ahbc_rdData      (rdfifo2ahbc_rdData      ),
      .rdfifo2ahbc_empty       (rdfifo2ahbc_empty       ),
      .wrfifo2ahbc_full        (wrfifo2ahbc_full        ),
      .ahbc2rdfifo_rdReq       (ahbc2rdfifo_rdReq       ),
      .ahbc2wrfifo_wrReq       (ahbc2wrfifo_wrReq       ),
      .ahbc2wrfifo_wrData      (ahbc2wrfifo_wrData      ),
      .wrfifo2ahbc_nfull       (wrfifo2ahbc_nfull       )
       
   );


   uctl_fifo_syn_asyn # (
      .FIFO_DATASIZE         (32                        ),
      .NEAR_FULL_TH          (1                         ),
      .BYPASS                (SYS_CORE_SYNC             ),
      .FIFO_ADDRSIZE         (DMA_RD_FIFO_ADR           )
   ) i_syncFifoRx( 
      //ahb interface signals
      .rClk                  (uctl_sysClk               ),
      .rrst_n                (uctl_sysRst_n             ),
		.sw_rst  	           (sw_rst                    ),
      .wClk                  (core_clk                  ),
      .wrst_n                (coreRst_n                 ),
      .dataIn                (dmaRx2ahbm_data           ),
      .wrEn                  (dmaRx2ahbm_wr             ),
      .rdEn                  (ahbc2rdfifo_rdReq         ),
      .nearly_full           (rdfifo_full               ),
      .empty                 (rdfifo2ahbc_empty         ),//ahbCore interface signal
      .numOfData             (words_inFifoRx            ),//ctrlAhbRx interface signal
      .numOfFreeLocs         (ahbm2dmaRx_availSpace     ),
      .dataOut               (rdfifo2ahbc_rdData        ) 
   );

   uctl_fifo_syn_asyn # (
      .FIFO_DATASIZE         (33                        ),
      .BYPASS                (SYS_CORE_SYNC             ),
      .FIFO_ADDRSIZE         (DMA_WR_FIFO_ADR           )
   ) i_syncFifoTx(
      //ahb interface signals
      .wClk                  (uctl_sysClk               ),
      .wrst_n                (uctl_sysRst_n             ),
	   .sw_rst					  (sw_rst                    ),
      .rClk                  (core_clk                  ),
      .rrst_n                (coreRst_n                 ),                          
      .dataIn                (ahbc2wrfifo_wrData        ),
      .wrEn                  (ahbc2wrfifo_wrReq         ),
      .rdEn                  (dmaTx2ahbm_rd             ),
      .full                  (wrfifo2ahbc_full          ),
      .empty                 (wrfifo_empty              ),
      .numOfFreeLocs         (/*UC*/                    ),
      .numOfData             (words_inFifoTx            ),
      .dataOut               (tx_wrData                 ),
      .nearly_full           (wrfifo2ahbc_nfull         ) 
   );
   assign ahbm2dmaTx_wrData   = tx_wrData[31:0];
   assign tx_dataDn           = (tx_wrData[32] & ~wrfifo_empty) & dmaTx2ahbm_rd;
   assign ahbm2dmaTx_ready    = ~wrfifo_empty;
   assign ahbm2dmaRx_ready    = ~rdfifo_full;

   assign dataInRx            = {dmaRx2ahbm_sWrAddr,dmaRx2ahbm_sRdWr,dmaRx2ahbm_len};
   assign {dmaRx2ahbm_sWrAddr_ps,dmaRx2ahbm_sRdWr_ps,dmaRx2ahbm_len_ps}  =  dataOutRx;

   assign dataInTx            = {dmaTx2ahbm_sRdAddr,dmaTx2ahbm_sRdWr,dmaTx2ahbm_len};
   assign {dmaTx2ahbm_sRdAddr_ps,dmaTx2ahbm_sRdWr_ps,dmaTx2ahbm_len_ps}  =  dataOutTx;


   uctl_pulsestretch  #(
         .BYPASS            (SYS_CORE_SYNC      ),
         .DATA_WD           (53                 )
      )psRx1(
      .clock1               (core_clk           ),    
      .clock1Rst_n          (uctl_rst_n         ),
      .clock2               (uctl_sysClk        ),
      .clock2Rst_n          (uctl_sysRst_n      ),
      .pulseIn              (dmaRx2ahbm_stransEn),
      .pulseOut             (pulseOutRx_stransEn),
      .dataIn               (dataInRx           ),
      .dataOut              (dataOutRx          )
   );
   
   uctl_pulsestretch  #(
         .BYPASS            (SYS_CORE_SYNC      )
      ) psRx2(
      .clock1               (uctl_sysClk        ),
      .clock1Rst_n          (uctl_sysRst_n      ),
      .clock2               (core_clk           ),    
      .clock2Rst_n          (uctl_rst_n         ),
      .pulseIn              (ctrl2dmaRx_dn_ps   ),
      .pulseOut             (ahbm2dmaRx_dn      ),
      .dataIn               ( 'h0               ),
      .dataOut              (/*NC*/             )
   );
   
   
   uctl_pulsestretch  #(
         .BYPASS            (SYS_CORE_SYNC      ),
         .DATA_WD           (53                 )
      )psTx1(
      .clock1               (core_clk           ),    
      .clock1Rst_n          (uctl_rst_n         ),
      .clock2               (uctl_sysClk        ),
      .clock2Rst_n          (uctl_sysRst_n      ),
      .pulseIn              (dmaTx2ahbm_stransEn),
      .pulseOut             (pulseOutTx_stransEn),
      .dataIn               (dataInTx           ),
      .dataOut              (dataOutTx          )
   );
   
   uctl_pulsestretch  #(
         .BYPASS            (SYS_CORE_SYNC      )
      )psTx2(
      .clock1               (uctl_sysClk        ),
      .clock1Rst_n          (uctl_sysRst_n      ),
      .clock2               (core_clk           ),    
      .clock2Rst_n          (uctl_rst_n         ),
      .pulseIn              (ctrl2dmaTx_dn_ps   ),
      .pulseOut             (ahbm2dmaTx_dataDn  ),
      .dataIn               ( 'h0               ),
      .dataOut              (/*NC*/             )
   );

/*

   always @(posedge  uctl_sysClk or negedge uctl_sysRst_n) begin
      if(!uctl_sysRst_n)begin
         epRd_en  <= 1'b0;
         epWr_en  <= 1'b0;
      end
      else if(dmaTx2ahbm_stransEn) begin 
         epRd_en  <= 1'b0;
         epWr_en  <= 1'b1;
      end
      else if(dmaRx2ahbm_stransEn) begin 
         epRd_en  <= 1'b1;
         epWr_en  <= 1'b0;
      end
      else begin 
         epRd_en  <= epRd_en;
         epWr_en  <= epWr_en;
      end
   end

   always @(*) begin
      if(epWr_en ) begin //dmaTx
         wrEn              = ahbc2wrfifo_wrReq;         
         rdEn 	            = dmaTx2ahbm_rd         ; 
         dataIn            = ahbc2wrfifo_wrData; 
         wrfifo2ahbc_full  = full;
         ahbm2dmaTx_ready  = empty;  
         ahbm2dmaTx_wrData = dataOut;
         ahbm2dmaRx_ready   =  1'b0;                      
         rdfifo2ahbc_empty  =  1'b0;  
         rdfifo2ahbc_rdData =	 {FIFO_DATA_SIZE{1'b0}};  
      end                  
      else if(epRd_en ) begin //dmaRx        
         wrEn               = dmaRx2ahbm_wr        ;  	                 
         rdEn 	             = ahbc2rdfifo_rdReq;                 
         //dataIn             = dmaRx2ahbm_data;
         ahbm2dmaRx_ready   =  full;                      
         rdfifo2ahbc_empty  =  empty;  
         rdfifo2ahbc_rdData =	 dataOut;
         wrfifo2ahbc_full  = 1'b0;
         ahbm2dmaTx_ready  =  1'b0;  
         ahbm2dmaTx_wrData = {FIFO_DATA_SIZE{1'b0}};
      end
      else begin 
         ahbm2dmaTx_ready  =  1'b0;  
         wrEn               = 1'b0;
         rdEn 	             = 1'b0;   
         dataIn             = {FIFO_DATA_SIZE{1'b0}};   
         ahbm2dmaRx_ready   = 1'b0;   
         rdfifo2ahbc_empty  = 1'b0;   
         rdfifo2ahbc_rdData = {FIFO_DATA_SIZE{1'b0}}; 
         wrfifo2ahbc_full  = 1'b0;
         ahbm2dmaTx_wrData = {FIFO_DATA_SIZE{1'b0}};
      end
   end
*/
endmodule 
