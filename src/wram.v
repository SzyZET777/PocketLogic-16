module wram ( 
  input clk,

  // RAM interface
  output reg [15:0] ram_data_rd,
  input      [15:0] ram_data_wr,
  input      [15:0] ram_adr,
  input      [1:0]  byte_en,
  input             ram_we
);

// RAM depth calculation
localparam depth = 16 * 1024 * 8 / 16;

reg [15:0] memory_0 [0:depth-1];
reg [15:0] memory_1 [0:depth-1];
reg [15:0] memory_2 [0:depth-1];


always @(posedge clk) begin
  if (ram_we) begin
    if (byte_en[0] && ram_adr[15:14] == 2'b00) memory_0[ram_adr[13:1]][15:8] <= ram_data_wr[15:8];
    if (byte_en[1] && ram_adr[15:14] == 2'b00) memory_0[ram_adr[13:1]][7:0] <= ram_data_wr[7:0];
    if (byte_en[0] && ram_adr[15:14] == 2'b01) memory_1[ram_adr[13:1]][15:8] <= ram_data_wr[15:8];
    if (byte_en[1] && ram_adr[15:14] == 2'b01) memory_1[ram_adr[13:1]][7:0] <= ram_data_wr[7:0];
    if (byte_en[0] && ram_adr[15:14] == 2'b10) memory_2[ram_adr[13:1]][15:8] <= ram_data_wr[15:8];
    if (byte_en[1] && ram_adr[15:14] == 2'b10) memory_2[ram_adr[13:1]][7:0] <= ram_data_wr[7:0];
  end else begin
    case (ram_adr[15:14])
      2'b00 : ram_data_rd <= memory_0[ram_adr[15:1]];
      2'b01 : ram_data_rd <= memory_1[ram_adr[15:1]];
      2'b10 : ram_data_rd <= memory_2[ram_adr[15:1]];
      2'b11 : ram_data_rd <= 16'h0000;
    endcase
  end
end


initial begin
  ram_data_rd <= 16'h0000;
  $readmemh("asm_out_0.txt", memory_0);
  $readmemh("asm_out_1.txt", memory_1);
end

endmodule
