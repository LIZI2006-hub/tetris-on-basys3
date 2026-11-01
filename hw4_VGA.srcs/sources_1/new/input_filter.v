`timescale 1ns/1ps
module input_filter(input wire clk, tick_ms, input wire [6:0] raw,
 output reg [6:0] held=0, output reg [6:0] press=0,
 output reg [2:0] repeat_pulse=0);
 (* ASYNC_REG="TRUE" *) reg [6:0] sync1=0, sync2=0;
 reg [3:0] count[0:6];
 reg [8:0] repeat_count[0:2];
 integer i;
 initial begin
  for(i=0;i<7;i=i+1) count[i]=0;
  for(i=0;i<3;i=i+1) repeat_count[i]=0;
 end
 always @(posedge clk) begin
  sync1<=raw; sync2<=sync1;
  press<=0; repeat_pulse<=0;
  if(tick_ms) begin
   for(i=0;i<7;i=i+1) begin
    if(sync2[i]==held[i]) count[i]<=0;
    else if(count[i]==15) begin
     held[i]<=sync2[i]; press[i]<=sync2[i]; count[i]<=0;
    end else count[i]<=count[i]+1'b1;
   end
   // raw bits 0/1/2: left/right/down. Initial delay 300 ms, repeat 80/40 ms.
   for(i=0;i<3;i=i+1) begin
    if(!held[i]) repeat_count[i]<=0;
    else if(repeat_count[i]==299) begin
     repeat_pulse[i]<=1; repeat_count[i]<= i==2 ? 260 : 220;
    end else repeat_count[i]<=repeat_count[i]+1'b1;
   end
  end
 end
endmodule
