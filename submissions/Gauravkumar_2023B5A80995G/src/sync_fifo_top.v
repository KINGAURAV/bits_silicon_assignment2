// =============================================================================
// sync_fifo_top.v
// Synchronous FIFO - Top-Level Module
// =============================================================================

module sync_fifo_top #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH      = 16
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  wr_full,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  rd_empty,
    output wire [ADDR_WIDTH:0]   count
);

    // Compute ADDR_WIDTH = clog2(DEPTH)
    function integer clog2;
        input integer value;
        integer i;
        begin
            clog2 = 0;
            for (i = value - 1; i > 0; i = i >> 1)
                clog2 = clog2 + 1;
        end
    endfunction

    localparam integer ADDR_WIDTH = clog2(DEPTH);

    // Instantiate core FIFO
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
    ) u_sync_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (wr_en),
        .wr_data (wr_data),
        .wr_full (wr_full),
        .rd_en   (rd_en),
        .rd_data (rd_data),
        .rd_empty(rd_empty),
        .count   (count)
    );

endmodule
