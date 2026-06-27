module divider_32c (
    input  wire        clk,
    input  wire        reset,       // active-high synchronous reset behavior in this module
    input  wire        enable,      // level-enable (toggle) — must be held high for duration
    input  wire        sign_sel,    // Sign Selection
    input  wire [31:0] numA,        // dividend
    input  wire [31:0] denB,        // divisor
    output reg         done,        // one-cycle pulse when quotient/remainder valid
    output reg  [31:0] quotient,
    output reg  [31:0] remainder
);

    // Internal registers (Changed logic to reg since they are assigned inside always blocks)
    reg [31:0] dividend_reg;
    reg [31:0] divisor_reg;
    reg [32:0] rem;            // 33-bit remainder
    reg [31:0] q_reg;
    reg  [5:0] count;
    reg        busy;
    reg        div_by_zero;     // flag

    reg [31:0] numA_reg, newA, newB;
    reg [31:0] u_quotient, u_remainder;
    reg        sign;

    // Combinational Sign Pre/Post-processing
    always @(*) begin
        case(sign_sel)
            // div,rem
            1'b0 : begin
                newA = numA[31] ? ~numA + 1'b1 : numA;
                newB = denB[31] ? ~denB + 1'b1 : denB;
                sign = numA[31] ^ denB[31];
            end
            // divu,remu
            1'b1 : begin
                newA = numA;
                newB = denB;
                sign = 1'b0;
            end
            // signed/signed by default
            default : begin
                newA = numA[31] ? ~numA + 1'b1 : numA;
                newB = denB[31] ? ~denB + 1'b1 : denB;
                sign = numA[31] ^ denB[31];
            end
        endcase

        quotient  = div_by_zero ? 32'hFFFFFFFF        :
                           sign ? ~u_quotient  + 1'b1 :
                                   u_quotient;

        remainder = div_by_zero ? numA_reg            :
                           sign ? ~u_remainder + 1'b1 :
                                   u_remainder;
    end

    // Combinational trial subtraction (Changed to wire/assign for Verilog-2001)
    wire [32:0] trial;
    assign trial = { rem[31:0], dividend_reg[31] } - { 1'b0, divisor_reg };

    // Sequential state machine
    always @(posedge clk) begin
        if (reset) begin
            numA_reg     <= 32'b0;
            dividend_reg <= 32'b0;
            divisor_reg  <= 32'b0;
            rem          <= 33'b0;
            q_reg        <= 32'b0;
            u_quotient   <= 32'b0;
            u_remainder  <= 32'b0;
            count        <= 6'b0;
            busy         <= 1'b0;
            done         <= 1'b0;
            div_by_zero  <= 1'b0;
        end else begin
            // Start new division if enable and idle
            if (enable && !busy && !done) begin
                numA_reg     <= numA;
                dividend_reg <= newA;
                divisor_reg  <= newB;
                q_reg        <= 32'b0;
                rem          <= 33'b0;
                count        <= 6'd32;
                busy         <= 1'b1;
                done         <= 1'b0;
                // check divide-by-zero
                div_by_zero  <= (denB == 32'b0);
            end else if (busy) begin
                if (div_by_zero) begin
                    busy      <= 1'b0;
                    done      <= 1'b1;
                    count     <= 6'd0;
                end else begin
                    // normal iterative division
                    if (!trial[32]) begin
                        if (count == 6'd1) begin
                            u_quotient   <= { q_reg[30:0], 1'b1 };
                            u_remainder  <= trial[31:0];
                            rem          <= trial;
                            q_reg        <= { q_reg[30:0], 1'b1 };
                            dividend_reg <= { dividend_reg[30:0], 1'b0 };
                            busy         <= 1'b0;
                            done         <= 1'b1;
                            count        <= 6'd0;
                        end else begin
                            rem          <= trial;
                            q_reg        <= { q_reg[30:0], 1'b1 };
                            dividend_reg <= { dividend_reg[30:0], 1'b0 };
                            count        <= count - 6'd1;
                        end
                    end else begin
                        if (count == 6'd1) begin
                            u_quotient   <= { q_reg[30:0], 1'b0 };
                            u_remainder  <= { rem[31:0], dividend_reg[31] };
                            rem          <= { rem[31:0], dividend_reg[31] };
                            q_reg        <= { q_reg[30:0], 1'b0 };
                            dividend_reg <= { dividend_reg[30:0], 1'b0 };
                            busy         <= 1'b0;
                            done         <= 1'b1;
                            count        <= 6'd0;
                        end else begin
                            rem          <= { rem[31:0], dividend_reg[31] };
                            q_reg        <= { q_reg[30:0], 1'b0 };
                            dividend_reg <= { dividend_reg[30:0], 1'b0 };
                            count        <= count - 6'd1;
                        end
                    end
                end
            end else begin
                done <= 1'b0; // idle
            end
        end
    end

endmodule