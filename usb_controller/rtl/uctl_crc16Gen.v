`timescale 1ns / 1ps
//-------------------------------------------------------------------
// Copyright © 2012 TECHVULCAN, Inc. All rights reserved.         
// TechVulcan Confidential and Proprietary
// Not to be used, copied reproduced in whole or in part, nor      
// its contents                        
// revealed in any manner to others without the express written      
// permission   of TechVulcan                   
// Licensed Material.                     
// Program Property of TECHVULCAN Incorporated.   
// ------------------------------------------------------------------
// DATE              : Wed, 09 Jan 2013 14:20:33
// AUTHOR            : MAHMOOD
// AUTHOR EMAIL      : vdn_mahmood@techvulcan.com
// FILE NAME         : uctl_crc16Gen.v
// VERSION           : 0.2
//-------------------------------------------------------------------
//version 0.2 fix
//crc_out is changed
//default state is added for byte enable
//--------------------------------------------------------------------
module uctl_crc16Gen#(
   parameter DATA_SIZE = 32

)(
   input  wire                   core_clk              ,  // Global signal
   input  wire                   uctl_rst_n            ,  // Global signal 
   input  wire                   sw_rst                ,  // Global signal 
   input  wire [3            :0] crc_DataBE            ,

   input  wire [31           :0] crc_Data              ,  // input 32 bit data   
   input  wire                   crc_lastData          ,  // TODO
   input  wire                   crc_dataValid         ,  // this will come with crc_in..when its high only then we 
                                                          // need to check that incoming crc having error or not                          
   input  wire [15           :0] crc_in                ,  // 16 bit incoming crc for checking
   input  wire                   crc_validIn           ,
  
   output reg [15           :0]  crc_out               ,  //16 bit crc16 ouput and 
   output reg                    crc_match             ,
   output wire                   crc_valid_out         
   );

   //-------------------------------------------------------------------
   // local reg/wire declarations
   //-------------------------------------------------------------------
   reg        crc_match_d; 
  
   reg [15:0] crc_data_in ; //using this register to pass initial values to function
   reg        crc_lastData_r;
   reg        crc_validIn_r ;
   reg [31:0] temp      ;
   wire       ld_defCrc;
  integer  i,j;

   //-----------------------------------------------------------
   //lsb to msb
   //-----------------------------------------------------------
   always @(*) begin
      for(i = 0; i<8 ;  i=i+1) begin
         temp[31-i] =  crc_Data[i];
         temp[23-i] =  crc_Data[8+i];
         temp[15-i] =  crc_Data[16+i];
         temp[7-i]  =  crc_Data[24+i];
      end
   end
   // ----------------------------------------------------------
   // Code begins here
   // ----------------------------------------------------------

   always @( posedge  core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n)begin
         crc_lastData_r       <=1'b0;
         crc_validIn_r        <=1'b0;
      end
      else if(sw_rst)begin
         crc_lastData_r       <=1'b0;
         crc_validIn_r        <=1'b0;
      end
      else begin 
         crc_lastData_r       <= crc_lastData   ;
         crc_validIn_r        <= crc_validIn    ;
      end
   end

   
   always @ (posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n)begin
         crc_data_in <= 16'hFFFF;
      end
      else if(sw_rst)begin
         crc_data_in <= 16'hFFFF;
      end
      else if(crc_dataValid) begin
         // initial crc will b 4'h1111 when 1st 32 bit data comes then it wil be newcrc_3 on next data
         //crc_data_out is the name of teh function and we are passing crce_data and previous  crc value 
         // to that function
         //crc_data_in <= crc_data_out( crc_Data, crc_data_in);      
         crc_data_in <= crc_data_out( temp, crc_data_in);      
      end
      else if(ld_defCrc) begin
         crc_data_in <= 16'hFFFF;
      end 
   end

   assign ld_defCrc  =  crc_valid_out;   
//   assign crc_out       = ~crc_data_in;                                
   always @(*) begin                                // assigning the 16-bit value to output crce
      for( j=0; j<=15; j=j+1) begin
         crc_out[15-j] = ~crc_data_in[j];
      end
   end

   assign crc_valid_out = (crc_lastData_r | crc_validIn_r);   

   always@(*)begin
      crc_match_d  = 1'b0;
      if(crc_validIn ==1'b1)begin
         if(crc_in==crc_out)begin
            crc_match_d =  1'b1;
         end
         else begin
            crc_match_d = 1'b0;
         end
      end
   end

   always @ (posedge core_clk or negedge uctl_rst_n) begin
      if(!uctl_rst_n)
         crc_match  <= 1'b0;
      else  
         crc_match  <= crc_match_d;
   end
   //------------------------------------------------
   // function to generate 16 bit crc --- Function 1
   //-----------------------------------------------
   function [15:0] nextCRC16_D8; 

      input [7:0] Data;
      input [15:0] crc;
      reg [7:0] d;
      reg [15:0] c;
      reg [15:0] newcrc;
      begin
         d = Data;
         c = crc;

         newcrc[0] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[2] ^ d[1] ^ d[0] ^ c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
         newcrc[1] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[2] ^ d[1] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
         newcrc[2] = d[1] ^ d[0] ^ c[8] ^ c[9];
         newcrc[3] = d[2] ^ d[1] ^ c[9] ^ c[10];
         newcrc[4] = d[3] ^ d[2] ^ c[10] ^ c[11];
         newcrc[5] = d[4] ^ d[3] ^ c[11] ^ c[12];
         newcrc[6] = d[5] ^ d[4] ^ c[12] ^ c[13];
         newcrc[7] = d[6] ^ d[5] ^ c[13] ^ c[14];
         newcrc[8] = d[7] ^ d[6] ^ c[0] ^ c[14] ^ c[15];
         newcrc[9] = d[7] ^ c[1] ^ c[15];
         newcrc[10] = c[2];
         newcrc[11] = c[3];
         newcrc[12] = c[4];
         newcrc[13] = c[5];
         newcrc[14] = c[6];
         newcrc[15] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[2] ^ d[1] ^ d[0] ^ c[7] ^ c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
         nextCRC16_D8 = newcrc;
      end
   endfunction
   //-----------------------------------------------------------------
   // takes 32bit i/p and calls F1 with 8bit data to calculate CRC
   //-----------------------------------------------------------------
   function [15:0] crc_data_out;                                                  
      input [31:0] temp;
      input [15:0] crc_data_in;
      reg[15:0] newcrc_0;
      reg[15:0] newcrc_1;
      reg[15:0] newcrc_2;
      reg[15:0] newcrc_3;
      begin
         newcrc_0 = nextCRC16_D8( temp[31:24]   , crc_data_in);                    // calls F1 with 8bit data and initial CRC i.e all 1's
         newcrc_1 = nextCRC16_D8( temp[23:16]  , newcrc_0 );                      // calls F2 with 8bit data and previously calculated CRC
         newcrc_2 = nextCRC16_D8( temp[15:8] , newcrc_1 );     
         newcrc_3 = nextCRC16_D8( temp[7:0] , newcrc_2 );     
         case (crc_DataBE)                                                           // according to BE function will give output
            4'b0001 : crc_data_out = newcrc_0;
            4'b0011 : crc_data_out = newcrc_1;
            4'b0111 : crc_data_out = newcrc_2;
            default : crc_data_out = newcrc_3;
         endcase
      //   crc_data_out = newcrc_3;
      end
   endfunction

endmodule


  // always @(*) begin                    //wrong
  //    for(integer i=0; i<8;  i=i+1) begin
  //       temp[31-i]  =  crc_Data[24+i];
  //       temp[23-i]  =  crc_Data[16+i];
  //       temp[15-i]  =  crc_Data[8+i];
  //       temp[7-i]   =  crc_Data[i];
  //    end
  // end
