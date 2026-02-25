module block ( 
  input clk,

  // RAM interface
  output reg [15:0] ram_data_rd,
  input      [15:0] ram_data_wr,
  input      [15:0] ram_adr,
  input      [1:0]  byte_en,
  input             ram_we
);

// RAM depth calculation
localparam depth = 512 * 8 / 16;

reg [15:0] memory [0:depth-1];

always @(posedge clk) begin
  if (ram_we) begin
    if (byte_en[0]) memory[ram_adr[15:1]][15:8] <= ram_data_wr[15:8];
    if (byte_en[1]) memory[ram_adr[15:1]][7:0] <= ram_data_wr[7:0];
  end else begin
    ram_data_rd <= memory[ram_adr[15:1]];
  end
end

initial begin
  ram_data_rd <= 16'h0000;
end

endmodule
