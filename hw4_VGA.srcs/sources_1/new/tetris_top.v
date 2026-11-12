`timescale 1ns/1ps

// 顶层模块：连接 Basys3 输入、游戏核心与 VGA 输出。
// 数据流：按键 -> input_filter -> tetris_core -> tetris_video -> RGB 寄存器。
// 时钟：只有 divider 使用板载 100 MHz；其余逻辑使用 BUFG 输出的 25 MHz。
// 操作：左/右移动，下加速，上旋转，中间重开；SW0 暂停，SW1 上升沿硬降落。
// 本文件保留原端口顺序，便于与原 XDC 和仿真顶层直接对应。

module tetris_top(
    input wire clk, btnL, btnR, btnD, btnU, btnC,
    input wire [1:0] sw,
    output reg [3:0] vgaRed = 0, vgaGreen = 0, vgaBlue = 0,
    output reg Hsync = 1, Vsync = 1,
    output wire [3:0] led
);

    // 两位计数器的高位每四个输入周期完成一周期，产生 25 MHz。
    reg [1:0] divider = 0;
    always @(posedge clk)
        divider <= divider + 1'b1;

    // 通过专用全局时钟网络分配分频时钟；对应 XDC 的 pixel_clk。
    wire game_clk;
    BUFG pixel_buf(.I(divider[1]), .O(game_clk));

    // 上电后约 2.62 ms 保持复位；计满后停止，直到重新配置 FPGA。
    reg [15:0] power_count = 0;
    wire power_rst = !(&power_count);
    always @(posedge game_clk)
        if (power_rst)
            power_count <= power_count + 1'b1;

    // 25,000 个像素时钟 = 1 ms；tick_ms 高电平仅持续一拍。
    reg [16:0] ms_count = 0;
    wire tick_ms = ms_count == 24999;
    always @(posedge game_clk)
        if (tick_ms)
            ms_count <= 0;
        else
            ms_count <= ms_count + 1'b1;

    // 输入处理接口：稳定电平、按下事件、左/右/下连发事件。
    wire [6:0] held, press;
    wire [2:0] rpt;

    // 位置式端口连接顺序：clk, tick_ms, raw, held, press, repeat_pulse。
    input_filter keys(
        game_clk,  // 游戏时钟
        tick_ms,  // 毫秒使能
        {sw[1], sw[0], btnC, btnU, btnD, btnR, btnL},  // 七路原始输入
        held,  // 去抖后稳定电平
        press,  // 单次按下脉冲
        rpt  // 左/右/下连发脉冲
    );

    // 中心键只重开游戏，不清零 VGA 扫描计数器。
    wire rst = power_rst | held[4];

    // 当前所有像素周期都有效，保留此使能名称以对应原有结构。
    wire pixel_ce = 1'b1;

    // h=0..799、v=0..524；可见区域为 h<640 且 v<480。
    reg [9:0] h = 0, v = 0;
    always @(posedge game_clk) begin
        if (power_rst) begin
            h <= 0;
            v <= 0;
        end
        else if (pixel_ce) begin
            if (h == 799) begin
                h <= 0;
                if (v == 524)
                    v <= 0;
                else
                    v <= v + 1'b1;
            end
            else
                h <= h + 1'b1;
        end
    end

    // 第 480 行开始进入垂直消隐，在此时启动游戏操作，减少画面撕裂。
    wire frame = pixel_ce && h == 0 && v == 480;

    // 位 4..0：硬降落、旋转、下移、右移、左移；移动合并按下与连发。
    wire [4:0] command = {press[6], press[3], press[2] | rpt[2], press[1] | rpt[1], press[0] | rpt[0]};

    // 显示模块给出棋盘读地址，核心返回格子颜色及活动方块状态。
    wire [3:0] col;
    wire [4:0] row;
    wire [2:0] color;
    wire signed [5:0] px, py;
    wire [2:0] kind, next_kind;
    wire [1:0] rotation;
    wire active, over;
    wire [15:0] lines;

    // 位置式连接与 tetris_core 的端口声明一一对应。
    tetris_core game(
        game_clk,  // 游戏时钟
        rst,  // 同步复位
        frame,  // 垂直消隐起点
        tick_ms,  // 毫秒使能
        held[5],  // 暂停状态
        command,  // 五种操作命令
        col,  // 显示读列
        row,  // 显示读行
        color,  // 已锁定格子颜色
        px,  // 活动块 x
        py,  // 活动块 y
        kind,  // 当前类型
        next_kind,  // 下一类型
        rotation,  // 当前方向
        active,  // 活动块有效
        over,  // 游戏结束
        lines  // 累计消行数
    );
    wire [11:0] rgb;

    // 绘图模块接收像素坐标及游戏状态，组合产生当前像素 RGB。
    tetris_video draw(
        h,  // 像素 x
        v,  // 像素 y
        col,  // 棋盘读列
        row,  // 棋盘读行
        color,  // 棋盘返回颜色
        px,  // 活动块 x
        py,  // 活动块 y
        kind,  // 当前类型
        next_kind,  // 下一类型
        rotation,  // 当前方向
        active,  // 活动块有效
        over,  // 游戏结束
        held[5],  // 暂停状态
        lines,  // 累计消行数
        rgb  // 组合 RGB 输出
    );

    // LD3..LD0：活动块有效、SW1 原始电平、暂停、游戏结束。
    assign led = {active, sw[1], held[5], over};
    always @(posedge game_clk)
        if (pixel_ce) begin
            // 水平负同步区间 656..751，共 96 像素；垂直 490..491，共两行。
            Hsync <= !(h >= 656 && h < 752);
            Vsync <= !(v >= 490 && v < 492);

            // RGB 与同步信号都根据同一组旧 h/v 寄存输出，保持像素对齐。
            if (h < 640 && v < 480 && !power_rst) begin
                vgaRed <= rgb[11:8];
                vgaGreen <= rgb[7:4];
                vgaBlue <= rgb[3:0];
            end
            else begin
                vgaRed <= 0;
                vgaGreen <= 0;
                vgaBlue <= 0;
            end
        end

endmodule
