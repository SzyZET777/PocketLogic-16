# PocketLogic-16
Simple, 16-bit computer made in Verilog with a custom CPU



Specs:
> 27MHz clock (the default on Tang Nano, but it could be higher)
> Simple, 16-bit CPU with 0.5IPC (not pipelined)
> 48KB of Work RAM
> 128x80 double-buffered graphics with 64 colors



Memory Map:
> Memory: (48KB)
 (0x0000 – 0x3FFF) 16KB - System ROM/RAM
 (0x4000 – 0x7FFF) 16KB - User RAM
 (0x8000 – 0xBFFF) 16KB - Dynamic Memory (heap&stack)
 
> Input/Output: (12KB)
 (0xC000 – 0xE7FF) 10.0KB - Video RAM (128x80 @6bpp)
 (0xE800 – 0xE9FF)  0.5KB - SD Block (1 block)
 (0xEA00 - 0xEFFF)  1.5KB - Empty (Reserved Space)
 (0xF000 – 0xFFFF)  4.0KB - IO Ports (2048x 16b-ports)

 

ISA:
> Notes:
 - All operations work on 16-bit numbers
 - There are no flags, all results are saved in registers
 - Words must be aligned to a 2-byte boundary


> Registers (16x 16-bit)
 (0x0-0x3) a0-a3 - function arguments
 (0x4-0x7) t0-t3 - temporary registers (caller saved)
 (0x8-0xB) s0-s3 - saved registers (callee saved)
     (0xC)    bp - stack base pointer
     (0xD)    sp - stack top pointer
     (0xE)    rv - return value
     (0xF)    ra - return address

    
> Instructions:
  > Group 0 - 2-Register ALU operation:
    > Arithmetic & Logic: 
      (0x00XY) - mov rX, rY  :  rX = rY
      (0x01XY) - and rX, rY  :  rX = rX & rY
      (0x02XY) - ior rX, rY  :  rX = rX | rY
      (0x03XY) - xor rX, rY  :  rX = rX ^ rY
      (0x04XY) - shl rX, rY  :  rX = rX << rY
      (0x05XY) - shr rX, rY  :  rX = rX >> rY
      (0x06XY) - add rX, rY  :  rX = rX + rY
      (0x07XY) - sub rX, rY  :  rX = rX - rY
    > Comparisons:
      (0x08XY) - equ rX, rY  :  rX = (rX == rY)
      (0x09XY) - dif rX, rY  :  rX = (rX != rY)
      (0x0AXY) - low rX, rY  :  rX = (unsigned) (rX < rY)
      (0x0BXY) - hig rX, rY  :  rX = (unsigned) (rX > rY)
      (0x0CXY) - lst rX, rY  :  rX = (signed) (rX < rY)
      (0x0DXY) - grt rX, rY  :  rX = (signed) (rX > rY)
      (0x0EXY) - lte rX, rY  :  rX = (signed) (rX <= rY)
      (0x0FXY) - gte rX, rY  :  rX = (signed) (rX ?= rY)

  > Group 1 - Register and 4-bit Immediate ALU operations:
    > Arithmetic & Logic:
      (0x10XI) - mov rX, I  :  rX = I
      (0x11XI) - and rX, I  :  rX = rX & I
      (0x12XI) - ior rX, I  :  rX = rX | I
      (0x13XI) - xor rX, I  :  rX = rX ^ I
      (...) (same as group 0)
   > Comparisons:
      (0x18XI) - equ rX, I  :  rX = (rX == I)
      (0x19XI) - dif rX, I  :  rX = (rX != I)
      (0x1AXI) - low rX, I  :  rX = (unsigned) (rX < I)
      (0x1BXI) - hig rX, I  :  rX = (unsigned) (rX > I)
      (...) (same as group 0)

  > Group 2 - Load / Store operations:
    > Load:
      (0x20XY) - ldb rX, [rY]  :  rX = memory[rY]
      (0x21XY) - ldw rX, [rY]  :  rX = memory[rY]
    > Store:
      (0x22XY) - stb rX, [rY]  :  memory[rY] = rX
      (0x23XY) - stw rX, [rY]  :  memory[rY] = rX

  > Group 3 - Jumps and full immediates:
    > Full immediate operations:
      (0x30X0'0xIIII) - ldi rX, IIII  :  rX = IIII
      (0x31X0'0xIIII) - adi rX, IIII  :  rX = rX + IIII
      (0x32X0'0xIIII) - eqi rX, IIII  :  rX = (rX == IIII)
      (0x33X0'0xIIII) - dfi rX, IIII  :  rX = (rX != IIII)
    > Jumps & Branches:
      (0x3000'0xIIII) - jmp IIII      :  pc = IIII
      (0x3100'0xIIII) - brc rX, IIII  :  if (rX != 0) pc = IIII
      (0x32X0'0xIIII) - jsr rX, IIII  :  rX = pc ; pc = IIII
      (0x33X0'0xIIII) - ret rX,       :  pc = rX

