module multiplier_16c (
    input  wire        clk,
    input  wire        reset,     // synchronous reset
    input  wire        enable,    // start when high and unit idle (pulse is fine)
    input  wire [1:0]  sign_sel,  // Sign Selection
    input  wire [31:0] opA,       // multiplicand
    input  wire [31:0] opB,       // multiplier
    output reg         done,      // one-cycle pulse when result valid
    output reg  [63:0] product
);

    // State (Changed to reg because they are assigned inside always blocks)
    reg [31:0] ACC;       // accumulator
    reg [31:0] Q;         // multiplier
    reg  [1:0] C;         // top carry bits
    reg [31:0] M;         // multiplicand
    reg  [4:0] count;
    reg        busy;

    // Combinational signals (Changed to reg for always @(*))
    reg [33:0] acc_ext;   // ACC extended
    reg [33:0] m_ext;     // M extended
    reg [33:0] addend;
    reg [33:0] sum34;
    reg  [1:0] q_low;
    reg [65:0] Ptmp;
    reg [65:0] Pshift;

    reg [31:0] newA, newB;
    reg        sign;
    reg [63:0] result;

    // ------------------------------------------------------------
    // Signed Pre-processing and Post-processing
    // ------------------------------------------------------------
    always @(*) begin
        case(sign_sel)
            // mul,mulh
            2'b00 : begin
                newA = opA[31] ? ~opA + 1'b1 : opA;
                newB = opB[31] ? ~opB + 1'b1 : opB;
                sign = opA[31] ^ opB[31];
            end
            // mulhsu
            2'b01 : begin
                newA = opA[31] ? ~opA + 1'b1 : opA;
                newB = opB;
                sign = opA[31];
            end
            // mulhu
            2'b10 : begin
                newA = opA;
                newB = opB;
                sign = 1'b0;
            end
            // signed/signed by default
            default : begin
                newA = opA[31] ? ~opA + 1'b1 : opA;
                newB = opB[31] ? ~opB + 1'b1 : opB;
                sign = opA[31] ^ opB[31];
            end
        endcase

        product = sign ? ~result + 1'b1 : result;
    end

    // ------------------------------------------------------------
    // Combinational datapath
    // ------------------------------------------------------------
    always @(*) begin
        // Extend ACC and M to 34 bits
        acc_ext = {2'b00, ACC};
        m_ext   = {2'b00, M};

        // Extract Q[1:0]
        q_low = { Q[1], Q[0] };

        // Radix-4 selection
        case (q_low)
            2'b00: addend = 34'd0;
            2'b01: addend = m_ext;
            2'b10: addend = m_ext << 1;
            2'b11: addend = m_ext + (m_ext << 1);
            default: addend = 34'd0;
        endcase

        sum34 = acc_ext + addend;

        // Build 66-bit Ptmp = {C, sum34, Q}
        Ptmp = { C, sum34, Q };

        // Shift right by 2
        Pshift = Ptmp >> 2;
    end

    // ------------------------------------------------------------
    // Sequential state machine
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (reset | !enable) begin
            ACC    <= 32'd0;
            Q      <= 32'd0;
            C      <= 2'b00;
            M      <= 32'd0;
            count  <= 5'd0;
            busy   <= 1'b0;
            done   <= 1'b0;
            result <= 64'd0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                if (enable) begin
                    // Start multiplication
                    M      <= newA;
                    ACC    <= 32'd0;
                    Q      <= newB;
                    C      <= 2'b00;
                    count  <= 5'd16;
                    busy   <= 1'b1;
                end
            end
            else begin
                // Update state after shift
                {C, ACC, Q} <= Pshift;

                count <= count - 5'd1;

                if (count == 5'd1) begin
                    busy   <= 1'b0;
                    done   <= 1'b1;
                    result <= Pshift[63:0];
                end
            end
        end
    end

endmodule