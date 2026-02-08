`default_nettype none

// Button-triggered hex counter on dual 7-segment display PMOD.
// Attach 7 segment display PMOD to Icebreaker PMOD1A port.
// Press BTN_N to single-step counter from 00 to FF.
// Press BTN1 (PMOD 2) to toggle free-running auto-increment.

module top(
           input  CLK,
           input  BTN_N,
           input  BTN1,
           output LED1,
           output LED2,
           output LED3,
           output LED4,
           output LED5,
           output P1A1,
           output P1A2,
           output P1A3,
           output P1A4,
           output P1A7,
           output P1A8,
           output P1A9,
           output P1A10
           );

   // Breakoff PMOD LEDs: LED1 shows running mode, rest off.
   assign LED1 = running;
   assign {LED5, LED4, LED3, LED2} = 4'b0000;

   // Wiring external pins.
   logic [6:0]    seg_pins_n;
   logic          digit_sel;
   assign {P1A9, P1A8, P1A7, P1A4, P1A3, P1A2, P1A1} = seg_pins_n;
   assign P1A10 = digit_sel;

   // Free-running counter for display multiplexing and timing.
   // display_state at bits [4:2] gives ~375 KHz refresh.
   // Bit 13 gives ~1.5 KHz for debounce sampling.
   // Bit 21 gives ~2.86 Hz for auto-increment when running.
   logic [23:0]   display_counter;
   logic [2:0]    display_state;
   assign display_state = display_counter[4:2];

   // Hex counter value: incremented by button press or auto-run.
   logic [7:0]    count;
   logic [3:0]    ones;
   logic [3:0]    tens;
   assign ones = count[3:0];
   assign tens = count[7:4];

   // BTN_N debounce shift register.
   // Sampled at ~1.5 KHz (display_counter bit 13).
   logic [2:0]    btn_shift;
   logic          btn_debounced;
   logic          btn_prev;

   // BTN1 debounce shift register.
   logic [2:0]    btn1_shift;
   logic          btn1_debounced;
   logic          btn1_prev;

   // Free-running mode toggle.
   logic          running;

   // Timing edge detection.
   logic          last_sample_bit;
   logic          last_auto_bit;

   logic [6:0]    ones_segments;
   logic [6:0]    tens_segments;

   digit_to_segments ones2segs(CLK, ones, ones_segments);
   digit_to_segments tens2segs(CLK, tens, tens_segments);

   always_ff @(posedge CLK) begin
      display_counter <= display_counter + 1;

      // Debounce: sample buttons into shift registers at ~1.5 KHz.
      last_sample_bit <= display_counter[13];
      if (display_counter[13] && !last_sample_bit) begin
         btn_shift  <= {btn_shift[1:0],  ~BTN_N};  // Invert: BTN_N is active-low
         btn1_shift <= {btn1_shift[1:0], BTN1};     // BTN1 is active-high
      end

      // Debounced signals: pressed when all 3 shift register bits are 1.
      btn_debounced  <= (btn_shift  == 3'b111);
      btn1_debounced <= (btn1_shift == 3'b111);

      // BTN_N edge detection: single-step on rising edge.
      btn_prev <= btn_debounced;
      if (btn_debounced && !btn_prev)
         count <= count + 1;

      // BTN1 edge detection: toggle free-running mode.
      btn1_prev <= btn1_debounced;
      if (btn1_debounced && !btn1_prev)
         running <= ~running;

      // Auto-increment when running, at ~2.86 Hz.
      last_auto_bit <= display_counter[21];
      if (running && display_counter[21] && !last_auto_bit)
         count <= count + 1;

      // Display multiplexing state machine (identical to 7seg_count).
      case (display_state)
        0, 1: seg_pins_n <= ~ones_segments;
        2:    seg_pins_n <= ~0;
        3:    digit_sel <= 0;
        4, 5: seg_pins_n <= ~tens_segments;
        6:    seg_pins_n <= ~0;
        7:    digit_sel <= 1;
      endcase
   end

endmodule // top

// Get the segments to illuminate to display a single hex digit.
// N.B., This is positive logic.  Display needs negative.
module digit_to_segments(input clk,
                         input [3:0] digit,
                         output logic [6:0] segments
                         );
   always_ff @(posedge clk)
     case (digit)
       0: segments <= 7'b0111111;
       1: segments <= 7'b0000110;
       2: segments <= 7'b1011011;
       3: segments <= 7'b1001111;
       4: segments <= 7'b1100110;
       5: segments <= 7'b1101101;
       6: segments <= 7'b1111101;
       7: segments <= 7'b0000111;
       8: segments <= 7'b1111111;
       9: segments <= 7'b1101111;
       4'hA: segments <= 7'b1110111;
       4'hB: segments <= 7'b1111100;
       4'hC: segments <= 7'b0111001;
       4'hD: segments <= 7'b1011110;
       4'hE: segments <= 7'b1111001;
       4'hF: segments <= 7'b1110001;
     endcase

endmodule
