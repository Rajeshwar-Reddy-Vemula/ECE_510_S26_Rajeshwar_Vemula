// mac_correct.v
// Derived from RTL coding guidelines in:
// Sutherland, S. "RTL Modeling with SystemVerilog for Simulation and Synthesis"
// ISBN 978-1-5467-7634-5, Chapter 3 (Sequential Logic Modeling)
//
// Key rules applied (from Sutherland §3.x):
// 1. Use always_ff for sequential logic — never plain always
// 2. Use only non-blocking assignments (<=) inside always_ff
// 3. Explicit type casting for mixed-width signed arithmetic
// 4. No initial blocks, no $display, no delays in synthesizable RTL

module mac (
    input  logic                clk,
    input  logic                rst,
    input  logic signed [7:0]   a,
    input  logic signed [7:0]   b,
    output logic signed [31:0]  out
);

    // Intermediate signal: 16-bit signed product
    // Declared outside always_ff so width is explicit to synthesiser
    // Per Sutherland §3.4: intermediate values should have explicit widths
    logic signed [15:0] product;

    // Combinational product — always_comb per Sutherland
    always_comb begin
        product = a * b;  // 8-bit signed × 8-bit signed = 16-bit signed
    end

    // Sequential accumulator — always_ff per Sutherland
    // Non-blocking assignment only
    // Sign extension: $signed() preserves sign through width extension
    always_ff @(posedge clk) begin
        if (rst) begin
            out <= 32'sd0;
        end else begin
            out <= out + $signed({{16{product[15]}}, product});
        end
    end

endmodule
