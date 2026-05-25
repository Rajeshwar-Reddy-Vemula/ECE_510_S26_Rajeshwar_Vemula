`timescale 1ns/1ps
`include "compute_core.sv"
`include "interface.sv"
module tb_interface;

    logic        clk, rst;
    logic [31:0] s_axi_awaddr;
    logic        s_axi_awvalid, s_axi_awready;
    logic [31:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb;
    logic        s_axi_wvalid,  s_axi_wready;
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid,  s_axi_bready;
    logic [31:0] s_axi_araddr;
    logic        s_axi_arvalid, s_axi_arready;
    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid,  s_axi_rready;

    logic [63:0] s_axis_tdata;
    logic        s_axis_tvalid;
    logic        s_axis_tready;
    logic [63:0] m_axis_tdata;
    logic        m_axis_tvalid;
    logic        m_axis_tready;

    logic [31:0] rd_val;

    interface_top dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    task check(input logic cond, input string name, input string detail);
        if (cond) begin
            $display("[PASS] %s: %s", name, detail);
            pass_count++;
        end else begin
            $display("[FAIL] %s: %s", name, detail);
            fail_count++;
        end
    endtask

    task axi_write(input [31:0] addr, input [31:0] data);
        @(negedge clk);
        s_axi_awaddr  = addr; s_axi_awvalid = 1;
        s_axi_wdata   = data; s_axi_wvalid  = 1; s_axi_wstrb = 4'hF;
        s_axi_bready  = 1;

        @(posedge clk);
        while (!(s_axi_awready && s_axi_wready)) @(posedge clk);

        @(negedge clk);
        s_axi_awvalid = 0; s_axi_wvalid = 0;

        @(posedge clk);
        while (!s_axi_bvalid) @(posedge clk);

        @(posedge clk); 
        
        @(negedge clk);
        s_axi_bready = 0;
    endtask

    task axi_read(input [31:0] addr, output [31:0] rdata);
        @(negedge clk);
        s_axi_araddr  = addr; s_axi_arvalid = 1; s_axi_rready = 1;

        @(posedge clk);
        while (!s_axi_arready) @(posedge clk);

        @(negedge clk);
        s_axi_arvalid = 0;

        @(posedge clk);
        while (!s_axi_rvalid) @(posedge clk);

        rdata = s_axi_rdata;

        @(negedge clk);
        s_axi_rready = 0;
    endtask

    task axis_send(input [15:0] dx, input [15:0] dy, input [15:0] dz);
        @(negedge clk);
        s_axis_tdata  = {16'h0, dz, dy, dx};
        s_axis_tvalid = 1;

        @(posedge clk);
        while (!s_axis_tready) @(posedge clk);

        @(negedge clk);
        s_axis_tvalid = 0;
        $display("[INFO] Pushed Ray D=(0x%04X, 0x%04X, 0x%04X) into Stream", dx, dy, dz);
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_interface);

        s_axi_awvalid = 0; s_axi_wvalid = 0; s_axi_bready = 0;
        s_axi_arvalid = 0; s_axi_rready = 0;
        s_axis_tvalid = 0; s_axis_tdata = 0; m_axis_tready = 1;

        $display("\n=======================================================");
        $display("STARTING SIMULATION: AXI4-Lite Setup & AXI-Stream Data");
        $display("=======================================================\n");

        rst = 1; repeat(5) @(posedge clk);
        rst = 0; repeat(2) @(posedge clk);

        $display("\n--- PHASE 1: AXI4-Lite Sphere Configuration ---");
        // Test with a diagonal ray hitting a sphere in positive space
        axi_write(32'h04, 32'h0000); // OX = 0.0
        axi_write(32'h08, 32'h0000); // OY = 0.0
        axi_write(32'h0C, 32'h0000); // OZ = 0.0
        axi_write(32'h1C, 32'h01BB); // CX = 1.73 (0x01BB)
        axi_write(32'h20, 32'h01BB); // CY = 1.73 (0x01BB)
        axi_write(32'h24, 32'h01BB); // CZ = 1.73 (0x01BB)
        axi_write(32'h28, 32'h0100); // R  = 1.0  (0x0100)
        check(1, "AXI4-Lite Write", "All object parameters loaded.");

        $display("\n--- PHASE 1b: Read Back Written Registers ---");
        axi_read(32'h1C, rd_val); $display("[INFO] Read SPH_CX : 0x%04X", rd_val[15:0]);
        axi_read(32'h20, rd_val); $display("[INFO] Read SPH_CY : 0x%04X", rd_val[15:0]);
        axi_read(32'h24, rd_val); $display("[INFO] Read SPH_CZ : 0x%04X", rd_val[15:0]);
        axi_read(32'h28, rd_val); $display("[INFO] Read SPH_R  : 0x%04X", rd_val[15:0]);

        $display("\n--- PHASE 2: AXI-Stream Ray Injection ---");
        // Sending diagonal Ray D: DX=0.577, DY=0.577, DZ=0.577
        axis_send(16'h0094, 16'h0094, 16'h0094);

        $display("\n--- PHASE 3: Polling for AXI-Stream Output ---");
        @(posedge clk);
        while (!m_axis_tvalid) @(posedge clk);
        
        // With these inputs, the expected hit distance is exactly 2.0 (0x0200)
        check(m_axis_tdata[15:0] == 16'h0200, "AXI-Stream Output", 
              $sformatf("Received hit_distance 0x%04X (Expected: 0x0200)", m_axis_tdata[15:0]));
        
        @(posedge clk);
        @(negedge clk);
        m_axis_tready = 0; 

        $display("\n=======================================================");
        if (fail_count == 0) $display("ALL TESTS PASSED (%0d PASS)", pass_count);
        else $display("SIMULATION FAILED (%0d FAIL)", fail_count);
        $display("=======================================================\n");

        $finish;
    end
endmodule
