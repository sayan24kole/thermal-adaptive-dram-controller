`timescale 1ns / 1ps

module refresh_controller (
    input  wire        clk,               // 125 MHz system clock
    input  wire [11:0] adc_raw,           // From xadc_reader
    input  wire        sw_adaptive_mode,  // 1 = Adaptive Thermal, 0 = Static Fixed (SW0)
    output reg         refresh_tick,      // 1-cycle pulse per row refresh
    output reg  [7:0]  refresh_row,       // Current row being refreshed (0 to 255)
    output reg         probe_out          // Toggles each full sweep for Pico Scope
);

    // Initial state
    initial begin
        refresh_tick = 0;
        refresh_row  = 0;
        probe_out    = 0;
    end

    // Clamp ADC to safe operating boundaries
    wire [11:0] clamped_adc = (adc_raw > 2000) ? 2000 : (adc_raw < 300) ? 300 : adc_raw;

    // =========================================================================
    // Refresh Interval Calculation
    // =========================================================================
    // Adaptive: row interval shrinks as temperature rises (faster refresh)
    // Static:   row interval is frozen at room-temperature speed
    wire [19:0] row_interval = sw_adaptive_mode ? 
                               ((2200 - clamped_adc) * 28) : 
                               (1700 * 28); // Fixed ~5 Hz sweep

    reg [19:0] row_timer = 0;

    // =========================================================================
    // Row Sequencer Engine
    // =========================================================================
    always @(posedge clk) begin
        refresh_tick <= 1'b0;
        row_timer    <= row_timer + 1'b1;

        if (row_timer >= row_interval) begin
            row_timer    <= 0;
            refresh_tick <= 1'b1;
            refresh_row  <= refresh_row + 1'b1;

            // When row counter wraps from 255 -> 0, toggle probe_out (one full 2 KB sweep done!)
            if (refresh_row == 8'hFF) begin
                probe_out <= ~probe_out;
            end
        end
    end

endmodule