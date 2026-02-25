module sd (
  input clk,

  // IO interface
  output [15:0] sd_data_out,
  input  [15:0] sd_data_inp,
  input  [15:0] sd_adr,
  input  [1:0]  byte_en,
  input         sd_we,

  // SD / CPU communication
  //input [15:0] sd_block_adr,
  //input sd_read_block,
  //input sd_save_block,
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
  if (clk_div_cnt - 16'd1 == 16'd0) begin
    SD_CLK = ~SD_CLK;
    clk_div_cnt <= clk_div_cnt;
  end else begin
    clk_div_cnt <= clk_div_cnt - 16'd1;
  end
end


// SD states
localparam sd_rst_del = 4'h0;
localparam sd_rst = 4'h1;
localparam wait_for_rst_r1 = 4'h2;
localparam check_rst_r1 = 4'h3;
localparam sd_volt = 4'h4;
localparam wait_for_volt_r1 = 4'h5;
localparam check_volt_r1 = 4'h6;
localparam sd_app = 4'h7;
localparam wait_for_app_r1 = 4'h8;
localparam check_app_r1 = 4'h9;
localparam sd_init = 4'hA;
localparam wait_for_init_r1 = 4'hB;
localparam check_init_r1 = 4'hC;
localparam idle = 4'hD;


// Clock Frequency
localparam clk_div = 16'd54; // Divides by 54*2 (54 + only on posedge)
localparam clk_freq = 32'd27000000 / (clk_div*2); // Normal (250kHz)
localparam cycles_in_ms = clk_freq / 32'd1000;


// Mapped SD Card Block / Sector (512B)
block block_1 (
  .clk (clk),

  // RAM interface
  .ram_data_rd (sd_data_out),
  .ram_data_wr (sd_data_inp),
  .ram_adr     (sd_adr),
  .byte_en     (byte_en),
  .ram_we      (sd_we)
);


// Registers
reg [3:0] state = sd_rst_del;
reg [15:0] bit_cnt = 16'd0;
reg [15:0] idx_cnt = 16'd0;
reg [31:0] del_cnt = cycles_in_ms * 1000;
reg [7:0] r1_response;

localparam  rst_cmd = 48'h400000000095;
localparam volt_cmd = 48'h48000001AA87;
localparam  app_cmd = 40'h7700000000;
localparam init_cmd = 40'h6940000000;


always @(*) begin
  if (state == sd_rst) begin
    SD_DI = rst_cmd[bit_cnt];
  end else if (state == sd_volt) begin
    SD_DI = volt_cmd[bit_cnt];
  end else if (state == sd_app) begin
    SD_DI = app_cmd[bit_cnt];
  end else if (state == sd_init) begin
    SD_DI = init_cmd[bit_cnt];
  end else begin
    SD_DI = 1'b1;
  end
end


initial r1_response = 8'hFF;


always @(posedge SD_CLK) begin
  if (state == sd_rst_del) begin
    if (del_cnt != 32'd0) begin
      del_cnt <= del_cnt - 32'd1;
    end else begin
      bit_cnt <= 16'd47;
      SD_CS <= 1'b0;
      state <= sd_rst;
    end
  end else if (state == sd_rst) begin
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
      state <= sd_volt;
    end else begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
    end
  end else if (state == sd_volt) begin
    if (bit_cnt != 16'd0) begin
      bit_cnt <= bit_cnt - 16'd1;
    end else begin
      bit_cnt <= 16'd39;
      state <= wait_for_volt_r1;
    end
  end else if (state == wait_for_volt_r1) begin
    if (SD_DO == 1'b0) begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
      state <= check_volt_r1;
    end
  end else if (state == check_volt_r1) begin
    if (bit_cnt == 16'd0) begin
      bit_cnt <= 16'd39;
      state <= sd_app;
    end else begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
    end
  end else if (state == sd_app) begin
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
      state <= sd_init;
    end else begin
      r1_response[bit_cnt] <= SD_DO;
      bit_cnt <= bit_cnt - 16'd1;
    end
  end else if (state == sd_init) begin
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
        state <= sd_app;
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

  end
end

endmodule
