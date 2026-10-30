`timescale 1ns / 1ps

module xadc_reader (
    input  wire        clk,        // 125 MHz system clock
    input  wire        vauxp7,     // Analog Positive (Pmod JA Pin 2)
    input  wire        vauxn7,     // Analog Negative Ground (Pmod JA Pin 8)
    output reg  [11:0] adc_raw,    // Raw 12-bit ADC reading (0 to 4095)
    output wire [7:0]  temp_c,     // Approximated real-time temperature in Celsius
    output reg         adc_valid   // Pulses high for 1 cycle on fresh conversion
);

    // =========================================================================
    // 1. DRP Control & Read Logic
    // =========================================================================
    wire [15:0] do_out;
    wire drdy;
    wire eoc;
    reg  den = 0;

    // Trigger DRP read as soon as conversion completes
    always @(posedge clk) begin
        if (eoc) begin
            den <= 1'b1;
        end else begin
            den <= 1'b0;
        end
    end

    // Latch ADC output when DRP signals ready
    always @(posedge clk) begin
        adc_valid <= 1'b0;
        if (drdy) begin
            adc_raw   <= do_out[15:4]; // Top 12 bits
            adc_valid <= 1'b1;
        end
    end

    // =========================================================================
    // 2. Temperature in Celsius Calculation
    // =========================================================================
    // LM35 produces 10 mV / Deg C.
    // 2:1 divider halves it to 5 mV / Deg C.
    // 12-bit ADC full scale is 1.0V across 4096 counts -> ~20.48 counts per Deg C.
    // Formula: temp_c = adc_raw / 20.48 ~= (adc_raw * 25) / 512
    assign temp_c = (adc_raw * 25) >> 9;

    // =========================================================================
    // 3. Built-in 7-Series XADC Silicon Primitive
    // =========================================================================
    XADC #(
        .INIT_40(16'h0017),      // Config 0: Select Aux Channel 7
        .INIT_41(16'h3100),      // Config 1: Single-channel continuous mode
        .INIT_42(16'h0A00),      // Config 2: Clock Div = 10 (12.5 MHz ADC clock)
        .INIT_48(16'h0000),
        .INIT_49(16'h0000)
    ) XADC_inst (
        .DCLK(clk),
        .RESET(1'b0),
        .VAUXP({8'b0, vauxp7, 7'b0}),
        .VAUXN({8'b0, vauxn7, 7'b0}),
        .VP(1'b0),
        .VN(1'b0),
        .CONVST(1'b0),
        .CONVSTCLK(1'b0),
        .DEN(den),
        .DADDR(7'h17),           // Channel 7 data register
        .DI(16'h0000),
        .DWE(1'b0),
        .DO(do_out),
        .DRDY(drdy),
        .EOC(eoc),
        .EOS(),
        .BUSY(),
        .ALM(),
        .OT()
    );

endmodule