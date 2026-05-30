// 4x4 binary-weight crossbar MAC unit
// out[j] = sum_i ( weight[i][j] ? +in[i] : -in[i] )
// weights: 1 bit per cell. 1 => +1, 0 => -1.

module crossbar_mac #(
    parameter int N         = 4,
    parameter int IN_WIDTH  = 8,
    // Output must hold N * max(|in|). For 8-bit signed (-128..127) and N=4:
    // worst case |sum| = 4*128 = 512 -> 11 bits signed covers it.
    parameter int OUT_WIDTH = IN_WIDTH + $clog2(N) + 1
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          load_w,            // pulse high to latch weights
    input  logic                          weight_in [N][N],  // weight_in[i][j], 1=+1, 0=-1
    input  logic signed [IN_WIDTH-1:0]    in_vec    [N],     // N signed inputs
    output logic signed [OUT_WIDTH-1:0]   out_vec   [N]      // N signed outputs
);

    // Weight register array
    logic weights [N][N];

    // Latch weights on load_w
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++)
                    weights[i][j] <= 1'b0;
        end
        else if (load_w) begin
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++)
                    weights[i][j] <= weight_in[i][j];
        end
    end

    // Combinational MAC
    logic signed [OUT_WIDTH-1:0] acc [N];

    always_comb begin
        for (int j = 0; j < N; j++) begin
            acc[j] = '0;
            for (int i = 0; i < N; i++) begin
                if (weights[i][j])
                    acc[j] = acc[j] + OUT_WIDTH'(in_vec[i]); // +1 * in[i]
                else
                    acc[j] = acc[j] - OUT_WIDTH'(in_vec[i]); // -1 * in[i]
            end
        end
    end

    // Registered output
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int j = 0; j < N; j++) out_vec[j] <= '0;
        end
        else begin
            for (int j = 0; j < N; j++) out_vec[j] <= acc[j];
        end
    end

endmodule
