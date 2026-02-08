# 7seg_count - Hex Counter on Dual 7-Segment Display

This project drives a two-digit 7-segment display PMOD connected to the ICEbreaker FPGA's PMOD1A port. It counts from 00 to FF in hexadecimal.

## Target

- Device: iCE40 UP5K (ICEbreaker FPGA)
- Pin constraints: `../icebreaker.pcf`
- Build: `make` (uses `../main.mk`)

## Module: `top` (7seg_count.v)

### Pin Mapping

- 7 output pins (`P1A1`-`P1A9`) drive the 7 segments (active-low).
- 1 output pin (`P1A10`) selects which of the two digits is active (`digit_sel`).

### Free-Running Counter

A 30-bit counter increments every clock cycle (12 MHz). Different bit slices serve different purposes:

| Signal          | Bits      | Purpose                                                        |
|-----------------|-----------|----------------------------------------------------------------|
| `ones`          | `[24:21]` | The ones hex digit (4 bits). Increments at ~6 Hz (12MHz/2^21) |
| `tens`          | `[28:25]` | The tens hex digit. Increments 16x slower than ones            |
| `display_state` | `[4:2]`   | 3-bit (0-7) state machine for display multiplexing at ~375 KHz |

Since `ones` and `tens` are consecutive 4-bit slices of the counter, the display naturally counts 00-FF in hex, then rolls over.

### Display Multiplexing State Machine

The two digits share the same 7 segment pins and are time-division multiplexed. The 8-state cycle:

| State | Action                                                        |
|-------|---------------------------------------------------------------|
| 0, 1  | Show **ones** digit segments (inverted for active-low display)|
| 2     | Blank all segments (`~0` = all high = all off)                |
| 3     | Switch `digit_sel` to 0 (select tens digit)                   |
| 4, 5  | Show **tens** digit segments                                  |
| 6     | Blank all segments                                            |
| 7     | Switch `digit_sel` to 1 (select ones digit)                   |

The blanking in states 2/6 prevents ghosting -- without it, the old digit's segments would briefly show on the new digit during the transition. Each digit gets a 25% duty cycle (2 of 8 states).

## Module: `digit_to_segments`

A lookup table converting a 4-bit hex value (0-F) into a 7-bit segment pattern. The bit pattern `segments[6:0]` maps to segments `gfedcba` of a standard 7-segment display. Examples:

- `0` -> `0111111` (segments a-f on, g off)
- `1` -> `0000110` (segments b,c on)
- `8` -> `1111111` (all segments on)

Uses positive logic internally -- the `top` module inverts with `~` when driving the active-low display pins.

## Key Design Decisions

- No external clock dividers needed -- the free-running counter's bit slices naturally provide counting speed (~6 Hz) and display refresh rate (~375 KHz).
- Segment blanking during digit transitions eliminates flicker/ghosting.
- `default_nettype none` enforced for safety (catches undeclared wire typos).
