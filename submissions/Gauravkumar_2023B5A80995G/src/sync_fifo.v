// =============================================================================
// sync_fifo.v
// Synchronous FIFO - Core Implementation Module
// =============================================================================

module sync_fifo #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH      = 16
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  wr_full,
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire                  rd_empty,
    output wire [ADDR_WIDTH:0]   count
);

    // Compute address width = clog2(DEPTH)
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

    // -------------------------------------------------------------------------
    // Internal storage and pointers
    // -------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   count_r;

    // -------------------------------------------------------------------------
    // Status flags
    // -------------------------------------------------------------------------
    assign rd_empty = (count_r == 0);
    assign wr_full  = (count_r == DEPTH);
    assign count    = count_r;

    // -------------------------------------------------------------------------
    // Valid operation qualifiers
    // -------------------------------------------------------------------------
    wire valid_wr = wr_en && !wr_full;
    wire valid_rd = rd_en && !rd_empty;

    // -------------------------------------------------------------------------
    // Synchronous logic
    // -------------------------------------------------------------------------
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr  <= 0;
            rd_ptr  <= 0;
            count_r <= 0;
            rd_data <= 0;
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= 0;
        end else begin

            // Write operation
            if (valid_wr) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
            end

            // Read operation
            if (valid_rd) begin
                rd_data <= mem[rd_ptr];
                rd_ptr  <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
            end

            // Occupancy counter
            if (valid_wr && !valid_rd)
                count_r <= count_r + 1;
            else if (valid_rd && !valid_wr)
                count_r <= count_r - 1;
            // simultaneous read+write: count unchanged

        end
    end

endmodule
