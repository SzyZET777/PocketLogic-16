; Start main:
  jmp main


; Constants:
define FRAMEBUFFER, 0xC000
define SD_CARD_BLOCK, 0xE800
define LEDS, 0xF000
define KEYBOARD, 0xF00A
define BUTTONS, 0xF00E


; Global Variables & Buffers
caps_lock_on: 
  byte 0

title_bar_str:
  text "PocketLogic-16"
  byte 0

cursor_pos:
  byte 0

app_menu_pos:
  word 0

caps_lock_on_str:
  text "ABC"

caps_lock_off_str:
  text "abc"

text_buffer:
  reserve 160

text_color_buffer:
  reserve 160


; func main () {
main:
  ldi sp, 0xC000

  jsr ra, buzzer_test
  ; jsr ra, buttons_test

  ; jsr ra, sd_card_test


loop:
  jsr ra, update_cursor_pos

  ldi a0, 0b101010
  jsr ra, clear_screen

  ldi a0, 0b000011
  ldi a1, title_bar_str
  jsr ra, draw_title_bar

  jsr ra, draw_caps_lock
  jsr ra, draw_app_menu

  jsr ra, draw_text_buffer
  jsr ra, refresh_screen

  jmp loop

end_main:
  jmp end_main
; }


; func draw_pixel (#x, #y, #col) {
draw_pixel:
  mov t0, a1
  shl t0, 7
  add t0, a0
  adi t0, FRAMEBUFFER
  stb a2, [t0]
  ret ra
; }


; func print_char (#x, #y, #col, #char) {
print_char:
  sub sp, 2
  stw ra, [sp]
  sub sp, 2
  stw s0, [sp]
  sub sp, 2
  stw s1, [sp]
  sub sp, 2
  stw s2, [sp]

  shl a0, 3
  shl a1, 3
  shl a3, 3

  mov s0, 8
print_char_loop_y:
  sub s0, 1
  
  ldi t0, char_table
  add t0, a3
  add t0, s0
  ldb s2, [t0]

  mov s1, 8
print_char_loop_x:
  sub s1, 1

  mov t0, s2
  and t0, 1
  xor t0, 1
  brc t0, print_char_skip
  
  ; Call draw_pixel Function

  add a0, s1
  add a1, s0

  jsr ra, draw_pixel

  sub a0, s1
  sub a1, s0

print_char_skip:
  shr s2, 1

  brc s1, print_char_loop_x
  brc s0, print_char_loop_y

  ldw s2, [sp]
  add sp, 2
  ldw s1, [sp]
  add sp, 2
  ldw s0, [sp]
  add sp, 2
  ldw ra, [sp]
  add sp, 2

  ret ra
; }


; func draw_text_buffer () {
draw_text_buffer:
  sub sp, 2
  stw ra, [sp]
  sub sp, 2
  stw s0, [sp]
  sub sp, 2
  stw s1, [sp]

  ldi s0, 10
draw_text_buffer_loop_y:
  sub s0, 1
  ldi s1, 16
draw_text_buffer_loop_x:
  sub s1, 1

  mov a0, s1
  mov a1, s0

  mov t1, s0
  shl t1, 4
  add t1, s1

  ldi t0, text_color_buffer
  add t0, t1
  ldb a2, [t0]

  ldi t0, text_buffer
  add t0, t1
  ldb a3, [t0]

  jsr ra, print_char

  brc s1, draw_text_buffer_loop_x
  brc s0, draw_text_buffer_loop_y

  ldw s1, [sp]
  add sp, 2
  ldw s0, [sp]
  add sp, 2
  ldw ra, [sp]
  add sp, 2

  ret ra
; }


; func clear_screen (#col) {
clear_screen:
  ldi t0, 10240
clear_screen_loop:
  sub t0, 1
  mov t1, t0
  adi t1, FRAMEBUFFER
  stb a0, [t1]
  brc t0, clear_screen_loop
  ret ra
; }


; func draw_title_bar (#col, *str) {
draw_title_bar:
  sub sp, 2
  stw s0, [sp]

  ldi s0, 16
draw_title_bar_loop:
  sub s0, 1
  ldi t0, text_color_buffer
  add t0, s0
  ldi t1, 0b111111
  stb t1, [t0]
  brc s0, draw_title_bar_loop
  
  ldi s0, 1024
draw_title_bar_back_loop:
  sub s0, 1
  ldi t0, FRAMEBUFFER
  add t0, s0
  stb a0, [t0]
  brc s0, draw_title_bar_back_loop

  ldi s0, 128
  mov t1, 0
draw_title_bar_outline_loop:
  sub s0, 1
  ldi t0, 50176
  add t0, s0
  stb t1, [t0]
  brc s0, draw_title_bar_outline_loop

  ldi s0, text_buffer
write_title_bar_str_loop:
  ldb t0, [a1]
  stb t0, [s0]
  add s0, 1
  add a1, 1
  ldb t0, [a1]
  brc t0, write_title_bar_str_loop

  ldw s0, [sp]
  add sp, 2

  ret ra
; }


; func draw_rect (#pos, #width, #height, #col) {
draw_rect:
  mov t1, a2
draw_rect_loop_y:
  sub t1, 1
  mov t2, a1
draw_rect_loop_x:
  sub t2, 1

  mov t0, t1
  shl t0, 7
  add t0, a0
  add t0, t2
  adi t0, FRAMEBUFFER
  stb a3, [t0]

  brc t2, draw_rect_loop_x
  brc t1, draw_rect_loop_y

  ret ra
; }


; func draw_rect_outline (#pos, #width, #height, #col) {
draw_rect_outline:
  shl a2, 7

  mov t0, a0
  shr t0, 7
  equ t0, 0
  brc t0, skip_top_rect_outline

  mov t1, a1
draw_top_rect_outline_loop:
  sub t1, 1
  ldi t0, FRAMEBUFFER
  add t0, t1
  add t0, a0
  adi t0, -128
  stb a3, [t0]
  brc t1, draw_top_rect_outline_loop

  mov t0, a0
  shr t0, 7
  eqi t0, 79
  brc t0, skip_bottom_rect_outline

skip_top_rect_outline:

  mov t1, a1
draw_bottom_rect_outline_loop:
  sub t1, 1
  ldi t0, FRAMEBUFFER
  add t0, t1
  add t0, a0
  add t0, a2
  stb a3, [t0]
  brc t1, draw_bottom_rect_outline_loop

skip_bottom_rect_outline:

  mov t0, a0
  ldi t1, 0xEF
  and t0, t1
  equ t0, 0
  brc t0, skip_left_rect_outline

  mov t1, a2
draw_left_rect_outline_loop:
  adi t1, -128
  ldi t0, FRAMEBUFFER
  add t0, t1
  add t0, a0
  sub t0, 1
  stb a3, [t0]
  brc t1, draw_left_rect_outline_loop

skip_left_rect_outline:

  mov t0, a0
  ldi t1, 0xEF
  and t0, t1
  eqi t0, 127
  brc t0, skip_right_rect_outline

  mov t1, a2
draw_right_rect_outline_loop:
  adi t1, -128
  ldi t0, FRAMEBUFFER
  add t0, t1
  add t0, a0
  add t0, a1
  stb a3, [t0]
  brc t1, draw_right_rect_outline_loop

skip_right_rect_outline

  shr a2, 7

  ret ra
; }


; func draw_caps_lock (#pos, #width, #height, #col) {
draw_caps_lock:
  sub sp, 2
  stw ra, [sp]

  ldi a0, 9216 ; 128*9*8
  ldi a1, 24 ; 8*3
  ldi a2, 8
  ldi a3, 0b111111
  jsr ra, draw_rect

  mov a3, 0
  jsr ra, draw_rect_outline

  ldi t1, caps_lock_on_str
  ldi t0, caps_lock_on
  ldb t0, [t0]
  brc t0, caps_lock_on_skip
  ldi t1, caps_lock_off_str
caps_lock_on_skip:

  ldi t0, text_buffer
  adi t0, 144

  ldb t2, [t1]
  stb t2, [t0]
  add t0, 1
  add t1, 1
  ldb t2, [t1]
  stb t2, [t0]
  add t0, 1
  add t1, 1
  ldb t2, [t1]
  stb t2, [t0]

  ldw ra, [sp]
  add sp, 2

  ret ra
; }


; func draw_app_menu () {
draw_app_menu:
  sub sp, 2
  stw ra, [sp]

  ldi a0, 2056 ; 128*16 + 8
  ldi a1, 112 ; 128-16
  ldi a2, 48 ; 8*6
  ldi a3, 0b111111
  jsr ra, draw_rect

  mov a3, 0
  jsr ra, draw_rect_outline

  ldi a0, 2056 ; 128*16 + 8
  ldi t0, cursor_pos
  ldb t0, [t0]
  shl t0, 10
  add a0, t0
  ldi a1, 112 ; 128-16
  ldi a2, 8
  mov a3, 0b11
  jsr ra, draw_rect

  mov t2, 6
app_menu_text_color_loop_y:
  sub t2, 1
  mov t3, 14
app_menu_text_color_loop_x:
  sub t3, 1
  mov t0, t2
  shl t0, 4
  add t0, t3
  adi t0, 33
  adi t0, text_color_buffer
  mov t1, 0
  stb t1, [t0]
  brc t3, app_menu_text_color_loop_x
  brc t2, app_menu_text_color_loop_y

  ldi t0, cursor_pos
  ldb t2, [t0]
  mov t3, 14
app_menu_cursor_text_color_loop:
  sub t3, 1
  mov t0, t2
  shl t0, 4
  add t0, t3
  adi t0, 33
  adi t0, text_color_buffer
  ldi t1, 0b111111
  stb t1, [t0]
  brc t3, app_menu_cursor_text_color_loop

  jsr ra, wait_for_sd

  ldi t0, 0xF016
  mov t1, 0
  stw t1, [t0]

  ldi t0, 0xF010
  mov t1, 1
  stw t1, [t0]

  jsr ra, wait_for_sd

  ldi t2, 0
app_menu_text_loop_y:
  ldi t3, 0
app_menu_text_loop_x:
  mov t0, t2
  ldi t1, app_menu_pos
  ldw t1, [t1]
  add t0, t1
  shl t0, 5
  adi t0, SD_CARD_BLOCK
  add t0, t3

  ldb t1, [t0]

  mov t0, t2
  shl t0, 4
  adi t0, text_buffer
  add t0, t3
  adi t0, 34
  
  stb t1, [t0]

  add t3, 1
  mov t0, t3
  dif t0, 12
  brc t0, app_menu_text_loop_x
  add t2, 1
  mov t0, t2
  dif t0, 6
  brc t0, app_menu_text_loop_y

  ldw ra, [sp]
  add sp, 2

  ret ra
; }


; func update_cursor_pos () {
update_cursor_pos:

; Check button_u
  ldi t0, BUTTONS
  ldw t0, [t0]
  and t0, 0b01
  equ t0, 0
  brc t0, dont_move_cursor_up

  ldi t0, cursor_pos
  ldb t1, [t0]
  dif t1, 0
  brc t1, move_cursor_up

  ldi t0, app_menu_pos
  ldw t1, [t0]
  sub t1, 1
  stw t1, [t0]

  jmp wait_for_cursor_up_release

move_cursor_up:

  ldi t0, cursor_pos
  ldb t1, [t0]
  sub t1, 1
  stb t1, [t0]

wait_for_cursor_up_release:
  ldi t0, BUTTONS
  ldw t0, [t0]
  and t0, 0b01
  brc t0, wait_for_cursor_up_release

  jmp dont_move_cursor_down

dont_move_cursor_up:

; Check button_d
  ldi t0, BUTTONS
  ldw t0, [t0]
  and t0, 0b10
  equ t0, 0
  brc t0, dont_move_cursor_down

  ldi t0, cursor_pos
  ldb t1, [t0]
  dif t1, 5
  brc t1, move_cursor_down

  ldi t0, app_menu_pos
  ldw t1, [t0]
  add t1, 1
  stw t1, [t0]

  jmp wait_for_cursor_down_release

move_cursor_down:

  ldi t0, cursor_pos
  ldb t1, [t0]
  add t1, 1
  stb t1, [t0]

wait_for_cursor_down_release:
  ldi t0, BUTTONS
  ldw t0, [t0]
  and t0, 0b10
  brc t0, wait_for_cursor_down_release

dont_move_cursor_down:

  ret ra
; }


; func wait_for_sd () {
wait_for_sd:
  ldi t0, 0xF012
app_menu_wait_for_sd_1:
  ldw t1, [t0]
  brc t1, app_menu_wait_for_sd_1
  ret ra
; }


; func refresh_screen () {
refresh_screen:
  ldi t1, 0xF008 ; GPU busy

wait_for_gpu:
  ldw t0, [t1]
  brc t0, wait_for_gpu

  ldi t1, 0xF006 ; CPU frame ready
  mov t0, 1
  stw t0, [t1]

  ret ra
; }


; func buzzer_test() {
buzzer_test:
  ldi t2, 2000
  ldi t0, 0xF00C
  stw t2, [t0]

  ldi t0, 0xF004
  ldi t1, 500 ; 0.5s
  stw t1, [t0]
buzzer_test_wait:
  ldw t1, [t0]
  brc t1, buzzer_test_wait

  ldi t2, 0
  ldi t0, 0xF00C
  stw t2, [t0]

  ret ra
; }


; func buttons_test() {
buttons_test:
  ldi t0, 0xF004
  ldi t1, 1000 ; 1s
  stw t1, [t0]

buttons_loop:
  ldi t0, BUTTONS
  ldw t1, [t0]
  shr t1, 2
  ldi t0, LEDS
  stw t1, [t0]
  ldi t0, 0xF004
  ldw t1, [t0]
  brc t1, buttons_loop

  ret ra
; }


; func sd_card_test() {
sd_card_test:
  sub sp, 2
  stw ra, [sp]

  ldi t0, 0xF016
  ldi t1, 0
  stw t1, [t0]

  jsr ra, wait_for_sd

  ldi t0, LEDS
  ldi t1, 0b1010
  stw t1, [t0]

  ldi t0, 0xF010
  mov t1, 1
  stw t1, [t0]

  jsr ra, wait_for_sd

  ldi t0, LEDS
  ldi t1, 0b1001
  stw t1, [t0]

  ldi t0, SD_CARD_BLOCK
  ldi t1, 0x1A12
  stw t1, [t0]

  ldi t0, 0xF014
  ldi t1, 1
  stw t1, [t0]

  jsr ra, wait_for_sd

  mov t2, 0
sd_card_test_loop:
  ldi t0, SD_CARD_BLOCK
  add t0, t2
  ldb t1, [t0]
  ldi t0, text_buffer
  add t0, t2
  adi t0, 93
  stb t1, [t0]
  add t2, 1
  mov t0, t2
  dfi t0, 64
  brc t0, sd_card_test_loop

  ldw ra, [sp]
  add sp, 2

  ret ra
; }


; func handle_keyboard () {
handle_keyboard:

; WARNING - not working function

; Draw line cursor (0x04):
  ldi t0, text_buffer
  add t0, s0
  adi t0, 32
  ldi t1, 0x04
  stb t1, [t0]

; Set cursor color to blue (0x03):
  ldi t0, text_color_buffer
  add t0, s0
  adi t0, 32
  mov t1, 0b11
  stb t1, [t0]

  ldi t0, KEYBOARD
  ldw s1, [t0]
  mov t0, s1
  equ t0, 0
  brc t0, keyboard_skip

  ldi t0, 0xF004
  ldi t1, 300
  stw t1, [t0]

wait_for_key_release:
  ldi t0, KEYBOARD
  ldw t1, [t0]
  brc t1, wait_for_key_release

; Check if caps lock was pressed
  mov t0, s1
  dif t0, 2
  brc t0, caps_lock_not_pressed
  ldi t0, caps_lock_on
  ldb t1, [t0]
  xor t1, 1
  stb t1, [t0]
  jmp keyboard_skip

caps_lock_not_pressed:

; Check if backspace was pressed
  mov t0, s1
  dif t0, 3
  brc t0, backspace_not_pressed
  ldi t0, text_buffer
  add t0, s0
  adi t0, 32
  mov t1, 0
  stb t1, [t0]
  sub s0, 1
  ldi t0, 0x3F
  and s0, t0
  jmp keyboard_skip:

backspace_not_pressed:

; Check if 300ms passed
  ldi t0, 0xF004
  ldw t1, [t0]

; Draw text character
  ldi t0, text_buffer
  add t0, s0
  adi t0, 32
; Check for alt characters
  equ t1, 0
  shl t1, 5
  add s1, t1
; Check for caps lock
  ldi t2, caps_lock_on
  ldb t2, [t2]
  shl t2, 6
  add s1, t2
; Store the character in a text buffer
  stb s1, [t0]

; Set new character color to black (0x00):
  ldi t0, text_color_buffer
  add t0, s0
  adi t0, 32
  mov t1, 0
  stb t1, [t0]

  add s0, 1
  ldi t0, 0x3F
  and s0, t0

keyboard_skip:
  ret ra
; }


; data char_table {
char_table:

; null:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; new line:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; shift lock:
  byte 0b00000000
  byte 0b00010000
  byte 0b00101000
  byte 0b01000100
  byte 0b01101100
  byte 0b00101000
  byte 0b00111000
  byte 0b00000000

; backspace:
  byte 0b00000000
  byte 0b00011110
  byte 0b00100010
  byte 0b01010110
  byte 0b01001010
  byte 0b00100010
  byte 0b00011110
  byte 0b00000000

; line cursor:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b01111100

; space:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; q letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b00111100
  byte 0b01000100
  byte 0b01000100
  byte 0b00111100
  byte 0b00000100
  byte 0b00000100

; w letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b01000100
  byte 0b01000100
  byte 0b01010100
  byte 0b01010100
  byte 0b00101000
  byte 0b00000000

; e letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b00111000
  byte 0b01000100
  byte 0b01111100
  byte 0b01000000
  byte 0b00111100
  byte 0b00000000

; r letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b00111100
  byte 0b00100000
  byte 0b00100000
  byte 0b00100000
  byte 0b00100000
  byte 0b00000000

; t letter:
  byte 0b00000000
  byte 0b00010000
  byte 0b00111000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000

; y letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b00111100
  byte 0b00000100
  byte 0b01111000

; u letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b00111010
  byte 0b00000000

; i letter:
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000
  byte 0b00110000
  byte 0b00010000
  byte 0b00010000
  byte 0b00111000
  byte 0b00000000

; o letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b00111000
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b00111000
  byte 0b00000000

; p letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b01111000
  byte 0b01000100
  byte 0b01000100
  byte 0b01111000
  byte 0b01000000
  byte 0b01000000

; a letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b00111000
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b00111010
  byte 0b00000000

  ; s letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b00111100
  byte 0b01000000
  byte 0b00111000
  byte 0b00000100
  byte 0b01111000
  byte 0b00000000

; d letter:
  byte 0b00000000
  byte 0b00000100
  byte 0b00111100
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b00111010
  byte 0b00000000

; f letter:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00100000
  byte 0b01111000
  byte 0b00100000
  byte 0b00100000
  byte 0b00100000

  ; g letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b00111000
  byte 0b01000100
  byte 0b01000100
  byte 0b00111100
  byte 0b00000100
  byte 0b01111000

; h letter:
  byte 0b00000000
  byte 0b00100000
  byte 0b00111000
  byte 0b00100100
  byte 0b00100100
  byte 0b00100100
  byte 0b00100100
  byte 0b00000000

; j letter:
  byte 0b00000000
  byte 0b00001000
  byte 0b00000000
  byte 0b00011000
  byte 0b00001000
  byte 0b00001000
  byte 0b00101000
  byte 0b00010000

; k letter:
  byte 0b00000000
  byte 0b00100000
  byte 0b00100100
  byte 0b00101000
  byte 0b00110000
  byte 0b00101000
  byte 0b00100100
  byte 0b00000000

; l letter:
  byte 0b00000000
  byte 0b00100000
  byte 0b00100000
  byte 0b00100000
  byte 0b00100000
  byte 0b00100100
  byte 0b00011000
  byte 0b00000000

; z letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b01111100
  byte 0b00001000
  byte 0b00010000
  byte 0b00100000
  byte 0b01111100
  byte 0b00000000

; x letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b01000100
  byte 0b00101000
  byte 0b00010000
  byte 0b00101000
  byte 0b01000100
  byte 0b00000000

; c letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b00111000
  byte 0b01000100
  byte 0b01000000
  byte 0b01000100
  byte 0b00111000
  byte 0b00000000

; v letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b01000100
  byte 0b01000100
  byte 0b00101000
  byte 0b00101000
  byte 0b00010000
  byte 0b00000000

; b letter:
  byte 0b00000000
  byte 0b01000000
  byte 0b01111000
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b01111000
  byte 0b00000000

; n letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b01011000
  byte 0b00100100
  byte 0b00100100
  byte 0b00100100
  byte 0b00100100
  byte 0b00000000

; m letter:
  byte 0b00000000
  byte 0b00000000
  byte 0b01010100
  byte 0b00101010
  byte 0b00101010
  byte 0b00101010
  byte 0b00101010
  byte 0b00000000

; arrow up:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; arrow down:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; arrow left:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; arrow right:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; ... character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b01010100
  byte 0b00000000

; _ character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b01111100
  byte 0b00000000

; number 1:
  byte 0b00000000
  byte 0b00010000
  byte 0b00110000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00111000
  byte 0b00000000

; number 2:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00000100
  byte 0b00011000
  byte 0b00100000
  byte 0b00111100
  byte 0b00000000

; number 3:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00001000
  byte 0b00000100
  byte 0b00100100
  byte 0b00011000
  byte 0b00000000

; number 4:
  byte 0b00000000
  byte 0b00001000
  byte 0b00010000
  byte 0b00100000
  byte 0b00101000
  byte 0b00111100
  byte 0b00001000
  byte 0b00000000

; number 5:
  byte 0b00000000
  byte 0b00111100
  byte 0b00100000
  byte 0b00011000
  byte 0b00000100
  byte 0b00100100
  byte 0b00011000
  byte 0b00000000

; number 6:
  byte 0b00000000
  byte 0b00011100
  byte 0b00100000
  byte 0b00111000
  byte 0b00100100
  byte 0b00100100
  byte 0b00011000
  byte 0b00000000

; number 7:
  byte 0b00000000
  byte 0b00111100
  byte 0b00000100
  byte 0b00001000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000

; number 8:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00011000
  byte 0b00100100
  byte 0b00100100
  byte 0b00011000
  byte 0b00000000

; number 9:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00100100
  byte 0b00011100
  byte 0b00000100
  byte 0b00111000
  byte 0b00000000

; number 0:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00101100
  byte 0b00110100
  byte 0b00100100
  byte 0b00011000
  byte 0b00000000

; < character:
  byte 0b00000000
  byte 0b00001000
  byte 0b00010000
  byte 0b00100000
  byte 0b00010000
  byte 0b00001000
  byte 0b00000000
  byte 0b00000000

; > character:
  byte 0b00000000
  byte 0b00100000
  byte 0b00010000
  byte 0b00001000
  byte 0b00010000
  byte 0b00100000
  byte 0b00000000
  byte 0b00000000

; = character:
  byte 0b00000000
  byte 0b00000000
  byte 0b01111100
  byte 0b00000000
  byte 0b01111100
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; + character:
  byte 0b00000000
  byte 0b00010000
  byte 0b00010000
  byte 0b01111100
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000
  byte 0b00000000

; - character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b01111100
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; * character:
  byte 0b00000000
  byte 0b00010000
  byte 0b01010100
  byte 0b00111000
  byte 0b01010100
  byte 0b00010000
  byte 0b00000000
  byte 0b00000000

; / character:
  byte 0b00000000
  byte 0b00000010
  byte 0b00000100
  byte 0b00001000
  byte 0b00010000
  byte 0b00100000
  byte 0b01000000
  byte 0b00000000

; ( character:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100000
  byte 0b00100000
  byte 0b00100000
  byte 0b00100000
  byte 0b00011000
  byte 0b00000000

; ) character:
  byte 0b00000000
  byte 0b00110000
  byte 0b00001000
  byte 0b00001000
  byte 0b00001000
  byte 0b00001000
  byte 0b00110000
  byte 0b00000000

; ! character:
  byte 0b00000000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000

; ? character:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00001000
  byte 0b00010000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000

; " character:
  byte 0b00000000
  byte 0b00101000
  byte 0b00101000
  byte 0b00101000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; : character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000
  byte 0b00000000

; ; character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000
  byte 0b00010000
  byte 0b00010000
  byte 0b00100000

; . character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000

; , character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00001000
  byte 0b00010000

; null:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; new line:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; shift lock:
  byte 0b00000000
  byte 0b00010000
  byte 0b00101000
  byte 0b01000100
  byte 0b01101100
  byte 0b00101000
  byte 0b00111000
  byte 0b00000000

; backspace:
  byte 0b00000000
  byte 0b00011110
  byte 0b00100010
  byte 0b01010110
  byte 0b01001010
  byte 0b00100010
  byte 0b00011110
  byte 0b00000000

; line cursor:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b01111100

; space:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; Q letter:
  byte 0b00000000
  byte 0b00111000
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b00111000
  byte 0b00000110

; W letter:
  byte 0b00000000
  byte 0b01000100
  byte 0b01000100
  byte 0b01010100
  byte 0b01010100
  byte 0b01101100
  byte 0b01000100
  byte 0b00000000

; E letter:
  byte 0b00000000
  byte 0b01111100
  byte 0b01000000
  byte 0b01111000
  byte 0b01000000
  byte 0b01000000
  byte 0b01111100
  byte 0b00000000

; R letter:
  byte 0b00000000
  byte 0b01111000
  byte 0b01000100
  byte 0b01000100
  byte 0b01111000
  byte 0b01000100
  byte 0b01000100
  byte 0b00000000

; T letter:
  byte 0b00000000
  byte 0b01111100
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000

; Y letter:
  byte 0b00000000
  byte 0b01000100
  byte 0b00101000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000

; U letter:
  byte 0b00000000
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b00111010
  byte 0b00000000

; I letter:
  byte 0b00000000
  byte 0b01111100
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b01111100
  byte 0b00000000

; O letter:
  byte 0b00000000
  byte 0b00111000
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b00111000
  byte 0b00000000

; P letter:
  byte 0b00000000
  byte 0b01111000
  byte 0b01000100
  byte 0b01000100
  byte 0b01111000
  byte 0b01000000
  byte 0b01000000
  byte 0b00000000

; A letter:
  byte 0b00000000
  byte 0b00111000
  byte 0b01000100
  byte 0b01000100
  byte 0b01111100
  byte 0b01000100
  byte 0b01000100
  byte 0b00000000

  ; S letter:
  byte 0b00000000
  byte 0b00111100
  byte 0b01000000
  byte 0b00111000
  byte 0b00000100
  byte 0b01000100
  byte 0b00111000
  byte 0b00000000

; D letter:
  byte 0b00000000
  byte 0b01111100
  byte 0b01000010
  byte 0b01000010
  byte 0b01000010
  byte 0b01000010
  byte 0b01111100
  byte 0b00000000

; F letter:
  byte 0b00000000
  byte 0b01111100
  byte 0b01000000
  byte 0b01111000
  byte 0b01000000
  byte 0b01000000
  byte 0b01000000
  byte 0b00000000

  ; G letter:
  byte 0b00000000
  byte 0b00111000
  byte 0b01000100
  byte 0b01000000
  byte 0b01001100
  byte 0b01000100
  byte 0b00111000
  byte 0b00000000

; H letter:
  byte 0b00000000
  byte 0b01000100
  byte 0b01000100
  byte 0b01111100
  byte 0b01000100
  byte 0b01000100
  byte 0b01000100
  byte 0b00000000

; J letter:
  byte 0b00000000
  byte 0b01111100
  byte 0b00000100
  byte 0b00000100
  byte 0b00000100
  byte 0b01000100
  byte 0b00111000
  byte 0b00000000

; K letter:
  byte 0b00000000
  byte 0b01000100
  byte 0b01001000
  byte 0b01110000
  byte 0b01001000
  byte 0b01000100
  byte 0b01000100
  byte 0b00000000
  
; L letter:
  byte 0b00000000
  byte 0b01000000
  byte 0b01000000
  byte 0b01000000
  byte 0b01000000
  byte 0b01000000
  byte 0b01111100
  byte 0b00000000

; Z letter:
  byte 0b00000000
  byte 0b01111100
  byte 0b00001000
  byte 0b00010000
  byte 0b00010000
  byte 0b00100000
  byte 0b01111100
  byte 0b00000000

; X letter:
  byte 0b00000000
  byte 0b01000100
  byte 0b00101000
  byte 0b00010000
  byte 0b00101000
  byte 0b01000100
  byte 0b01000100
  byte 0b00000000

; C letter:
  byte 0b00000000
  byte 0b00111000
  byte 0b01000100
  byte 0b01000000
  byte 0b01000000
  byte 0b01000100
  byte 0b00111000
  byte 0b00000000

; V letter:
  byte 0b00000000
  byte 0b01000100
  byte 0b01000100
  byte 0b00101000
  byte 0b00101000
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000

; B letter:
  byte 0b00000000
  byte 0b01111000
  byte 0b01000100
  byte 0b01111000
  byte 0b01000100
  byte 0b01000100
  byte 0b01111000
  byte 0b00000000

; N letter:
  byte 0b00000000
  byte 0b01000100
  byte 0b01100100
  byte 0b01010100
  byte 0b01010100
  byte 0b01001100
  byte 0b01000100
  byte 0b00000000

; M letter:
  byte 0b00000000
  byte 0b01000100
  byte 0b01101100
  byte 0b01010100
  byte 0b01010100
  byte 0b01000100
  byte 0b01000100
  byte 0b00000000

; arrow up:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; arrow down:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; arrow left:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; arrow right:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; ... character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b01010100
  byte 0b00000000

; _ character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b01111100
  byte 0b00000000

; number 1:
  byte 0b00000000
  byte 0b00010000
  byte 0b00110000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00111000
  byte 0b00000000

; number 2:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00000100
  byte 0b00011000
  byte 0b00100000
  byte 0b00111100
  byte 0b00000000

; number 3:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00001000
  byte 0b00000100
  byte 0b00100100
  byte 0b00011000
  byte 0b00000000

; number 4:
  byte 0b00000000
  byte 0b00001000
  byte 0b00010000
  byte 0b00100000
  byte 0b00101000
  byte 0b00111100
  byte 0b00001000
  byte 0b00000000

; number 5:
  byte 0b00000000
  byte 0b00111100
  byte 0b00100000
  byte 0b00011000
  byte 0b00000100
  byte 0b00100100
  byte 0b00011000
  byte 0b00000000

; number 6:
  byte 0b00000000
  byte 0b00011100
  byte 0b00100000
  byte 0b00111000
  byte 0b00100100
  byte 0b00100100
  byte 0b00011000
  byte 0b00000000

; number 7:
  byte 0b00000000
  byte 0b00111100
  byte 0b00000100
  byte 0b00001000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000

; number 8:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00011000
  byte 0b00100100
  byte 0b00100100
  byte 0b00011000
  byte 0b00000000

; number 9:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00100100
  byte 0b00011100
  byte 0b00000100
  byte 0b00111000
  byte 0b00000000

; number 0:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00101100
  byte 0b00110100
  byte 0b00100100
  byte 0b00011000
  byte 0b00000000

; < character:
  byte 0b00000000
  byte 0b00001000
  byte 0b00010000
  byte 0b00100000
  byte 0b00010000
  byte 0b00001000
  byte 0b00000000
  byte 0b00000000

; > character:
  byte 0b00000000
  byte 0b00100000
  byte 0b00010000
  byte 0b00001000
  byte 0b00010000
  byte 0b00100000
  byte 0b00000000
  byte 0b00000000

; = character:
  byte 0b00000000
  byte 0b00000000
  byte 0b01111100
  byte 0b00000000
  byte 0b01111100
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; + character:
  byte 0b00000000
  byte 0b00010000
  byte 0b00010000
  byte 0b01111100
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000
  byte 0b00000000

; - character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b01111100
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; * character:
  byte 0b00000000
  byte 0b00010000
  byte 0b01010100
  byte 0b00111000
  byte 0b01010100
  byte 0b00010000
  byte 0b00000000
  byte 0b00000000

; / character:
  byte 0b00000000
  byte 0b00000010
  byte 0b00000100
  byte 0b00001000
  byte 0b00010000
  byte 0b00100000
  byte 0b01000000
  byte 0b00000000

; ( character:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100000
  byte 0b00100000
  byte 0b00100000
  byte 0b00100000
  byte 0b00011000
  byte 0b00000000

; ) character:
  byte 0b00000000
  byte 0b00110000
  byte 0b00001000
  byte 0b00001000
  byte 0b00001000
  byte 0b00001000
  byte 0b00110000
  byte 0b00000000

; ! character:
  byte 0b00000000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000

; ? character:
  byte 0b00000000
  byte 0b00011000
  byte 0b00100100
  byte 0b00001000
  byte 0b00010000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000

; " character:
  byte 0b00000000
  byte 0b00101000
  byte 0b00101000
  byte 0b00101000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000

; : character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000
  byte 0b00000000

; ; character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000
  byte 0b00010000
  byte 0b00010000
  byte 0b00100000

; . character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00010000
  byte 0b00000000

; , character:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00001000
  byte 0b00010000

; }
