module cocotb_iverilog_dump();
initial begin
    $dumpfile("sim_build/mac.fst");
    $dumpvars(0, mac);
end
endmodule
