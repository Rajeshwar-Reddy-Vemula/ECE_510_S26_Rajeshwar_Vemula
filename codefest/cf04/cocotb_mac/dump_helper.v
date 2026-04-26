module dump_helper;
initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0);
    #1000000;
    $finish;
end
endmodule
