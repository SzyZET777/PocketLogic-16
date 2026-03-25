#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>



// TODO:
/*
- find and fix bugs
*/



// Defines, Enums, Structs, Constants
enum tok_type {MNEMONIC_ALU,MNEMONIC_LSU,MNEMONIC_JCU,REGISTER,DIRECTIVE,
               IMMEDIATE_4,IMMEDIATE_8,IMMEDIATE_16,SYMBOL,STRING,END};

struct token {
  enum tok_type type;
  int value;
  char string_value[128];
};

struct symbol {
  char name[128];
  int value;
};

struct instruction {
  unsigned mne_type;
  unsigned imm_type;
  unsigned group;
  unsigned opcode;
  unsigned dest_reg;
  unsigned source_reg;
  unsigned immediate;
};

char number_chars[] = {'0','1','2','3','4','5','6','7','8','9','a','b',
                       'c','d','e','f','\0'};

char skipped_chars[] = {' ',',','.','+','-',':','(',')','[',']','{','}',
                        '<','>',';','\n','\0'};

char* mnemonics_alu[] = {"mov","and","ior","xor","shl","shr","add","sub",
                         "equ","dif","low","hig","lst","grt","lte","gte","\0"};

char* mnemonics_lsu[] = {"ldb","ldw","stb","stw","\0"};

char* mnemonics_jcu[] = {"ldi","adi","eqi","dfi","jmp","brc","jsr","ret","\0"};

char* registers[] = {"a0","a1","a2","a3","t0","t1","t2","t3",
                     "s0","s1","s2","s3","bp","sp","rv","ra","\0"};

char* directives[] = {"byte", "word", "text", "reserve", "define", "sector", "\0"};

char* pl16_to_ascii = {"@@@@@ qwertyuiopasdfghjklzxcvbnm@@@@@_1234567890<>=+-*/()!?\":;.,@@@@@ QWERTYUIOPASDFGHJKLZXCVBNM@@@@@_1234567890<>=+-*/()!?\":;.,\0"};



// Global variables
FILE* source_code;
FILE* tmp_file;
FILE* output_file_0;
FILE* output_file_1;

bool negate_next_number = false;
bool tolower_next_chars = true;
int token_index = 0;
int symbol_index = 0;
int pass_num = 0;
struct token tok[32];
struct symbol sym_tab[65536];



// Functions
void open_files_for_passes(int argc, char* argv[]) {
  if (argc != 4) {
    printf("First argument should be the source code\n");
    printf("Second argument should be an output file\n");
    exit(-1);
  }

  source_code = fopen(argv[1], "r");
  tmp_file = fopen("asm_tmp.txt", "w");
  output_file_0 = fopen(argv[2], "w");
  output_file_1 = fopen(argv[3], "w");

  fprintf(tmp_file,"");
  fprintf(output_file_0,"");
  fprintf(output_file_1,"");

  fclose(tmp_file);
  tmp_file = fopen("asm_tmp.txt", "a");

  if (source_code == NULL) {
    printf("Source code file not found!\n");
    exit(-1);
  }
}


void open_files_for_output(int argc, char* argv[]) {
  tmp_file = fopen("asm_tmp.txt", "r");
  output_file_0 = fopen(argv[2], "a");
  output_file_1 = fopen(argv[3], "a");
}



void close_files() {
  fclose(source_code);
  fclose(tmp_file);
  fclose(output_file_0);
  fclose(output_file_1);
}


int find_char_in_arr(char element, char arr[]) {
  for (int i = 0; arr[i] != '\0'; i++) {
    if (element == arr[i]) return i;
  }
  return -1;
}


int find_string_in_arr(char element[], char* arr[]) {
  for (int i = 0; arr[i][0] != '\0'; i++) {
    if (strcmp(element, arr[i]) == 0) return i;
  }
  return -1;
}


int find_sym_in_sym_tab(char* name) {
  for (int i = 0; i < symbol_index; i++) {
    if (strcmp(name, sym_tab[i].name) == 0) return i;
  }
  return -1;
}

int convert_to_immediate(char arr[], int* number) {
  int index = 0;
  int base = 10;
  int multiplier = 1;

  if (arr[index] == '0') {
    if (arr[index+1] == 'x') {
      base = 16;
      index += 2;
    } else if (arr[index+1] == 'b') {
      base = 2;
      index += 2;
    }
  }

  int end = index;
  while (arr[index+1] != '\0') index++;

  *number = 0;

  for (int i = index; i >= end; i--) {
    int n = find_char_in_arr(arr[i], number_chars);
    if (n == -1 || n >= base) return -1;
    *number += n * multiplier;
    multiplier *= base;
  }
  
  if (negate_next_number) {
    *number = -*number;
  }

  if (*number >= 65536) {
    printf("Number %i doesn't fit in 16 bits!\n", *number);
    exit(-1);
  } else if (*number < -32768) {
    printf("Number %i doesn't fit in 16 bits!\n", *number);
    exit(-1);
  }

  return 0;
}


int convert_to_pl16(char chr) {
  int i = 0;
  while (pl16_to_ascii[i] != 0) {
    if (pl16_to_ascii[i] == chr) {
      return i;
    }
    i++;
  }
  return 0;
}


void convert_to_hex_string(unsigned num, char* str, int size) {
  for (int i = size-1; i >= 0; i--) {
    str[i] = number_chars[num%16];
    num /= 16;
  }
  str[size] = '\0';
}


struct token peek() {
  return tok[token_index];
}


bool next() {
  token_index++;
  if (tok[token_index].type == END) {
    return false;
  }
  return true;
}


void convert_tok_to_ins_struct(struct instruction* ins) {
  ins->mne_type = -1;
  ins->imm_type = -1;
  ins->group = -1;
  ins->opcode = -1;
  ins->dest_reg = -1;
  ins->source_reg = -1;
  ins->immediate = 0;

  if (peek().type == MNEMONIC_ALU) {
    ins->mne_type = MNEMONIC_ALU;
    ins->opcode = peek().value;
    if (!next()) return;
  }

  if (peek().type == MNEMONIC_LSU) {
    ins->mne_type = MNEMONIC_LSU;
    ins->opcode = peek().value;
    if (!next()) return;
  }

  if (peek().type == MNEMONIC_JCU) {
    ins->mne_type = MNEMONIC_JCU;
    ins->opcode = peek().value;
    if (!next()) return;
  }

  if (peek().type == REGISTER) {
    ins->dest_reg = peek().value;
    if (!next()) return;
  }

  if (peek().type == REGISTER) {
    ins->source_reg = peek().value;
    if (!next()) return;
  }

  if (peek().type == IMMEDIATE_4 || peek().type == IMMEDIATE_8 || peek().type == IMMEDIATE_16 || peek().type == SYMBOL) {
    ins->imm_type = peek().type;
    ins->immediate = peek().value & 0xFFFF;
    if (!next()) return;
  }
}


unsigned assemble_ins_struct(struct instruction* ins) {
  if (ins->mne_type == MNEMONIC_ALU && ins->dest_reg != -1 && ins->source_reg != -1 && ins->imm_type == -1) {
    ins->group = 0;
  } else if (ins->mne_type == MNEMONIC_ALU && ins->dest_reg != -1 && ins->source_reg == -1 && ins->imm_type == IMMEDIATE_4) {
    ins->group = 1;
  } else if (ins->mne_type == MNEMONIC_LSU && ins->dest_reg != -1 && ins->source_reg != -1 && ins->imm_type == -1) {
    ins->group = 2;
  } else if (ins->mne_type == MNEMONIC_JCU) {
    ins->group = 3;
    if (ins->dest_reg == -1) ins->dest_reg = 0;
    if (ins->source_reg == -1) ins->source_reg = 0;
  } else {
    printf("Wrong operands for this type of instruction!\n");
    exit(-1);
  }

  unsigned asm_ins = 0;
  asm_ins |= ins->group << 12;
  asm_ins |= ins->opcode << 8;
  asm_ins |= ins->dest_reg << 4;

  if (ins->group == 0) {
    asm_ins |= ins->source_reg;
  } else if (ins->group == 1) {
    asm_ins |= ins->immediate & 0xF;
  } else if (ins->group == 2) {
    asm_ins |= ins->source_reg;
  } else if (ins->group == 3) {
    if (ins->imm_type != -1) {
      asm_ins <<= 16;
      asm_ins |= ins->immediate;
    }
  } else {
    printf("Unknown instruction!\n");
    exit(-1);
  }

  return asm_ins;
}


void handle_directives(int* adr) {
  if (strcmp(peek().string_value, "byte") == 0) {
    if (!next()) return;
    char data_str[5];

    if (peek().value >= 256) {
      printf("Number %i doesn't fit in 8 bits!\n", peek().value);
      exit(-1);
    } else if (peek().value < -128) {
      printf("Number %i doesn't fit in 8 bits!\n", peek().value);
      exit(-1);
    }

    convert_to_hex_string(peek().value, data_str, 2);
    if (pass_num == 2) {
      fprintf(tmp_file, "%s", data_str);
    }
    *adr += 1;

  } else if (strcmp(peek().string_value, "word") == 0) {
    if (!next()) return;
    char data_str[5];
    convert_to_hex_string(peek().value, data_str, 4);

    if (*adr % 2 == 1) {
      *adr += 1;
      if (pass_num == 2) {
        fprintf(tmp_file, "00");
      }
    }

    if (pass_num == 2) {
      fprintf(tmp_file, "%s", data_str);
    }

    *adr += 2;

  } else if (strcmp(peek().string_value, "text") == 0) {
    if (!next()) return;

    char data_str[5];

    if (pass_num == 2) {
      for (int i = 1; i < strlen(peek().string_value)-1; i++) {
        convert_to_hex_string(convert_to_pl16(peek().string_value[i]), data_str, 2);
        fprintf(tmp_file, "%s", data_str);
      }
    }

    *adr += strlen(peek().string_value) - 2;

  } else if (strcmp(peek().string_value, "reserve") == 0) {
    if (!next()) return;
    if (pass_num == 2) {
      for (int i = 0; i < peek().value; i++) {
        fprintf(tmp_file, "00");
      }
    }
    *adr += peek().value;

  } else if (strcmp(peek().string_value, "define") == 0) {
    char symbol_name[128];
    if (!next()) return;
    strcpy(symbol_name, peek().string_value);
    if (!next()) return;
    if (find_sym_in_sym_tab(symbol_name) == -1 && pass_num == 1) {
      strcpy(sym_tab[symbol_index].name, symbol_name);
      sym_tab[symbol_index].value = peek().value;
      symbol_index++;
    } else if (pass_num == 1) {
      printf("Symbol got redefined!\n");
      exit(-1);
    }

  } else if (strcmp(peek().string_value, "sector") == 0) {
    if (!next()) return;
    if (peek().value < *adr) {
      printf("Wrong sector address!\n");
      exit(-1);
    }

    int adr_before_sector_skip = *adr;
    while (*adr != peek().value) {
      *adr += 1;
      if (pass_num == 2) {
        fprintf(tmp_file, "00");
      }
    }

    printf("New sector started, %d addresses skipped\n", (*adr)-adr_before_sector_skip);

  } else {
    printf("Unknown directive found!\n");
    exit(-1);
  }

  if (!next()) return;
}


void lexer_step(char line[128]) {
  int tok_index = 0;
  int tok_buffer_index = 0;
  char tok_buffer[128];
  char value[5];
  int number;
  char sign;

  negate_next_number = false;
  tolower_next_chars = true;

  for (int i = 0; line[i] != '\0' && line[i] != '\n' && line[i] != ';'; i++) {
    if (line[i] == '-') negate_next_number = true;
    if (line[i] == '\"') tolower_next_chars = !tolower_next_chars;
    if (find_char_in_arr(line[i], skipped_chars) != -1) continue;

    if (tolower_next_chars) tok_buffer[tok_buffer_index] = tolower(line[i]);
    else tok_buffer[tok_buffer_index] = line[i];

    tok_buffer_index++;

    if (find_char_in_arr(line[i+1], skipped_chars) != -1 || line[i+1] == 0) {
      tok_buffer[tok_buffer_index] = '\0';
      number = 0;

      if (find_string_in_arr(tok_buffer, mnemonics_alu) != -1) {
        tok[tok_index].type = MNEMONIC_ALU;
        tok[tok_index].value = find_string_in_arr(tok_buffer, mnemonics_alu);
        convert_to_hex_string(tok[tok_index].value, value, 4);
        printf("MNE (0x%s): %s\n", value, tok_buffer);

      } else if (find_string_in_arr(tok_buffer, mnemonics_lsu) != -1) {
        tok[tok_index].type = MNEMONIC_LSU;
        tok[tok_index].value = find_string_in_arr(tok_buffer, mnemonics_lsu);
        convert_to_hex_string(tok[tok_index].value, value, 4);
        printf("MNE (0x%s): %s\n", value, tok_buffer);

      } else if (find_string_in_arr(tok_buffer, mnemonics_jcu) != -1) {
        tok[tok_index].type = MNEMONIC_JCU;
        tok[tok_index].value = find_string_in_arr(tok_buffer, mnemonics_jcu);
        convert_to_hex_string(tok[tok_index].value, value, 4);
        printf("MNE (0x%s): %s\n", value, tok_buffer);

      } else if (find_string_in_arr(tok_buffer, registers) != -1) {
        tok[tok_index].type = REGISTER;
        tok[tok_index].value = find_string_in_arr(tok_buffer, registers);
        convert_to_hex_string(tok[tok_index].value, value, 4);
        printf("REG (0x%s): %s\n", value, tok_buffer);
        
      } else if (find_string_in_arr(tok_buffer, directives) != -1) {
        tok[tok_index].type = DIRECTIVE;
        strcpy(tok[tok_index].string_value, tok_buffer);
        printf("DIR: %s\n", tok_buffer);

      } else if (tok_buffer[0] == '\"') {
        tok[tok_index].type = STRING;
        i++;
        while (line[i+1] != 0) {
          tok_buffer[tok_buffer_index] = tolower(line[i]);
          i++;
          tok_buffer_index++;
        }
        tok_buffer[tok_buffer_index] = '\0';
        strcpy(tok[tok_index].string_value, tok_buffer);
        printf("STR: %s\n", tok_buffer);

      } else if (convert_to_immediate(tok_buffer, &number) != -1) {
        if (number >= -8 && number < 16) tok[tok_index].type = IMMEDIATE_4;
        else if (number >= -128 && number < 256) tok[tok_index].type = IMMEDIATE_8;
        else tok[tok_index].type = IMMEDIATE_16;
        if (negate_next_number) sign = '-';
        else sign = '+';
        tok[tok_index].value = number;
        convert_to_hex_string(tok[tok_index].value, value, 4);
        printf("IMM (0x%s): %c%s\n", value, sign, tok_buffer);

      } else {
        tok[tok_index].type = SYMBOL;
        strcpy(tok[tok_index].string_value, tok_buffer);
        if (pass_num == 2) {
          int sym_index = find_sym_in_sym_tab(tok_buffer);
          if (sym_index == -1) {
            printf("Undefined symbol %s\n", tok_buffer);
            exit(-1);
          } else {
            tok[tok_index].value = sym_tab[sym_index].value;
          }
        }
        printf("SYM: %s\n", tok_buffer);
      }

      tok_buffer_index = 0;
      tok_index++;
    }
  }

  tok[tok_index].type = END;

  printf("> Lexing done\n");
}


void parser_step(int* adr) {
  token_index = 0;
  
  if (peek().type == END) return;

  if (peek().type == SYMBOL) {
    if (*adr % 2 == 1) {
      *adr += 1;
      if (pass_num == 2) {
        fprintf(tmp_file, "00");
      }
    }
    if (find_sym_in_sym_tab(peek().string_value) == -1 && pass_num == 1) {
      strcpy(sym_tab[symbol_index].name, peek().string_value);
      sym_tab[symbol_index].value = *adr;
      symbol_index++;
    } else if (pass_num == 1) {
      printf("Symbol got redefined!\n");
      exit(-1);
    }
    if (!next()) return;
  }

  if (peek().type == MNEMONIC_ALU || peek().type == MNEMONIC_LSU || peek().type == MNEMONIC_JCU) {
    struct instruction ins;
    unsigned asm_ins;
    char asm_ins_str[9];

    convert_tok_to_ins_struct(&ins);
    asm_ins = assemble_ins_struct(&ins);

    if (ins.group == 3 && ins.imm_type != -1) {
      convert_to_hex_string(asm_ins, asm_ins_str, 8);
    } else {
      convert_to_hex_string(asm_ins, asm_ins_str, 4);
    }

    if (pass_num == 2) {
      fprintf(tmp_file, "%s", asm_ins_str);
    }

    if (ins.group == 3 && ins.imm_type != -1) {
      *adr += 4;
    } else {
      *adr += 2;
    }

    printf("> Parsing done (0x%s)\n", asm_ins_str);
    
  } else if (peek().type == DIRECTIVE) {
    handle_directives(adr);
    printf("> Parsing done\n");
  }

  if (peek().type != END) {
    printf("Unexpected tokens found!\n");
    exit(-1);
  }

}


void add_newspaces_to_output(int mem_width) {
  if (mem_width % 4 != 0) {
    printf("Memory width must be aligned to a 4-bit boundary!\n");
    exit(-1);
  }
  mem_width /= 4; // Bit width to hex width
  char* line = (char*)malloc(mem_width+1);
  int line_of_memory = 0;
  while (fgets(line, mem_width+1, tmp_file) != NULL) {
    for (int i = 0; i < mem_width; i++) {
      if (line[i] == '\0') {
        for (int j = i; j < mem_width; j++) {
          line[j] = '0';
          line[j+1] = '\0';
        }
        break;
      }
    }
    if (line_of_memory < 8192) {
      fprintf(output_file_0, "%s\n", line);
    } else { 
      fprintf(output_file_1, "%s\n", line);
    }
    line_of_memory++;
  }
  free(line);
}



// Main
int main(int argc, char* argv[]) {
  open_files_for_passes(argc, argv);
  
  char line[128];
  int adr = 0;
  token_index = 0;
  
  // Symbol pass
  pass_num = 1;

  while (fgets(line, 128, source_code) != NULL) {
    lexer_step(line);
    parser_step(&adr);
  }

  char symbol_val_str[128];
  printf("\nSymbol table:\n");
  for (int i = 0; i < symbol_index; i++) {
    convert_to_hex_string(sym_tab[i].value, symbol_val_str, 4);
    printf("> %s = 0x%s\n", sym_tab[i].name, symbol_val_str);
  }
  printf("\n");

  close_files();
  open_files_for_passes(argc, argv);

  adr = 0;
  token_index = 0;

  // Assembler pass
  pass_num = 2;

  while (fgets(line, 128, source_code) != NULL) {
    lexer_step(line);
    parser_step(&adr);
  }

  close_files();
  open_files_for_output(argc, argv);
  
  add_newspaces_to_output(16);

  printf("> File %s succesfully assembled into %s\n", argv[1], argv[2]);

  close_files();

  return 0;
}
