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

### Part 1: Binary Counter on PMOD LEDs
- **27-bit counter**: `reg [BITS+LOG2DELAY-1:0] counter` where `BITS=5`, `LOG2DELAY=22` → `[26:0]` = 27 bits
- **5-bit output**: `outcnt <= counter >> LOG2DELAY` extracts upper 5 bits `[26:22]` after frequency division
- **Gray code pattern**: `outcnt ^ (outcnt >> 1)` converts binary to Gray code where only one LED changes at a time
- **LED mapping**: `{LED1, LED2, LED3, LED4, LED5}` where LED5 (center red) shows LSB, LED1-LED4 (green) show bits [4:1]

### Part 2: Button Counter on Main Board LEDs
- Counts pressed buttons: `!BTN_N + BTN1 + BTN2 + BTN3`
- Displays count on active-low LEDs: `{LEDR_N, LEDG_N} = ~(button_count)`

### Part 3: 16-bit Shift Register on PMOD Pins
- Combines PMOD 1A and 1B (16 pins total)
- Shifts single '1' bit: `1 << (outcnt & 15)` cycles through pins 0-15

## Pin Configuration

Uses `../icebreaker.pcf` for pin constraints targeting iCE40 UP5K in SG48 package at 13 MHz.

## Code Conventions

- Module name: `top` (required by synthesis flow)
- Clock: `CLK` input drives all logic
- Active-low signals: Use `_N` suffix (e.g., `BTN_N`, `LEDR_N`)
- Localparams for constants rather than `define` macros
- Combinatorial assignments use `assign`, sequential use `always @(posedge CLK)`