module gpu (
  input clk,

  // IO interface
  output reg [15:0] gpu_data_out,
  input      [15:0] gpu_data_inp,
  input      [15:0] gpu_adr,
  input      [1:0]  byte_en,
  input             gpu_we,

  // GPU / CPU communication
  input cpu_frame_ready,
  output reg gpu_busy,

  // LCD IO
  output reg LCD_CLK,
  output reg LCD_DIN,
  output reg LCD_CS,
  output reg LCD_DC
);


// IO Interface
initial LCD_CLK <= 1'b0;
initial LCD_CS <= 1'b0;

initial gpu_busy <= 1'b1;

always @(posedge clk) LCD_CLK = ~LCD_CLK;
// always @(*) LCD_CLK = clk;

wire [15:0] ram_data_rd_1, ram_data_rd_2;

reg [15:0] ram_data_rd_tmp, ram_data_rd, gpu_adr_1, gpu_adr_2;
reg buffer_num = buffer_1;
reg vram_we, vram_we_1, vram_we_2;

always @(*) begin
  if (buffer_num == buffer_1) begin
    ram_data_rd_tmp = ram_data_rd_1;
    gpu_data_out = ram_data_rd_2;
    gpu_adr_1 = {idx_cnt[15:9], idx_cnt[7:1]};
    gpu_adr_2 = gpu_adr;
    vram_we_1 = 1'b0;
    vram_we_2 = gpu_we;
  end else begin
    ram_data_rd_tmp = ram_data_rd_2;
    gpu_data_out = ram_data_rd_1;
    gpu_adr_1 = gpu_adr;
    gpu_adr_2 = {idx_cnt[15:9], idx_cnt[7:1]};
    vram_we_1 = gpu_we;
    vram_we_2 = 1'b0;
  end
end

always @(*) begin
  if (idx_cnt[1] == 1'b0) begin
    ram_data_rd = ram_data_rd_tmp[15:8];
  end else begin
    ram_data_rd = ram_data_rd_tmp[7:0];
  end
end

always @(*) begin
  if (mode == rst_snd || mode == rst_del) begin
    LCD_DIN = rst_seq[idx_cnt][bit_cnt];
  end else if (mode == idle) begin
    LCD_DIN = ram_wr[bit_cnt];
  end else begin
    LCD_DIN = ram_data_rd[bit_cnt>>1];
  end
end

always @(*) begin
  if (mode == rst_snd || mode == rst_del) begin 
    LCD_DC = dc[idx_cnt];
  end else if (mode == idle) begin
    LCD_DC = 1'b0;
  end else begin
    LCD_DC = 1'b1;
  end
end


// GPU states
localparam rst_snd = 2'b00;
localparam rst_del = 2'b01;
localparam idle = 2'b10;
localparam send = 2'b11;

// Clock Frequency
localparam clk_freq = 32'd27000000; // Normal (27MHz)
// localparam clk_freq = 32'd1000; // Test (1KHz)
localparam cycles_in_ms = clk_freq / 32'd1000;

// Resolution
localparam resolution = 16'd128 * 16'd80;

// Frame Buffer Numbers
localparam buffer_1 = 1'b0;
localparam buffer_2 = 1'b1;


reg [7:0]  rst_seq [18:0];
reg        dc      [18:0];
reg [31:0] delay   [18:0];

initial begin
  rst_seq[0]  = 8'b00000001; dc[0]  = 1'b0; delay[0]  = cycles_in_ms * 32'd150; // SWRESET
  rst_seq[1]  = 8'b00010001; dc[1]  = 1'b0; delay[1]  = cycles_in_ms * 32'd500; // SLPOUT
  rst_seq[2]  = 8'b00111010; dc[2]  = 1'b0; delay[2]  = cycles_in_ms * 32'd000; // COLMOD
  rst_seq[3]  = 8'b01010011; dc[3]  = 1'b1; delay[3]  = cycles_in_ms * 32'd010; // COLMOD_PARAM
  rst_seq[4]  = 8'b00110110; dc[4]  = 1'b0; delay[4]  = cycles_in_ms * 32'd000; // MADCTL
  rst_seq[5]  = 8'b10100000; dc[5]  = 1'b1; delay[5]  = cycles_in_ms * 32'd000; // MADCTL_PARAM
  rst_seq[6]  = 8'b00101010; dc[6]  = 1'b0; delay[6]  = cycles_in_ms * 32'd000; // CASET
  rst_seq[7]  = 8'b00000000; dc[7]  = 1'b1; delay[7]  = cycles_in_ms * 32'd000; // CASET_PARAM_1
  rst_seq[8]  = 8'b00100000; dc[8]  = 1'b1; delay[8]  = cycles_in_ms * 32'd000; // CASET_PARAM_2
  rst_seq[9]  = 8'b00000001; dc[9]  = 1'b1; delay[9]  = cycles_in_ms * 32'd000; // CASET_PARAM_3
  rst_seq[10] = 8'b00011111; dc[10] = 1'b1; delay[10] = cycles_in_ms * 32'd000; // CASET_PARAM_4
  rst_seq[11] = 8'b00101011; dc[11] = 1'b0; delay[11] = cycles_in_ms * 32'd000; // RASET
  rst_seq[12] = 8'b00000000; dc[12] = 1'b1; delay[12] = cycles_in_ms * 32'd000; // RASET_PARAM_1
  rst_seq[13] = 8'b00101000; dc[13] = 1'b1; delay[13] = cycles_in_ms * 32'd000; // RASET_PARAM_2
  rst_seq[14] = 8'b00000000; dc[14] = 1'b1; delay[14] = cycles_in_ms * 32'd000; // RASET_PARAM_3
  rst_seq[15] = 8'b11000111; dc[15] = 1'b1; delay[15] = cycles_in_ms * 32'd000; // RASET_PARAM_4
  rst_seq[16] = 8'b00100001; dc[16] = 1'b0; delay[16] = cycles_in_ms * 32'd010; // INVON
  rst_seq[17] = 8'b00010011; dc[17] = 1'b0; delay[17] = cycles_in_ms * 32'd010; // NORON
  rst_seq[18] = 8'b00101001; dc[18] = 1'b0; delay[18] = cycles_in_ms * 32'd020; // DISPON
end


// VRAM 1
vram vram_1 (
  .clk (clk),

  // RAM interface
  .ram_data_rd (ram_data_rd_1),
  .ram_data_wr (gpu_data_inp),
  .ram_adr     (gpu_adr_1),
  .byte_en     (byte_en),
  .ram_we      (vram_we_1)
);


// VRAM 2
vram vram_2 (
  .clk (clk),

  // RAM interface
  .ram_data_rd (ram_data_rd_2),
  .ram_data_wr (gpu_data_inp),
  .ram_adr     (gpu_adr_2),
  .byte_en     (byte_en),
  .ram_we      (vram_we_2)
);


// Registers
reg [1:0] mode = rst_snd;
reg idle_wait = 1'b0;

reg [15:0] bit_cnt = 16'd7;
reg [15:0] idx_cnt = 16'd0;
reg [31:0] del_cnt = 16'd0;

localparam ram_wr = 8'b00101100; // RAM_WR LCD Command

// State Machine
always @(posedge LCD_CLK) begin
  if (mode == rst_del && idx_cnt == 16'd19 && del_cnt == 32'd0) begin
    LCD_CS <= 1'b1;
    bit_cnt <= 16'd7;
    gpu_busy <= 1'b0;
    idle_wait <= 1'b1;
    mode <= idle;

  end else if (mode == rst_snd) begin
    if (bit_cnt == 16'd0) begin
      bit_cnt <= 16'd7;
      idx_cnt <= idx_cnt + 16'd1;
      if (delay[idx_cnt] != 16'd0) begin
        LCD_CS <= 1'b1;
        del_cnt <= delay[idx_cnt];
        mode <= rst_del; 
      end
    end else begin
      bit_cnt <= bit_cnt - 16'd1;
    end

  end else if (mode == rst_del) begin
    if (del_cnt == 32'd0) begin
      LCD_CS <= 1'b0;
      mode <= rst_snd;
    end else begin
      del_cnt <= del_cnt - 32'd1;
    end

  end else if (mode == idle) begin
    if (idle_wait) begin
      if (cpu_frame_ready) begin
        idle_wait <= 1'b0;
        LCD_CS <= 1'b0;
        gpu_busy <= 1'b1;
      end
    end else begin
      if (bit_cnt == 16'd0) begin
        if (buffer_num == buffer_1) begin
          buffer_num <= buffer_2;
        end else begin
          buffer_num <= buffer_1;
        end

        bit_cnt <= 16'd11;
        idx_cnt <= 16'd0;
        mode <= send;
      end else begin
        bit_cnt <= bit_cnt - 16'd1;
      end
    end
  end else if (mode == send) begin
    if (bit_cnt == 16'd0) begin
      bit_cnt <= 16'd11;
      if (idx_cnt+16'd1 < 4*resolution) begin
        idx_cnt <= idx_cnt + 16'd1;
      end else begin
        LCD_CS <= 1'b1;
        bit_cnt <= 16'd7;
        idx_cnt <= 16'd0;
        gpu_busy <= 1'b0;
        idle_wait <= 1'b1;
        mode <= idle;
      end
    end else begin
      bit_cnt <= bit_cnt - 16'd1;
    end

  end
end

endmodule
