module sd (
  input clk,

  // IO interface
  output [15:0] sd_data_out,
  input  [15:0] sd_data_inp,
  input  [15:0] sd_adr,
  input  [1:0]  byte_en,
  input         sd_we,

  // SD / CPU communication
  input [15:0] sd_block_adr,
  input sd_read_block,
  input sd_save_block,
  output reg sd_busy,

  // SD IO
  input SD_DO,
  output reg SD_DI,
  output reg SD_CS,
  output reg SD_CLK
);


// IO Interface
initial SD_CLK <= 1'b0;
initial SD_CS <= 1'b1;

initial sd_busy <= 1'b1;

reg [15:0] clk_div_cnt = 16'd0;

always @(posedge clk) begin
  clk_div_cnt <= clk_div_cnt + 16'd1;
  if (clk_div_cnt >= clk_div + 16'd1) begin
    clk_div_cnt <= 16'd0;
  end
  SD_CLK <= (clk_div_cnt < clk_div/2) ? 1'b1 : 1'b0;
end


// SD states
localparam rst_del = 8'h00;
localparam send_cmd_rst = 8'h01;
localparam wait_for_rst_r1 = 8'h02;
localparam check_rst_r1 = 8'h03;
localparam send_cmd_volt = 8'h04;
localparam wait_for_volt_r7 = 8'h05;
localparam check_volt_r1 = 8'h06;
localparam send_cmd_app = 8'h07;
localparam wait_for_app_r1 = 8'h08;
localparam check_app_r1 = 8'h09;
localparam send_cmd_init = 8'h0A;
localparam wait_for_init_r1 = 8'h0B;
localparam check_init_r1 = 8'h0C;
localparam idle = 8'h0D;
localparam send_cmd_read = 8'h0E;
localparam wait_for_read_r1 = 8'h0F;
localparam check_read_r1 = 8'h10;
localparam wait_for_data_block = 8'h11;
localparam read_data_block = 8'h12;
localparam read_data_packet_crc = 8'h13;
localparam send_cmd_write = 8'h14;


// Clock Frequency
localparam clk_div = 16'd108; // Divides clock by 108
localparam clk_freq = 32'd27000000 / clk_div; // Normal (250kHz)
localparam cycles_in_ms = clk_freq / 32'd1000;


// Mapped SD Card Block / Sector (512B)
reg [15:0] block_data_inp;
reg [15:0] block_adr;
reg [1:0] block_byte_en;
reg block_we;

block block_1 (
  .clk (clk),

  // RAM interface
  .ram_data_rd (sd_data_out),
  .ram_data_wr (block_data_inp),
  .ram_adr     (block_adr),
  .byte_en     (block_byte_en),
  .ram_we      (block_we)
);


// Registers
reg [7:0] state = rst_del;
reg [15:0] bit_cnt = 16'd0;
reg [15:0] idx_cnt = 16'd0;
reg [31:0] del_cnt = cycles_in_ms * 1000;
reg [7:0] r1_response = 8'hFF;
reg [39:0] r7_response = 40'hFFFFFFFFFF;
reg [15:0] sd_data_word = 16'h1010;
reg [15:0] sd_data_word_reg = 16'h1010;
reg [15:0] block_adr_reg = 16'd0;
reg sd_data_word_ready = 1'b0;


// Commands
localparam  rst_cmd = 48'h400000000095;
localparam volt_cmd = 48'h48000001AA87;
localparam  app_cmd = 40'h7700000000;
localparam init_cmd = 40'h6940000000;
wire [39:0] read_cmd = {24'h510000, 16'h0800+sd_block_adr};


always @(*) begin
  if (state == send_cmd_rst) begin
    SD_DI = rst_cmd[bit_cnt];
  end else if (state == send_cmd_volt) begin
    SD_DI = volt_cmd[bit_cnt];
  end else if (state == send_cmd_app) begin
    SD_DI = app_cmd[bit_cnt];
  end else if (state == send_cmd_init) begin
    SD_DI = init_cmd[bit_cnt];
  end else if (state == send_cmd_read) begin
    SD_DI = read_cmd[bit_cnt];
  end else begin
    SD_DI = 1'b1;
  end
end


always @(*) begin
  if (sd_busy) begin
    block_data_inp = sd_data_word_reg;
    block_adr = block_adr_reg;
    block_byte_en = 2'b11;
    block_we = sd_data_word_ready;
  end else begin
    block_data_inp = sd_data_inp;
    block_adr = sd_adr;
    block_byte_en = byte_en;
    block_we = sd_we;
  end
end


always @(posedge SD_CLK) begin
  if (state == rst_del) begin
    if (del_cnt != 32'd0) begin
      del_cnt <= del_cnt - 32'd1;
    end else begin
      bit_cnt <= 16'd47;
      SD_CS <= 1'b0;
      state <= send_cmd_rst;
    end
  end else if (state == send_cmd_rst) begin
    if (bit_cnt != 16'd0) begin
      bit_cnt <= bit_cnt - 16'd1;
    end else begin
      bit_cnt <= 16'd7;
      state <= wait_for_rst_r1;
    end
  end else if (state == wait_for_rst_r1) begin
    if (SD_DO == 1'b0) begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
      state <= check_rst_r1;
    end
  end else if (state == check_rst_r1) begin
    if (bit_cnt == 16'd0) begin
      bit_cnt <= 16'd47;
      state <= send_cmd_volt;
    end else begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
    end
  end else if (state == send_cmd_volt) begin
    if (bit_cnt != 16'd0) begin
      bit_cnt <= bit_cnt - 16'd1;
    end else begin
      bit_cnt <= 16'd39;
      state <= wait_for_volt_r7;
    end
  end else if (state == wait_for_volt_r7) begin
    if (SD_DO == 1'b0) begin
      r7_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
      state <= check_volt_r1;
    end
  end else if (state == check_volt_r1) begin
    if (bit_cnt == 16'd0) begin
      bit_cnt <= 16'd39;
      state <= send_cmd_app;
    end else begin
      r7_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
    end
  end else if (state == send_cmd_app) begin
    if (bit_cnt != 16'd0) begin
      bit_cnt <= bit_cnt - 16'd1;
    end else begin
      bit_cnt <= 16'd7;
      state <= wait_for_app_r1;
    end
  end else if (state == wait_for_app_r1) begin
    if (SD_DO == 1'b0) begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
      state <= check_app_r1;
    end
  end else if (state == check_app_r1) begin
    if (bit_cnt == 16'd0) begin
      bit_cnt <= 16'd39;
      state <= send_cmd_init;
    end else begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
    end
  end else if (state == send_cmd_init) begin
    if (bit_cnt != 16'd0) begin
      bit_cnt <= bit_cnt - 16'd1;
    end else begin
      bit_cnt <= 16'd7;
      state <= wait_for_init_r1;
    end
  end else if (state == wait_for_init_r1) begin
    if (SD_DO == 1'b0) begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
      state <= check_init_r1;
    end
  end else if (state == check_init_r1) begin
    if (bit_cnt == 16'd0) begin
      if ({r1_response[7:1],SD_DO} != 8'h00) begin
        bit_cnt <= 16'd39;
        state <= send_cmd_app;
      end else begin
        sd_busy <= 1'b0;
        SD_CS <= 1'b1;
        state <= idle;
      end
    end else begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
    end
  end else if (state == idle) begin
    if (sd_read_block) begin
      sd_busy <= 1'b1;
      SD_CS <= 1'b0;
      bit_cnt <= 16'd39;
      state <= send_cmd_read;
    end
  end else if (state == send_cmd_read) begin
    if (bit_cnt != 16'd0) begin
      bit_cnt <= bit_cnt - 16'd1;
    end else begin
      bit_cnt <= 16'd7;
      state <= wait_for_read_r1;
    end
  end else if (state == wait_for_read_r1) begin
    if (SD_DO == 1'b0) begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
      state <= check_read_r1;
    end
  end else if (state == check_read_r1) begin
    if (bit_cnt == 16'd0) begin
      state <= wait_for_data_block;
    end else begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
    end
  end else if (state == wait_for_data_block) begin
    if (SD_DO == 1'b0) begin
      bit_cnt <= 16'd15;
      idx_cnt <= 16'd0;
      state <= read_data_block;
    end
  end else if (state == read_data_block) begin
    sd_data_word[bit_cnt] <= SD_DO;
    if (bit_cnt == 16'd0) begin
      sd_data_word_ready <= 1'b1;
      sd_data_word_reg <= {sd_data_word[15:1], SD_DO};
      block_adr_reg <= idx_cnt;
      idx_cnt <= idx_cnt + 16'd2;
      if (idx_cnt == 16'd510) begin
        bit_cnt <= 16'd15;
        state <= read_data_packet_crc;
      end else begin
        bit_cnt <= 16'd15;
      end
    end else begin
      sd_data_word_ready <= 1'b0;
      bit_cnt <= bit_cnt - 16'd1;
    end
  end else if (state == read_data_packet_crc) begin
    sd_data_word_ready <= 1'b0;
    if (bit_cnt == 16'd0) begin
      sd_busy <= 1'b0;
      SD_CS <= 1'b1;
      state <= idle;
    end else begin
      bit_cnt <= bit_cnt - 16'd1;
    end
  end
end

endmodule
