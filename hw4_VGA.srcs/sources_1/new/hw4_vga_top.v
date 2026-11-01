`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/24 09:56:46
// Design Name: 
// Module Name: hw4_vga_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module hw4_vga_top (
    input wire clk, btnL,btnR,btnD,btnU,btnC,
    input wire [1:0] sw,
    output reg [3:0] vgaRed=0,vgaGreen=0,vgaBlue=0,
    output reg Hsync=1,Vsync=1,
    output wire [3:0] led
);
 // A dedicated global buffer drives the divided clock. Only the divider uses 100 MHz.
 reg [1:0] divider=0;
 always @(posedge clk) divider<=divider+1'b1;
 wire game_clk;
 BUFG pixel_buf(.I(divider[1]),.O(game_clk));
 reg [15:0] power_count=0;
 wire power_rst = !(&power_count);
 always @(posedge game_clk) if(power_rst) power_count<=power_count+1'b1;
 reg [16:0] ms_count=0;
 wire tick_ms = ms_count==24999;
 always @(posedge game_clk) if(tick_ms) ms_count<=0; else ms_count<=ms_count+1'b1;
 wire [6:0] held,press;
 wire [2:0] rpt;
 input_filter keys(game_clk,tick_ms,{sw[1],sw[0],btnC,btnU,btnD,btnR,btnL},held,press,rpt);
 wire rst=power_rst | held[4];
 wire pixel_ce=1'b1;
 reg [9:0] h=0,v=0;
 // 25 MHz, 800x525 totals = 59.524 Hz. Single game/pixel clock domain.
 always @(posedge game_clk) begin
  if(power_rst) begin h<=0; v<=0; end
  else if(pixel_ce) begin
   if(h==799) begin h<=0; if(v==524) v<=0; else v<=v+1'b1; end
   else h<=h+1'b1;
  end
 end
 wire frame=pixel_ce && h==0 && v==480;
 wire [4:0] command={press[6],press[3],press[2]|rpt[2],press[1]|rpt[1],press[0]|rpt[0]};
 wire [3:0] col; wire [4:0] row; wire [2:0] color;
 wire signed [5:0] px,py;
 wire [2:0] kind,next_kind;
 wire [1:0] rotation;
 wire active,over;
 wire [15:0] lines;
 tetris_core game(game_clk,rst,frame,tick_ms,held[5],command,col,row,color,
                  px,py,kind,next_kind,rotation,active,over,lines);
 wire [11:0] rgb;
 tetris_video draw(h,v,col,row,color,px,py,kind,next_kind,rotation,active,over,held[5],lines,rgb);
 assign led={active,sw[1],held[5],over};
 always @(posedge game_clk) if(pixel_ce) begin
  Hsync<= !(h>=656 && h<752);
  Vsync<= !(v>=490 && v<492);
  if(h<640 && v<480 && !power_rst) begin
   vgaRed<=rgb[11:8]; vgaGreen<=rgb[7:4]; vgaBlue<=rgb[3:0];
  end else begin vgaRed<=0; vgaGreen<=0; vgaBlue<=0; end
 end
endmodule

