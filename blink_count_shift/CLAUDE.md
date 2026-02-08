# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iCEBreaker FPGA example project that demonstrates LED control, button input, and PMOD I/O functionality. The project consists of a single Verilog module (`blink_count_shift.v`) that implements three distinct features on the iCE40 UP5K FPGA.

## Build System

The project uses a Makefile-based build system with ice40 toolchain:

- `make` or `make all` - Synthesize and build the bitstream (creates .rpt and .bin files)
- `make prog` - Program the FPGA via iceprog
- `make sudo-prog` - Program with sudo privileges
- `make clean` - Remove generated files

The build uses:
- Yosys for synthesis (creates .json from .v)
- nextpnr-ice40 for place & route (creates .asc from .json)
- icepack for bitstream generation (creates .bin from .asc)
- icetime for timing analysis (creates .rpt from .asc)

## Hardware Architecture

### Sequential Logic: The `always` Block

The `always @(posedge CLK)` block contains the only sequential (registered) logic in the design. It executes once per rising clock edge (12 MHz = every ~83 ns):

- **`counter <= counter + 1`** — Increments a 27-bit counter every clock cycle. Full wrap-around takes 2^27 = ~134 million cycles (~11.2 seconds).
- **`outcnt <= counter >> LOG2DELAY`** — Right-shifts counter by 22 bits, extracting upper 5 bits `[26:22]` as a frequency divider. `outcnt` increments once every 2^22 = ~4.2 million cycles (~0.35 seconds).

Both use **non-blocking assignment (`<=`)**, meaning both right-hand sides are evaluated using the *current* values before either register updates. This models real flip-flop behavior — a new value computed at cycle N appears at the register output at cycle N+1.

### Combinational Logic: The `assign` Statements

All three `assign` statements are combinational — outputs update immediately when inputs change, with no clock dependency.

#### Part 1: Gray Code LEDs (line 35)
```
assign {LED1, LED2, LED3, LED4, LED5} = outcnt ^ (outcnt >> 1);
```
- Converts the 5-bit binary counter `outcnt` to **Gray code** via XOR with itself shifted right by 1
- Gray code ensures only one LED changes state between consecutive counter values (e.g., binary `01111` → `10000` flips all bits, but Gray code transitions always flip exactly one)
- Concatenation maps bit 4 (MSB) → LED1, bit 0 (LSB) → LED5

#### Part 2: Button Counter on Main Board LEDs (line 37)
```
assign {LEDR_N, LEDG_N} = ~(!BTN_N + BTN1 + BTN2 + BTN3);
```
- **`!BTN_N`** inverts the active-low button so it contributes 1 when pressed, matching the active-high `BTN1`–`BTN3`
- Arithmetic addition sums how many buttons are pressed (0–4), producing a 2-bit result
- **`~`** bitwise inverts because `LEDR_N` and `LEDG_N` are active-low (0 = LED on)
- Result: 0 pressed = both off, 1 = green on, 2 = red on, 3 = both on

#### Part 3: Walking '1' Shift Register on PMOD Pins (lines 39–40)
```
assign {P1A1, ..., P1B10} = 1 << (outcnt & 15);
```
- Concatenates all 16 PMOD pins (1A + 1B) into a 16-bit bus (P1A1 = bit 15 MSB, P1B10 = bit 0 LSB)
- **`outcnt & 15`** masks to lower 4 bits (values 0–15), selecting which pin is active
- **`1 << N`** produces a 16-bit value with exactly one bit set, creating a walking '1' that cycles through all 16 PMOD pins (~0.35 seconds per step)

## Pin Configuration (PCF File)

Uses `../icebreaker.pcf` for pin constraints targeting iCE40 UP5K in SG48 package at 12 MHz. The PCF maps Verilog signal names to physical chip package pin numbers using `set_io` commands:

```
set_io -nowarn <signal_name> <pin_number>
```

The `-nowarn` flag suppresses warnings for signals defined in the PCF but not used in the current design, allowing the PCF to be shared across multiple projects.

Key pin mappings:
| Signal | Pin | Physical connection |
|---|---|---|
| `CLK` | 35 | 12 MHz oscillator |
| `BTN_N` | 10 | User button (active-low, pull-up to 3V3) |
| `LEDR_N` / `LEDG_N` | 11 / 37 | Board LEDs (active-low) |
| `LED1`–`LED5` | 26,27,25,23,21 | PMOD 2 break-off section LEDs |
| `BTN1`–`BTN3` | 20,19,18 | PMOD 2 break-off section buttons (active-high, pull-down to GND) |
| `P1A1`–`P1A10` | 4,2,47,45,3,48,46,44 | PMOD 1A connector |
| `P1B1`–`P1B10` | 43,38,34,31,42,36,32,28 | PMOD 1B connector |

## Button Circuit Design (from iCEBreaker v1.0e schematic)

The active-high vs active-low behavior is determined by the physical wiring on the board:

- **`BTN_N` (SW1, active-low)**: FPGA pin is connected through a **10k pull-up resistor (R13) to +3V3**. The button shorts the pin to GND when pressed. Unpressed = 1, pressed = 0.
- **`BTN1`–`BTN3` (SW2–SW4, active-high)**: Each FPGA pin is connected through a **10k pull-down resistor (R16A/B/C) to GND**. Each button connects the pin to +3V3 when pressed. Unpressed = 0, pressed = 1.

The schematic is available at `v1.0e/icebreaker-sch.pdf`.

## Code Conventions

- Module name: `top` (required by synthesis flow)
- Clock: `CLK` input drives all logic
- Active-low signals: Use `_N` suffix (e.g., `BTN_N`, `LEDR_N`)
- Localparams for constants rather than `define` macros
- Combinatorial assignments use `assign`, sequential use `always @(posedge CLK)`
- Non-blocking assignment (`<=`) in sequential blocks, continuous `assign` for combinational logic