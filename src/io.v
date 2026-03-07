module io (
  input clk,

  // IO interface
  output reg [15:0] io_data_inp,
  input      [15:0] io_data_out,
  input      [15:0] io_port,
  input      [1:0]  byte_en,
  input             io_we,

  // Keybaord IO
  input  [9:0] KEYBOARD_COL,
  output [2:0] KEYBOARD_ROW,

  // LEDs IO
  output [5:0] LEDS,

  // LCD IO
  output LCD_CS,
  output LCD_CLK,
  output LCD_DIN,
  output LCD_DC,

  // Buzzer IO
  output BUZZER,

  // Buttons IO
  input BUTTON_U,
  input BUTTON_D,
  input BUTTON_L,
  input BUTTON_R,
  input BUTTON_ENT,
  input BUTTON_ESC,
  input BUTTON_F1,
  input BUTTON_F2,

  // SD IO
  input SD_DO,
  output SD_DI,
  output SD_CS,
  output SD_CLK
);


// Clock frequency
localparam clk_mhz = 16'd27;
localparam clk_khz = 16'd27000;

// IO ports
localparam lcd_ports_start = 16'hC000;
localparam lcd_ports_end = 16'hE800;
localparam sd_ports_start = 16'hE800;
localparam sd_ports_end = 16'hEA00;
localparam leds_port = 16'hF000;
localparam us_timer_port = 16'hF002;
localparam ms_timer_port = 16'hF004;
localparam cpu_frame_ready_port = 16'hF006;
localparam gpu_busy_port = 16'hF008;
localparam keyboard_port = 16'hF00A;
localparam buzzer_port = 16'hF00C;
localparam buttons_port = 16'hF00E;
localparam sd_read_block_port = 16'hF010;
localparam sd_busy_port = 16'hF012;
localparam sd_save_block_port = 16'hF014;


// IO input mux
reg [15:0] io_data_inp_tmp;
reg [1:0] io_sel = 2'b00;

always @(posedge clk) begin
  if (io_port < lcd_ports_end) begin
    io_sel <= 2'b00;
  end else if (io_port < sd_ports_end) begin
    io_sel <= 2'b01;
  end else begin
    io_sel <= 2'b11;
  end
end

always @(*) begin
  if (io_sel == 2'b00) io_data_inp = gpu_data_out;
  else if (io_sel == 2'b01) io_data_inp = sd_data_out;
  else io_data_inp = io_data_inp_tmp;
end

always @(posedge clk) begin
  case (io_port)
    us_timer_port : io_data_inp_tmp <= us_timer;
    ms_timer_port : io_data_inp_tmp <= ms_timer;
    cpu_frame_ready_port : io_data_inp_tmp <= cpu_frame_ready;
    gpu_busy_port : io_data_inp_tmp <= gpu_busy | cpu_frame_ready;
    keyboard_port : io_data_inp_tmp <= keyboard_data_out;
    buttons_port : io_data_inp_tmp <= buttons_reg;
    sd_busy_port : io_data_inp_tmp <= sd_busy | sd_read_block | sd_save_block;
    default : io_data_inp_tmp <= 16'h0000;
  endcase    
end


// Main GPU (0xC000 – 0xE7FF)
wire [15:0] gpu_data_out;
wire gpu_we = (io_port >= lcd_ports_start && io_port < lcd_ports_end) ? io_we : 1'b0;
wire gpu_busy;
reg cpu_frame_ready;

gpu main_gpu (
  .clk (clk),

  // IO interface
  .gpu_data_out (gpu_data_out),
  .gpu_data_inp (io_data_out),
  .gpu_adr      (io_port-lcd_ports_start),
  .byte_en      (byte_en),
  .gpu_we       (gpu_we),

  // GPU / CPU communication
  .cpu_frame_ready (cpu_frame_ready),
  .gpu_busy (gpu_busy),

  // LCD IO
  .LCD_CLK (LCD_CLK),
  .LCD_DIN (LCD_DIN),
  .LCD_CS  (LCD_CS),
  .LCD_DC  (LCD_DC)
);


// GPU / CPU communication
always @(posedge clk) begin
  if (cpu_frame_ready == 1'b0) begin
    if (io_port == cpu_frame_ready_port && io_we && !gpu_busy) begin
      cpu_frame_ready <= io_data_out[0];
    end
  end else begin
    if (gpu_busy) cpu_frame_ready <= 1'b0;
  end
end


// LEDs (0xF000)
reg [5:0] leds_reg = 6'b000000;

always @(posedge clk) begin
  if (io_port == leds_port && io_we) leds_reg <= io_data_out[5:0];
end

assign LEDS = ~DEBUG_OUT[5:0]; // ~leds_reg;


// Microsecond timer (0xF002)
reg [15:0] cycle_us_timer = 16'd0;
reg [15:0] us_timer = 16'd0;

always @(posedge clk) begin
  if (cycle_us_timer == 16'd0) cycle_us_timer <= clk_mhz;
  else cycle_us_timer <= cycle_us_timer - 16'd1;
end

always @(posedge clk) begin
  if (io_port == us_timer_port && io_we) begin
    us_timer <= io_data_out;
  end else if (us_timer != 16'd0 && cycle_us_timer == 16'd0) begin
    us_timer <= us_timer - 16'd1;
  end
end


// Millisecond timer (0xF004)
reg [15:0] cycle_ms_timer = 16'd0;
reg [15:0] ms_timer = 16'd0;

always @(posedge clk) begin
  if (cycle_ms_timer == 16'd0) cycle_ms_timer <= clk_khz;
  else cycle_ms_timer <= cycle_ms_timer - 16'd1;
end

always @(posedge clk) begin
  if (io_port == ms_timer_port && io_we) begin
    ms_timer <= io_data_out;
  end else if (ms_timer != 16'd0 && cycle_ms_timer == 16'd0) begin
    ms_timer <= ms_timer - 16'd1;
  end
end


// Keyboard (0xF00A)
reg [15:0] cycle_keybaord_timer = 16'd0;
reg [15:0] keyboard_data_out = 16'h00;
reg [15:0] keyboard_data_tmp_0 = 16'h00;
reg [15:0] keyboard_data_tmp_1 = 16'h00;
reg [15:0] keyboard_data_tmp_2 = 16'h00;
reg [2:0] row_enable = 3'b001;

always @(posedge clk) begin
  if (cycle_ms_timer == 16'd0) begin
    cycle_keybaord_timer <= clk_khz;

    if (buttons_reg[4]) begin
      keyboard_data_out <= 16'h01;
    end else if (buttons_reg[0]) begin
      keyboard_data_out <= 16'h20;
    end else if (buttons_reg[1]) begin
      keyboard_data_out <= 16'h21;
    end else if (buttons_reg[2]) begin 
      keyboard_data_out <= 16'h22;
    end else if (buttons_reg[3]) begin
      keyboard_data_out <= 16'h23;
    end else if (keyboard_data_tmp_0 != 16'h00) begin
      keyboard_data_out <= keyboard_data_tmp_0;
    end else if (keyboard_data_tmp_1 != 16'h00) begin
      keyboard_data_out <= keyboard_data_tmp_1;
    end else if (keyboard_data_tmp_2 != 16'h00) begin
      keyboard_data_out <= keyboard_data_tmp_2;
    end else begin
      keyboard_data_out <= 16'h00;
    end

    case (row_enable)
      3'b001 : row_enable <= 3'b010;
      3'b010 : row_enable <= 3'b100;
      3'b100 : row_enable <= 3'b001;
      default : row_enable <= 3'b001;
    endcase
  end else begin
    cycle_keybaord_timer <= cycle_keybaord_timer - 16'd1;
  end
end

always @(posedge clk) begin
  if (row_enable == 3'b001) begin
         if (~KEYBOARD_COL[0]) keyboard_data_tmp_0 <= 16'h06;
    else if (~KEYBOARD_COL[1]) keyboard_data_tmp_0 <= 16'h07;
    else if (~KEYBOARD_COL[2]) keyboard_data_tmp_0 <= 16'h08;
    else if (~KEYBOARD_COL[3]) keyboard_data_tmp_0 <= 16'h09;
    else if (~KEYBOARD_COL[4]) keyboard_data_tmp_0 <= 16'h0A;
    else if (~KEYBOARD_COL[5]) keyboard_data_tmp_0 <= 16'h0B;
    else if (~KEYBOARD_COL[6]) keyboard_data_tmp_0 <= 16'h0C;
    else if (~KEYBOARD_COL[7]) keyboard_data_tmp_0 <= 16'h0D;
    else if (~KEYBOARD_COL[8]) keyboard_data_tmp_0 <= 16'h0E;
    else if (~KEYBOARD_COL[9]) keyboard_data_tmp_0 <= 16'h0F;
    else keyboard_data_tmp_0 <= 16'h00;
  end else if (row_enable == 3'b010) begin
         if (~KEYBOARD_COL[1]) keyboard_data_tmp_1 <= 16'h10;
    else if (~KEYBOARD_COL[2]) keyboard_data_tmp_1 <= 16'h11;
    else if (~KEYBOARD_COL[3]) keyboard_data_tmp_1 <= 16'h12;
    else if (~KEYBOARD_COL[4]) keyboard_data_tmp_1 <= 16'h13;
    else if (~KEYBOARD_COL[5]) keyboard_data_tmp_1 <= 16'h14;
    else if (~KEYBOARD_COL[6]) keyboard_data_tmp_1 <= 16'h15;
    else if (~KEYBOARD_COL[7]) keyboard_data_tmp_1 <= 16'h16;
    else if (~KEYBOARD_COL[8]) keyboard_data_tmp_1 <= 16'h17;
    else if (~KEYBOARD_COL[9]) keyboard_data_tmp_1 <= 16'h18;
    else keyboard_data_tmp_1 <= 16'h00;
  end else if (row_enable == 3'b100) begin
         if (~KEYBOARD_COL[0]) keyboard_data_tmp_2 <= 16'h02;
    else if (~KEYBOARD_COL[1]) keyboard_data_tmp_2 <= 16'h19;
    else if (~KEYBOARD_COL[2]) keyboard_data_tmp_2 <= 16'h1A;
    else if (~KEYBOARD_COL[3]) keyboard_data_tmp_2 <= 16'h1B;
    else if (~KEYBOARD_COL[4]) keyboard_data_tmp_2 <= 16'h1C;
    else if (~KEYBOARD_COL[5]) keyboard_data_tmp_2 <= 16'h1D;
    else if (~KEYBOARD_COL[6]) keyboard_data_tmp_2 <= 16'h1E;
    else if (~KEYBOARD_COL[7]) keyboard_data_tmp_2 <= 16'h1F;
    else if (~KEYBOARD_COL[8]) keyboard_data_tmp_2 <= 16'h05;
    else if (~KEYBOARD_COL[9]) keyboard_data_tmp_2 <= 16'h03;
    else keyboard_data_tmp_2 <= 16'h00;
  end
end

assign KEYBOARD_ROW[0] = ~row_enable[0];
assign KEYBOARD_ROW[1] = ~row_enable[1];
assign KEYBOARD_ROW[2] = ~row_enable[2];


// Buzzer (0xF00C)
reg [15:0] buzzer_period = 16'd0;
reg [15:0] buzzer_cnt = 16'd0;
reg [7:0] buzzer_clk_div = clk_mhz;
reg buzzer_reg = 1'b0;

always @(posedge clk) begin
  if (io_port == buzzer_port && io_we) buzzer_period <= (io_data_out>>1);
end

always @(posedge clk) begin
  if (buzzer_clk_div - 8'd1 == 0) begin
    if (buzzer_cnt - 16'd1 == 0) begin
      buzzer_cnt <= buzzer_period;
      buzzer_reg <= ~buzzer_reg;
    end else begin
      if (buzzer_period != 16'd0) buzzer_cnt <= buzzer_cnt - 16'd1;
    end 
    buzzer_clk_div <= clk_mhz;
  end else begin
    buzzer_clk_div <= buzzer_clk_div - 8'd1;
  end
end

assign BUZZER = buzzer_reg;


// Buttons (0xF00E)
reg [7:0] buttons_reg;

always @(*) begin
  buttons_reg[0] = ~BUTTON_U;
  buttons_reg[1] = ~BUTTON_D;
  buttons_reg[2] = ~BUTTON_L;
  buttons_reg[3] = ~BUTTON_R;
  buttons_reg[4] = ~BUTTON_ENT;
  buttons_reg[5] = ~BUTTON_ESC;
  buttons_reg[6] = ~BUTTON_F1;
  buttons_reg[7] = ~BUTTON_F2;
end


// SD Card
wire [15:0] sd_data_out;
wire sd_we = (io_port >= sd_ports_start && io_port < sd_ports_end) ? io_we : 1'b0;
wire sd_busy;
reg sd_read_block = 1'b0, sd_save_block = 1'b0;

wire [7:0] DEBUG_OUT;

sd sd_controller (
  .clk (clk),

  // IO interface
  .sd_data_out (sd_data_out),
  .sd_data_inp (io_data_out),
  .sd_adr      (io_port-sd_ports_start),
  .byte_en     (byte_en),
  .sd_we       (sd_we),

  // SD / CPU communication
  .sd_read_block (sd_read_block),
  .sd_save_block (sd_save_block),
  .sd_busy (sd_busy),

  // DEBUG
  .DEBUG_OUT (DEBUG_OUT),

  // SD IO
  .SD_DI (SD_DI),
  .SD_DO (SD_DO),
  .SD_CS (SD_CS),
  .SD_CLK (SD_CLK)
);

// SD / CPU communication
always @(posedge clk) begin
  if (sd_read_block == 1'b0) begin
    if (io_port == sd_read_block_port && io_we && !sd_busy) begin
      sd_read_block <= io_data_out[0];
    end
  end else begin
    if (sd_busy) sd_read_block <= 1'b0;
  end
end

always @(posedge clk) begin
  if (sd_save_block == 1'b0) begin
    if (io_port == sd_save_block_port && io_we && !sd_busy) begin
      sd_save_block <= io_data_out[0];
    end
  end else begin
    if (sd_busy) sd_save_block <= 1'b0;
  end
end


endmodule
