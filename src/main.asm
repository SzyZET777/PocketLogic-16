; func main () {
main:
  ldi sp, 0xC000

; Set background color to grey:
  ldi s0, 160
set_background_color_loop:
  sub s0, 1
  ldi t0, back_color_buffer
  add t0, s0
  ldi t1, 0b101010
  stb t1, [t0]
  brc s0, set_background_color_loop

; Set text box color to white:
  ldi s0, 64
set_text_box_color_loop:
  sub s0, 1
  ldi t0, back_color_buffer
  add t0, s0
  ldi t1, 0b111111
  stb t1, [t0]
  brc s0, set_text_box_color_loop

  mov s0, 0
loop:
; Draw line cursor (0x04):
  ldi t0, text_buffer
  add t0, s0
  ldi t1, 0x04
  stb t1, [t0]

; Set cursor color to blue (0x03):
  ldi t0, front_color_buffer
  add t0, s0
  mov t1, 0b11
  stb t1, [t0]

  ldi t0, 0xF00A
  ldw s1, [t0]
  mov t0, s1
  equ t0, 0
  brc t0, skip

  ldi t0, 0xF004
  ldi t1, 300
  stw t1, [t0]

wait_for_key_release:
  ldi t0, 0xF00A
  ldw t1, [t0]
  brc t1, wait_for_key_release

  ldi t0, 0xF004
  ldw t1, [t0]

  ldi t0, text_buffer
  add t0, s0
  equ t1, 0
  shl t1, 5
  add s1, t1
  stb s1, [t0]

; Set new character color to black (0x00):
  ldi t0, front_color_buffer
  add t0, s0
  mov t1, 0
  stb t1, [t0]

  add s0, 1
  ldi t0, 0x3F
  and s0, t0

skip:

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
  adi t0, 0xC000
  stb a2, [t0]
  ret ra
; }


; func print_char (#x, #y, #col_f, #col_b, #char) {
print_char:
  ldw t0, [sp]
  add sp, 2

  sub sp, 2
  stw ra, [sp]
  sub sp, 2
  stw s0, [sp]
  sub sp, 2
  stw s1, [sp]
  sub sp, 2
  stw s2, [sp]
  sub sp, 2
  stw s3, [sp]

  mov s3, t0

  shl a0, 3
  shl a1, 3
  shl s3, 3

  mov s0, 8
print_char_loop_y:
  sub s0, 1
  
  ldi t0, char_table
  add t0, s3
  add t0, s0
  ldb s2, [t0]

  mov s1, 8
print_char_loop_x:
  sub s1, 1

  ; Foreground color if S2 & 1 == 1
  mov t0, s2
  and t0, 1
  
  sub sp, 2
  stw a2, [sp]

  brc t0, print_char_skip
  
  mov a2, a3

print_char_skip:

  ; Call draw_pixel Function

  add a0, s1
  add a1, s0

  jsr ra, draw_pixel

  sub a0, s1
  sub a1, s0

  ldw a2, [sp]
  add sp, 2

  shr s2, 1

  brc s1, print_char_loop_x
  brc s0, print_char_loop_y

  ldw s3, [sp]
  add sp, 2
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

  ldi t0, front_color_buffer
  add t0, t1
  ldb a2, [t0]

  ldi t0, back_color_buffer
  add t0, t1
  ldb a3, [t0]

  ldi t0, text_buffer
  add t0, t1
  ldb t0, [t0]

  sub sp, 2
  stw t0, [sp]

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

; delete:
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

; block cursor:
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
  byte 0b00000000
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


; data text_buffer {
text_buffer:
  reserve 160
; }

; data front_color_buffer  {
front_color_buffer:
  reserve 160
; }

; data back_color_buffer {
back_color_buffer:
  reserve 160
; }

