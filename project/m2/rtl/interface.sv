`timescale 1ns/1ps

module interface_top (
    input  logic        clk,
    input  logic        rst,

    // AXI4-Lite Slave (Object Config)
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // AXI4-Stream Slave (Ray D Input)
    input  logic [63:0] s_axis_tdata,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,

    // AXI4-Stream Master (Hit Output)
    output logic [63:0] m_axis_tdata,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready
);

    logic signed [15:0] reg_ray_ox, reg_ray_oy, reg_ray_oz;
    logic signed [15:0] reg_sph_cx, reg_sph_cy, reg_sph_cz;
    logic signed [15:0] reg_sph_r;
    
    logic        reg_busy;
    logic        stream_start;
    logic        core_done;
    logic        core_hit_valid;
    logic signed [15:0] core_hit_distance;
    
    // Output holding registers
    logic        out_valid_reg;
    logic [15:0] out_dist_reg;

    compute_core u_core (
        .clk         (clk),          
        .rst         (rst),
        .start       (stream_start),
        .ray_ox      (reg_ray_ox),   
        .ray_oy      (reg_ray_oy),
        .ray_oz      (reg_ray_oz),   
        .ray_dx      (s_axis_tdata[15:0]),   // DX from stream
        .ray_dy      (s_axis_tdata[31:16]),  // DY from stream
        .ray_dz      (s_axis_tdata[47:32]),  // DZ from stream
        .sph_cx      (reg_sph_cx),   
        .sph_cy      (reg_sph_cy),
        .sph_cz      (reg_sph_cz),   
        .sph_r       (reg_sph_r),
        .hit_distance(core_hit_distance),
        .hit_valid   (core_hit_valid),
        .done        (core_done)
    );

    // -----------------------------------------------------------------------
    // AXI-Stream Control
    // -----------------------------------------------------------------------
    assign s_axis_tready = ~reg_busy;
    assign stream_start  = s_axis_tvalid && s_axis_tready;
    assign m_axis_tdata  = {48'h0, out_dist_reg};
    assign m_axis_tvalid = out_valid_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            reg_busy      <= 1'b0;
            out_valid_reg <= 1'b0;
            out_dist_reg  <= 16'h0;
        end else begin
            // Lock input bus while computing
            if (stream_start) reg_busy <= 1'b1;
            else if (core_done) reg_busy <= 1'b0;

            // Hold output data until accepted by master
            if (core_done) begin
                out_valid_reg <= 1'b1;
                out_dist_reg  <= core_hit_distance;
            end else if (m_axis_tready && out_valid_reg) begin
                out_valid_reg <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------------------------
    // AXI4-Lite Write Channel
    // -----------------------------------------------------------------------
    logic        aw_done;
    logic        w_done;
    logic [31:0] aw_addr;
    logic [31:0] w_data;

    always_ff @(posedge clk) begin
        if (rst) begin
            s_axi_awready <= 1'b1;
            s_axi_wready  <= 1'b1;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            aw_done       <= 1'b0;
            w_done        <= 1'b0;
            reg_ray_ox    <= '0; reg_ray_oy <= '0; reg_ray_oz <= '0;
            reg_sph_cx    <= '0; reg_sph_cy <= '0; reg_sph_cz <= '0;
            reg_sph_r     <= '0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                aw_addr       <= s_axi_awaddr;
                aw_done       <= 1'b1;
                s_axi_awready <= 1'b0;
            end

            if (s_axi_wvalid && s_axi_wready) begin
                w_data        <= s_axi_wdata;
                w_done        <= 1'b1;
                s_axi_wready  <= 1'b0;
            end

            if (aw_done && w_done && !s_axi_bvalid) begin
                case (aw_addr[7:0])
                    8'h04: reg_ray_ox <= w_data[15:0];
                    8'h08: reg_ray_oy <= w_data[15:0];
                    8'h0C: reg_ray_oz <= w_data[15:0];
                    8'h1C: reg_sph_cx <= w_data[15:0];
                    8'h20: reg_sph_cy <= w_data[15:0];
                    8'h24: reg_sph_cz <= w_data[15:0];
                    8'h28: reg_sph_r  <= w_data[15:0];
                    default: ;
                endcase
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
                aw_done      <= 1'b0;
                w_done       <= 1'b0;
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid  <= 1'b0;
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
            end
        end
    end

    // -----------------------------------------------------------------------
    // AXI4-Lite Read Channel
    // -----------------------------------------------------------------------
    logic [31:0] rd_data_reg;
    assign s_axi_rdata = rd_data_reg; 

    always_ff @(posedge clk) begin
        if (rst) begin
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            rd_data_reg   <= '0;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_arready <= 1'b0;
                case (s_axi_araddr[7:0])
                    8'h00: rd_data_reg <= {30'b0, reg_busy, 1'b0}; // Read busy status
                    8'h04: rd_data_reg <= {16'b0, reg_ray_ox};
                    8'h08: rd_data_reg <= {16'b0, reg_ray_oy};
                    8'h0C: rd_data_reg <= {16'b0, reg_ray_oz};
                    8'h1C: rd_data_reg <= {16'b0, reg_sph_cx};
                    8'h20: rd_data_reg <= {16'b0, reg_sph_cy};
                    8'h24: rd_data_reg <= {16'b0, reg_sph_cz};
                    8'h28: rd_data_reg <= {16'b0, reg_sph_r};
                    default: rd_data_reg <= 32'hDEADBEEF;
                endcase
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid  <= 1'b0;
                s_axi_arready <= 1'b1;
            end
        end
    end

endmodule
