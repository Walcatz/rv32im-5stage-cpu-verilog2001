// -----------------------------------------------------------------------------
// Clean 16-cycle unsigned radix-4 restoring divider core
// Verilog-2001
//
// This module has no RV32M signedness, quotient/remainder selection, special
// case handling, history cache, or ALU-facing behavior.  It only computes:
//
//     quotient  = dividend / divisor
//     remainder = dividend % divisor
//
// Algorithm:
//   - radix-4 restoring division
//   - each cycle consumes 2 dividend bits and emits 2 quotient bits
//   - 32-bit division completes in 16 busy cycles
//
// start is a one-cycle pulse.  It is accepted only when busy is 0.
// done is a one-cycle pulse when quotient/remainder are updated.
// divisor must be nonzero; divide-by-zero is handled by rv32m_div_unit.
// -----------------------------------------------------------------------------
module divider_16c_core (
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
    reg [33:0] rem_reg;
    reg  [4:0] count;

    wire [33:0] rem_shift;
    wire [33:0] divisor_x1;
    wire [33:0] divisor_x2;
    wire [33:0] divisor_x3;

    reg  [1:0]  q_digit;
    reg  [33:0] rem_next_c;

    wire [31:0] next_quotient;
    wire [31:0] next_dividend;

    // Bring down the next two dividend bits.
    assign rem_shift = {rem_reg[31:0], dividend_shift[31:30]};

    // 34-bit divisor multiples.  3 * (2^32 - 1) fits in 34 bits.
    assign divisor_x1 = {2'b00, divisor_reg};
    assign divisor_x2 = {1'b0, divisor_reg, 1'b0};
    assign divisor_x3 = divisor_x2 + divisor_x1;

    assign next_quotient = {quotient_shift[29:0], q_digit};
    assign next_dividend = {dividend_shift[29:0], 2'b00};

    always @(*) begin
        if (rem_shift >= divisor_x3) begin
            q_digit    = 2'b11;
            rem_next_c = rem_shift - divisor_x3;
        end else if (rem_shift >= divisor_x2) begin
            q_digit    = 2'b10;
            rem_next_c = rem_shift - divisor_x2;
        end else if (rem_shift >= divisor_x1) begin
            q_digit    = 2'b01;
            rem_next_c = rem_shift - divisor_x1;
        end else begin
            q_digit    = 2'b00;
            rem_next_c = rem_shift;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            dividend_shift <= 32'd0;
            divisor_reg    <= 32'd0;
            quotient_shift <= 32'd0;
            rem_reg        <= 34'd0;
            count          <= 5'd0;
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
                rem_reg        <= 34'd0;
                count          <= 5'd16;
                busy           <= 1'b1;
            end else if (busy) begin
                dividend_shift <= next_dividend;
                quotient_shift <= next_quotient;
                rem_reg        <= rem_next_c;
                count          <= count - 5'd1;

                if (count == 5'd1) begin
                    busy      <= 1'b0;
                    done      <= 1'b1;
                    quotient  <= next_quotient;
                    remainder <= rem_next_c[31:0];
                    count     <= 5'd0;
                end
            end
        end
    end

endmodule
