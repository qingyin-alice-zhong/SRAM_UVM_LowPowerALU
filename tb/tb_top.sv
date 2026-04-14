`timescale 1ns/1ps

module tb_top;
    import uvm_pkg::*;
    import ahb_uvm_pkg::*;

    logic HCLK;
    logic HRESETn;
    initial begin
        HCLK = 1'b0;
        forever #5 HCLK = ~HCLK;
    end

    initial begin
        HRESETn = 1'b0;
        repeat (5) @(posedge HCLK);
        HRESETn = 1'b1;
    end

    ahb_if ahb_vif(
        .HCLK(HCLK),
        .HRESETn(HRESETn)
    );

    assign ahb_vif.HREADY = 1'b1;

    initial begin
        ahb_vif.sleep_i = 1'b0;
    end

    ahb_sram_32x32 dut (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HSEL(ahb_vif.HSEL),
        .HADDR(ahb_vif.HADDR),
        .HTRANS(ahb_vif.HTRANS),
        .HWRITE(ahb_vif.HWRITE),
        .HSIZE(ahb_vif.HSIZE),
        .HBURST(ahb_vif.HBURST),
        .HWDATA(ahb_vif.HWDATA),
        .HREADY(ahb_vif.HREADY),
        .sleep_i(ahb_vif.sleep_i),
        .HRDATA(ahb_vif.HRDATA),
        .HREADYOUT(ahb_vif.HREADYOUT),
        .HRESP(ahb_vif.HRESP)
    );

    ahb_sva ahb_checker (
        .vif(ahb_vif)
    );

    initial begin
        uvm_config_db#(virtual ahb_if)::set(null, "uvm_test_top.env.agent.*", "vif", ahb_vif);
        uvm_config_db#(virtual ahb_if)::set(null, "uvm_test_top.env.*", "vif", ahb_vif);
        run_test();
    end

endmodule
