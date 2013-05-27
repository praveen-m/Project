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
// DATE           : Sun, 03 Mar 2013 19:29:51
// AUTHOR         : Darshan Naik
// AUTHOR EMAIL   : darshan.naik@techvulcan.com
// FILE NAME      : uctl_cmdIfMif.v
// VERSION        : 0.3      
//------------------------------------------------------------------


// VERSION        : 0.3
//                   addr incrment and wrfifo rd req logic changed for
//                   dma Mode :000 (direct mem access)                      
// VERSION        : 0.2  
//                   external dma logic implemented
// VERSION        : 0.1  
//                   intial release


/* TODO
      
*/
//---------------------------------------------------------------------
//----------------------------------------------------------------------


module uctl_cmdIfMif #(
      parameter START_MEM_HADDR   =32'h0_0000, 
      parameter END_MEM_HADDR     =32'h0_03FC
)     
(
   
   input  wire                       sys_clk          ,
   input  wire                       sysRst_n         ,
   input  wire                       sw_rst           ,

   //----------------------------------------------
   // Cmd IF
   //----------------------------------------------
   input  wire                       cmdIf_trEn       ,
   input  wire                       cmdIf_req        ,
   input  wire [31               :0] cmdIf_addr       ,
   input  wire                       cmdIf_wrRd       ,
   output reg                        cmdIf_ack        ,

   input  wire                       cmdIf_wrData_req ,
   input  wire [31               :0] cmdIf_wrData     ,
   output reg                        cmdIf_wrData_ack ,

   input  wire                       cmdIf_rdData_req ,
   output reg                        cmdIf_rdData_ack ,
   output wire [31               :0] cmdIf_rdData     ,


   //----------------------------------------------
   // memory interface
   //----------------------------------------------
   output reg                        mem_req          ,        
   output reg                        mem_wrRd         ,
   output reg  [31               :0] mem_addr         ,                          
   output wire [31               :0] mem_wrData       ,   
   input  wire                       mem_ack          ,
   input  wire                       mem_rdVal        ,
   input  wire [31               :0] mem_rdData       ,

   //-----------------------------------------------
   // sept interface
   //-----------------------------------------------
   output reg                        cmdIf2sept_dn          ,
   input  wire                       sept2cmdIf_wr          , 
   input  wire [2                :0] sept2cmdIf_dmaMode     ,   
   input  wire [31               :0] sept2cmdIf_addr        ,//local buffer address
   input  wire [19               :0] sept2cmdIf_len         ,
   input  wire [31               :0] sept2cmdIf_epStartAddr ,
   input  wire [31               :0] sept2cmdIf_epEndAddr   ,  
   
   //------------------------------------------------
   // Register Interface
   //------------------------------------------------
   input  wire [21               :0] reg2cmdIf_memSegAddr   ,
   
   //-----------------------------------------------
   // sepr interface
   //-----------------------------------------------
   output reg                        cmdIf2sepr_dn          ,
   input  wire                       sepr2cmdIf_rd          , 
   input  wire [2                :0] sepr2cmdIf_dmaMode     ,   
   input  wire [31               :0] sepr2cmdIf_addr        ,//local buffer address
   input  wire [19               :0] sepr2cmdIf_len         ,
   input  wire [31               :0] sepr2cmdIf_epStartAddr ,
   input  wire [31               :0] sepr2cmdIf_epEndAddr   
   
   );
   
   localparam  BYTE     =3'b000,
               HWORD    =3'b001,
               WORD     =3'b010;

   localparam  CM_IDLE  =1'b0,
               CM_TRSFR =1'b1;

   localparam  MIF_WR_IDLE  = 1'b0,
               MIF_WR_TRANS = 1'b1;

   localparam  MIF_RD_IDLE  = 1'b0,
               MIF_RD_TRANS = 1'b1;


   reg                      next_state                ;
   reg                      current_state             ;
   reg                      nxt_state_wr              ;
   reg                      cur_state_wr              ;
   reg                      nxt_state_rd              ;
   reg                      cur_state_rd              ;
   reg  [31             :0] mem_addr_r                ;
   reg  [31             :0] mem_wr_addr_r             ;
   reg  [31             :0] mem_rd_addr_r             ;
   reg                      mem_rd_req_f              ;
   reg                      mem_wr_req_f              ;
   reg                      mem_rd_req_f2             ;
   reg                      mem_addr_ld               ;
   reg                      mem_addr_incr             ;
   reg                      mem_wr_addr_incr          ;
   reg                      mem_rd_addr_incr          ;
   reg                      set_mem_rd_req_f          ;
   reg                      set_mem_rd_req_f2         ;
   reg                      set_mem_wr_req_f          ;
   reg                      clr_mem_rd_req_f          ;
   reg                      clr_mem_rd_req_f2         ;
   reg                      clr_mem_wr_req_f          ;
   reg                      wrfifo_wr_req             ;
   reg                      wrfifo_rd_req             ;
   wire                     wrfifo_empty              ;
   wire                     wrfifo_full               ;
   wire                     rdfifo_empty              ;
   wire                     rdfifo_full               ;
   reg                      rdfifo_rd_req             ;
   reg                      rdfifo_wr_req             ;
   wire [31             :0] wrfifo_data_out           ;
   wire [31             :0] wrfifo_data_in            ;
   wire [31             :0] rdfifo_data_out           ;
   wire [31             :0] rdfifo_data_in            ;
   wire                     cmdIf_trEn_mem            ;  
   reg                      memIf                     ;  
   reg  [19             :0] mem_bytes_wr_cntr_t       ;
   wire                     mem_bytes_wr_cntr_t_is_0  ;
   reg  [19             :0] mem_bytes_rd_cntr_t       ;
   wire                     mem_bytes_rd_cntr_t_is_0  ;
   reg  [31             :0] mem_rd_addr_l_nxt         ;
   reg  [31             :0] mem_wr_addr_l_nxt         ;
   wire                     wrReq_Ack_high            ;
   wire                     rdReq_Ack_high            ;
   reg                      mem_bytes_wr_cntr_ld      ;
   reg                      mem_bytes_wr_cntr_dec     ; 
   reg                      mem_bytes_rd_cntr_ld      ;
   reg                      mem_bytes_rd_cntr_dec     ; 
   wire                     nearly_full               ;
   wire                     set_req                   ;
   wire                     clr_req                   ;  
   reg                      req_f                     ;
   
   //assign statements
   assign cmdIf_trEn_mem =(cmdIf_trEn && memIf) ? 1:0;

   
   always @(*) begin
      if((cmdIf_addr >= START_MEM_HADDR) && (cmdIf_addr <=END_MEM_HADDR)) begin
         memIf =1'b1;
      end
      else begin
         memIf=1'b0;
      end
   end

    //storing local  addr and incrementing it
   always @ (posedge sys_clk or negedge sysRst_n) begin//{
      if(!sysRst_n) begin
         mem_wr_addr_r <= {32{1'b0}}  ;
         mem_rd_addr_r <= {32{1'b0}}  ;
         mem_addr_r <= {32{1'b0}}  ;
      end
      else if(mem_addr_ld)begin
         if (sept2cmdIf_dmaMode == 3'b001 && cmdIf_wrRd ==1'b1 ) begin
            mem_wr_addr_r<= sept2cmdIf_addr ;
         end   
         if (sepr2cmdIf_dmaMode == 3'b001 && cmdIf_wrRd ==1'b0) begin   
            mem_rd_addr_r<= sepr2cmdIf_addr ;     
         end
         if ((sept2cmdIf_dmaMode == 3'b000) | 
                  (sepr2cmdIf_dmaMode == 3'b000)) begin
            mem_addr_r    <={reg2cmdIf_memSegAddr,cmdIf_addr[9:0]};
         end
      end
      else if (mem_addr_incr) begin
         mem_addr_r     <= mem_addr_r     + 3'b100;
      end
      else if (mem_wr_addr_incr) begin
         mem_wr_addr_r  <= mem_wr_addr_r  + 3'b100;
      end
      else if (mem_rd_addr_incr) begin
         mem_rd_addr_r  <= mem_rd_addr_r  + 3'b100;
      end
      else begin
         mem_wr_addr_r <= mem_wr_addr_l_nxt     ;
         mem_rd_addr_r <= mem_rd_addr_l_nxt     ;
         mem_addr_r    <= mem_addr_r            ; 
      end
   end

  


   // setting and clearing read flag for cmd If state machine
   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n) begin
         mem_rd_req_f<= 1'b0;
      end
      else if (sw_rst) begin
         mem_rd_req_f<= 1'b0;
      end
      else begin
         if (set_mem_rd_req_f) begin
            mem_rd_req_f<= 1'b1;
         end
         else if(clr_mem_rd_req_f) begin
            mem_rd_req_f<= 1'b0;
         end
      end
   end


   // setting and clearing read flag for mem If state machine
   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n) begin
         mem_rd_req_f2<= 1'b0;
      end
      else if (sw_rst) begin
         mem_rd_req_f2<= 1'b0;
      end
      else begin
         if (set_mem_rd_req_f2) begin
            mem_rd_req_f2<= 1'b1;
         end
         else if(clr_mem_rd_req_f2) begin
            mem_rd_req_f2<= 1'b0;
         end
      end
   end


   // setting and clearing write flag for mem If state machine
   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n) begin
         mem_wr_req_f<= 1'b0;
      end
      else if (sw_rst) begin
         mem_wr_req_f<= 1'b0;
      end
      else begin
         if (set_mem_wr_req_f) begin
            mem_wr_req_f<= 1'b1;
         end
         else if(clr_mem_wr_req_f) begin
            mem_wr_req_f<= 1'b0;
         end
      end
   end
   
   
   //assign statements
   assign cmdIf_rdData              = rdfifo_data_out ; 
   assign wrfifo_data_in            = cmdIf_wrData    ;  
   

   // state machine for cmd If
   always @(*) begin
      next_state           =current_state;
      mem_addr_ld          =1'b0;
      cmdIf_ack            =1'b0;
      wrfifo_wr_req        =1'b0;
      set_mem_rd_req_f     =1'b0;
      cmdIf_rdData_ack     =1'b0;
      cmdIf_wrData_ack     =1'b0;
      clr_mem_rd_req_f     =1'b0;
      rdfifo_rd_req        =1'b0;
      case(current_state)
         CM_IDLE: begin
            if(cmdIf_trEn_mem && cmdIf_req) begin
               // Check that the previous write transfer
               // is done which means mem if is idle now
               if(wrfifo_empty) begin
                  next_state        =CM_TRSFR;
                  cmdIf_ack         =1'b1;
                  mem_addr_ld       =1'b1;
                  if(cmdIf_wrRd == 1'b0) begin
                     set_mem_rd_req_f =1'b1;
                  end
               end
            end
            else begin
               next_state        =CM_IDLE;
               clr_mem_rd_req_f  = 1'b1;
            end
         end // case:IDLE   


         CM_TRSFR: begin
            if(!cmdIf_trEn_mem) begin
               next_state        =CM_IDLE;
               clr_mem_rd_req_f  = 1'b1;
            end
            else begin
               if (cmdIf_req) begin
                  // Check that the previous write transfer
                  // is done which means mem if is idle now
                  if(wrfifo_empty) begin
                     next_state        =CM_TRSFR;
                     cmdIf_ack         =1'b1;
                     mem_addr_ld       =1'b1;
                     if(cmdIf_wrRd == 1'b0) begin
                        set_mem_rd_req_f =1'b1;
                     end
                     else begin
                        clr_mem_rd_req_f =1'b1;
                     end
                  end
               end
               else if(cmdIf_wrData_req) begin
                  if(wrfifo_full) begin
                     cmdIf_wrData_ack  =1'b0;
                     wrfifo_wr_req     =1'b0;
                  end
                  else begin
                     next_state        =CM_TRSFR;
                     cmdIf_wrData_ack  =1'b1;
                     wrfifo_wr_req     =1'b1;
                  end
               end
               else if(cmdIf_rdData_req) begin
                  if(rdfifo_empty) begin
                     cmdIf_rdData_ack  =1'b0;
                     rdfifo_rd_req     =1'b0;
                  end
                  else begin
                     next_state        =CM_TRSFR;
                     cmdIf_rdData_ack  =1'b1;
                     rdfifo_rd_req     =1'b1;
                  end
               end
            end  
         end // CM_TRSFR: begin

         default : next_state = current_state ;

      endcase
   end // state machine for cmd If  


   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n ) begin
         current_state <= CM_IDLE;
      end
      else if(sw_rst) begin
         current_state <= CM_IDLE;
      end
      else begin
         current_state <= next_state;
      end
   end

   
   // when nearly full block the mem req   
   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n ) begin
         req_f <= 1'b0;
      end
      else begin
         if(set_req) begin
            req_f     <= 1'b1;
         end
         else if (clr_req) begin
            req_f     <= 1'b0;
         end
      end
   end

   assign set_req = (mem_rd_req_f && ~rdfifo_full && mem_ack==1'b0) ? 1:0;
   assign clr_req = (mem_rd_req_f && ~rdfifo_full && mem_ack==1'b1) ? 1:0;

   // wr/rd request logic for the mif
   always@(*) begin   
      mem_req  = (mem_rd_req_f & ~rdfifo_full & !nearly_full) |
                 (mem_rd_req_f & req_f ) | ~wrfifo_empty;
      mem_wrRd = ~wrfifo_empty;
   end 


   // wrapping of address is done here
   always @(*) begin
      if(mem_wr_addr_r >  sept2cmdIf_epEndAddr) begin
         mem_wr_addr_l_nxt  = sept2cmdIf_epStartAddr ;
      end
      else begin
         mem_wr_addr_l_nxt  = mem_wr_addr_r          ;
      end
      if(mem_rd_addr_r >  sepr2cmdIf_epEndAddr) begin
         mem_rd_addr_l_nxt  = sepr2cmdIf_epStartAddr ;
      end
      else begin
         mem_rd_addr_l_nxt  = mem_rd_addr_r             ;
      end
   end 
   
 
   // storing bytes and decrementing it for write operation
   always @ (posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n) begin
         mem_bytes_wr_cntr_t <= {20{1'b0}};                                               // loc reg value on global rst
      end

      else if(mem_bytes_wr_cntr_ld) begin                                                 // on load signl, assign tot no f bytes to locl reg   
         mem_bytes_wr_cntr_t <= sept2cmdIf_len;                                              // length of transfer in bytes
      end

      else if (mem_bytes_wr_cntr_dec) begin                                               // on dec signal , dec the countr by 4
         if( mem_bytes_wr_cntr_t < 3'd4) begin           
            mem_bytes_wr_cntr_t <= {20{1'b0}};                                            // if no f bytes < 4 , make value f loc reg is 0
         end 
         else begin
            mem_bytes_wr_cntr_t <= mem_bytes_wr_cntr_t - 3'd4;                            // decrsin d no f bytes by 4 if no f bytes are > 0
         end
      end  
   end

   assign mem_bytes_wr_cntr_t_is_0     =(mem_bytes_wr_cntr_t == {20{1'b0}}) ? 1:0 ; 


   // storing bytes and decrementing it for read operation
   always @ (posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n) begin
         mem_bytes_rd_cntr_t <= {20{1'b0}};                                                  // loc reg value on global rst
      end

      else if(mem_bytes_rd_cntr_ld) begin                                                    // on load signl, assign tot no f bytes to locl reg   
         mem_bytes_rd_cntr_t <= sepr2cmdIf_len;                                              // length of transfer in bytes
      end

      else if (mem_bytes_rd_cntr_dec) begin                                                  // on dec signal , dec the countr by 4
         if( mem_bytes_rd_cntr_t < 3'd4) begin           
            mem_bytes_rd_cntr_t <= {20{1'b0}};                                               // if no f bytes < 4 , make value f loc reg is 0
         end 
         else begin
            mem_bytes_rd_cntr_t <= mem_bytes_rd_cntr_t - 3'd4;                               // decrsin d no f bytes by 4 if no f bytes are > 0
         end
      end  
   end

   assign mem_bytes_rd_cntr_t_is_0     =(mem_bytes_rd_cntr_t == {20{1'b0}}) ? 1:0 ;
 
 
   
   always @ (*) begin
      if(sept2cmdIf_dmaMode ==3'b001) begin
         mem_addr = mem_wr_addr_r;
      end
      else if(sepr2cmdIf_dmaMode==3'b001) begin
         mem_addr = mem_rd_addr_r;
      end
      else if(sept2cmdIf_dmaMode ==3'b000 ||sepr2cmdIf_dmaMode==3'b000) begin
         mem_addr = mem_addr_r;
      end
      else begin
         mem_addr = {32{1'b0}};
      end
   end
   
   //assig statements
   

   assign mem_wrData                = wrfifo_data_out                            ;
   
   assign rdfifo_data_in            = mem_rdData                                 ; 

   assign wrReq_Ack_high            = ( (mem_req == 1'b1) && (mem_ack == 1'b1) &&
                                        (mem_wrRd==1'b1) )  ? 1:0                ;
   assign rdReq_Ack_high            = ( (mem_req == 1'b1) && (mem_ack == 1'b1) &&
                                        (mem_wrRd==1'b0) )  ? 1:0                ;
 


   /*always @ (*) begin
      if ((sept2cmdIf_dmaMode == 3'b000) | 
                  (sepr2cmdIf_dmaMode == 3'b000)) begin
         if(mem_ack) begin
            mem_addr_incr  = 1'b1;
            wrfifo_rd_req  = 1'b1;
         end
         else begin
            mem_addr_incr  = 1'b0;
            wrfifo_rd_req  = 1'b0;
         end
      end
      else begin
         mem_addr_incr  = 1'b0;
         wrfifo_rd_req  = 1'b0;
      end
   end
   */

   //state machine mem If
   always @ (*) begin
      nxt_state_wr            = cur_state_wr ;
      mem_bytes_wr_cntr_ld    = 1'b0         ;
      mem_bytes_wr_cntr_dec   = 1'b0         ; 
      set_mem_wr_req_f        = 1'b0         ;
      clr_mem_wr_req_f        = 1'b0         ;
      cmdIf2sept_dn           = 1'b0         ;
      wrfifo_rd_req           = 1'b0         ;
      mem_addr_incr           = 1'b0         ;
      mem_wr_addr_incr        = 1'b0         ;
      

      case(cur_state_wr) 
         MIF_WR_IDLE :  begin
            if (sept2cmdIf_dmaMode == 3'b001) begin
               if(sept2cmdIf_wr==1'b1) begin
                  if(sept2cmdIf_len == {20{1'b0}} ) begin
                     nxt_state_wr         =  MIF_WR_IDLE ;
                     cmdIf2sept_dn        =  1'b1     ;
                  end
                  else begin
                     set_mem_wr_req_f     = 1'b1      ;
                     mem_bytes_wr_cntr_ld = 1'b1      ; 
                     nxt_state_wr         = MIF_WR_TRANS ;
                  end
               end
            end
            if (sept2cmdIf_dmaMode == 3'b000) begin
               if(wrReq_Ack_high) begin
                  mem_addr_incr  = 1'b1;
                  wrfifo_rd_req  = 1'b1;
               end   
            end 
         end//  MIF_WR_IDLE:begin

         MIF_WR_TRANS : begin   
            if(wrReq_Ack_high) begin
               mem_wr_addr_incr           = 1'b1;
               mem_bytes_wr_cntr_dec      = 1'b1;
               wrfifo_rd_req              = 1'b1;
            end
      
            if (mem_wr_req_f) begin
               if (mem_bytes_wr_cntr_t_is_0) begin
                  nxt_state_wr            = MIF_WR_IDLE;
                  cmdIf2sept_dn           = 1'b1;
                  clr_mem_wr_req_f        = 1'b1; 
               end
               else begin
                  nxt_state_wr            = cur_state_wr;
               end
            end
         end // MIF_WR_TRANS :begin

         default : nxt_state_wr = cur_state_wr;

      endcase
   end // state machine for mem If
   
   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n ) begin
         cur_state_wr <= MIF_WR_IDLE;
      end
      else if(sw_rst) begin
         cur_state_wr <= MIF_WR_IDLE;
      end
      else begin
         cur_state_wr <= nxt_state_wr;
      end
   end
   

   

   //state machine mem If
   always @ (*) begin
      nxt_state_rd            = cur_state_rd ;
      mem_bytes_rd_cntr_ld    = 1'b0         ;
      mem_bytes_rd_cntr_dec   = 1'b0         ; 
      set_mem_rd_req_f2       = 1'b0         ;
      clr_mem_rd_req_f2       = 1'b0         ; 
      cmdIf2sepr_dn           = 1'b0         ;
      rdfifo_wr_req           = 1'b0         ;
      mem_addr_incr           = 1'b0         ;
      mem_rd_addr_incr        = 1'b0         ;

      case(cur_state_rd) 
         MIF_RD_IDLE :  begin

            if (sepr2cmdIf_dmaMode == 3'b001) begin   
               if (sepr2cmdIf_rd==1'b1) begin
                  if(sepr2cmdIf_len == {20{1'b0}}) begin
                     nxt_state_rd         =  MIF_RD_IDLE ;
                     cmdIf2sepr_dn        =  1'b1     ;
                  end
                  else begin
                     set_mem_rd_req_f2       = 1'b1      ;
                     mem_bytes_rd_cntr_ld    = 1'b1      ; 
                     nxt_state_rd            = MIF_RD_TRANS ;
                  end
               end
            end


            if (sepr2cmdIf_dmaMode == 3'b000) begin
               if(rdReq_Ack_high)begin
                  mem_addr_incr         = 1'b1;
               end
               if (mem_rdVal)  begin
                  rdfifo_wr_req         = 1'b1; 
               end
            end  

         end//  MIF_RD_IDLE:begin

         MIF_RD_TRANS : begin   
            if(rdReq_Ack_high)begin
               mem_rd_addr_incr            = 1'b1;
            end
            
            if (mem_rdVal) begin
               mem_bytes_rd_cntr_dec      = 1'b1;
               rdfifo_wr_req              = 1'b1;
            end
      
            if (mem_rd_req_f2) begin
               if (mem_bytes_rd_cntr_t_is_0) begin
                  nxt_state_rd            = MIF_RD_IDLE;
                  cmdIf2sepr_dn           = 1'b1;
                  clr_mem_rd_req_f2       = 1'b1; 
               end
               else begin
                  nxt_state_rd            = cur_state_rd;
               end
            end 
         end // MIF_RD_TRANS :begin

         default : nxt_state_rd = cur_state_rd;

      endcase
   end // state machine for mem If
   
   always @(posedge sys_clk or negedge sysRst_n) begin
      if(!sysRst_n ) begin
         cur_state_rd <= MIF_RD_IDLE;
      end
      else if(sw_rst) begin
         cur_state_rd <= MIF_RD_IDLE;
      end
      else begin
         cur_state_rd <= nxt_state_rd;
      end
   end


   // read fifo 
   uctl_syncFifo rdfifo (
            .clk         (sys_clk)        ,
            .rst_n       (sysRst_n)       ,
            .sw_rst      (cmdIf_ack)      ,
            .wrEn        (rdfifo_wr_req)  ,
            .rdEn        (rdfifo_rd_req)  ,
            .dataIn      (rdfifo_data_in) ,
            .full        (rdfifo_full)    ,
            .nearly_full (nearly_full)    ,       
            .empty       (rdfifo_empty)   ,
            .dataOut     (rdfifo_data_out)
   );
   
   //write fifo
   uctl_syncFifo wrfifo (
            .clk     (sys_clk)         ,
            .rst_n   (sysRst_n)        ,
            .sw_rst  (cmdIf_ack)       ,
            .wrEn    (wrfifo_wr_req)   ,
            .rdEn    (wrfifo_rd_req)   ,
            .dataIn  (wrfifo_data_in)  ,
            .full    (wrfifo_full)     ,
            .empty   (wrfifo_empty)    ,
            .dataOut (wrfifo_data_out) 
   );
   


endmodule
