// -----------------------------------------------------------------------------
// RV32M multiplier wrapper + clean 16-cycle unsigned multiplier core
// Verilog-2001
//
// External enable semantics are preserved as a level enable:
//   - enable = 1 starts/keeps one request alive until done.
//   - enable = 0 cancels/clears the active request and rearms the wrapper.
//   - after done, the wrapper will not auto-restart while enable remains high.
//
// ALU integration recommendation:
//   - Decode RV32M multiply instructions into mul_op below.
//   - Use result[31:0] directly as the writeback value.
//   - product[63:0] is exposed for debug/compatibility, but the ALU no longer
//     needs to choose high/low bits itself.
// -----------------------------------------------------------------------------

module rv32m_mul_unit (
    input  wire        clk,
    input  wire        reset,     // synchronous reset
    input  wire        enable,    // level enable; keep high until done, low cancels/rearms
    input  wire [1:0]  mul_op,    // 00: MUL, 01: MULH, 10: MULHSU, 11: MULHU
    input  wire [31:0] opA,
    input  wire [31:0] opB,
    output reg         done,      // one-cycle pulse when result/product are updated
    output reg  [31:0] result,    // final RV32M writeback result
    output reg  [63:0] product    // full product for debug/compatibility
);

    localparam MUL_OP_MUL    = 2'b00;
    localparam MUL_OP_MULH   = 2'b01;
    localparam MUL_OP_MULHSU = 2'b10;
    localparam MUL_OP_MULHU  = 2'b11;

    localparam SIGN_UU = 2'b00; // unsigned * unsigned
    localparam SIGN_SS = 2'b01; // signed   * signed
    localparam SIGN_SU = 2'b10; // signed   * unsigned

    // Current request preprocessing.
    reg [31:0] req_A_mag_c;
    reg [31:0] req_B_mag_c;
    reg        req_negative_c;
    reg [1:0]  req_sign_mode_c;
    reg        req_is_low_c;

    // Latched request information for a normal core execution.
    reg [31:0] active_rawA;
    reg [31:0] active_rawB;
    reg        active_is_low;
    reg        active_negative;
    reg [1:0]  active_sign_mode;

    // Last-result history.  It is kept across enable-low idle gaps so the
    // canonical MULH/MULHU/MULHSU followed by MUL sequence can short-circuit.
    reg        hist_valid;
    reg [31:0] hist_rawA;
    reg [31:0] hist_rawB;
    reg [1:0]  hist_sign_mode;
    reg [63:0] hist_product;

    wire same_operands;
    wire hist_hit;
    wire [31:0] hist_result;

    // Clean unsigned multiplier core.
    wire        core_reset;
    wire        core_start;
    wire        core_busy;
    wire        core_done;
    wire [63:0] core_product_unsigned;

    reg         completed;

    wire [63:0] final_product;
    wire [31:0] final_result;

    assign same_operands = hist_valid &&
                           (opA == hist_rawA) &&
                           (opB == hist_rawB);

    // MUL only needs the low 32 bits, which are independent of signedness.
    // High-result ops need matching full-product signedness semantics.
    assign hist_hit = same_operands &&
                      (req_is_low_c || (hist_sign_mode == req_sign_mode_c));

    assign hist_result = req_is_low_c ? hist_product[31:0] : hist_product[63:32];

    // Reset the core when the wrapper is disabled/cancelled.  History is not
    // cleared by enable=0; only reset clears history.
    assign core_reset = reset || !enable;

    // Start a normal multiplication only when there is no cached answer and
    // the core has no pending done pulse waiting for the wrapper to consume.
    assign core_start = enable && !done && !core_busy && !core_done &&
                        !hist_hit && !completed;

    multiplier_16c_core u_mul_core (
        .clk        (clk),
        .reset      (core_reset),
        .start      (core_start),
        .multiplicand(req_A_mag_c),
        .multiplier (req_B_mag_c),
        .busy       (core_busy),
        .done       (core_done),
        .product    (core_product_unsigned)
    );

    assign final_product = active_negative ? (~core_product_unsigned + 64'd1) :
                                             core_product_unsigned;
    assign final_result  = active_is_low ? final_product[31:0] : final_product[63:32];

    // ------------------------------------------------------------
    // RV32M semantic preprocessing
    // ------------------------------------------------------------
    always @(*) begin
        req_A_mag_c     = opA;
        req_B_mag_c     = opB;
        req_negative_c  = 1'b0;
        req_sign_mode_c = SIGN_UU;
        req_is_low_c    = 1'b0;

        case (mul_op)
            MUL_OP_MUL: begin
                // MUL returns the low 32 bits.  Signedness does not matter for
                // the low half, so use unsigned operands for the core.
                req_A_mag_c     = opA;
                req_B_mag_c     = opB;
                req_negative_c  = 1'b0;
                req_sign_mode_c = SIGN_UU;
                req_is_low_c    = 1'b1;
            end

            MUL_OP_MULH: begin
                req_A_mag_c     = opA[31] ? (~opA + 32'd1) : opA;
                req_B_mag_c     = opB[31] ? (~opB + 32'd1) : opB;
                req_negative_c  = opA[31] ^ opB[31];
                req_sign_mode_c = SIGN_SS;
                req_is_low_c    = 1'b0;
            end

            MUL_OP_MULHSU: begin
                req_A_mag_c     = opA[31] ? (~opA + 32'd1) : opA;
                req_B_mag_c     = opB;
                req_negative_c  = opA[31];
                req_sign_mode_c = SIGN_SU;
                req_is_low_c    = 1'b0;
            end

            MUL_OP_MULHU: begin
                req_A_mag_c     = opA;
                req_B_mag_c     = opB;
                req_negative_c  = 1'b0;
                req_sign_mode_c = SIGN_UU;
                req_is_low_c    = 1'b0;
            end

            default: begin
                req_A_mag_c     = opA;
                req_B_mag_c     = opB;
                req_negative_c  = 1'b0;
                req_sign_mode_c = SIGN_UU;
                req_is_low_c    = 1'b1;
            end
        endcase
    end

    // ------------------------------------------------------------
    // Wrapper control and history short-circuit
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            done             <= 1'b0;
            result           <= 32'd0;
            product          <= 64'd0;
            completed        <= 1'b0;
            active_rawA      <= 32'd0;
            active_rawB      <= 32'd0;
            active_is_low    <= 1'b0;
            active_negative  <= 1'b0;
            active_sign_mode <= SIGN_UU;
            hist_valid       <= 1'b0;
            hist_rawA        <= 32'd0;
            hist_rawB        <= 32'd0;
            hist_sign_mode   <= SIGN_UU;
            hist_product     <= 64'd0;
        end else if (!enable) begin
            // Cancel/rearm the active request.  Keep history for later hits.
            done             <= 1'b0;
            result           <= 32'd0;
            product          <= 64'd0;
            completed        <= 1'b0;
            active_rawA      <= 32'd0;
            active_rawB      <= 32'd0;
            active_is_low    <= 1'b0;
            active_negative  <= 1'b0;
            active_sign_mode <= SIGN_UU;
        end else begin
            done <= 1'b0;

            if (!completed && hist_hit) begin
                // Short-circuit from the previous full product.
                result    <= hist_result;
                product   <= hist_product;
                done      <= 1'b1;
                completed <= 1'b1;
            end else if (core_start) begin
                // The core samples req_A_mag_c/req_B_mag_c on this same clock.
                active_rawA      <= opA;
                active_rawB      <= opB;
                active_is_low    <= req_is_low_c;
                active_negative  <= req_negative_c;
                active_sign_mode <= req_sign_mode_c;
            end else if (core_done) begin
                result        <= final_result;
                product       <= final_product;
                done          <= 1'b1;
                completed     <= 1'b1;

                hist_valid     <= 1'b1;
                hist_rawA      <= active_rawA;
                hist_rawB      <= active_rawB;
                hist_sign_mode <= active_sign_mode;
                hist_product   <= final_product;
            end
        end
    end

endmodule


