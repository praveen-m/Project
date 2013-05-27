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
// DATE		   	: Fri, 08 Mar 2013 11:31:50
// AUTHOR	      : Lalit Kumar
// AUTHOR EMAIL	: lalit.kumar@techvulcan.com
// FILE NAME		: usb_controller_memory.v
// VERSION        : 0.1
//-------------------------------------------------------------------

module usb_controller_memory #(
   parameter MEM_ADDR_SIZE    = 20,
             MEM_DATA_SIZE    = 32
)(
   // *************************************************************************
   // Global signals
   // *************************************************************************
      input wire                          uctl_coreClk             ,
      input wire                          uctl_core_rst_n          ,
      
   // *************************************************************************
   // Endpoint Buffer Interface -1  (Write Port - USB side)
   // *************************************************************************
      input  wire                         uctl_MemUsbWrCen    ,
      input  wire  [MEM_ADDR_SIZE   -1:0] uctl_MemUsbWrAddr   ,
      input  wire  [MEM_DATA_SIZE   -1:0] uctl_MemUsbWrDin    ,
      output wire                         uctl_MemUsbWrAck    ,

   // *************************************************************************
   // Endpoint Buffer Interface -2  (Write Port - DMA side)
   // *************************************************************************
      input  wire                         uctl_MemDmaWrCen    ,
      input  wire  [MEM_ADDR_SIZE   -1:0] uctl_MemDmaWrAddr   ,
      input  wire  [MEM_DATA_SIZE   -1:0] uctl_MemDmaWrDin    ,
      output wire                         uctl_MemDmaWrAck    ,


   // *************************************************************************
   // Endpoint Buffer Interface - 3 (Read Port - USB side)                     
   // *************************************************************************
      input  wire                         uctl_MemUsbRdCen    ,                
      input  wire  [MEM_ADDR_SIZE   -1:0] uctl_MemUsbRdAddr   ,                
      output wire                         uctl_MemUsbRdAck    ,                
      output wire  [MEM_DATA_SIZE   -1:0] uctl_MemUsbRdDout   ,
      output wire                         uctl_MemUsbRdDVld   ,

   // *************************************************************************
   // Endpoint Buffer Interface - 4 (Read Port - DMA side)
   // **************************************************************************
      input  wire                         uctl_MemDmaRdCen    ,
      input  wire  [MEM_ADDR_SIZE   -1:0] uctl_MemDmaRdAddr   ,
      output wire                         uctl_MemDmaRdAck    ,
      output wire  [MEM_DATA_SIZE   -1:0] uctl_MemDmaRdDout   ,
      output wire                         uctl_MemDmaRdDVld   
  
  
);
   wire [4        -1:0]  b0_uctl_bankReq                       ;   
   wire [4        -1:0]  b1_uctl_bankReq                       ;   
   wire [4        -1:0]  b2_uctl_bankReq                       ;   
   wire [4        -1:0]  b3_uctl_bankReq                       ;   
   wire [4        -1:0]  c0_ack                                ;   
   wire [4        -1:0]  c1_ack                                ;   
   wire [4        -1:0]  c2_ack                                ;   
   wire [4        -1:0]  c3_ack                                ;   
   wire [4        -1:0]  c0_bankDVl                            ;
   wire [4        -1:0]  c1_bankDVl                            ;
   wire [4        -1:0]  c2_bankDVl                            ;
   wire [4        -1:0]  c3_bankDVl                            ; 
   //wire [4        -1:0]  uctl_bankReq                          ;  

   wire                    b0_mem_ce                           ; 
   wire                    b0_rw_en                            ; 
   wire [MEM_ADDR_SIZE - 4 -1:0] b0_mem_addr                        ; 
   wire [MEM_DATA_SIZE-1:0] b0_mem_dataIn                      ; 
   wire [MEM_DATA_SIZE-1:0] b0_mem_dataOut                     ; 
   wire                    b1_mem_ce                           ; 
   wire                    b1_rw_en                            ; 
   wire [MEM_ADDR_SIZE -4 -1:0] b1_mem_addr                        ; 
   wire [MEM_DATA_SIZE-1:0] b1_mem_dataIn                      ; 
   wire [MEM_DATA_SIZE-1:0] b1_mem_dataOut                     ; 
   wire                    b2_mem_ce                           ; 
   wire                    b2_rw_en                            ; 
   wire [MEM_ADDR_SIZE-4 -1:0] b2_mem_addr                        ; 
   wire [MEM_DATA_SIZE-1:0] b2_mem_dataIn                      ; 
   wire [MEM_DATA_SIZE-1:0] b2_mem_dataOut                     ; 
   wire                    b3_mem_ce                           ; 
   wire                    b3_rw_en                            ; 
   wire [MEM_ADDR_SIZE-4 -1:0] b3_mem_addr                        ; 
   wire [MEM_DATA_SIZE-1:0] b3_mem_dataIn                      ; 
   wire [MEM_DATA_SIZE-1:0] b3_mem_dataOut                     ; 
   wire [MEM_DATA_SIZE-1:0] b0_MemUsbRdDout                    ; 
   wire [MEM_DATA_SIZE-1:0] b2_MemUsbRdDout                    ; 
   wire [MEM_DATA_SIZE-1:0] b1_MemUsbRdDout                    ;                                
   wire [MEM_DATA_SIZE-1:0] b3_MemUsbRdDout                    ;
   wire [MEM_DATA_SIZE-1:0] b0_MemDmaRdDout                    ;
   wire [MEM_DATA_SIZE-1:0] b2_MemDmaRdDout                    ;
   wire [MEM_DATA_SIZE-1:0] b1_MemDmaRdDout                    ;
   wire [MEM_DATA_SIZE-1:0] b3_MemDmaRdDout                    ;
   wire [4          -1:0]  c0_bankReq                          ;
   wire [4          -1:0]  c1_bankReq                          ;
   wire [4          -1:0]  c2_bankReq                          ;
   wire [4          -1:0]  c3_bankReq                          ;
   wire [4          -1:0]  b0_rdDvl                            ;
   wire [4          -1:0]  b1_rdDvl                            ;
   wire [4          -1:0]  b2_rdDvl                            ;
   wire [4          -1:0]  b3_rdDvl                            ;
   wire [4          -1:0]  b0_uctl_chipSel                     ;
   wire [4          -1:0]  b1_uctl_chipSel                     ;
   wire [4          -1:0]  b2_uctl_chipSel                     ;
   wire [4          -1:0]  b3_uctl_chipSel                     ;
                           

    assign uctl_MemUsbRdDout  = b0_MemUsbRdDout| b1_MemUsbRdDout |                                                           
                                b2_MemUsbRdDout| b3_MemUsbRdDout          ;                                                         

    assign uctl_MemDmaRdDout  = b0_MemDmaRdDout| b1_MemDmaRdDout |                                                         
                                b2_MemDmaRdDout| b3_MemDmaRdDout          ;                                                         

   assign  c0_ack             ={ b0_uctl_chipSel[0] , b1_uctl_chipSel[0]  ,
                                 b2_uctl_chipSel[0] , b3_uctl_chipSel[0] };          

   assign  c1_ack             ={ b0_uctl_chipSel[1] , b1_uctl_chipSel[1]  ,
                                 b2_uctl_chipSel[1] , b3_uctl_chipSel[1] }; 

   assign  c2_ack             ={ b0_uctl_chipSel[2] , b1_uctl_chipSel[2]  ,
                                 b2_uctl_chipSel[2] , b3_uctl_chipSel[2] }; 

   assign  c3_ack             ={ b0_uctl_chipSel[3] , b1_uctl_chipSel[3]  ,
                                 b2_uctl_chipSel[3] , b3_uctl_chipSel[3] }; 
            
   assign c0_bankDVl          ={ b0_rdDvl[0] , b1_rdDvl[0]                ,
                                 b2_rdDvl[0] , b3_rdDvl[0]}               ;                               

   assign c1_bankDVl          ={ b0_rdDvl[1] , b1_rdDvl[1]                ,               
                                 b2_rdDvl[1] , b3_rdDvl[1]}               ; 

   assign c2_bankDVl          ={ b0_rdDvl[2] , b1_rdDvl[2]                ,               
                                 b2_rdDvl[2] , b3_rdDvl[2]}               ; 

   assign c3_bankDVl          ={ b0_rdDvl[3] , b1_rdDvl[3]                ,               
                                 b2_rdDvl[3] , b3_rdDvl[3]}               ;


   assign b0_uctl_bankReq     ={ c3_bankReq[0] , c2_bankReq[0]            ,
                                 c1_bankReq[0] , c0_bankReq[0]}           ;                               

   assign b1_uctl_bankReq     ={ c3_bankReq[1] , c2_bankReq[1]            ,               
                                 c1_bankReq[1] , c0_bankReq[1]}           ; 

   assign b2_uctl_bankReq     ={ c3_bankReq[2] , c2_bankReq[2]            ,               
                                 c1_bankReq[2] , c0_bankReq[2]}           ; 

   assign b3_uctl_bankReq     ={ c3_bankReq[3] , c2_bankReq[3]            ,               
                                 c1_bankReq[3] , c0_bankReq[3]}           ;




  //epct bank (read from ep buffer)
   uctl_bankSel c0_bankSel (
      .uctl_offsetAddr     (uctl_MemUsbRdAddr[3:2]    )  , 
      .uctl_req            (uctl_MemUsbRdCen          )  , 
      .uctl_bankAck        (c0_ack                    )  , 
      .uctl_bankDVl        (c0_bankDVl                )  , 
      .uctl_bankReq        (c0_bankReq                )  , 
      .uctl_rdAck          (uctl_MemUsbRdAck          )  , 
      .uctl_dValid         (uctl_MemUsbRdDVld         )   
   );                        

   //epcr bank (write to ep buffer)
   uctl_bankSel c1_bankSel (
      .uctl_offsetAddr     (uctl_MemUsbWrAddr[3:2]    )  , 
      .uctl_req            (uctl_MemUsbWrCen          )  , 
      .uctl_bankAck        (c1_ack                    )  , 
      .uctl_bankDVl        (c1_bankDVl                )  , 
      .uctl_bankReq        (c1_bankReq                )  , 
      .uctl_rdAck          (uctl_MemUsbWrAck          )  , 
      .uctl_dValid         (                          )   
   );

   //sepr bank(dma read)
   uctl_bankSel c2_bankSel (
      .uctl_offsetAddr     (uctl_MemDmaRdAddr[3:2]    )  , 
      .uctl_req            (uctl_MemDmaRdCen          )  , 
      .uctl_bankAck        (c2_ack                    )  , 
      .uctl_bankDVl        (c2_bankDVl                )  , 
      .uctl_bankReq        (c2_bankReq                )  , 
      .uctl_rdAck          (uctl_MemDmaRdAck          )  , 
      .uctl_dValid         (uctl_MemDmaRdDVld         )    
   );                                                      
                                                           
   //sept bank (dma write)                                 
   uctl_bankSel c3_bankSel (
      .uctl_offsetAddr     (uctl_MemDmaWrAddr[3:2]    )  , 
      .uctl_req            (uctl_MemDmaWrCen          )  , 
      .uctl_bankAck        (c3_ack                    )  ,
      .uctl_bankDVl        (c3_bankDVl                )  , 
      .uctl_bankReq        (c3_bankReq                )  , 
      .uctl_rdAck          (uctl_MemDmaWrAck          )  , 
      .uctl_dValid         (/*UNC*/                   )   
   );

   uctl_bankPriorityLogic
   b0_priority                (                               
      .uctl_bankReq           (b0_uctl_bankReq           )  ,   
      .uctl_memCe             (b0_mem_ce                 )  ,  
      .uctl_mem_rw            (b0_rw_en                  )  ,
      .uctl_chipSel           (b0_uctl_chipSel           )  
   );

   uctl_bankPriorityLogic
   b1_priority               (                           
     .uctl_bankReq           (b1_uctl_bankReq           )  ,   
     .uctl_memCe             (b1_mem_ce                 )  ,  
     .uctl_mem_rw            (b1_rw_en                  )  ,
     .uctl_chipSel           (b1_uctl_chipSel           )  
   );

   uctl_bankPriorityLogic
   b2_priority               (                                 
     .uctl_bankReq           (b2_uctl_bankReq           )  ,   
     .uctl_memCe             (b2_mem_ce                 )  ,  
     .uctl_mem_rw            (b2_rw_en                  )  ,
     .uctl_chipSel           (b2_uctl_chipSel           )  
   );

   uctl_bankPriorityLogic
   b3_priority               (                                
     .uctl_bankReq           (b3_uctl_bankReq           )  ,   
     .uctl_memCe             (b3_mem_ce                 )  ,  
     .uctl_mem_rw            (b3_rw_en                  )  ,
     .uctl_chipSel           (b3_uctl_chipSel           )  
   );

 
   uctl_cc_mux #(
      .MEM_ADDR_SIZE       (MEM_ADDR_SIZE  - 4           ), 
      .MEM_DATA_SIZE       (MEM_DATA_SIZE                )
      )b0_ccMux      (
     .uctl_clk               (uctl_coreClk              )  ,
     .uctl_core_rst_n        (uctl_core_rst_n           )  , 

     .uctl_chipsel           (b0_uctl_chipSel           )  ,

     .uctl_cl0Addr           (uctl_MemUsbRdAddr[MEM_ADDR_SIZE -1 : 4] )  ,                   
     .uctl_cl0DOut           ({MEM_DATA_SIZE{1'b0}}     )  ,         
     .uctl_cl0DIn            (b0_MemUsbRdDout           )  ,

     .uctl_cl1Addr           (uctl_MemUsbWrAddr[MEM_ADDR_SIZE -1 : 4] )  ,
     .uctl_cl1DOut           (uctl_MemUsbWrDin          )  ,
     .uctl_cl1DIn            (                          )  ,

     .uctl_cl2Addr           (uctl_MemDmaRdAddr[MEM_ADDR_SIZE -1 : 4] )  ,
     .uctl_cl2DOut           ({MEM_DATA_SIZE{1'b0}}     )  ,
     .uctl_cl2DIn            (b0_MemDmaRdDout           )  ,

     .uctl_cl3Addr           (uctl_MemDmaWrAddr[MEM_ADDR_SIZE -1 : 4] )  ,
     .uctl_cl3DOut           (uctl_MemDmaWrDin          )  ,
     .uctl_cl3DIn            (                          )  ,


     .mem_addr               (b0_mem_addr               )  ,
     .mem_dIn                (b0_mem_dataIn             )  ,
     .mem_dOut               (b0_mem_dataOut            )  ,
     .uctl_rdDVl             (b0_rdDvl                  )
   );             

   uctl_cc_mux #(
      .MEM_ADDR_SIZE       (MEM_ADDR_SIZE - 4            ), 
      .MEM_DATA_SIZE       (MEM_DATA_SIZE                )
      )b1_ccMux      (
     .uctl_clk               (uctl_coreClk              )  ,
     .uctl_core_rst_n        (uctl_core_rst_n           )  , 

     .uctl_chipsel           (b1_uctl_chipSel           )  ,

     .uctl_cl0Addr           (uctl_MemUsbRdAddr[MEM_ADDR_SIZE -1 : 4]          )  ,
     .uctl_cl0DOut           ({MEM_DATA_SIZE{1'b0}}     )  ,
     .uctl_cl0DIn            (b1_MemUsbRdDout           )  ,

     .uctl_cl1Addr           (uctl_MemUsbWrAddr[MEM_ADDR_SIZE -1 : 4]          )  ,
     .uctl_cl1DOut           (uctl_MemUsbWrDin          )  ,
     .uctl_cl1DIn            (                          )  ,

     .uctl_cl2Addr           (uctl_MemDmaRdAddr[MEM_ADDR_SIZE -1 : 4]          )  ,
     .uctl_cl2DOut           ({MEM_DATA_SIZE{1'b0}}     )  ,
     .uctl_cl2DIn            (b1_MemDmaRdDout           )  ,

     .uctl_cl3Addr           (uctl_MemDmaWrAddr[MEM_ADDR_SIZE -1 : 4]          )  ,
     .uctl_cl3DOut           (uctl_MemDmaWrDin          )  ,
     .uctl_cl3DIn            (                          )  ,                           

     .mem_addr               (b1_mem_addr               )  ,
     .mem_dIn                (b1_mem_dataIn             )  ,
     .mem_dOut               (b1_mem_dataOut            )  ,
     .uctl_rdDVl             (b1_rdDvl                  )
   );
          
   uctl_cc_mux #(
      .MEM_ADDR_SIZE       (MEM_ADDR_SIZE -4             ), 
      .MEM_DATA_SIZE       (MEM_DATA_SIZE                )
      )b2_ccMux      (
     .uctl_clk               (uctl_coreClk              )  ,
     .uctl_core_rst_n        (uctl_core_rst_n           )  , 

     .uctl_chipsel           (b2_uctl_chipSel           )  ,

     .uctl_cl0Addr           (uctl_MemUsbRdAddr[MEM_ADDR_SIZE -1 : 4]          )  ,     
     .uctl_cl0DOut           ({MEM_DATA_SIZE{1'b0}}     )  ,     
     .uctl_cl0DIn            (b2_MemUsbRdDout           )  ,     

     .uctl_cl1Addr           (uctl_MemUsbWrAddr[MEM_ADDR_SIZE -1 : 4]          )  ,     
     .uctl_cl1DOut           (uctl_MemUsbWrDin          )  ,     
     .uctl_cl1DIn            (                          )  ,     

     .uctl_cl2Addr           (uctl_MemDmaRdAddr[MEM_ADDR_SIZE -1 : 4]          )  ,     
     .uctl_cl2DOut           ({MEM_DATA_SIZE{1'b0}}     )  ,     
     .uctl_cl2DIn            (b2_MemDmaRdDout           )  ,

     .uctl_cl3Addr           (uctl_MemDmaWrAddr[MEM_ADDR_SIZE -1 : 4]          )  ,
     .uctl_cl3DOut           (uctl_MemDmaWrDin          )  ,
     .uctl_cl3DIn            (                          )  ,     

     .mem_addr               (b2_mem_addr               )  ,
     .mem_dIn                (b2_mem_dataIn             )  ,
     .mem_dOut               (b2_mem_dataOut            )  ,
     .uctl_rdDVl             (b2_rdDvl                  )
   );
             
   uctl_cc_mux #(
      .MEM_ADDR_SIZE       (MEM_ADDR_SIZE -4             ), 
      .MEM_DATA_SIZE       (MEM_DATA_SIZE                )
      )b3_ccMux      (
     .uctl_clk               (uctl_coreClk              )  ,
     .uctl_core_rst_n        (uctl_core_rst_n           )  , 

     .uctl_chipsel           (b3_uctl_chipSel           )  ,

     .uctl_cl0Addr           (uctl_MemUsbRdAddr[MEM_ADDR_SIZE -1 : 4]          )  ,     
     .uctl_cl0DOut           ({MEM_DATA_SIZE{1'b0}}     )  ,     
     .uctl_cl0DIn            (b3_MemUsbRdDout           )  ,     

     .uctl_cl1Addr           (uctl_MemUsbWrAddr[MEM_ADDR_SIZE -1 : 4]          )  ,     
     .uctl_cl1DOut           (uctl_MemUsbWrDin          )  ,     
     .uctl_cl1DIn            (                          )  ,     

     .uctl_cl2Addr           (uctl_MemDmaRdAddr[MEM_ADDR_SIZE -1 : 4]          )  ,     
     .uctl_cl2DOut           ({MEM_DATA_SIZE{1'b0}}     )  ,     
     .uctl_cl2DIn            (b3_MemDmaRdDout           )  ,     

     .uctl_cl3Addr           (uctl_MemDmaWrAddr[MEM_ADDR_SIZE -1 : 4]          )  ,
     .uctl_cl3DOut           (uctl_MemDmaWrDin          )  ,
     .uctl_cl3DIn            (                          )  ,     

     .mem_addr               (b3_mem_addr               )  ,
     .mem_dIn                (b3_mem_dataIn             )  ,
     .mem_dOut               (b3_mem_dataOut            )  ,
     .uctl_rdDVl             (b3_rdDvl                  )
   );
          
   uctl_memory #(
      .MEM_ADDR_SIZE       (MEM_ADDR_SIZE -4             ), 
      .MEM_DATA_SIZE       (MEM_DATA_SIZE                )
      )b0_memory           (
     .coreClk                 (uctl_coreClk              )  ,                      
     .mem_ce                  (b0_mem_ce                 )  ,                      
     .rw_en                   (b0_rw_en                  )  ,                      
     .mem_addr                (b0_mem_addr               )  ,                      
     .mem_dataIn              (b0_mem_dataIn             )  ,                      
     .mem_dataOut             (b0_mem_dataOut            )
   );


   uctl_memory #(
      .MEM_ADDR_SIZE       (MEM_ADDR_SIZE -4             ), 
      .MEM_DATA_SIZE       (MEM_DATA_SIZE                )
      )b1_memory           (
     .coreClk                 (uctl_coreClk              )  ,                      
     .mem_ce                  (b1_mem_ce                 )  ,                      
     .rw_en                   (b1_rw_en                  )  ,                      
     .mem_addr                (b1_mem_addr               )  ,                      
     .mem_dataIn              (b1_mem_dataIn             )  ,                      
     .mem_dataOut             (b1_mem_dataOut            )
   );

   uctl_memory #(
      .MEM_ADDR_SIZE       (MEM_ADDR_SIZE -4             ), 
      .MEM_DATA_SIZE       (MEM_DATA_SIZE                )
      )b2_memory           (
     .coreClk                 (uctl_coreClk              )  ,                      
     .mem_ce                  (b2_mem_ce                 )  ,                      
     .rw_en                   (b2_rw_en                  )  ,                      
     .mem_addr                (b2_mem_addr               )  ,                      
     .mem_dataIn              (b2_mem_dataIn             )  ,                      
     .mem_dataOut             (b2_mem_dataOut            )
   );

   uctl_memory #(
      .MEM_ADDR_SIZE       (MEM_ADDR_SIZE  -4            ), 
      .MEM_DATA_SIZE       (MEM_DATA_SIZE                )
      )b3_memory           (
     .coreClk                 (uctl_coreClk              )  ,                      
     .mem_ce                  (b3_mem_ce                 )  ,                      
     .rw_en                   (b3_rw_en                  )  ,                      
     .mem_addr                (b3_mem_addr               )  ,                      
     .mem_dataIn              (b3_mem_dataIn             )  ,                      
     .mem_dataOut             (b3_mem_dataOut            )
   );



endmodule
