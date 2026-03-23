// =============================================================================
// tb_sync_fifo.v
// Self-Checking Testbench for Synchronous FIFO
// Includes: Golden Model, Scoreboard, Directed Tests, Coverage Counters
// =============================================================================

`timescale 1ns/1ps

module tb_sync_fifo;

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter integer DATA_WIDTH = 8;
    parameter integer DEPTH      = 16;
    parameter integer ADDR_WIDTH = 4; // clog2(16) = 4

    // Clock period
    parameter CLK_PERIOD = 10;

    // Random seed (change to vary random tests)
    integer SEED = 42;

    // =========================================================================
    // DUT Signals
    // =========================================================================
    reg                  clk;
    reg                  rst_n;
    reg                  wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    wire                 wr_full;
    reg                  rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire                 rd_empty;
    wire [ADDR_WIDTH:0]  count;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    sync_fifo_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
    ) dut (
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

    // =========================================================================
    // Golden Reference Model
    // =========================================================================
    reg [DATA_WIDTH-1:0] model_mem    [0:DEPTH-1];
    integer              model_wr_ptr;
    integer              model_rd_ptr;
    integer              model_count;
    reg [DATA_WIDTH-1:0] model_rd_data;

    always @(posedge clk) begin
        if (!rst_n) begin
            model_wr_ptr  <= 0;
            model_rd_ptr  <= 0;
            model_count   <= 0;
            model_rd_data <= 0;
        end else begin
            // Simultaneous read and write
            if (wr_en && (model_count < DEPTH) && rd_en && (model_count > 0)) begin
                model_mem[model_wr_ptr] = wr_data;
                model_wr_ptr = (model_wr_ptr == DEPTH-1) ? 0 : model_wr_ptr + 1;
                model_rd_data = model_mem[model_rd_ptr];
                model_rd_ptr = (model_rd_ptr == DEPTH-1) ? 0 : model_rd_ptr + 1;
                // model_count unchanged
            end
            // Write only
            else if (wr_en && (model_count < DEPTH)) begin
                model_mem[model_wr_ptr] = wr_data;
                model_wr_ptr  = (model_wr_ptr == DEPTH-1) ? 0 : model_wr_ptr + 1;
                model_count   = model_count + 1;
            end
            // Read only
            else if (rd_en && (model_count > 0)) begin
                model_rd_data = model_mem[model_rd_ptr];
                model_rd_ptr  = (model_rd_ptr == DEPTH-1) ? 0 : model_rd_ptr + 1;
                model_count   = model_count - 1;
            end
        end
    end

    // =========================================================================
    // Coverage Counters
    // =========================================================================
    integer cov_full;
    integer cov_empty;
    integer cov_wrap;
    integer cov_simul;
    integer cov_overflow;
    integer cov_underflow;

    // Track previous pointer values to detect wrap
    reg [ADDR_WIDTH-1:0] prev_wr_ptr;
    reg [ADDR_WIDTH-1:0] prev_rd_ptr;

    // Access internal DUT pointers for coverage tracking
    wire [ADDR_WIDTH-1:0] dut_wr_ptr = dut.u_sync_fifo.wr_ptr;
    wire [ADDR_WIDTH-1:0] dut_rd_ptr = dut.u_sync_fifo.rd_ptr;

    always @(posedge clk) begin
        if (!rst_n) begin
            prev_wr_ptr <= 0;
            prev_rd_ptr <= 0;
        end else begin
            // Full coverage
            if (wr_full)
                cov_full = cov_full + 1;
            // Empty coverage
            if (rd_empty)
                cov_empty = cov_empty + 1;
            // Wrap detection (pointer went from DEPTH-1 back to 0)
            if ((prev_wr_ptr == DEPTH-1 && dut_wr_ptr == 0) ||
                (prev_rd_ptr == DEPTH-1 && dut_rd_ptr == 0))
                cov_wrap = cov_wrap + 1;
            // Simultaneous valid read+write
            if (wr_en && rd_en && !wr_full && !rd_empty)
                cov_simul = cov_simul + 1;
            // Overflow attempt
            if (wr_en && wr_full)
                cov_overflow = cov_overflow + 1;
            // Underflow attempt
            if (rd_en && rd_empty)
                cov_underflow = cov_underflow + 1;

            prev_wr_ptr <= dut_wr_ptr;
            prev_rd_ptr <= dut_rd_ptr;
        end
    end

    // =========================================================================
    // Scoreboard
    // =========================================================================
    integer cycle;
    integer error_count;
    reg     in_reset;

    task scoreboard_check;
        input [63:0] test_name_hash; // unused, test name printed externally
        begin
            #1; // small delay to let DUT signals settle after posedge

            if (!in_reset) begin
                // Compare rd_data (only meaningful after a valid read)
                if (rd_en && !rd_empty) begin
                    if (rd_data !== model_rd_data) begin
                        $display("ERROR at time %0t, cycle %0d [SEED=%0d]", $time, cycle, SEED);
                        $display("  rd_data mismatch: expected=%0h, got=%0h", model_rd_data, rd_data);
                        $display("  wr_en=%b wr_data=%0h rd_en=%b wr_full=%b rd_empty=%b",
                                  wr_en, wr_data, rd_en, wr_full, rd_empty);
                        $display("  model_wr_ptr=%0d model_rd_ptr=%0d model_count=%0d",
                                  model_wr_ptr, model_rd_ptr, model_count);
                        error_count = error_count + 1;
                        $finish;
                    end
                end

                // Compare count
                if (count !== model_count) begin
                    $display("ERROR at time %0t, cycle %0d [SEED=%0d]", $time, cycle, SEED);
                    $display("  count mismatch: expected=%0d, got=%0d", model_count, count);
                    $display("  wr_en=%b wr_data=%0h rd_en=%b wr_full=%b rd_empty=%b",
                              wr_en, wr_data, rd_en, wr_full, rd_empty);
                    $display("  model_wr_ptr=%0d model_rd_ptr=%0d model_count=%0d",
                              model_wr_ptr, model_rd_ptr, model_count);
                    error_count = error_count + 1;
                    $finish;
                end

                // Compare rd_empty
                if (rd_empty !== (model_count == 0)) begin
                    $display("ERROR at time %0t, cycle %0d [SEED=%0d]", $time, cycle, SEED);
                    $display("  rd_empty mismatch: expected=%0b, got=%0b",
                              (model_count == 0), rd_empty);
                    error_count = error_count + 1;
                    $finish;
                end

                // Compare wr_full
                if (wr_full !== (model_count == DEPTH)) begin
                    $display("ERROR at time %0t, cycle %0d [SEED=%0d]", $time, cycle, SEED);
                    $display("  wr_full mismatch: expected=%0b, got=%0b",
                              (model_count == DEPTH), wr_full);
                    error_count = error_count + 1;
                    $finish;
                end
            end
        end
    endtask

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // Helper Tasks
    // =========================================================================

    // Apply reset
    task apply_reset;
        begin
            in_reset = 1;
            rst_n = 0;
            wr_en = 0;
            rd_en = 0;
            wr_data = 0;
            @(posedge clk); #1;
            @(posedge clk); #1;
            rst_n = 1;
            @(posedge clk); #1;
            in_reset = 0;
            cycle = 0;
        end
    endtask

    // Drive one cycle and run scoreboard
    task drive_cycle;
        input             t_wr_en;
        input [DATA_WIDTH-1:0] t_wr_data;
        input             t_rd_en;
        begin
            @(posedge clk);
            wr_en   = t_wr_en;
            wr_data = t_wr_data;
            rd_en   = t_rd_en;
            cycle   = cycle + 1;
            scoreboard_check(0);
        end
    endtask

    // Idle cycle
    task idle_cycle;
        begin
            drive_cycle(0, 0, 0);
        end
    endtask

    // =========================================================================
    // TEST 1: Reset Test
    // =========================================================================
    task test_reset;
        begin
            $display("\n--- TEST: Reset Test ---");
            apply_reset();
            idle_cycle();

            if (count !== 0 || rd_empty !== 1 || wr_full !== 0) begin
                $display("FAIL: Reset Test - count=%0d rd_empty=%0b wr_full=%0b",
                          count, rd_empty, wr_full);
                $finish;
            end
            $display("PASS: Reset Test");
        end
    endtask

    // =========================================================================
    // TEST 2: Single Write / Read Test
    // =========================================================================
    task test_single_write_read;
        reg [DATA_WIDTH-1:0] wdata;
        begin
            $display("\n--- TEST: Single Write/Read Test ---");
            apply_reset();
            wdata = 8'hA5;

            // Write
            drive_cycle(1, wdata, 0);
            if (count !== 1) begin
                $display("FAIL: count should be 1 after write, got %0d", count);
                $finish;
            end

            // Read
            drive_cycle(0, 0, 1);
            @(posedge clk); #1; // extra cycle for rd_data to appear
            if (rd_data !== wdata) begin
                $display("FAIL: rd_data=%0h, expected=%0h", rd_data, wdata);
                $finish;
            end

            idle_cycle();
            if (count !== 0) begin
                $display("FAIL: count should be 0 after read, got %0d", count);
                $finish;
            end
            $display("PASS: Single Write/Read Test");
        end
    endtask

    // =========================================================================
    // TEST 3: Fill Test (Full Condition)
    // =========================================================================
    task test_fill;
        integer i;
        begin
            $display("\n--- TEST: Fill Test ---");
            apply_reset();
            for (i = 0; i < DEPTH; i = i + 1)
                drive_cycle(1, i[DATA_WIDTH-1:0], 0);

            idle_cycle();
            if (count !== DEPTH || wr_full !== 1) begin
                $display("FAIL: Fill Test - count=%0d wr_full=%0b", count, wr_full);
                $finish;
            end
            $display("PASS: Fill Test");
        end
    endtask

    // =========================================================================
    // TEST 4: Drain Test (Empty Condition)
    // =========================================================================
    task test_drain;
        integer i;
        begin
            $display("\n--- TEST: Drain Test ---");
            apply_reset();
            // Fill first
            for (i = 0; i < DEPTH; i = i + 1)
                drive_cycle(1, i[DATA_WIDTH-1:0], 0);
            // Drain
            for (i = 0; i < DEPTH; i = i + 1)
                drive_cycle(0, 0, 1);

            idle_cycle();
            if (count !== 0 || rd_empty !== 1) begin
                $display("FAIL: Drain Test - count=%0d rd_empty=%0b", count, rd_empty);
                $finish;
            end
            $display("PASS: Drain Test");
        end
    endtask

    // =========================================================================
    // TEST 5: Overflow Attempt Test
    // =========================================================================
    task test_overflow;
        integer i;
        reg [DATA_WIDTH-1:0] saved_data;
        begin
            $display("\n--- TEST: Overflow Attempt Test ---");
            apply_reset();
            for (i = 0; i < DEPTH; i = i + 1)
                drive_cycle(1, i[DATA_WIDTH-1:0], 0);

            // Attempt extra write when full
            drive_cycle(1, 8'hFF, 0);
            drive_cycle(1, 8'hFE, 0);

            idle_cycle();
            if (count !== DEPTH) begin
                $display("FAIL: Overflow Test - count changed to %0d", count);
                $finish;
            end
            $display("PASS: Overflow Attempt Test");
        end
    endtask

    // =========================================================================
    // TEST 6: Underflow Attempt Test
    // =========================================================================
    task test_underflow;
        reg [DATA_WIDTH-1:0] stable_data;
        begin
            $display("\n--- TEST: Underflow Attempt Test ---");
            apply_reset();

            // Attempt read on empty FIFO
            drive_cycle(0, 0, 1);
            drive_cycle(0, 0, 1);

            idle_cycle();
            if (count !== 0 || rd_empty !== 1) begin
                $display("FAIL: Underflow Test - count=%0d rd_empty=%0b", count, rd_empty);
                $finish;
            end
            $display("PASS: Underflow Attempt Test");
        end
    endtask

    // =========================================================================
    // TEST 7: Simultaneous Read/Write Test
    // =========================================================================
    task test_simultaneous;
        integer i;
        begin
            $display("\n--- TEST: Simultaneous Read/Write Test ---");
            apply_reset();

            // Half-fill the FIFO
            for (i = 0; i < DEPTH/2; i = i + 1)
                drive_cycle(1, i[DATA_WIDTH-1:0], 0);

            // Simultaneous read/write for DEPTH cycles
            for (i = 0; i < DEPTH; i = i + 1)
                drive_cycle(1, (8'h80 + i[DATA_WIDTH-1:0]), 1);

            idle_cycle();
            if (count !== DEPTH/2) begin
                $display("FAIL: Simultaneous Test - count=%0d, expected=%0d", count, DEPTH/2);
                $finish;
            end
            $display("PASS: Simultaneous Read/Write Test");
        end
    endtask

    // =========================================================================
    // TEST 8: Pointer Wrap-Around Test
    // =========================================================================
    task test_wrap_around;
        integer i;
        begin
            $display("\n--- TEST: Pointer Wrap-Around Test ---");
            apply_reset();

            // Fill completely
            for (i = 0; i < DEPTH; i = i + 1)
                drive_cycle(1, (8'hC0 + i[DATA_WIDTH-1:0]), 0);

            // Drain completely (pointers advance to DEPTH-1)
            for (i = 0; i < DEPTH; i = i + 1)
                drive_cycle(0, 0, 1);

            // Fill again - forces pointer wrap-around through 0
            for (i = 0; i < DEPTH; i = i + 1)
                drive_cycle(1, (8'hD0 + i[DATA_WIDTH-1:0]), 0);

            // Drain again and verify data integrity
            for (i = 0; i < DEPTH; i = i + 1)
                drive_cycle(0, 0, 1);

            idle_cycle();
            if (count !== 0) begin
                $display("FAIL: Wrap-Around Test - count=%0d", count);
                $finish;
            end
            $display("PASS: Pointer Wrap-Around Test");
        end
    endtask

    // =========================================================================
    // TEST 9: Random Stress Test
    // =========================================================================
    task test_random;
        integer i;
        reg t_wr, t_rd;
        reg [DATA_WIDTH-1:0] t_data;
        begin
            $display("\n--- TEST: Random Stress Test (seed=%0d) ---", SEED);
            apply_reset();

            for (i = 0; i < 500; i = i + 1) begin
                t_wr   = $random(SEED) % 2;
                t_rd   = $random(SEED) % 2;
                t_data = $random(SEED) % 256;
                drive_cycle(t_wr, t_data, t_rd);
            end

            $display("PASS: Random Stress Test");
        end
    endtask

    // =========================================================================
    // Coverage Summary
    // =========================================================================
    task print_coverage;
        begin
            $display("\n========================================");
            $display("  COVERAGE SUMMARY");
            $display("========================================");
            $display("  cov_full      = %0d", cov_full);
            $display("  cov_empty     = %0d", cov_empty);
            $display("  cov_wrap      = %0d", cov_wrap);
            $display("  cov_simul     = %0d", cov_simul);
            $display("  cov_overflow  = %0d", cov_overflow);
            $display("  cov_underflow = %0d", cov_underflow);
            $display("========================================");

            if (cov_full == 0)      $display("WARNING: cov_full not exercised!");
            if (cov_empty == 0)     $display("WARNING: cov_empty not exercised!");
            if (cov_wrap == 0)      $display("WARNING: cov_wrap not exercised!");
            if (cov_simul == 0)     $display("WARNING: cov_simul not exercised!");
            if (cov_overflow == 0)  $display("WARNING: cov_overflow not exercised!");
            if (cov_underflow == 0) $display("WARNING: cov_underflow not exercised!");

            if (cov_full > 0 && cov_empty > 0 && cov_wrap > 0 &&
                cov_simul > 0 && cov_overflow > 0 && cov_underflow > 0)
                $display("  ALL COVERAGE BINS HIT - ADEQUATE COVERAGE");
        end
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        // Initialize coverage counters
        cov_full      = 0;
        cov_empty     = 0;
        cov_wrap      = 0;
        cov_simul     = 0;
        cov_overflow  = 0;
        cov_underflow = 0;
        error_count   = 0;
        in_reset      = 1;
        cycle         = 0;

        // Initialize signals
        rst_n   = 0;
        wr_en   = 0;
        rd_en   = 0;
        wr_data = 0;

        $display("========================================");
        $display("  SYNC FIFO TESTBENCH START");
        $display("  DATA_WIDTH=%0d  DEPTH=%0d", DATA_WIDTH, DEPTH);
        $display("========================================");

        // Run all directed tests
        test_reset();
        test_single_write_read();
        test_fill();
        test_drain();
        test_overflow();
        test_underflow();
        test_simultaneous();
        test_wrap_around();
        test_random();

        // Print coverage summary
        print_coverage();

        $display("\n========================================");
        if (error_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  %0d ERROR(S) DETECTED", error_count);
        $display("========================================\n");

        $finish;
    end

endmodule
