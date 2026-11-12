// 组合字库：仅保存界面需要的字符与固定文字，未定义字符显示为空白。
// font(c)：ASCII 编码 -> 35 位的 5x7 点阵；bit34 为左上角，bit0 为右下角。
// hexchar(v)：四位数值 -> 十六进制字符；LINES 因而使用 0000..FFFF 显示。
// label_char(line_id,index)：文字编号与字符序号 -> ASCII 编码。
// 字库仅提供点阵；放大两倍和字符间距由 tetris_video 完成。

function [34:0] font;
    input [7:0] c;
    begin
        case (c)
            8'd65: font = 35'b01110100011000111111100011000110001;  // A
            8'd66: font = 35'b11110100011000111110100011000111110;  // B
            8'd67: font = 35'b01111100001000010000100001000001111;  // C
            8'd68: font = 35'b11110100011000110001100011000111110;  // D
            8'd69: font = 35'b11111100001000011110100001000011111;  // E
            8'd70: font = 35'b11111100001000011110100001000010000;  // F
            8'd71: font = 35'b01111100001000010111100011000101110;  // G
            8'd72: font = 35'b10001100011000111111100011000110001;  // H
            8'd73: font = 35'b11111001000010000100001000010011111;  // I
            8'd76: font = 35'b10000100001000010000100001000011111;  // L
            8'd77: font = 35'b10001110111010110101100011000110001;  // M
            8'd78: font = 35'b10001110011010110011100011000110001;  // N
            8'd79: font = 35'b01110100011000110001100011000101110;  // O
            8'd80: font = 35'b11110100011000111110100001000010000;  // P
            8'd82: font = 35'b11110100011000111110101001001010001;  // R
            8'd83: font = 35'b01111100001000001110000010000111110;  // S
            8'd84: font = 35'b11111001000010000100001000010000100;  // T
            8'd85: font = 35'b10001100011000110001100011000101110;  // U
            8'd86: font = 35'b10001100011000110001100010101000100;  // V
            8'd87: font = 35'b10001100011000110101101011010101010;  // W
            8'd88: font = 35'b10001100010101000100010101000110001;  // X
            8'd48: font = 35'b01110100011001110101110011000101110;  // 0
            8'd49: font = 35'b00100011000010000100001000010001110;  // 1
            8'd50: font = 35'b01110100010000100010001000100011111;  // 2
            8'd51: font = 35'b11110000010000101110000010000111110;  // 3
            8'd52: font = 35'b00010001100101010010111110001000010;  // 4
            8'd53: font = 35'b11111100001000011110000010000111110;  // 5
            8'd54: font = 35'b01110100001000011110100011000101110;  // 6
            8'd55: font = 35'b11111000010001000100010000100001000;  // 7
            8'd56: font = 35'b01110100011000101110100011000101110;  // 8
            8'd57: font = 35'b01110100011000101111000010000101110;  // 9
            8'd47: font = 35'b00001000100001000100010000100010000;  // /
            default: font = 0;
        endcase
    end
endfunction

function [7:0] hexchar;
    input [3:0] v;
    begin
        hexchar = v < 10 ? 8'd48 + v : 8'd55 + v;
    end
endfunction

function [7:0] label_char;
    input [2:0] line_id;
    input [5:0] index;
    begin
        case ({line_id, index})
            9'd0: label_char = 8'd84;  // T
            9'd1: label_char = 8'd69;  // E
            9'd2: label_char = 8'd84;  // T
            9'd3: label_char = 8'd82;  // R
            9'd4: label_char = 8'd73;  // I
            9'd5: label_char = 8'd83;  // S
            9'd64: label_char = 8'd78;  // N
            9'd65: label_char = 8'd69;  // E
            9'd66: label_char = 8'd88;  // X
            9'd67: label_char = 8'd84;  // T
            9'd128: label_char = 8'd76;  // L
            9'd129: label_char = 8'd73;  // I
            9'd130: label_char = 8'd78;  // N
            9'd131: label_char = 8'd69;  // E
            9'd132: label_char = 8'd83;  // S
            9'd192: label_char = 8'd71;  // G
            9'd193: label_char = 8'd65;  // A
            9'd194: label_char = 8'd77;  // M
            9'd195: label_char = 8'd69;  // E
            9'd197: label_char = 8'd79;  // O
            9'd198: label_char = 8'd86;  // V
            9'd199: label_char = 8'd69;  // E
            9'd200: label_char = 8'd82;  // R
            9'd256: label_char = 8'd80;  // P
            9'd257: label_char = 8'd65;  // A
            9'd258: label_char = 8'd85;  // U
            9'd259: label_char = 8'd83;  // S
            9'd260: label_char = 8'd69;  // E
            9'd320: label_char = 8'd76;  // L
            9'd321: label_char = 8'd47;  // /
            9'd322: label_char = 8'd82;  // R
            9'd324: label_char = 8'd77;  // M
            9'd325: label_char = 8'd79;  // O
            9'd326: label_char = 8'd86;  // V
            9'd327: label_char = 8'd69;  // E
            9'd330: label_char = 8'd85;  // U
            9'd332: label_char = 8'd82;  // R
            9'd333: label_char = 8'd79;  // O
            9'd334: label_char = 8'd84;  // T
            9'd335: label_char = 8'd65;  // A
            9'd336: label_char = 8'd84;  // T
            9'd337: label_char = 8'd69;  // E
            9'd340: label_char = 8'd68;  // D
            9'd342: label_char = 8'd68;  // D
            9'd343: label_char = 8'd79;  // O
            9'd344: label_char = 8'd87;  // W
            9'd345: label_char = 8'd78;  // N
            9'd384: label_char = 8'd67;  // C
            9'd386: label_char = 8'd82;  // R
            9'd387: label_char = 8'd69;  // E
            9'd388: label_char = 8'd83;  // S
            9'd389: label_char = 8'd69;  // E
            9'd390: label_char = 8'd84;  // T
            9'd393: label_char = 8'd83;  // S
            9'd394: label_char = 8'd87;  // W
            9'd395: label_char = 8'd48;  // 0
            9'd397: label_char = 8'd80;  // P
            9'd398: label_char = 8'd65;  // A
            9'd399: label_char = 8'd85;  // U
            9'd400: label_char = 8'd83;  // S
            9'd401: label_char = 8'd69;  // E
            9'd404: label_char = 8'd83;  // S
            9'd405: label_char = 8'd87;  // W
            9'd406: label_char = 8'd49;  // 1
            9'd408: label_char = 8'd68;  // D
            9'd409: label_char = 8'd82;  // R
            9'd410: label_char = 8'd79;  // O
            9'd411: label_char = 8'd80;  // P
            default: label_char = 32;
        endcase
    end
endfunction
