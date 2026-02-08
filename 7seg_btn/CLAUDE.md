# 7seg_btn - Button-Triggered Hex Counter on Dual 7-Segment Display

This project drives a two-digit 7-segment display PMOD connected to the ICEbreaker FPGA's PMOD1A port. It counts from 00 to FF in hexadecimal. The on-board user button (`BTN_N`) single-steps the counter, while `BTN1` on the PMOD 2 button/LED board toggles free-running auto-increment mode.

Based on `7seg_count`, but replaces the auto-incrementing counter with button-triggered counting and adds a free-running toggle.

## Target

- Device: iCE40 UP5K (ICEbreaker FPGA)
- Pin constraints: `../icebreaker.pcf`
- Build: `make` (uses `../main.mk`)

## Module: `top` (7seg_btn.v)

### Pin Mapping

- 7 output pins (`P1A1`-`P1A9`) drive the 7 segments (active-low).
- 1 output pin (`P1A10`) selects which of the two digits is active (`digit_sel`).
- 1 input pin (`BTN_N`) reads the on-board user button (active-low, pin 10).
- 1 input pin (`BTN1`) reads button 1 on the PMOD 2 button/LED board (active-high, pin 20).

### Differences from `7seg_count`

In `7seg_count`, a single 30-bit free-running counter served double duty: its upper bit slices provided the hex digits, and its lower bit slices drove the display multiplexing. The counter incremented every clock cycle, so the display auto-counted at ~6 Hz.

In `7seg_btn`, the counter and display are separated:

| Signal            | Width   | Purpose                                                        |
|-------------------|---------|----------------------------------------------------------------|
| `display_counter` | 24 bits | Free-running counter for display multiplexing and timing       |
| `count`           | 8 bits  | The displayed hex value, incremented by button or auto-run     |
| `running`         | 1 bit   | Free-running mode toggle, controlled by BTN1                   |

### Button Debounce

Both buttons use the same debounce technique:

1. **Prescaler**: Bit 13 of `display_counter` provides a ~1.5 KHz sample clock (12 MHz / 2^13).
2. **Shift register**: Each button is sampled into its own 3-bit shift register at each rising edge of the sample clock. `BTN_N` is inverted (active-low), `BTN1` is used directly (active-high).
3. **Debounced signal**: A button is considered pressed only when all 3 shift register bits are 1 (i.e., three consecutive samples show the button held down). This requires ~2 ms of stable press.

### Edge Detection

Both buttons use rising-edge detection to trigger exactly once per press:

- `btn_prev` / `btn1_prev` latch the previous debounced state.
- `BTN_N` increments `count` on rising edge: `btn_debounced && !btn_prev`.
- `BTN1` toggles `running` on rising edge: `btn1_debounced && !btn1_prev`.

### Free-Running Mode

When `running` is high (toggled by BTN1):

- The counter auto-increments at ~2.86 Hz, using the rising edge of `display_counter[21]` (12 MHz / 2^22).
- `BTN_N` single-stepping still works while running.

### Display Multiplexing State Machine

Identical to `7seg_count`. The two digits share the same 7 segment pins and are time-division multiplexed using a 3-bit `display_state` derived from `display_counter[4:2]` (~375 KHz):

| State | Action                                                         |
|-------|----------------------------------------------------------------|
| 0, 1  | Show **ones** digit segments (inverted for active-low display) |
| 2     | Blank all segments                                             |
| 3     | Switch `digit_sel` to 0 (select tens digit)                    |
| 4, 5  | Show **tens** digit segments                                   |
| 6     | Blank all segments                                             |
| 7     | Switch `digit_sel` to 1 (select ones digit)                    |

## Module: `digit_to_segments`

Identical to `7seg_count`. A lookup table converting a 4-bit hex value (0-F) into a 7-bit segment pattern (`gfedcba`).

## Key Design Decisions

- Display refresh and counting are fully separated, unlike `7seg_count` where they shared one counter.
- Debounce uses a 3-bit shift register sampled at ~1.5 KHz, requiring ~2 ms of stable input to register a press.
- Edge detection ensures one increment per press, regardless of how long the button is held.
- Free-running toggle uses the same debounce and edge-detection pattern as single-step.
- `display_counter` widened to 24 bits (from 20) to provide the auto-increment timing bit; no impact on display or debounce logic.
- Counter wraps naturally from FF to 00 via 8-bit overflow.
- `default_nettype none` enforced for safety.
