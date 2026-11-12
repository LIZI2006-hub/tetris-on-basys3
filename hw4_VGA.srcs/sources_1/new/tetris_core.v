// 游戏核心：保存棋盘，执行移动、旋转、落地、消行和结束判断。
// cmd[0..4] = 左移、右移、下移、旋转、硬降落；frame 为垂直消隐起点。
// view_row / view_col 是显示模块的读地址，view_color 返回已锁定格子的颜色。
// 活动方块单独用 px、py、kind、rotation 描述，落地前不写入 board。
// 坐标原点在棋盘左上角，x 向右增加，y 向下增加。
// 状态流程：CLEAR -> SPAWN -> CHECK -> DECIDE -> IDLE；
// 落地流程：LOCK -> ROW -> SHIFT / TOP -> ROW -> SPAWN。
// 逐格检测和逐行搬移复用组合逻辑，避免一次并行处理整个棋盘。

module tetris_core(
    input wire clk, rst, frame, tick_ms, pause,
    input wire [4:0] cmd,
    input wire [3:0] view_col,
    input wire [4:0] view_row,
    output wire [2:0] view_color,
    output reg signed [5:0] px, py,
    output reg [2:0] kind, next_kind,
    output reg [1:0] rotation,
    output reg active, game_over,
    output reg [15:0] lines
);
    `include "shapes.vh"

    // 棋盘存储 20 行 x 10 格 x 3 bit = 600 bit；0=空，1..7=颜色编号。
    reg [29:0] board[0:19];

    // 显示端为组合读取；越界读地址返回空。+: 3 表示从起点取三位。
    wire [29:0] view_data = view_row < 20 ? board[view_row] : 30'b0;
    assign view_color = view_col < 10 ? view_data[view_col * 3 +: 3] : 3'b0;

    // 主状态编码；保持原编码，便于已有仿真按状态等待。
    localparam CLEAR = 0,
               SPAWN = 1,
               IDLE = 2,
               CHECK = 3,
               DECIDE = 4,
               LOCK = 5,
               ROW = 6,
               SHIFT = 7,
               TOP = 8;

    // 共用碰撞检测器，通过 op 区分失败后应结束、拒绝移动还是锁定。
    localparam OP_SPAWN = 0,
               OP_MOVE = 1,
               OP_DOWN = 2,
               OP_HARD = 3;
    reg [3:0] state;
    reg [1:0] op;

    // 候选位置/方向；只有检查通过才提交到 px、py、rotation。
    reg signed [5:0] tx, ty;
    reg [1:0] tr;

    // 遍历 4x4 掩码；低两位为局部 x，高两位为局部 y。
    reg [3:0] cell_i;

    // 16 拍内碰撞结果的累计或，进入检查前清零。
    reg blocked;
    reg [4:0] row_i, shift_i;

    // 每种命令保存一个待处理标志，不是事件队列；重复同类事件会合并。
    reg [4:0] pending;

    // 自动下落毫秒计数；lines 决定阈值，最高速度为 100 ms/格。
    reg [9:0] fall_ms;
    reg [15:0] rng;

    // mask 用于候选检测；live_mask 用于将当前合法位置锁定到棋盘。
    wire [15:0] mask = shape(kind, tr);
    wire [15:0] live_mask = shape(kind, rotation);

    // 有符号坐标可表示 -1，正确检测左/上边界；显式转换避免无符号扩展。
    wire signed [5:0] cx = tx + $signed({4'b0, cell_i[1:0]});
    wire signed [5:0] cy = ty + $signed({4'b0, cell_i[3:2]});
    wire signed [5:0] lx = px + $signed({4'b0, cell_i[1:0]});
    wire signed [5:0] ly = py + $signed({4'b0, cell_i[3:2]});

    // 先保护行、列索引，再读取候选格；越界本身由 hit 判定为碰撞。
    wire [29:0] check_row = (cy >= 0 && cy < 20) ? board[cy[4:0]] : 30'b0;
    wire [2:0] check_cell = (cx >= 0 && cx < 10) ? check_row[cx[3:0] * 3 +: 3] : 3'b0;

    // 掩码为 0 的位置不参与碰撞；占用格越界或碰到非空格即失败。
    wire hit = mask[cell_i] && (cx < 0 || cx >= 10 || cy < 0 || cy >= 20 || check_cell != 0);
    wire [29:0] scan_row = board[row_i];

    // 十个格子分别非零才算满行，不能直接对 30 个颜色位做归约与。
    wire full_row = (scan_row[2:0] != 0) &&
                    (scan_row[5:3] != 0) &&
                    (scan_row[8:6] != 0) &&
                    (scan_row[11:9] != 0) &&
                    (scan_row[14:12] != 0) &&
                    (scan_row[17:15] != 0) &&
                    (scan_row[20:18] != 0) &&
                    (scan_row[23:21] != 0) &&
                    (scan_row[26:24] != 0) &&
                    (scan_row[29:27] != 0);

    // 每消除 10 行缩短 100 ms，下落间隔从 600 ms 逐档降至 100 ms。
    wire [9:0] fall_limit = lines >= 50 ? 100 :
                            lines >= 40 ? 200 :
                            lines >= 30 ? 300 :
                            lines >= 20 ? 400 :
                            lines >= 10 ? 500 :
                            600;
    always @(posedge clk) begin
        // 这里只复位控制寄存器；board 随后由 CLEAR 每拍清一行。
        if (rst) begin
            state <= CLEAR;
            row_i <= 0;
            shift_i <= 0;
            pending <= 0;
            fall_ms <= 0;
            px <= 3;
            py <= 0;
            tx <= 3;
            ty <= 0;
            tr <= 0;
            rotation <= 0;
            kind <= 0;
            next_kind <= 0;
            active <= 0;
            game_over <= 0;
            lines <= 0;
            cell_i <= 0;
            blocked <= 0;
            op <= OP_SPAWN;

            // 固定种子的 LFSR 产生伪随机序列，本版保留原来的出块算法。
            rng <= 16'hACE1;
        end
        else begin
            rng <= {rng[14:0], rng[15] ^ rng[13] ^ rng[12] ^ rng[10]};

            // 先合并输入；同一时序块内后面的赋值对重叠位有更高优先级。
            pending <= pending | cmd;

            // 暂停/结束清除待处理命令和落下计时；已启动的短操作仍会执行完成。
            if (pause || game_over) begin
                pending <= 0;
                fall_ms <= 0;
            end
            else if (tick_ms) begin
                if (fall_ms >= fall_limit - 1) begin
                    fall_ms <= 0;
                    pending[2] <= 1;
                end
                else
                    fall_ms <= fall_ms + 1'b1;
            end

            // 状态机在每个 clk 沿只执行当前状态对应的分支。
            case (state)

                // 逐行清空棋盘，20 拍后进入出生流程。
                CLEAR: begin
                    board[row_i] <= 0;
                    if (row_i == 19)
                        state <= SPAWN;
                    else
                        row_i <= row_i + 1'b1;
                end

                // 取出预览块作为当前块；3 bit 随机值 7 映射为 I，因此存在选择偏差。
                SPAWN: begin
                    kind <= next_kind;
                    next_kind <= rng[2:0] == 7 ? 0 : rng[2:0];
                    tx <= 3;
                    ty <= 0;
                    tr <= 0;
                    blocked <= 0;
                    cell_i <= 0;
                    op <= OP_SPAWN;
                    state <= CHECK;
                    pending <= 0;
                    fall_ms <= 0;
                end

                // 仅在垂直消隐起点启动操作；优先级：硬降落 > 旋转 > 左 > 右 > 下。
                IDLE: if (frame && !pause && !game_over && |pending) begin
                    tx <= px;
                    ty <= py;
                    tr <= rotation;
                    cell_i <= 0;
                    blocked <= 0;
                    op <= OP_MOVE;
                    if (pending[4]) begin
                        ty <= py + 1'b1;
                        op <= OP_HARD;
                        pending <= 0;
                    end
                    else if (pending[3]) begin
                        tr <= rotation + 1'b1;
                        pending[3] <= 0;
                    end
                    else if (pending[0]) begin
                        tx <= px - 1'b1;
                        pending[0] <= 0;
                    end
                    else if (pending[1]) begin
                        tx <= px + 1'b1;
                        pending[1] <= 0;
                    end
                    else begin
                        ty <= py + 1'b1;
                        op <= OP_DOWN;
                        pending[2] <= 0;
                    end
                    state <= CHECK;
                end

                // 每拍检查一个掩码位置；第 16 拍仍要计入 blocked。
                CHECK: begin
                    blocked <= blocked | hit;
                    if (cell_i == 15)
                        state <= DECIDE;
                    else
                        cell_i <= cell_i + 1'b1;
                end

                // 独立下一拍读取 blocked，确保包含 CHECK 最后一拍的非阻塞更新。
                DECIDE: begin
                    if (blocked) begin
                        // 出生失败结束游戏；下降失败锁定当前位置；横移/旋转失败保持原状。
                        if (op == OP_SPAWN) begin
                            game_over <= 1;
                            active <= 0;
                            state <= IDLE;
                        end
                        else if (op == OP_DOWN || op == OP_HARD) begin
                            cell_i <= 0;
                            active <= 0;
                            state <= LOCK;
                        end
                        else
                            state <= IDLE;
                    end
                    else begin
                        // 检测通过才提交候选状态。硬降落继续尝试下一行，直到首次失败。
                        px <= tx;
                        py <= ty;
                        rotation <= tr;
                        active <= 1;
                        if (op == OP_HARD) begin
                            ty <= ty + 1'b1;
                            cell_i <= 0;
                            blocked <= 0;
                            state <= CHECK;
                        end
                        else
                            state <= IDLE;
                    end
                end

                // 逐格写入最后一个合法位置。kind 为 0..6，写入时加 1，保留 0 表示空。
                LOCK: begin
                    if (live_mask[cell_i] && lx >= 0 && lx < 10 && ly >= 0 && ly < 20)
                        board[ly[4:0]][lx[3:0] * 3 +: 3] <= kind + 3'd1;
                    if (cell_i == 15) begin
                        row_i <= 19;
                        state <= ROW;
                    end
                    else
                        cell_i <= cell_i + 1'b1;
                end

                // 从第 19 行向上检查；行数达到 65535 后饱和，不回绕。
                ROW: begin
                    if (full_row) begin
                        if (lines != 65535)
                            lines <= lines + 1'b1;
                        shift_i <= row_i;
                        if (row_i == 0)
                            state <= TOP;
                        else
                            state <= SHIFT;
                    end
                    else if (row_i == 0)
                        state <= SPAWN;
                    else
                        row_i <= row_i - 1'b1;
                end

                // 每拍把上方一行复制到当前行，顺序向上推进，避免覆盖尚未搬移的数据。
                SHIFT: begin
                    board[shift_i] <= board[shift_i - 1'b1];
                    if (shift_i == 1)
                        state <= TOP;
                    else
                        shift_i <= shift_i - 1'b1;
                end

                // 清空最顶行后重新检查原 row_i，才能连续消除刚落下来的满行。
                TOP: begin
                    board[0] <= 0;
                    state <= ROW;
                end
                default: state <= CLEAR;
            endcase
        end
    end

endmodule