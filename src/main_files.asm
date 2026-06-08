; Kernelspace Code:
  sector 0x0000


; Start main:
  jmp main


; def constants {
  define FRAMEBUFFER, 0xC000
  define SD_CARD_BLOCK, 0xE800
  define LEDS, 0xF000
  define MS_TIMER, 0xF004
  define KEYBOARD, 0xF00A
  define BUTTONS, 0xF00E
  define SD_CARD_BLOCK_ADR, 0xF016
  define BUTTON_U, 0
  define BUTTON_D, 1
  define BUTTON_L, 2
  define BUTTON_R, 3
  define BUTTON_ENT, 4
  define BUTTON_ESC, 5
  define BUTTON_F1, 6
  define BUTTON_F2, 7
; }


; data global_variables_and_buffers {
  caps_lock_on: 
    byte 0

  title_bar_str:
    text "PocketLogic-16"
    byte 0

  cursor_pos:
    word 0

  app_menu_pos:
    word 0

  filtered_files_list_size:
    word 0

  caps_lock_on_str:
    text "ABC"

  caps_lock_off_str:
    text "abc"

  file_type_str:
    text "app:"

  tmp_str:
    reserve 128

  text_buffer:
    reserve 160

  text_color_buffer:
    reserve 160

  filtered_files_list:
    reserve 1024
; }


; func main () {
  main:
    ldi sp, 0xC000

    jsr ra, buzzer_test

    mov a0, 0
    jsr ra, save_program_to_sd

  exit_from_an_app:
    mov a0, 0
    ldi a1, file_type_str
    jsr ra, filter_files

  loop:
    jsr ra, load_and_run_app
    jsr ra, update_cursor_pos
    jsr ra, update_caps_lock

    ldi a0, 0b101010
    jsr ra, clear_screen
    jsr ra, clear_text_buffer

    mov a0, 0b11
    ldi a1, title_bar_str
    jsr ra, draw_title_bar

    jsr ra, draw_caps_lock
    mov a0, 0b11
    jsr ra, draw_file_menu

    jsr ra, draw_text_buffer
    jsr ra, refresh_screen

    jmp loop

  end_main:
    jmp end_main
; }

; func clamp_signed_var (*var, #min, #max) {
  clamp_signed_var:
    ldw t0, [a0]
    grt t0, a1
    brc t0, clamp_signed_var_skip_1
    stw a1, [a0]
  clamp_signed_var_skip_1:
    ldw t0, [a0]
    lst t0, a2
    brc t0, clamp_signed_var_skip_2
    stw a2, [a0]
  clamp_signed_var_skip_2:
    ret ra
; }

; func clamp_unsigned_var (*var, #min, #max) {
  clamp_unsigned_var:
    ldw t0, [a0]
    hig t0, a1
    brc t0, clamp_unsigned_var_skip_1
    stw a1, [a0]
  clamp_unsigned_var_skip_1:
    ldw t0, [a0]
    low t0, a2
    brc t0, clamp_unsigned_var_skip_2
    stw a2, [a0]
  clamp_unsigned_var_skip_2:
    ret ra
; }

; func jump_if_button_pressed (#button, *label_pressed, *label_not_pressed) {
  jump_if_button_pressed:
    ldi t0, BUTTONS
    ldw t0, [t0]
    shr t0, a0
    and t0, 1
    brc t0, button_pressed_wait

    ret a2 ; Not pressed

  button_pressed_wait: 
    ldi t0, BUTTONS
    ldw t0, [t0]
    shr t0, a0
    and t0, 1
    dif t0, 0
    brc t0, button_pressed_wait

    ret a1 ; Pressed
; }

; func get_key () -> (#key) {
  get_key:
    ldi t0, KEYBOARD
    ldw t0, [t0]
    mov rv, t0
    equ t0, 0
    brc t0, key_not_pressed
    mov t0, rv
    equ t0, 2
    brc t0, key_not_pressed
    ldi t0, MS_TIMER
    ldi t1, 300
    stw t1, [t0]
  wait_for_key_release:
    ldi t0, KEYBOARD
    ldw t0, [t0]
    brc t0, wait_for_key_release
    ldi t0, MS_TIMER
    ldw t1, [t0]
    equ t1, 0
    shl t1, 5
    add rv, t1
  key_not_pressed:
    ret ra
; }

; func get_title_str (#file_index, *title_str) {
  get_title_str:
    sub sp, 2
    stw ra, [sp]

    ; Get #real_file_index from filtered_files_list
    shl a0, 1
    adi a0, filtered_files_list
    ldw a0, [a0]

    ; Get title from SD_CARD
    ldi t0, SD_CARD_BLOCK_ADR
    mov t1, a0
    shr t1, 4
    stw t1, [t0]

    ldi t0, 0xF010
    mov t1, 1
    stw t1, [t0]

    jsr ra, wait_for_sd

    shl a0, 5
    adi a0, SD_CARD_BLOCK
    
    ldi t1, 32
  get_title_str_loop:
    sub t1, 1
    mov t2, a0
    add t2, t1
    ldb t2, [t2]
    mov t3, a1
    add t3, t1
    stb t2, [t3]
    brc t1, get_title_str_loop

    ldw ra, [sp]
    add sp, 2
    ret ra
}

; func print_str (#pos, *str, #limit, #ellipsis) {
  print_str:
    sub sp, 2
    stw ra, [sp]

    adi a0, text_buffer
    
    mov t1, 0
  print_str_loop:
    mov t2, a1
    add t2, t1
    ldb t2, [t2]
    mov t0, t2
    equ t0, 0
    brc t0, print_str_skip
    mov t3, a0
    add t3, t1
    stb t2, [t3]
    add t1, 1
    mov t0, t1
    dif t0, a2
    brc t0, print_str_loop

    equ a3, 0
    brc a3, print_char_skip

    mov t3, a0
    add t3, a2
    sub t3, 1
    ldi t1, 0x24
    stb t1, [t3]

  print_str_skip:
    ldw ra, [sp]
    add sp, 2
    ret ra
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

; func clear_text_buffer () {
  clear_text_buffer:
    ldi t0, 160
    mov t2, 5
  clear_text_buffer_loop:
    sub t0, 1
    mov t1, t0
    adi t1, text_buffer
    stb t2, [t1]
    mov t1, t0
    adi t1, text_color_buffer
    stb t2, [t1]
    brc t0, clear_text_buffer_loop
    ret ra
; }

; func draw_title_bar (#col, *str) {
  draw_title_bar:
    sub sp, 2
    stw ra, [sp]
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

    mov a0, 0
    ldi a2, 16
    mov a3, 1
    jsr ra, print_str

    ldw s0, [sp]
    add sp, 2
    ldw ra, [sp]
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

; func reset_menu_pos () {
  reset_menu_pos:
    mov t0, 0
    ldi t1, cursor_pos
    stw t0, [t1]
    ldi t1, app_menu_pos
    stw t0, [t1] 
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

; func draw_caps_lock () {
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

; func draw_file_menu_cursor (#color) {
  draw_file_menu_cursor:
    sub sp, 2
    stw ra, [sp]

    mov a3, a0
    ldi a0, 2056 ; 128*16 + 8
    ldi t0, cursor_pos
    ldw t0, [t0]
    shl t0, 10
    add a0, t0
    ldi a1, 112 ; 128-16
    ldi a2, 8
    jsr ra, draw_rect

    ldi t0, cursor_pos
    ldw t2, [t0]
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

    ldw ra, [sp]
    add sp, 2

    ret ra
; }

; func draw_file_menu_arrows () {
  draw_file_menu_arrows:
    ldi t0, app_menu_pos
    ldw t0, [t0]
    equ t0, 0
    brc t0, app_menu_arrow_up_skip

    ldi t0, text_buffer
    adi t0, 46
    ldi t1, 0x20
    stb t1, [t0]

  app_menu_arrow_up_skip:
    ldi t0, app_menu_pos
    ldw t0, [t0]
    add t0, 6
    ldi t1, filtered_files_list_size
    ldw t1, [t1]
    equ t0, t1
    brc t0, app_menu_arrow_down_skip

    ldi t0, filtered_files_list_size
    ldw t0, [t0]
    lte t0, 6
    brc t0, app_menu_arrow_down_skip

    ldi t0, text_buffer
    adi t0, 126
    ldi t1, 0x21
    stb t1, [t0]

  app_menu_arrow_down_skip:
    ret ra
}

; func draw_file_menu (#col) {
  draw_file_menu:
    sub sp, 2
    stw ra, [sp]
    sub sp, 2
    stw s0, [sp]

    mov s0, a0
    jsr ra, draw_standard_window
    mov a0, s0
    jsr ra, draw_file_menu_cursor
    jsr ra, draw_file_menu_arrows

    ldi s0, 0
  app_menu_text_loop_y:
  
    mov a0, s0
    ldi t1, app_menu_pos
    ldw t1, [t1]
    add a0, t1
    ldi a1, tmp_str
    jsr ra, get_title_str

    mov a0, s0
    shl a0, 4
    adi a0, 33
    ldi a1, tmp_str
    mov a2, 13
    mov a3, 1
    jsr ra, print_str

  app_menu_text_loop_skip:
    add s0, 1
    mov t0, s0
    dif t0, 6
    brc t0, app_menu_text_loop_y

    ldi a0, text_buffer
    ldi a1, filtered_files_list_size
    ldw a1, [a1]
    ; jsr ra, word_to_hex

    ldw s0, [sp]
    add sp, 2
    ldw ra, [sp]
    add sp, 2

    ret ra
; }

; func draw_standard_window () {
  draw_standard_window:
    sub sp, 2
    stw ra, [sp]

    ldi a0, 2056 ; 128*16 + 8
    ldi a1, 112 ; 128-16
    ldi a2, 48 ; 8*6
    ldi a3, 0b111111
    jsr ra, draw_rect

    mov a3, 0
    jsr ra, draw_rect_outline

    ldw ra, [sp]
    add sp, 2

    ret ra
}

; func cursor_up (*cursor_pos, *menu_pos) {
  cursor_up:
    ldw t1, [a0]
    dif t1, 0
    brc t1, cursor_up_move

    ldw t0, [a1]
    equ t0, 0
    brc t0, cursor_up_return

    ldw t1, [a1]
    sub t1, 1
    stw t1, [a1]
    ret ra

  cursor_up_move:
    ldw t1, [a0]
    sub t1, 1
    stw t1, [a0]

  cursor_up_return:
    ret ra
}

; func cursor_down (*cursor_pos, *menu_pos, *menu_size) {
  cursor_down:
    ldw t1, [a0]
    dif t1, 5
    brc t1, cursor_down_move

    ldw t0, [a1]
    add t0, 6
    ldw t1, [a2]
    equ t0, t1
    brc t0, cursor_down_return

    ldw t1, [a1]
    add t1, 1
    stw t1, [a1]
    ret ra

  cursor_down_move:
    ldw t0, [a2]
    ldw t1, [a0]
    sub t0, 1
    lte t0, t1
    brc t0, cursor_down_return

    ldw t1, [a0]
    add t1, 1
    stw t1, [a0]

  cursor_down_return:
    ret ra
}

; func update_cursor_pos () {
  update_cursor_pos:
    sub sp, 2
    stw ra, [sp]

    ldi a0, BUTTON_U
    ldi a1, move_cursor_up
    ldi a2, dont_move_cursor_up
    jsr ra, jump_if_button_pressed

  move_cursor_up:
    ldi a0, cursor_pos
    ldi a1, app_menu_pos
    jsr ra, cursor_up

  dont_move_cursor_up:

    ldi a0, BUTTON_D
    ldi a1, move_cursor_down
    ldi a2, dont_move_cursor_down
    jsr ra, jump_if_button_pressed

  move_cursor_down:
    ldi a0, cursor_pos 
    ldi a1, app_menu_pos
    ldi a2, filtered_files_list_size    
    jsr ra, cursor_down

  dont_move_cursor_down:
    ldw ra, [sp]
    add sp, 2

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

; func buzzer_test () {
  buzzer_test:
    ldi t2, 2000
    ldi t0, 0xF00C
    stw t2, [t0]

    ldi t0, MS_TIMER
    ldi t1, 500 ; 500ms
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
    ldi t0, SD_CARD_BLOCK_ADR
    mov t1, a0
    add t1, t2
    stw t1, [t0]

    mov t3, 0
  save_program_to_sd_adr_loop:
    mov t0, t2
    shl t0, 9
    add t0, t3
    adi t0, user_start
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

; func load_program_from_sd (#file_index) {
  load_program_from_sd:
    sub sp, 2
    stw ra, [sp]

    shl a0, 5

    jsr ra, wait_for_sd

    mov t2, 0
  load_program_from_sd_block_loop:
    ldi t0, SD_CARD_BLOCK_ADR
    mov t1, a0
    add t1, t2
    stw t1, [t0]

    ldi t0, 0xF010
    mov t1, 1
    stw t1, [t0]
    jsr ra, wait_for_sd

    mov t3, 0
  load_program_from_sd_adr_loop:
    ldi t0, SD_CARD_BLOCK
    add t0, t3
    ldw t1, [t0]

    mov t0, t2
    shl t0, 9
    add t0, t3
    adi t0, user_start
    stw t1, [t0]

    add t3, 2
    mov t0, t3
    dfi t0, 512
    brc t0, load_program_from_sd_adr_loop

    add t2, 1
    mov t0, t2
    dfi t0, 32
    brc t0, load_program_from_sd_block_loop

    ldw ra, [sp]
    add sp, 2
    
    ret ra
; }

; func filter_files (#skip_type_check, *file_type_str) {
  filter_files:
    sub sp, 2
    stw ra, [sp]
    sub sp, 2
    stw s0, [sp]
    sub sp, 2
    stw s1, [sp]

    jsr ra, reset_menu_pos

    ldi t0, filtered_files_list_size
    mov t1, 0
    stw t1, [t0]

    mov s0, 0
  clear_filtered_files_list:
    ldi t0, filtered_files_list
    add t0, s0
    mov t1, 0
    stw t1, [t0]
    add s0, 2
    mov t0, s0
    dfi t0, 1024
    brc t0, clear_filtered_files_list

    jsr ra, wait_for_sd

    mov t3, 0
    mov s0, 0
  filter_files_block_loop:
    ldi t0, SD_CARD_BLOCK_ADR
    stw s0, [t0]

    ldi t0, 0xF010
    mov t1, 1
    stw t1, [t0]

    jsr ra, wait_for_sd

    mov s1, 0
  filter_files_adr_loop:
    brc a0, type_skip
    ldi t0, SD_CARD_BLOCK
    add t0, s1
    ldw t1, [t0]
    ldw t2, [a1]
    dif t1, t2
    brc t1, filter_files_skip
    add t0, 2
    add a1, 2
    ldw t1, [t0]
    ldw t2, [a1]
    sub a1, 2
    dif t1, t2
    brc t1, filter_files_skip
    jmp type_checked

  type_skip:
    ldi t0, SD_CARD_BLOCK
    add t0, s1
    ldw t1, [t0]
    equ t1, 0
    brc t1, filter_files_skip
    add t0, 2
    ldw t1, [t0]
    equ t1, 0
    brc t1, filter_files_skip

  type_checked:
    mov t1, s0
    shl t1, 4
    mov t2, s1
    shr t2, 5
    add t1, t2

    ldi t0, filtered_files_list
    add t0, t3
    stw t1, [t0]

    adi t3, 2
    shr t3, 1
    ldi t0, filtered_files_list_size
    stw t3, [t0]
    shl t3, 1
    
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

; func load_and_run_app () {
  load_and_run_app:
    sub sp, 2
    stw ra, [sp]

    ldi a0, BUTTON_ENT
    ldi a1  load_and_run_app_ok
    ldi a2, load_and_run_app_skip
    jsr ra, jump_if_button_pressed

  load_and_run_app_ok: 
    ldi a0, cursor_pos
    ldw a0, [a0]
    ldi t2, app_menu_pos
    ldw t2, [t2]
    add a0, t2
    shl a0, 1
    adi a0, filtered_files_list
    ldw a0, [a0]

    jsr ra, load_program_from_sd
    jsr ra, user_start

    jmp exit_from_an_app

  load_and_run_app_skip:
    ldw ra, [sp]
    add sp, 2

    ret ra
; }


; data char_table {
  char_table:

  ; null:
    byte 0b00000000
    byte 0b01100100
    byte 0b01010100
    byte 0b01010110
    byte 0b00000000
    byte 0b01111110
    byte 0b00000000
    byte 0b00000000

  ; new line:
    byte 0b00000000
    byte 0b00000010
    byte 0b00010010
    byte 0b00100010
    byte 0b01111100
    byte 0b00100000
    byte 0b00010000
    byte 0b00000000

  ; caps lock:
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
    byte 0b01100100
    byte 0b01010100
    byte 0b01010110
    byte 0b00000000
    byte 0b01111110
    byte 0b00000000
    byte 0b00000000

  ; new line:
    byte 0b00000000
    byte 0b00000010
    byte 0b00010010
    byte 0b00100010
    byte 0b01111100
    byte 0b00100000
    byte 0b00010000
    byte 0b00000000

  ; caps lock:
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

user_start:
text "sys:files_list"
reserve 18
text "app:buzzer_test"
reserve 17
text "app:char_editor"
reserve 17
text "app:test_001"
reserve 20
text "app:test_002"
reserve 20
text "app:test_003"
reserve 20
text "app:test_004"
reserve 20
text "app:test_005"
reserve 20
text "tmp:test_006"
reserve 20
text "app:test_007"
reserve 20
text "tmp:test_008"
reserve 20
text "app:test_009"
reserve 20
