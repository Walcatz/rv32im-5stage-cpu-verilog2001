module multiplier_16c_core (
    input  wire        clk,
    input  wire        reset,       // synchronous reset
    input  wire        start,       // one-cycle start pulse, ignored while busy
    input  wire [31:0] multiplicand,
    input  wire [31:0] multiplier,
    output reg         busy,
    output reg         done,
    output reg  [63:0] product
);

    reg [33:0] ACC;   // 34-bit accumulator, enough for ACC + 3*M
    reg [31:0] Q;     // multiplier / lower product bits
    reg [31:0] M;     // multiplicand
    reg  [4:0] count; // 16 radix-4 steps

    reg [33:0] m_ext;
    reg [33:0] addend;
    reg [33:0] sum34;
    reg [65:0] ptmp;
    reg [65:0] pshift;

    always @(*) begin
        m_ext = {2'b00, M};
        case (Q[1:0])
            2'b00: addend = 34'd0;
            2'b01: addend = m_ext;
            2'b10: addend = m_ext << 1;
            2'b11: addend = m_ext + (m_ext << 1);
            default: addend = 34'd0;
        endcase

        sum34  = ACC + addend;
        ptmp   = {sum34, Q};
        pshift = ptmp >> 2;
    end

    always @(posedge clk) begin
        if (reset) begin
            ACC     <= 34'd0;
            Q       <= 32'd0;
            M       <= 32'd0;
            count   <= 5'd0;
            busy    <= 1'b0;
            done    <= 1'b0;
            product <= 64'd0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                ACC   <= 34'd0;
                Q     <= multiplier;
                M     <= multiplicand;
                count <= 5'd16;
                busy  <= 1'b1;
            end else if (busy) begin
                {ACC, Q} <= pshift;
                count    <= count - 5'd1;

                if (count == 5'd1) begin
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    product <= pshift[63:0];
                end
            end
        end
    end

endmodule
