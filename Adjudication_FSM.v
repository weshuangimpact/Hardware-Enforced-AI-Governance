// ============================================================================
// Module      : Adjudication_FSM
// Description : Hardware-Enforced AI Governance Core (Deterministic FSM)
// ============================================================================

module Adjudication_FSM (
    input  wire        clk,                 // System Clock (硬體時脈)
    input  wire        rst_n,               // Active-low Reset (實體重置訊號)
    input  wire        req_valid,           // Payload valid signal (資料流入觸發)
    input  wire [31:0] payload_amount,      // 32-bit AI Inference Amount
    input  wire [7:0]  payload_currency,    // 8-bit AI Inference Currency

    output reg         resp_valid,          // Adjudication complete signal
    output reg  [1:0]  adjudication_status, // 00=DENY, 01=ALLOW, 10=PENDING
    output reg         hardware_gate_open   // 1=Physical Unblock, 0=Fail-Close Block
);

    // ------------------------------------------------------------------------
    // FSM State Encoding (狀態機編碼)
    // ------------------------------------------------------------------------
    localparam ST_IDLE      = 2'b00;
    localparam ST_EVALUATE  = 2'b01;
    localparam ST_DONE      = 2'b10;

    reg [1:0] current_state, next_state;

    // ------------------------------------------------------------------------
    // Sequential Logic: State Register (時序邏輯：狀態轉換)
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= ST_IDLE;
        else
            current_state <= next_state;
    end

    // ------------------------------------------------------------------------
    // Combinational Logic: Next State & Adjudication Rules (組合邏輯：裁決規則)
    // ------------------------------------------------------------------------
    always @(*) begin
        // Default assignments (預設硬體訊號，確保 Fail-Close 物理防護)
        next_state          = current_state;
        resp_valid          = 1'b0;
        adjudication_status = 2'b00;
        hardware_gate_open  = 1'b0; // 預設實體閘門絕對關閉

        case (current_state)
            ST_IDLE: begin
                // 當接收到有效的 AI 負載訊號，進入裁決狀態
                if (req_valid)
                    next_state = ST_EVALUATE;
            end

            ST_EVALUATE: begin
                // 【純硬體平行比對】無須 CPU 排程，所有條件在 1 個 Clock 內瞬間完成判定
                if (payload_amount > 32'd50000) begin
                    adjudication_status = 2'b00; // DENY
                    hardware_gate_open  = 1'b0;  // 實體阻斷
                end
                else if (payload_currency == 8'hFF) begin
                    adjudication_status = 2'b10; // PENDING
                    hardware_gate_open  = 1'b0;  // 實體阻斷，等待人工/修復介入
                end
                else begin
                    adjudication_status = 2'b01; // ALLOW
                    hardware_gate_open  = 1'b1;  // 授權開啟實體閘門
                end

                resp_valid = 1'b1; // 發出裁決完成訊號
                next_state = ST_DONE;
            end

            ST_DONE: begin
                // 等待前端資料流清除後，重置回待命狀態
                if (!req_valid)
                    next_state = ST_IDLE;
                else
                    next_state = ST_DONE; 
            end

            default: next_state = ST_IDLE;
        endcase
    end

endmodule
