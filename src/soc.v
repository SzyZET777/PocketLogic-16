module soc (
  // General
  input clk,

  // External IO
  input  [9:0] KEYBOARD_COL,
  output [2:0] KEYBOARD_ROW,
  output [5:0] LEDS,
  output       LCD_CLK,
  output       LCD_DIN,
  output       LCD_CS,
  output       LCD_DC,
  output       BUZZER
);


// Memory Select Values
localparam ram_sel = 1'b0;
localparam io_sel = 1'b1;


// Wires
wire [15:0] mem_data_wr, mem_adr, ram_data_rd, io_data_inp;
wire [1:0] byte_en;
wire mem_we;


// RAM / IO Select
reg [15:0] mem_data_rd;
reg mem_sel = ram_sel;

always @(posedge clk) begin
  mem_sel <= (mem_adr < 16'hC000) ? ram_sel : io_sel;
end

always @(*) begin
  if (mem_sel == ram_sel) begin
    mem_data_rd = ram_data_rd;
  end else begin
    mem_data_rd = io_data_inp;
  end
end


// Main CPU
cpu main_cpu (
  .clk (clk),

  // Memory interface
  .mem_data_rd (mem_data_rd),
  .mem_data_wr (mem_data_wr),
  .mem_adr     (mem_adr),
  .byte_en     (byte_en),
  .mem_we      (mem_we)
);


// Work RAM
wram wram (
  .clk (clk),

  // RAM interface
  .ram_data_rd (ram_data_rd),
  .ram_data_wr (mem_data_wr),
  .ram_adr     (mem_adr),
  .byte_en     (byte_en),
  .ram_we      (mem_we)
);


// IO controller
io io_controller (
  .clk (clk),

  // IO interface
  .io_data_inp (io_data_inp),
  .io_data_out (mem_data_wr),
  .io_port     (mem_adr),
  .byte_en     (byte_en),
  .io_we       (mem_we),

  // Keybaord IO
  .KEYBOARD_COL (KEYBOARD_COL),
  .KEYBOARD_ROW (KEYBOARD_ROW),

  // LEDs IO
  .LEDS (LEDS),

  // LCD IO
  .LCD_CLK (LCD_CLK),
  .LCD_DIN (LCD_DIN),
  .LCD_CS  (LCD_CS),
  .LCD_DC  (LCD_DC),

  // Buzzer IO
  .BUZZER (BUZZER)
);


endmodule
