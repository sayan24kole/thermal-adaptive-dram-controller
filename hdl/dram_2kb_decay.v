`timescale 1ns / 1ps

module dram_2kb_decay (
    input  wire        clk,                 // 125 MHz clock
    input  wire [11:0] adc_raw,             // From xadc_reader
    input  wire        refresh_tick,        // From refresh_controller
    input  wire [7:0]  refresh_row,         // Row currently being refreshed (0 to 255)
    
    // Live Inspection Port (Driven by Vivado VIO Dashboard)
    input  wire [10:0] inspect_addr,        // Address to inspect (0 to 2047)
    input  wire [7:0]  wr_data,             // Data to write
    input  wire        wr_en,               // 1 = Write pulse
    output reg  [7:0]  inspected_data,      // 8-bit contents of inspect_addr
    output reg  [8:0]  corrupt_row_count    // Total number of currently decayed rows (0 to 256)
);

    // =========================================================================
    // 1. 2 KB Memory Array (Infers Clean Hardware RAM)
    // =========================================================================
    reg [7:0] memory [0:2047];
    reg [7:0] raw_mem_data = 8'hA5;

    // Pre-initialize memory on FPGA power-up
    integer i;
    initial begin
        for (i = 0; i < 2048; i = i + 1) begin
            memory[i] = (i[7:0] ^ 8'h5A);
        end
        // Address 1000 explicit known byte: 0xA5 (0b10100101)
        memory[1000] = 8'hA5;
    end

    // Single unified write port (Eliminates Multiple Driver conflict!)
    always @(posedge clk) begin
        if (wr_en) begin
            memory[inspect_addr] <= wr_data;
        end
        raw_mem_data <= memory[inspect_addr];
    end

    // =========================================================================
    // 2. Dynamic Retention Deadline Calculation
    // =========================================================================
    // Room temp (~500): retention limit ~ 160 ms (Safe!)
    // High heat  (~1700): retention limit ~ 40 ms (Collapses!)
    wire [11:0] clamped_adc = (adc_raw > 2000) ? 2000 : (adc_raw < 300) ? 300 : adc_raw;
    wire [24:0] retention_limit = (2100 - clamped_adc) * 12500;

    reg [24:0] global_timer = 0;
    always @(posedge clk) begin
        global_timer <= global_timer + 1'b1;
    end

    // =========================================================================
    // 3. Row Decay & Refresh Tracking (Unified Single Driver)
    // =========================================================================
    reg [24:0] last_refreshed [0:255];
    reg [255:0] row_decayed = 0;
    reg [7:0] check_row = 0;

    wire [24:0] elapsed_time = global_timer - last_refreshed[check_row];

    always @(posedge clk) begin
        check_row <= check_row + 1'b1;

        // Has this row exceeded its thermal retention deadline?
        if (elapsed_time > retention_limit) begin
            row_decayed[check_row] <= 1'b1; // Mark Decayed
        end

        // When refresh visits a row, it rescues it (takes priority!)
        if (refresh_tick) begin
            last_refreshed[refresh_row] <= global_timer;
            row_decayed[refresh_row]    <= 1'b0; // Rescued / Healthy!
        end
    end

    // =========================================================================
    // 4. Smooth 1-per-cycle Background Corruption Counter
    // =========================================================================
    reg [8:0] count_accum = 0;
    always @(posedge clk) begin
        if (check_row == 8'd0) begin
            corrupt_row_count <= count_accum;
            count_accum       <= row_decayed[0];
        end else begin
            count_accum <= count_accum + row_decayed[check_row];
        end
    end

    // =========================================================================
    // 5. Output Data Presentation
    // =========================================================================
    // Address 1000 belongs to row: inspect_addr[10:3]
    wire [7:0] inspected_row = inspect_addr[10:3];
    wire is_decayed = row_decayed[inspected_row];

    always @(posedge clk) begin
        if (is_decayed) begin
            inspected_data <= 8'h00; // DECAYED: bits have collapsed!
        end else begin
            inspected_data <= raw_mem_data; // INTACT: valid healthy data!
        end
    end

endmodule