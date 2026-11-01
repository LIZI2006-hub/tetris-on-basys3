function [15:0] shape;
 input [2:0] k; input [1:0] r;
 begin case({k,r})
 5'd0: shape=16'h000F;
 5'd1: shape=16'h1111;
 5'd2: shape=16'h000F;
 5'd3: shape=16'h1111;
 5'd4: shape=16'h0033;
 5'd5: shape=16'h0033;
 5'd6: shape=16'h0033;
 5'd7: shape=16'h0033;
 5'd8: shape=16'h0027;
 5'd9: shape=16'h0232;
 5'd10: shape=16'h0072;
 5'd11: shape=16'h0131;
 5'd12: shape=16'h0071;
 5'd13: shape=16'h0113;
 5'd14: shape=16'h0047;
 5'd15: shape=16'h0322;
 5'd16: shape=16'h0074;
 5'd17: shape=16'h0311;
 5'd18: shape=16'h0017;
 5'd19: shape=16'h0223;
 5'd20: shape=16'h0036;
 5'd21: shape=16'h0231;
 5'd22: shape=16'h0036;
 5'd23: shape=16'h0231;
 5'd24: shape=16'h0063;
 5'd25: shape=16'h0132;
 5'd26: shape=16'h0063;
 5'd27: shape=16'h0132;
 default:shape=16'h000F;
 endcase end
endfunction
