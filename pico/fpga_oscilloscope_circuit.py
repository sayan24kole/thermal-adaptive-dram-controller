import machine
import time

# Listen on GPIO 15 (Pico Pin 20)
probe_pin = machine.Pin(15, machine.Pin.IN)

print("=" * 55)
print("  ZYBO VARIABLE REFRESH MONITOR (PICO SCOPE) ")
print("=" * 55)

while True:
    # Measure the high pulse duration in microseconds (1 sec timeout)
    high_time_us = machine.time_pulse_us(probe_pin, 1, 1_000_000)
    
    if high_time_us > 0:
        # Full period = 2x high time (since FPGA outputs 50% duty cycle)
        period_ms = (high_time_us * 2) / 1000.0
        freq_hz = 1000.0 / period_ms if period_ms > 0 else 0
        
        # Draw a live visual bar of refresh speed:
        bar_len = min(int(freq_hz * 2), 35)
        bar = "█" * bar_len
        
        print(f"Refresh: {freq_hz:5.1f} Hz  |  Period: {period_ms:6.1f} ms  | {bar}")
    else:
        print("Waiting for signal from Zybo JA1...")
        
    time.sleep(0.2)