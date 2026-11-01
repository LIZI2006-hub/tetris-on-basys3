`timescale 1ns/1ps
// All state uses clk. Commands: bit0 left, 1 right, 2 down, 3 rotate, 4 hard drop.
module tetris_core(
 input wire clk, rst, frame, tick_ms, pause,
 input wire [4:0] cmd,
 input wire [3:0] view_col, input wire [4:0] view_row,
 output wire [2:0] view_color,
 output reg signed [5:0] px, py,
 output reg [2:0] kind, next_kind,
 output reg [1:0] rotation,
 output reg active, game_over,
 output reg [15:0] lines
);
 `include "shapes.vh"
 reg [29:0] board [0:19];
 wire [29:0] view_data = view_row < 20 ? board[view_row] : 30'b0;
 assign view_color = view_col < 10 ? view_data[view_col*3 +: 3] : 3'b0;
 localparam CLEAR=0, SPAWN=1, IDLE=2, CHECK=3, DECIDE=4,
            LOCK=5, ROW=6, SHIFT=7, TOP=8;
 localparam OP_SPAWN=0, OP_MOVE=1, OP_DOWN=2, OP_HARD=3;
 reg [3:0] state;
 reg [1:0] op;
 reg signed [5:0] tx,ty;
 reg [1:0] tr;
 reg [3:0] cell_i;
 reg blocked;
 reg [4:0] row_i, shift_i;
 reg [4:0] pending;
 reg [9:0] fall_ms;
 reg [15:0] rng;
 wire [15:0] mask = shape(kind,tr);
 wire [15:0] live_mask = shape(kind,rotation);
 wire signed [5:0] cx = tx + $signed({4'b0,cell_i[1:0]});
 wire signed [5:0] cy = ty + $signed({4'b0,cell_i[3:2]});
 wire signed [5:0] lx = px + $signed({4'b0,cell_i[1:0]});
 wire signed [5:0] ly = py + $signed({4'b0,cell_i[3:2]});
 wire [29:0] check_row = (cy>=0 && cy<20) ? board[cy[4:0]] : 30'b0;
 wire [2:0] check_cell = (cx>=0 && cx<10) ? check_row[cx[3:0]*3 +:3] : 3'b0;
 wire hit = mask[cell_i] && (cx<0 || cx>=10 || cy<0 || cy>=20 || check_cell!=0);
 wire [29:0] scan_row = board[row_i];
 wire full_row = (scan_row[2:0]!=0) && (scan_row[5:3]!=0) &&
 (scan_row[8:6]!=0) && (scan_row[11:9]!=0) && (scan_row[14:12]!=0) &&
 (scan_row[17:15]!=0) && (scan_row[20:18]!=0) && (scan_row[23:21]!=0) &&
 (scan_row[26:24]!=0) && (scan_row[29:27]!=0);
 wire [9:0] fall_limit = lines>=50 ? 100 : lines>=40 ? 200 :
                           lines>=30 ? 300 : lines>=20 ? 400 : lines>=10 ? 500 : 600;
 always @(posedge clk) begin
  if(rst) begin
   state<=CLEAR; row_i<=0; shift_i<=0; pending<=0; fall_ms<=0;
   px<=3; py<=0; tx<=3; ty<=0; tr<=0; rotation<=0;
   kind<=0; next_kind<=0; active<=0; game_over<=0; lines<=0;
   cell_i<=0; blocked<=0; op<=OP_SPAWN; rng<=16'hACE1;
  end else begin
   rng<={rng[14:0],rng[15]^rng[13]^rng[12]^rng[10]};
   pending<=pending | cmd;
   if(pause || game_over) begin pending<=0; fall_ms<=0; end
   else if(tick_ms) begin
    if(fall_ms>=fall_limit-1) begin fall_ms<=0; pending[2]<=1; end
    else fall_ms<=fall_ms+1'b1;
   end
   case(state)
    CLEAR: begin
     board[row_i]<=0;
     if(row_i==19) state<=SPAWN; else row_i<=row_i+1'b1;
    end
    SPAWN: begin
     kind<=next_kind; next_kind<=rng[2:0]==7 ? 0 : rng[2:0];
     tx<=3; ty<=0; tr<=0; blocked<=0; cell_i<=0; op<=OP_SPAWN; state<=CHECK;
     pending<=0; fall_ms<=0;
    end
    IDLE: if(frame && !pause && !game_over && |pending) begin
     tx<=px; ty<=py; tr<=rotation; cell_i<=0; blocked<=0; op<=OP_MOVE;
     // Highest priority is hard drop, then rotate, left, right, gravity.
     if(pending[4]) begin ty<=py+1'b1; op<=OP_HARD; pending<=0; end
     else if(pending[3]) begin tr<=rotation+1'b1; pending[3]<=0; end
     else if(pending[0]) begin tx<=px-1'b1; pending[0]<=0; end
     else if(pending[1]) begin tx<=px+1'b1; pending[1]<=0; end
     else begin ty<=py+1'b1; op<=OP_DOWN; pending[2]<=0; end
     state<=CHECK;
    end
    CHECK: begin
     blocked<=blocked | hit;
     if(cell_i==15) state<=DECIDE; else cell_i<=cell_i+1'b1;
    end
    DECIDE: begin
     if(blocked) begin
      if(op==OP_SPAWN) begin game_over<=1; active<=0; state<=IDLE; end
      else if(op==OP_DOWN || op==OP_HARD) begin cell_i<=0; active<=0; state<=LOCK; end
      else state<=IDLE;
     end else begin
      px<=tx; py<=ty; rotation<=tr; active<=1;
      if(op==OP_HARD) begin ty<=ty+1'b1; cell_i<=0; blocked<=0; state<=CHECK; end
      else state<=IDLE;
     end
    end
    LOCK: begin
     if(live_mask[cell_i] && lx>=0 && lx<10 && ly>=0 && ly<20)
      board[ly[4:0]][lx[3:0]*3 +:3]<=kind+3'd1;
     if(cell_i==15) begin row_i<=19; state<=ROW; end else cell_i<=cell_i+1'b1;
    end
    ROW: begin
     if(full_row) begin
      if(lines!=65535) lines<=lines+1'b1;
      shift_i<=row_i;
      if(row_i==0) state<=TOP; else state<=SHIFT;
     end else if(row_i==0) state<=SPAWN;
     else row_i<=row_i-1'b1;
    end
    SHIFT: begin
     board[shift_i]<=board[shift_i-1'b1];
     if(shift_i==1) state<=TOP; else shift_i<=shift_i-1'b1;
    end
    TOP: begin board[0]<=0; state<=ROW; end // Recheck same row after shifting.
    default: state<=CLEAR;
   endcase
  end
 end
endmodule
