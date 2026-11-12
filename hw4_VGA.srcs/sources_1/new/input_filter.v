`timescale 1ns/1ps

// 输入处理：两级同步 -> 约 16 ms 去抖 -> 单次按下事件 / 长按连发。
// raw[0..6] = 左、右、下、上、中间、SW0、SW1。
// held 是稳定电平；press 与 repeat_pulse 是仅持续一个 clk 周期的事件。
// tick_ms 是毫秒使能脉冲，所有寄存器仍由 clk 驱动。

module input_filter(
    input wire clk, tick_ms,
    input wire [6:0] raw,
    output reg [6:0] held = 0,
    output reg [6:0] press = 0,
    output reg [2:0] repeat_pulse = 0
);

    // 两级寄存器降低异步输入亚稳态向后传播的概率；属性供实现工具识别。
    (* ASYNC_REG = "TRUE" *) reg [6:0] sync1 = 0, sync2 = 0;

    // 每个输入分别计数 16 次不同采样，避免按键间相互影响。
    reg [3:0] count[0:6];
    reg [8:0] repeat_count[0:2];
    integer i;

    // Artix-7 支持配置时的寄存器初值；这里不是上板后的软件初始化。
    initial begin
        for (i = 0; i < 7; i = i + 1)
            count[i] = 0;
        for (i = 0; i < 3; i = i + 1)
            repeat_count[i] = 0;
    end

    always @(posedge clk) begin
        // 非阻塞赋值使 sync2 接收上一拍的 sync1，形成真正的两级同步。
        sync1 <= raw;
        sync2 <= sync1;

        // 事件默认清零，仅在后续条件满足时置位，因此脉冲宽度为一拍。
        press <= 0;
        repeat_pulse <= 0;

        // 去抖与长按计数只在每毫秒的使能事件上推进。
        if (tick_ms) begin
            for (i = 0; i < 7; i = i + 1) begin
                // 采样恢复到当前稳定值就清零；必须连续 16 次不同才接受新状态。
                if (sync2[i] == held[i])
                    count[i] <= 0;
                else if (count[i] == 15) begin
                    // 更新稳定电平；新值为 1 才产生 press，释放时不产生按下事件。
                    held[i] <= sync2[i];
                    press[i] <= sync2[i];
                    count[i] <= 0;
                end
                else
                    count[i] <= count[i] + 1'b1;
            end
            for (i = 0; i < 3; i = i + 1) begin
                // 仅左/右/下启用连发：稳定按下约 300 ms 后首次重复。
                if (!held[i])
                    repeat_count[i] <= 0;
                else if (repeat_count[i] == 299) begin
                    repeat_pulse[i] <= 1;

                    // 随后回装 220 / 260，分别再等待 80 ms / 40 ms。
                    repeat_count[i] <= i == 2 ? 260 : 220;
                end
                else
                    repeat_count[i] <= repeat_count[i] + 1'b1;
            end
        end
    end

endmodule