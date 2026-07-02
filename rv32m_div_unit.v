// -----------------------------------------------------------------------------
// RV32M divider wrapper + clean 32-cycle unsigned divider core
// Verilog-2001
//
// External enable semantics match the existing level-enable style:
//   - enable = 1 starts/keeps one request alive until done.
//   - enable = 0 cancels/clears the active request and rearms the wrapper.
//   - after done, the wrapper will not auto-restart while enable remains high.
//
// ALU integration recommendation:
//   - Decode RV32M divide instructions into div_op below.
//   - Use result[31:0] directly as the writeback value.
//   - quotient/remainder are exposed for debug/compatibility.
// -----------------------------------------------------------------------------

module rv32m_div_unit (
    input  wire        clk,
    input  wire        reset,      // synchronous reset
    input  wire        enable,     // level enable; keep high until done, low cancels/rearms
    input  wire [1:0]  div_op,     // 00: DIV, 01: DIVU, 10: REM, 11: REMU
    input  wire [31:0] opA,        // dividend / rs1
    input  wire [31:0] opB,        // divisor  / rs2
    output reg         done,       // one-cycle pulse when result is updated
    output reg  [31:0] result,     // final RV32M writeback result
    output reg  [31:0] quotient,   // full quotient for debug/compatibility
    output reg  [31:0] remainder   // full remainder for debug/compatibility
);

    localparam DIV_OP_DIV  = 2'b00;
    localparam DIV_OP_DIVU = 2'b01;
    localparam DIV_OP_REM  = 2'b10;
    localparam DIV_OP_REMU = 2'b11;

    // Current request semantic preprocessing.
    reg        req_signed_c;
    reg        req_want_rem_c;
    reg [31:0] req_A_mag_c;
    reg [31:0] req_B_mag_c;
    reg        req_q_negative_c;
    reg        req_r_negative_c;
    reg        req_div_by_zero_c;
    reg        req_overflow_c;
    reg [31:0] req_special_q_c;
    reg [31:0] req_special_r_c;
    reg [31:0] req_special_result_c;
    reg        req_special_c;

    // Latched request information for a normal core execution.
    reg [31:0] active_rawA;
    reg [31:0] active_rawB;
    reg        active_signed;
    reg        active_want_rem;
    reg        active_q_negative;
    reg        active_r_negative;

    // Last-result history.  Kept across enable-low idle gaps to accelerate
    // canonical DIV/REM and DIVU/REMU pairs with the same operands.
    reg        hist_valid;
    reg [31:0] hist_rawA;
    reg [31:0] hist_rawB;
    reg        hist_signed;
    reg [31:0] hist_quotient;
    reg [31:0] hist_remainder;

    wire same_operands;
    wire hist_hit;
    wire [31:0] hist_result;

    // Clean unsigned divider core.
    wire        core_reset;
    wire        core_start;
    wire        core_busy;
    wire        core_done;
    wire [31:0] core_quotient_unsigned;
    wire [31:0] core_remainder_unsigned;

    reg         completed;

    wire [31:0] final_quotient;
    wire [31:0] final_remainder;
    wire [31:0] final_result;

    assign same_operands = hist_valid &&
                           (opA == hist_rawA) &&
                           (opB == hist_rawB);

    // Signed and unsigned division generally produce different quotient and
    // remainder, so history only crosses requests with the same signedness.
    assign hist_hit = same_operands && (hist_signed == req_signed_c);

    assign hist_result = req_want_rem_c ? hist_remainder : hist_quotient;

    // Reset the core when the wrapper is disabled/cancelled.  History is not
    // cleared by enable=0; only reset clears history.
    assign core_reset = reset || !enable;

    assign core_start = enable && !done && !completed && !core_busy && !core_done &&
                        !req_special_c && !hist_hit;

    divider_32c_core u_div_core (
        .clk      (clk),
        .reset    (core_reset),
        .start    (core_start),
        .dividend (req_A_mag_c),
        .divisor  (req_B_mag_c),
        .busy     (core_busy),
        .done     (core_done),
        .quotient (core_quotient_unsigned),
        .remainder(core_remainder_unsigned)
    );

    assign final_quotient  = active_q_negative ? (~core_quotient_unsigned + 32'd1) :
                                                 core_quotient_unsigned;
    assign final_remainder = active_r_negative ? (~core_remainder_unsigned + 32'd1) :
                                                 core_remainder_unsigned;
    assign final_result    = active_want_rem ? final_remainder : final_quotient;

    // ------------------------------------------------------------
    // RV32M semantic preprocessing
    // ------------------------------------------------------------
    always @(*) begin
        req_signed_c         = (div_op == DIV_OP_DIV) || (div_op == DIV_OP_REM);
        req_want_rem_c       = (div_op == DIV_OP_REM) || (div_op == DIV_OP_REMU);
        req_div_by_zero_c    = (opB == 32'd0);
        req_overflow_c       = req_signed_c &&
                               (opA == 32'h8000_0000) &&
                               (opB == 32'hFFFF_FFFF);

        req_A_mag_c          = opA;
        req_B_mag_c          = opB;
        req_q_negative_c     = 1'b0;
        req_r_negative_c     = 1'b0;
        req_special_q_c      = 32'd0;
        req_special_r_c      = 32'd0;
        req_special_result_c = 32'd0;
        req_special_c        = req_div_by_zero_c || req_overflow_c;

        if (req_signed_c) begin
            req_A_mag_c      = opA[31] ? (~opA + 32'd1) : opA;
            req_B_mag_c      = opB[31] ? (~opB + 32'd1) : opB;
            req_q_negative_c = opA[31] ^ opB[31];
            // RISC-V REM has the same sign as the dividend rs1.
            req_r_negative_c = opA[31];
        end

        if (req_div_by_zero_c) begin
            req_special_q_c      = 32'hFFFF_FFFF;
            req_special_r_c      = opA;
            req_special_result_c = req_want_rem_c ? opA : 32'hFFFF_FFFF;
        end else if (req_overflow_c) begin
            // Only signed minint / -1 overflows in RV32.
            req_special_q_c      = 32'h8000_0000;
            req_special_r_c      = 32'h0000_0000;
            req_special_result_c = req_want_rem_c ? 32'h0000_0000 : 32'h8000_0000;
        end
    end

    // ------------------------------------------------------------
    // Wrapper control, special cases, and history short-circuit
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            done              <= 1'b0;
            result            <= 32'd0;
            quotient          <= 32'd0;
            remainder         <= 32'd0;
            completed         <= 1'b0;
            active_rawA       <= 32'd0;
            active_rawB       <= 32'd0;
            active_signed     <= 1'b0;
            active_want_rem   <= 1'b0;
            active_q_negative <= 1'b0;
            active_r_negative <= 1'b0;
            hist_valid        <= 1'b0;
            hist_rawA         <= 32'd0;
            hist_rawB         <= 32'd0;
            hist_signed       <= 1'b0;
            hist_quotient     <= 32'd0;
            hist_remainder    <= 32'd0;
        end else if (!enable) begin
            // Cancel/rearm the active request.  Keep history for later hits.
            done              <= 1'b0;
            result            <= 32'd0;
            quotient          <= 32'd0;
            remainder         <= 32'd0;
            completed         <= 1'b0;
            active_rawA       <= 32'd0;
            active_rawB       <= 32'd0;
            active_signed     <= 1'b0;
            active_want_rem   <= 1'b0;
            active_q_negative <= 1'b0;
            active_r_negative <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!completed && req_special_c) begin
                // Divide-by-zero and signed-overflow complete immediately.
                result         <= req_special_result_c;
                quotient       <= req_special_q_c;
                remainder      <= req_special_r_c;
                done           <= 1'b1;
                completed      <= 1'b1;

                hist_valid     <= 1'b1;
                hist_rawA      <= opA;
                hist_rawB      <= opB;
                hist_signed    <= req_signed_c;
                hist_quotient  <= req_special_q_c;
                hist_remainder <= req_special_r_c;
            end else if (!completed && hist_hit) begin
                // Short-circuit from the previous quotient/remainder pair.
                result    <= hist_result;
                quotient  <= hist_quotient;
                remainder <= hist_remainder;
                done      <= 1'b1;
                completed <= 1'b1;
            end else if (core_start) begin
                // The core samples req_A_mag_c/req_B_mag_c on this same clock.
                active_rawA       <= opA;
                active_rawB       <= opB;
                active_signed     <= req_signed_c;
                active_want_rem   <= req_want_rem_c;
                active_q_negative <= req_q_negative_c;
                active_r_negative <= req_r_negative_c;
            end else if (core_done) begin
                result         <= final_result;
                quotient       <= final_quotient;
                remainder      <= final_remainder;
                done           <= 1'b1;
                completed      <= 1'b1;

                hist_valid     <= 1'b1;
                hist_rawA      <= active_rawA;
                hist_rawB      <= active_rawB;
                hist_signed    <= active_signed;
                hist_quotient  <= final_quotient;
                hist_remainder <= final_remainder;
            end
        end
    end

endmodule


// -----------------------------------------------------------------------------
// Clean 32-cycle unsigned restoring divider core
//
// This module has no RV32M signedness, quotient/remainder selection, special
// case handling, history cache, or ALU-facing behavior.  It only computes:
//
//     quotient  = dividend / divisor
//     remainder = dividend % divisor
//
// start is a one-cycle pulse.  It is accepted only when busy is 0.
// done is a one-cycle pulse when quotient/remainder are updated.
// divisor must be nonzero; divide-by-zero is handled by rv32m_div_unit.
// -----------------------------------------------------------------------------
module divider_32c_core (
    input  wire        clk,
    input  wire        reset,      // synchronous reset
    input  wire        start,      // one-cycle start pulse, ignored while busy
    input  wire [31:0] dividend,
    input  wire [31:0] divisor,
    output reg         busy,
    output reg         done,
    output reg  [31:0] quotient,
    output reg  [31:0] remainder
);

    reg [31:0] dividend_shift;
    reg [31:0] divisor_reg;
    reg [31:0] quotient_shift;
    reg [32:0] rem_reg;
    reg  [5:0] count;

    wire [32:0] rem_shift;
    wire [32:0] trial;
    wire        trial_ok;
    wire [32:0] next_rem;
    wire [31:0] next_quotient;
    wire [31:0] next_dividend;

    assign rem_shift     = {rem_reg[31:0], dividend_shift[31]};
    assign trial         = rem_shift - {1'b0, divisor_reg};
    assign trial_ok      = ~trial[32];
    assign next_rem      = trial_ok ? trial : rem_shift;
    assign next_quotient = {quotient_shift[30:0], trial_ok};
    assign next_dividend = {dividend_shift[30:0], 1'b0};

    always @(posedge clk) begin
        if (reset) begin
            dividend_shift <= 32'd0;
            divisor_reg    <= 32'd0;
            quotient_shift <= 32'd0;
            rem_reg        <= 33'd0;
            count          <= 6'd0;
            busy           <= 1'b0;
            done           <= 1'b0;
            quotient       <= 32'd0;
            remainder      <= 32'd0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                dividend_shift <= dividend;
                divisor_reg    <= divisor;
                quotient_shift <= 32'd0;
                rem_reg        <= 33'd0;
                count          <= 6'd32;
                busy           <= 1'b1;
            end else if (busy) begin
                dividend_shift <= next_dividend;
                quotient_shift <= next_quotient;
                rem_reg        <= next_rem;
                count          <= count - 6'd1;

                if (count == 6'd1) begin
                    busy      <= 1'b0;
                    done      <= 1'b1;
                    quotient  <= next_quotient;
                    remainder <= next_rem[31:0];
                    count     <= 6'd0;
                end
            end
        end
    end

endmodule
