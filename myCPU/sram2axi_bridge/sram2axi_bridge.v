module sram2axi_bridge(
    input clk   ,
    input resetn,
    // inst sram interface
    input        inst_sram_req    ,
    input        inst_sram_wr     ,
    input [ 1:0] inst_sram_size   ,
    input [ 3:0] inst_sram_wstrb  ,
    input [31:0] inst_sram_addr   ,
    input [31:0] inst_sram_wdata  ,
    output       inst_sram_addr_ok,
    output       inst_sram_data_ok,
    output       inst_sram_rdata  ,
    // data sram interface
    input         data_sram_req    ,
    input         data_sram_wr     ,
    input [ 1:0]  data_sram_size   ,
    input [ 3:0]  data_sram_wstrb  ,
    input [31:0]  data_sram_addr   ,
    input [31:0]  data_sram_wdata  ,
    output        data_sram_addr_ok,
    output        data_sram_data_ok,
    output [31:0] data_sram_rdata  ,
    // axi interface
    // AR
    output [ 3:0] arid   ,
    output [31:0] araddr ,
    output [ 7:0] arlen  ,
    output [ 2:0] arsize ,
    output [ 1:0] arburst,
    output [ 1:0] arlock ,
    output [ 3:0] arcache,
    output [ 2:0] arprot ,
    output        arvalid,
    input         arready,
    // R
    input [ 3:0] rid   ,
    input [31:0] rdata ,
    input [ 1:0] rresp ,
    input        rlast ,
    input        rvalid,
    output       rready,
    // AW
    output [ 3:0] awid   ,
    output [31:0] awaddr ,
    output [ 7:0] awlen  ,
    output [ 2:0] awsize ,
    output [ 1:0] awburst,
    output [ 1:0] awlock ,
    output [ 3:0] awcache,
    output [ 2:0] awprot ,
    output        awvalid,
    input         awready,
    // W
    output [ 3:0] wid   ,
    output [31:0] wdata ,
    output [ 3:0] wstrb ,
    output        wlast ,
    output        wvalid,
    input         wready,
    // B
    input [ 3:0] bid   ,
    input [ 1:0] bresp ,
    input        bvalid,
    output       bready
);

endmodule