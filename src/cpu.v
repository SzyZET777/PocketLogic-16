module cpu (
  input clk,

  // Memory interface
  input      [15:0] mem_data_rd,
  output reg [15:0] mem_data_wr,
  output reg [15:0] mem_adr,
  output reg [1:0]  byte_en,
  output reg        mem_we
);


// CPU states
localparam id = 2'b00;
localparam ex = 2'b01;
localparam rst = 2'b10;

// Opcode groups
localparam grp_rr = 4'h0; // Register and Register
localparam grp_ri = 4'h1; // Register and Immediate
localparam grp_ls = 4'h2; // Load and Store
localparam grp_jc = 4'h3; // Jump Control

// Opcodes
localparam opc_mov = 4'h0;
localparam opc_and = 4'h1;
localparam opc_ior = 4'h2;
localparam opc_xor = 4'h3;
localparam opc_shl = 4'h4;
localparam opc_shr = 4'h5;
localparam opc_add = 4'h6;
localparam opc_sub = 4'h7;

localparam opc_equ = 4'h8;
localparam opc_dif = 4'h9;
localparam opc_low = 4'hA;
localparam opc_hig = 4'hB;
localparam opc_lst = 4'hC;
localparam opc_grt = 4'hD;
localparam opc_lte = 4'hE;
localparam opc_gte = 4'hF;

localparam opc_ldb = 4'h0;
localparam opc_ldw = 4'h1;
localparam opc_stb = 4'h2;
localparam opc_stw = 4'h3;

localparam opc_ldi = 4'h0;
localparam opc_adi = 4'h1;
localparam opc_eqi = 4'h2;
localparam opc_dfi = 4'h3;
localparam opc_jmp = 4'h4;
localparam opc_brc = 4'h5;
localparam opc_jsr = 4'h6;
localparam opc_ret = 4'h7;


// ID temporary wires
wire [3:0] grp_tmp = mem_data_rd[15:12];
wire [3:0] opc_tmp = mem_data_rd[11:8];
wire [3:0] reg1_tmp = mem_data_rd[7:4];
wire [3:0] reg2_tmp = mem_data_rd[3:0];
wire [3:0] imm_tmp = mem_data_rd[3:0];


// RAM address decode logic
always @(*) begin
  if (state == id && grp_tmp == grp_ls) mem_adr = reg2_val;
  else if (state == id && grp_tmp == grp_jc) mem_adr = pc;
  else if (state == ex && grp == grp_jc) mem_adr = jump_target;
  else mem_adr = pc;
end


// Writing data to Memory
always @(*) begin
  if (state == id && grp_tmp == grp_ls && opc_tmp == opc_stb) begin
    mem_we = 1'b1;
    mem_data_wr = {reg1_val[7:0], reg1_val[7:0]};
    byte_en[0] = mem_adr[0] == 0; // mem_data_wr[15:8];
    byte_en[1] = mem_adr[0] == 1; // mem_data_wr[7:0];
  end else if (state == id && grp_tmp == grp_ls && opc_tmp == opc_stw) begin
    mem_we = 1'b1;
    mem_data_wr = reg1_val;
    byte_en[0] = 1'b1;
    byte_en[1] = 1'b1;
  end else begin
    mem_we = 1'b0;
    mem_data_wr = 16'h0000;
    byte_en[0] = 1'b0;
    byte_en[1] = 1'b0;
  end
end


// Main state machine
reg [15:0] src1 = 16'h0;
reg [15:0] src2 = 16'h0;
reg [3:0] grp = 4'h0;
reg [3:0] opc = 4'h0;
reg [3:0] dest = 4'h0;
reg [1:0] state = rst;
reg [15:0] rst_cnt = 16'd1000;

always @(posedge clk) begin
  if (state == id) begin
    grp <= grp_tmp;
    opc <= opc_tmp;
    dest <= reg1_tmp;
    src1 <= reg1_val;
    src2 <= (grp_tmp == grp_ri) ? imm_tmp : reg2_val;
    state <= ex;
  end else if (state == ex || state == rst) begin
    state <= id;
  end
end


// Arithmetic Logic Unit
reg [15:0] alu_out;

always @(*) begin
  case (opc)
    opc_mov : alu_out = src2;
    opc_and : alu_out = src1 & src2;
    opc_ior : alu_out = src1 | src2;
    opc_xor : alu_out = src1 ^ src2;
    opc_shl : alu_out = src1 << src2;
    opc_shr : alu_out = src1 >> src2;
    opc_add : alu_out = src1 + src2;
    opc_sub : alu_out = src1 - src2;

    opc_equ : alu_out = src1 == src2;
    opc_dif : alu_out = src1 != src2;
    opc_low : alu_out = src1 < src2;
    opc_hig : alu_out = src1 > src2;
    opc_lst : alu_out = $signed(src1) < $signed(src2);
    opc_grt : alu_out = $signed(src1) > $signed(src2);
    opc_lte : alu_out = $signed(src1) <= $signed(src2);
    opc_gte : alu_out = $signed(src1) >= $signed(src2);

    default : alu_out = src1; // reg1 = reg1 (NOP)
  endcase
end


// Load Store Unit
reg [15:0] lsu_out;

always @(*) begin
  case (opc)
    opc_ldb : lsu_out = mem_byte_rd;
    opc_ldw : lsu_out = mem_data_rd;

    default : lsu_out = src1; // reg1 = reg1 (NOP)
  endcase
end


// Jump Control Unit
reg [15:0] jcu_out;

always @(*) begin
  case (opc)
    opc_ldi : jcu_out = mem_data_rd;
    opc_adi : jcu_out = src1 + mem_data_rd;
    opc_eqi : jcu_out = src1 == mem_data_rd;
    opc_dfi : jcu_out = src1 != mem_data_rd;
    opc_jsr : jcu_out = next_pc;

    default : jcu_out = src1; // reg1 = reg1 (NOP)
  endcase
end


// Register file
reg [15:0] registers [15:0];
reg [15:0] reg1_val, reg2_val;

always @(*) begin
  if (state == id) begin
    reg1_val = registers[reg1_tmp];
    reg2_val = registers[reg2_tmp];
  end else begin
    reg1_val = 16'h0000;
    reg2_val = 16'h0000;
  end
end

always @(posedge clk) begin
  if (state == ex) begin
    case (grp)
      grp_rr : registers[dest] <= alu_out;
      grp_ri : registers[dest] <= alu_out;
      grp_ls : registers[dest] <= lsu_out;
      grp_jc : registers[dest] <= jcu_out;
    endcase
  end
end


// Program counter
reg [15:0] pc = 16'h0000;
reg [15:0] jump_target;
reg [15:0] next_pc;

always @(posedge clk) begin
  if (state == id) next_pc <= pc + 16'h0002;
end

always @(*) begin
  case (opc)
    opc_ldi : jump_target = pc + 16'h0002;
    opc_adi : jump_target = pc + 16'h0002;
    opc_eqi : jump_target = pc + 16'h0002;
    opc_dfi : jump_target = pc + 16'h0002;
    opc_jmp : jump_target = mem_data_rd;
    opc_brc : jump_target = (src1) ? mem_data_rd : pc + 16'h0002;
    opc_jsr : jump_target = mem_data_rd;
    opc_ret : jump_target = src1;

    default : jump_target = 16'h0000;
  endcase
end

always @(posedge clk) begin
  if (state == rst) pc <= pc + 16'h0002;   
  else if (state == ex) begin
    if (grp == 4'h3) pc <= jump_target + 16'h0002;
    else pc <= next_pc;
  end
end


// Memory byte/word select (big-endian)
reg [7:0] mem_byte_rd;

always @(*) begin
  case (src2[0])
    1'b0 : mem_byte_rd = mem_data_rd[15:8];
    1'b1 : mem_byte_rd = mem_data_rd[7:0];
  endcase
end


endmodule
