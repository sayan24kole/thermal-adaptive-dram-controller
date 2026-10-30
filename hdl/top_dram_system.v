`timescale 1ns / 1ps

module top_dram_system (
    input  wire        sysclk,     // 125 MHz onboard clock (Pin K17)
    input  wire        sw0,        // Physical Switch 0 (Pin G15): 1 = Adaptive, 0 = Static
    input  wire        vauxp7,     // Analog Positive (Pin L14)
    input  wire        vauxn7,     // Analog Negative Ground (Pin L15)
    output wire [3:0]  leds,       // Board status & corruption alarm LEDs
    output wire        probe_out   // Scope / Pico probe output (Pin N15)
);

    // =========================================================================
    // Internal Interconnect Wires
    // =========================================================================
    wire [11:0] adc_raw;
    wire [7:0]  temp_c;
    wire        adc_valid;

    wire        refresh_tick;
    wire [7:0]  refresh_row;

    wire [10:0] vio_inspect_addr;
    wire [7:0]  vio_wr_data;
    wire        vio_wr_en;
    wire        vio_mode_sw;

    wire [7:0]  inspected_data;
    wire [8:0]  corrupt_row_count;

    // Both physical SW0 and the VIO Dashboard switch can control the mode:
    wire effective_adaptive_mode = sw0 & vio_mode_sw;

    // =========================================================================
    // 1. Module 1: XADC Analog Temperature Reader
    // =========================================================================
    xadc_reader u_xadc (
        .clk       (sysclk),
        .vauxp7    (vauxp7),
        .vauxn7    (vauxn7),
        .adc_raw   (adc_raw),
        .temp_c    (temp_c),
        .adc_valid (adc_valid)
    );

    // =========================================================================
    // 2. Module 2: Adaptive vs. Static Refresh Controller
    // =========================================================================
    refresh_controller u_refresh (
        .clk              (sysclk),
        .adc_raw          (adc_raw),
        .sw_adaptive_mode (effective_adaptive_mode),
        .refresh_tick     (refresh_tick),
        .refresh_row      (refresh_row),
        .probe_out        (probe_out)
    );

    // =========================================================================
    // 3. Module 3: 2 KB Emulated DRAM with Thermal Decay Engine
    // =========================================================================
    dram_2kb_decay u_dram (
        .clk               (sysclk),
        .adc_raw           (adc_raw),
        .refresh_tick      (refresh_tick),
        .refresh_row       (refresh_row),
        .inspect_addr      (vio_inspect_addr),
        .wr_data           (vio_wr_data),
        .wr_en             (vio_wr_en),
        .inspected_data    (inspected_data),
        .corrupt_row_count (corrupt_row_count)
    );

    // =========================================================================
    // 4. Module 4: Vivado JTAG VIO Dashboard Core
    // =========================================================================
    vio_0 u_vio (
        .clk        (sysclk),
        .probe_in0  (inspected_data),     // [7:0] What is inside Address 1000
        .probe_in1  (temp_c),             // [7:0] Live Temperature in Deg C
        .probe_in2  (corrupt_row_count),  // [8:0] Number of decayed rows (0 to 256)
        .probe_in3  (probe_out),          // [0:0] Live toggle of refresh clock
        .probe_out0 (vio_inspect_addr),   // [10:0] Address to inspect (defaults to 1000)
        .probe_out1 (vio_wr_data),        // [7:0] Custom byte to write
        .probe_out2 (vio_wr_en),          // [0:0] Write pulse button
        .probe_out3 (vio_mode_sw)         // [0:0] Dashboard Adaptive Mode switch
    );

    // =========================================================================
    // 5. Onboard Physical LED Indicators
    // =========================================================================
    // LD0: Heartbeat / Refresh tick
    // LD1: Sensor is at Room Temp (> 20 C)
    // LD2: Sensor is Heated (> 45 C)
    // LD3: CORRUPTION ALARM! Lights up bright RED if any DRAM row decays!
    reg [25:0] hb_cnt = 0;
    always @(posedge sysclk) hb_cnt <= hb_cnt + 1'b1;

    assign leds[0] = hb_cnt[25];                     // Heartbeat blink
    assign leds[1] = (temp_c >= 20);                 // Ambient active
    assign leds[2] = (temp_c >= 45);                 // Flame warming up
    assign leds[3] = (corrupt_row_count > 0);        // ? CRITICAL DATA CORRUPTION ALARM

endmodule