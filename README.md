# Thermal-Aware Adaptive DRAM Refresh Controller on FPGA

An FPGA-based hardware implementation of an **Adaptive Auto Self-Refresh (ASR) DRAM Controller**. 

Real-world DRAM memory cells suffer from temperature-dependent sub-threshold leakage , where charge retention time halves approximately every 10°C. This project implements a closed-loop system where an external analog temperature sensor dynamically modulates the row refresh rate of an emulated 2 KB DRAM memory core, preventing thermal decay and memory corruption under extreme heat.

---

## Features
- **Analog Thermal Sensing:** Utilizes the Xilinx 7-Series internal 12-bit **XADC** (Auxiliary Channel 7) to continuously sample temperature from an external **LM35** sensor.
- **2 KB Emulated DRAM Core:** 2048-byte memory organized as 256 rows × 8 bytes, featuring physical retention deadline tracking and row decay modeling.
- **Dynamic Adaptive Refresh Controller:** Sweeps memory rows dynamically, scaling refresh frequency from ~5 Hz (idle/ambient) up to ~35 Hz+ when heated.
- **Static vs. Adaptive Demo Mode:** Physical toggle switch (`SW0`) allows comparing legacy fixed-rate refresh (which experiences severe data decay under heat) against adaptive refresh (which maintains 100% data integrity).
- **Interactive JTAG VIO Dashboard:** Vivado Virtual Input/Output (VIO) GUI allows live inspection and writing of individual memory addresses (e.g., Address 1000) down to the binary bit level without external serial wiring.
- **Oscilloscope / Pulse Monitor:** Outputs a 50% duty cycle refresh pulse stream to standard PMOD pins, monitored via a Raspberry Pi Pico acting as a frequency analyzer.

---

## System Architecture

```text
                   +-------------------------------------------------------------+
                   |                     DIGILENT ZYBO Z7                        |
                   |                                                             |
LM35 Sensor -------+--> [ XADC Reader ]                                          |
(via 2:1 Divider)  |          |                                                  |
                   |          v (adc_raw / temp_c)                               |
                   |          |                                                  |
                   |          +-------------------+                              |
                   |          |                   |                              |
                   |          v                   v                              |
                   |   [ Decay Engine ]   [ Refresh Controller ]                 |
                   |   Retention deadline  Row Sweeper (0 to 255)                |
                   |   shrinks with heat   Modulated by temp & SW0               |
                   |          |                   |                              |
                   |          |                   +---------> Pmod JA1 (Pico)    |
                   |          +---------->+<------+                              |
                   |                      |                                      |
                   |                      v                                      |
                   |         [ 2 KB Emulated DRAM Memory ]                       |
                   |                      ^                                      |
                   |                      | (Inspect / Write)                    |
                   |                      v                                      |
                   |         [ Vivado JTAG VIO Dashboard ]                       |
                   +-------------------------------------------------------------+
```
## Hardware Bill of Materials (BOM)

| Component | Quantity | Purpose |
| :--- | :---: | :--- |
| **Digilent Zybo (Zynq-7010)** | 1 | FPGA Development Board |
| **Texas Instruments LM35** | 1 | Precision Centigrade Temperature Sensor (10 mV/°C) |
| **10 kΩ Resistors** | 2 | 2:1 Voltage Divider (Overvoltage protection for XADC) |
| **Raspberry Pi Pico** | 1 | 5V Power Supply & Pulse-Width Frequency Scope |
| **Breadboard & Jumpers** | - | Circuit prototyping & Common Ground plane |

---

## Pin Connections & Circuit Schematic

### 1. LM35 Voltage Divider Circuit

```text
  [LM35 Pin 1 (+Vs)] --------> +5V (Pico Pin 40 / VBUS)
  [LM35 Pin 3 (GND)] --------> Breadboard Common GND

  [LM35 Pin 2 (Out)] 
           |
           +---- [ 10 kΩ ] ----+----> Safe Output Node (0.5x Vout) ---> Zybo Pmod JA Pin 2 (L14)
                               |
```
### 2. Zybo Z7 Pin Mapping

| Port Name | Direction | Zybo Pin | Description |
| :--- | :---: | :---: | :--- |
| `sysclk` | Input | `K17` | 125 MHz Onboard System Clock |
| `sw0` | Input | `G15` | Slider Switch 0 (`1` = Adaptive Mode, `0` = Static Mode) |
| `vauxp7` | Input | `L14` | Pmod JA Pin 2 (Analog Vaux7 Positive Input) |
| `vauxn7` | Input | `L15` | Pmod JA Pin 8 (Analog Vaux7 Negative Ground Reference) |
| `probe_out` | Output | `N15` | Pmod JA Pin 1 (Refresh wave to Pico Scope GPIO 15) |
| `leds[0]` | Output | `M14` | Heartbeat / Refresh tick indicator |
| `leds[1]` | Output | `M15` | Ambient Temperature Active (Temp > 20°C) |
| `leds[2]` | Output | `G14` | Heated Active (Temp > 45°C) |
| `leds[3]` | Output | `D18` | **CRITICAL ALARM:** Memory Row Decay / Corruption Detected |

---

## How to Reproduce

### 1. Setup Vivado Project
1. Open **Vivado 2020.2** (or newer).
2. Create a new RTL Project targeting part **`xc7z010clg400-1`** (or select the **Zybo Z7-10** board preset).
3. Add all Verilog design files from `/hdl` and the constraint file from `/constrs`.
4. In the Sources tab, add the pre-configured VIO IP from `/ip/vio_0/vio_0.xci`.
5. Right-click **`top_dram_system.v`** and select **Set as Top**.
6. Click **Generate Bitstream** under Program and Debug.

### 2. Pi Pico Frequency Monitor
1. Open **Thonny IDE**.
2. Connect **Raspberry Pi Pico Pin 20 (`GPIO 15`)** to **Zybo Pmod JA Pin 1**.
3. Load and run `/pico/pico_scope_monitor.py` on the Pico.

### 3. Running the Live Demo
1. Connect the Zybo via micro-USB, turn power switch **`SW4` ON**, and ensure **`SW0` is flipped UP (`1`)**.
2. Open Vivado **Hardware Manager**   -->   **Auto Connect**   -->   **Program Device** using `top_dram_system.bit`.
3. In the **`hw_vio_1`** dashboard tab, click the **`+` (Add Probes)** icon and add all probes:
   - Format **`probe_in0` (`inspected_data`)**   -->  **Radix**  -->   **Binary** (Inspects Address 1000).
   - Format **`probe_in1` (`temp_c`)**  -->   **Radix**   -->   **Unsigned Decimal**.
   - Format **`probe_in2` (`corrupt_row_count`)**  -->   **Radix**   -->   **Unsigned Decimal**.
   - Format **`probe_out0` (`inspect_addr`)**   -->   **Radix**   -->   **Unsigned Decimal** (Defaults to `1000`).

---

## Experimental Validation

### Experiment A: Adaptive Mode (`SW0 = UP / 1`)
- Address 1000 initially reads `10100101` (`0xA5`).
- Bring a lighter flame 2 to 3 inches away from the LM35 sensor.
- `temp_c` climbs from ~30°C to 70°C+ on the VIO screen.
- On the Pi Pico scope, the refresh frequency dynamically scales up from **~5 Hz to 25+ Hz**.
- **Result:** `corrupt_row_count` stays strictly at **`0`**. The adaptive refresh outruns thermal charge leakage, and Address 1000 remains 100% intact!

### Experiment B: Static Failure Mode (`SW0 = DOWN / 0`)
- Flip physical switch **`SW0` DOWN (`0`)** to disable thermal adaptation.
- Apply heat to the LM35 sensor again.
- The refresh frequency on the Pi Pico remains stubbornly locked at ~5 Hz.
- As temperature rises, cell retention time collapses below the fixed refresh interval.
- **Result:**
  - `corrupt_row_count` rapidly escalates (`15... 64... 180...`).
  - **`LD3` on the Zybo turns ON** (Red Corruption Alarm).
  - The bits at Address 1000 decay and collapse to **`00000000`** live on the dashboard!
- Flip **`SW0` back UP (`1`)**: The adaptive sweep kicks back in, clears all decayed rows back to `0`, and turns off the alarm.
                               +---- [ 10 kΩ ] ----> Breadboard Common GND
