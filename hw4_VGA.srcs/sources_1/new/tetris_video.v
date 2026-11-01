`timescale 1ns/1ps
module tetris_video(
 input wire [9:0] x,y,
 output wire [3:0] col, output wire [4:0] row,
 input wire [2:0] color,
 input wire signed [5:0] px,py,
 input wire [2:0] kind,next_kind, input wire [1:0] rotation,
 input wire active,over,pause, input wire [15:0] lines,
 output reg [11:0] rgb
);
 `include "shapes.vh"
 `include "font.vh"
 wire inside_board = x>=208 && x<368 && y>=64 && y<384;
 assign col=inside_board ? ((x-208)>>4) : 0;
 assign row=inside_board ? ((y-64)>>4) : 0;
 wire signed [6:0] dx=$signed({3'b0,col})-$signed(px);
 wire signed [6:0] dy=$signed({2'b0,row})-$signed(py);
 wire [15:0] live=shape(kind,rotation), preview=shape(next_kind,0);
 wire piece=active && dx>=0 && dx<4 && dy>=0 && dy<4 && live[{dy[1:0],dx[1:0]}];
 reg [2:0] tile;
 reg [7:0] ch;
 reg [9:0] text_x,text_y;
 reg text_area;
 reg [34:0] glyph;
 integer ix,iy,ci;
 function [11:0] palette;
  input [2:0] c;
  begin case(c)
   1:palette=12'h0EF; 2:palette=12'hFE0; 3:palette=12'hB4F;
   4:palette=12'h36F; 5:palette=12'hF91; 6:palette=12'h4E6;
   7:palette=12'hF45; default:palette=12'h112;
  endcase end
 endfunction
 always @* begin
  rgb=12'h012; tile=0; ch=32; text_x=0;text_y=0; text_area=0;
  ix=0;iy=0;ci=0;glyph=0;
  if(x>=204 && x<372 && y>=60 && y<388) rgb=over ? 12'hF45 : pause ? 12'hFE0 : 12'h567;
  if(inside_board) begin
   tile=piece ? kind+3'd1 : color;
   rgb=palette(tile);
   if(x[3:0]==0 || y[3:0]==0) rgb=12'h023;
   else if(tile!=0 && (x[3:0]==1 || y[3:0]==1)) rgb=12'hFFF;
  end
  if(x>=400 && x<464 && y>=96 && y<160) begin
   if(preview[{y[5:4]-2'd2,x[5:4]-2'd1}]) rgb=palette(next_kind+3'd1);
   if(x[3:0]==0 || y[3:0]==0) rgb=12'h012;
  end
  // Text uses 5x7 glyphs at 2x scale, 12 pixel character spacing.
  if(x>=208 && x<280 && y>=24 && y<38) begin
   text_area=1; text_x=x-208;text_y=y-24;
   ch=label_char(0,(x-208)/12);
  end else if(x>=400 && x<460 && y>=64 && y<78) begin
   text_area=1;text_x=x-400;text_y=y-64;ch=label_char(1,(x-400)/12);
  end else if(x>=400 && x<460 && y>=192 && y<206) begin
   text_area=1;text_x=x-400;text_y=y-192;ch=label_char(2,(x-400)/12);
  end else if(x>=400 && x<448 && y>=216 && y<230) begin
   text_area=1;text_x=x-400;text_y=y-216;
   case((x-400)/12)
    0:ch=hexchar(lines[15:12]); 1:ch=hexchar(lines[11:8]);
    2:ch=hexchar(lines[7:4]); default:ch=hexchar(lines[3:0]);
   endcase
  end else if(x>=400 && x<508 && y>=272 && y<286 && (over || pause)) begin
   text_area=1;text_x=x-400;text_y=y-272;ch=label_char(over ? 3:4,(x-400)/12);
  end else if(x>=160 && x<496 && y>=416 && y<430) begin
   text_area=1;text_x=x-160;text_y=y-416;ch=label_char(5,(x-160)/12);
  end else if(x>=160 && x<496 && y>=440 && y<454) begin
   text_area=1;text_x=x-160;text_y=y-440;ch=label_char(6,(x-160)/12);
  end
  if(text_area) begin
   ix=(text_x%12)>>1; iy=text_y>>1; glyph=font(ch);
   if(ix<5 && iy<7 && glyph[34-(iy*5+ix)]) rgb=12'hDEF;
  end
 end
endmodule
