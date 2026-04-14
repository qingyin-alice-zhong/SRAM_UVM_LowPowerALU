interface ahb_if (
    input logic HCLK,
    input logic HRESETn
);
    logic        HSEL;
    logic [31:0] HADDR;
    logic [1:0]  HTRANS;
    logic        HWRITE;
    logic [2:0]  HSIZE;
    logic [2:0]  HBURST;
    logic [31:0] HWDATA;
    logic        HREADY;
    logic        sleep_i;
    logic [31:0] HRDATA;
    logic        HREADYOUT;
    logic        HRESP;

    modport dut_mp (
        input  HCLK, HRESETn, HSEL, HADDR, HTRANS, HWRITE, HSIZE, HBURST, HWDATA, HREADY, sleep_i,
        output HRDATA, HREADYOUT, HRESP
    );

    modport tb_mp (
        input  HCLK, HRESETn, HRDATA, HREADYOUT, HRESP,
        output HSEL, HADDR, HTRANS, HWRITE, HSIZE, HBURST, HWDATA, HREADY, sleep_i
    );
endinterface
