; Kernelspace Code:
  sector 0x0000


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

filtered_files_list_size:
  byte 0

caps_lock_on_str:
  text "ABC"

caps_lock_off_str:
  text "abc"

file_type_str:
  text "app:"

text_buffer:
  reserve 160

text_color_buffer:
  reserve 160

filtered_files_list:
  reserve 2048


; func main () {
main:
  ldi sp, 0xC000

  jsr ra, buzzer_test

  mov a0, 0
  jsr ra, save_program_to_sd

  ldi a0, file_type_str
  jsr ra, filter_files

loop:
  jsr ra, update_cursor_pos
  jsr ra, update_caps_lock

  ldi a0, 0b101010
  jsr ra, clear_screen

  ldi a0, 0b000011
  ldi a1, title_bar_str
  jsr ra, draw_title_bar

  jsr ra, draw_caps_lock
  jsr ra, draw_app_menu

  ; jsr ra, user_main

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

  ldi t0, text_buffer
  adi t0, 46
  mov t1, 0
  stb t1, [t0]

  ldi t0, app_menu_pos
  ldw t0, [t0]
  equ t0, 0
  brc t0, app_menu_arrow_up_skip

  ldi t0, text_buffer
  adi t0, 46
  ldi t1, 0x20
  stb t1, [t0]

app_menu_arrow_up_skip:

  ldi t0, text_buffer
  adi t0, 126
  mov t1, 0
  stb t1, [t0]

  ldi t0, app_menu_pos
  ldw t0, [t0]
  add t0, 6
  ldi t1, filtered_files_list_size
  ldb t1, [t1]
  equ t0, t1
  brc t0, app_menu_arrow_down_skip

  ldi t0, filtered_files_list_size
  ldb t0, [t0]
  lte t0, 6
  brc t0, app_menu_arrow_down_skip

  ldi t0, text_buffer
  adi t0, 126
  ldi t1, 0x21
  stb t1, [t0]

app_menu_arrow_down_skip:

  ldi t2, 0
app_menu_text_loop_y:
  ldi t3, 0
app_menu_text_loop_x:
  mov t0, t2
  ldi t1, app_menu_pos
  ldw t1, [t1]
  add t0, t1
  shl t0, 5
  adi t0, filtered_files_list
  add t0, t3

  ldb t1, [t0]

  mov t0, t2
  shl t0, 4
  adi t0, text_buffer
  add t0, t3
  adi t0, 33
  
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
  ldw t0, [t0]
  equ t0, 0
  brc t0, wait_for_cursor_up_release

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
  ldw t0, [t0]
  add t0, 6
  ldi t1, filtered_files_list_size
  ldb t1, [t1]
  equ t0, t1
  brc t0, wait_for_cursor_down_release

  ldi t0, app_menu_pos
  ldw t1, [t0]
  add t1, 1
  stw t1, [t0]

  jmp wait_for_cursor_down_release

move_cursor_down:
  ldi t0, filtered_files_list_size
  ldb t0, [t0]
  ldi t1, cursor_pos
  ldb t1, [t1]
  sub t0, 1
  lte t0, t1
  brc t0, wait_for_cursor_down_release

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


; func update_caps_lock () {
update_caps_lock:
  ldi t0, KEYBOARD
  ldw t0, [t0]
  dif t0, 2
  brc t0, caps_lock_not_pressed
  ldi t0, caps_lock_on
  ldb t1, [t0]
  xor t1, 1
  stb t1, [t0]
wait_for_caps_lock_release:
  ldi t0, KEYBOARD
  ldw t0, [t0]
  equ t0, 2
  brc t0, wait_for_caps_lock_release
caps_lock_not_pressed:
  ret ra
; }


; func wait_for_sd () {
wait_for_sd:
  ldi t0, 0xF012
wait_for_sd_loop:
  ldw t1, [t0]
  brc t1, wait_for_sd_loop
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


; func save_program_to_sd (#file_index) {
save_program_to_sd:
  sub sp, 2
  stw ra, [sp]

  shl a0, 5

  jsr ra, wait_for_sd

  mov t2, 0
save_program_to_sd_block_loop:
  ldi t0, 0xF016
  mov t1, a0
  add t1, t2
  stw t1, [t0]

  mov t3, 0
save_program_to_sd_adr_loop:
  mov t0, t2
  add t0, a0
  shl t0, 9
  add t0, t3
  adi t0, user_main
  ldw t1, [t0]

  ldi t0, SD_CARD_BLOCK
  add t0, t3
  stw t1, [t0]

  add t3, 2
  mov t0, t3
  dfi t0, 512
  brc t0, save_program_to_sd_adr_loop

  ldi t0, 0xF014
  mov t1, 1
  stw t1, [t0]
  jsr ra, wait_for_sd

  add t2, 1
  mov t0, t2
  dfi t0, 32
  brc t0, save_program_to_sd_block_loop

  ldw ra, [sp]
  add sp, 2
  
  ret ra
; }


; func filter_files (*file_type_str) {
filter_files:
  sub sp, 2
  stw ra, [sp]
  sub sp, 2
  stw s0, [sp]
  sub sp, 2
  stw s1, [sp]

  ldi t0, filtered_files_list_size
  mov t1, 0
  stb t1, [t0]

  mov s0, 0
clear_filtered_files_list:
  ldi t0, filtered_files_list
  add t0, s0
  mov t1, 0
  stw t1, [t0]
  add s0, 2
  mov t0, s0
  dfi t0, 2048
  brc t0, clear_filtered_files_list

  jsr ra, wait_for_sd

  mov t3, 0
  mov s0, 0
filter_files_block_loop:
  ldi t0, 0xF016
  stw s0, [t0]

  ldi t0, 0xF010
  mov t1, 1
  stw t1, [t0]

  jsr ra, wait_for_sd

  mov s1, 0
filter_files_adr_loop:
  ldi t0, SD_CARD_BLOCK
  add t0, s1
  ldw t1, [t0]
  ldw t2, [a0]
  dif t1, t2
  brc t1, filter_files_skip
  add t0, 2
  add a0, 2
  ldw t1, [t0]
  ldw t2, [a0]
  sub a0, 2
  dif t1, t2
  brc t1, filter_files_skip

  mov t2, 0
filter_files_copy_loop:
  ldi t0, SD_CARD_BLOCK
  add t0, s1
  add t0, t2
  ldw t1, [t0]

  ldi t0, filtered_files_list
  add t0, t3
  add t0, t2
  stw t1, [t0]

  add t2, 2
  mov t0, t2
  dfi t0, 32
  brc t0, filter_files_copy_loop

  ldi t0, filtered_files_list_size
  ldb t1, [t0]
  add t1, 1
  stb t1, [t0]

  adi t3, 32
  
filter_files_skip:
  adi s1, 32
  mov t0, s1
  dfi t0, 512
  brc t0, filter_files_adr_loop

  add s0, 1
  mov t0, s0
  dfi t0, 32
  brc t0, filter_files_block_loop

  ldw s1, [sp]
  add sp, 2
  ldw s0, [sp]
  add sp, 2
  ldw ra, [sp]
  add sp, 2

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
  byte 0b00010000
  byte 0b00111000
  byte 0b01010100
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000

; arrow down:
  byte 0b00000000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b01010100
  byte 0b00111000
  byte 0b00010000
  byte 0b00000000

; arrow left:
  byte 0b00000000
  byte 0b00010000
  byte 0b00100000
  byte 0b01111110
  byte 0b00100000
  byte 0b00010000
  byte 0b00000000
  byte 0b00000000

; arrow right:
  byte 0b00000000
  byte 0b00001000
  byte 0b00000100
  byte 0b01111110
  byte 0b00000100
  byte 0b00001000
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
  byte 0b00100000
  byte 0b00000000
  byte 0b00100000
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
  byte 0b00010000
  byte 0b00111000
  byte 0b01010100
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b00000000

; arrow down:
  byte 0b00000000
  byte 0b00010000
  byte 0b00010000
  byte 0b00010000
  byte 0b01010100
  byte 0b00111000
  byte 0b00010000
  byte 0b00000000

; arrow left:
  byte 0b00000000
  byte 0b00010000
  byte 0b00100000
  byte 0b01111110
  byte 0b00100000
  byte 0b00010000
  byte 0b00000000
  byte 0b00000000

; arrow right:
  byte 0b00000000
  byte 0b00001000
  byte 0b00000100
  byte 0b01111110
  byte 0b00000100
  byte 0b00001000
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
  byte 0b00100000
  byte 0b00000000
  byte 0b00100000
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


; Userspace Code:
  sector 0x4000


; func user_main () {
user_main:
  text "app:test_000"
  reserve 20
  text "dat:test_001"
  reserve 20
  text "apk:test_002"
  reserve 20
  text "tmp:test_003"
  reserve 20
  text "app:test_004"
  reserve 20
  text "png:test_005"
  reserve 20
  text "jpg:test_006"
  reserve 20
  text "app:test_007"
  reserve 20
  text "app:test_008"
  reserve 20
  text "dat:test_009"
  reserve 20
  text "apk:test_010"
  reserve 20
  text "tmp:test_011"
  reserve 20
  text "app:test_012"
  reserve 20
  text "png:test_013"
  reserve 20
  text "jpg:test_014"
  reserve 20
  text "apk:test_015"
  reserve 20
  text "app:test_016"
  reserve 20
  text "dat:test_017"
  reserve 20
  text "apk:test_018"
  reserve 20
  text "tmp:test_019"
  reserve 20
  text "app:test_020"
  reserve 20
  text "png:test_021"
  reserve 20
  text "jpg:test_022"
  reserve 20
  text "app:test_023"
  reserve 20
  text "app:test_024"
  reserve 20
  text "dat:test_025"
  reserve 20
  text "apk:test_026"
  reserve 20
  text "tmp:test_027"
  reserve 20
  text "app:test_028"
  reserve 20
  text "png:test_029"
  reserve 20
  text "jpg:test_030"
  reserve 20
  text "app:test_031"
  reserve 20
; }
