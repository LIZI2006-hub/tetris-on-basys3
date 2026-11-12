`timescale 1ns/1ps

// 组合绘图模块：根据当前 VGA 坐标计算一个像素的 12 位 RGB。
// 输出 col / row 请求棋盘格，输入 color 接收该格的已落地颜色。
// 绘制顺序：背景 -> 边框 -> 棋盘/活动块 -> 下一块预览 -> 文字。
// 后面的颜色赋值覆盖前面的颜色；实际 RGB 输出寄存器位于 tetris_top。
// 不使用整屏帧缓存，游戏状态与坐标共同决定当前像素。

module tetris_video(
    input wire [9:0] x, y,
    output wire [3:0] col,
    output wire [4:0] row,
    input wire [2:0] color,
    input wire signed [5:0] px, py,
    input wire [2:0] kind, next_kind,
    input wire [1:0] rotation,
    input wire active, over, pause,
    input wire [15:0] lines,
    output reg [11:0] rgb
);
    `include "shapes.vh"
    `include "font.vh"

    // 棋盘左上角 (208,64)，10x20 格，每格 16x16 像素。
    wire inside_board = x >= 208 && x < 368 && y >= 64 && y < 384;

    // 减去原点再右移四位，得到棋盘列/行；16 像素格使除法直接变成移位。
    assign col = inside_board ? ((x - 208) >> 4) : 0;
    assign row = inside_board ? ((y - 64) >> 4) : 0;

    // 当前棋盘格相对活动块原点的位置；负数表示在活动块左边或上方。
    wire signed [6:0] dx = $signed({3'b0, col}) - $signed(px);
    wire signed [6:0] dy = $signed({2'b0, row}) - $signed(py);
    wire [15:0] live = shape(kind, rotation), preview = shape(next_kind, 0);

    // 局部坐标合法且对应掩码位为 1 才叠加活动块；索引 dy*4+dx。
    wire piece = active && dx >= 0 && dx < 4 && dy >= 0 && dy < 4 && live[{dy[1:0], dx[1:0]}];

    // tile 为最终格子颜色编号；ch/glyph 为文字编码与字形。
    reg [2:0] tile;
    reg [7:0] ch;
    reg [9:0] text_x, text_y;
    reg text_area;
    reg [34:0] glyph;
    integer ix, iy, ci;

    // 将三位格子编号转换为 RGB 各四位的颜色；0 对应空格背景。
    function [11:0] palette;
        input [2:0] c;
        begin
            case (c)
                1: palette = 12'h0EF;
                2: palette = 12'hFE0;
                3: palette = 12'hB4F;
                4: palette = 12'h36F;
                5: palette = 12'hF91;
                6: palette = 12'h4E6;
                7: palette = 12'hF45;
                default: palette = 12'h112;
            endcase
        end
    endfunction

    // 纯组合绘图：先给所有临时变量默认值，避免不完整赋值产生锁存器。
    always @* begin
        rgb = 12'h012;
        tile = 0;
        ch = 32;
        text_x = 0;
        text_y = 0;
        text_area = 0;
        ix = 0;
        iy = 0;
        ci = 0;
        glyph = 0;

        // 先画外边框：结束红色、暂停黄色、正常灰色。
        if (x >= 204 && x < 372 && y >= 60 && y < 388)
            rgb = over ? 12'hF45 : pause ? 12'hFE0 : 12'h567;

        // 棋盘层：活动方块优先，其余显示已锁定格子。
        if (inside_board) begin
            tile = piece ? kind + 3'd1 : color;
            rgb = palette(tile);

            // 用坐标低四位绘制 16 像素网格；非空方块增加一像素亮边。
            if (x[3:0] == 0 || y[3:0] == 0)
                rgb = 12'h023;
            else if (tile != 0 && (x[3:0] == 1 || y[3:0] == 1))
                rgb = 12'hFFF;
        end

        // NEXT 预览使用 4x4 格；低位索引减去预览原点对应的格偏移。
        if (x >= 400 && x < 464 && y >= 96 && y < 160) begin
            if (preview[{y[5:4] - 2'd2, x[5:4] - 2'd1}])
                rgb = palette(next_kind + 3'd1);
            if (x[3:0] == 0 || y[3:0] == 0)
                rgb = 12'h012;
        end

        // 文字层：5x7 点阵放大两倍，字形 10x14 像素，字符间距 12 像素。
        if (x >= 208 && x < 280 && y >= 24 && y < 38) begin
            text_area = 1;
            text_x = x - 208;
            text_y = y - 24;
            ch = label_char(0, (x - 208) / 12);
        end
        else if (x >= 400 && x < 460 && y >= 64 && y < 78) begin
            text_area = 1;
            text_x = x - 400;
            text_y = y - 64;
            ch = label_char(1, (x - 400) / 12);
        end
        else if (x >= 400 && x < 460 && y >= 192 && y < 206) begin
            text_area = 1;
            text_x = x - 400;
            text_y = y - 192;
            ch = label_char(2, (x - 400) / 12);
        end
        else if (x >= 400 && x < 448 && y >= 216 && y < 230) begin
            text_area = 1;
            text_x = x - 400;
            text_y = y - 216;

            // LINES 拆成四个半字节，显示为十六进制，例如 000A 表示 10 行。
            case ((x - 400) / 12)
                0: ch = hexchar(lines[15:12]);
                1: ch = hexchar(lines[11:8]);
                2: ch = hexchar(lines[7:4]);
                default: ch = hexchar(lines[3:0]);
            endcase
        end
        else if (x >= 400 && x < 508 && y >= 272 && y < 286 && (over || pause)) begin
            text_area = 1;
            text_x = x - 400;
            text_y = y - 272;
            ch = label_char(over ? 3 : 4, (x - 400) / 12);
        end
        else if (x >= 160 && x < 496 && y >= 416 && y < 430) begin
            text_area = 1;
            text_x = x - 160;
            text_y = y - 416;
            ch = label_char(5, (x - 160) / 12);
        end
        else if (x >= 160 && x < 496 && y >= 440 && y < 454) begin
            text_area = 1;
            text_x = x - 160;
            text_y = y - 440;
            ch = label_char(6, (x - 160) / 12);
        end

        // 计算字符内坐标；ix=5 留作间距，只在 5x7 字形点阵为 1 时覆盖文字色。
        if (text_area) begin
            ix = (text_x % 12) >> 1;
            iy = text_y >> 1;
            glyph = font(ch);
            if (ix < 5 && iy < 7 && glyph[34 - (iy * 5 + ix)])
                rgb = 12'hDEF;
        end
    end

endmodule
