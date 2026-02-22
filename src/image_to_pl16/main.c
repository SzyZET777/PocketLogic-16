#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>



// Global variables
FILE* source_file;
FILE* output_file;



// Defines, Enums, Structs, Constants
char number_chars[] = {'0','1','2','3','4','5','6','7','8','9','a','b',
                       'c','d','e','f','\0'};



// Functions
void open_files(int argc, char* argv[]) {
  if (argc != 3) {
    printf("First argument should be the source code\n");
    printf("Second argument should be an output file\n");
    exit(-1);
  }

  source_file = fopen(argv[1], "r");
  output_file = fopen(argv[2], "w");

  fprintf(output_file,"");

  fclose(output_file);
  output_file = fopen(argv[2], "a");

  if (source_file == NULL) {
    printf("Source code file not found!\n");
    exit(-1);
  }
}


void close_files() {
  fclose(source_file);  
  fclose(output_file);
}


void convert_to_hex_string(unsigned num, char* str, int size) {
  for (int i = size-1; i >= 0; i--) {
    str[i] = number_chars[num%16];
    num /= 16;
  }
  str[size] = '\0';
}



// Main
int main(int argc, char* argv[]) {

  open_files(argc, argv);

  unsigned int bitmap[64*1024];

  int indx = 0;
  do bitmap[indx++] = fgetc(source_file);
  while (bitmap[indx] != EOF);

  for (int i = 0; i < 128*80; i+=2) {
    char bitmap_line[5];
    convert_to_hex_string(bitmap[0x8A + 4*i + 0], bitmap_line, 4);
    printf("%s/", bitmap_line);
    convert_to_hex_string(bitmap[0x8A + 4*i + 1], bitmap_line, 4);
    printf("%s/", bitmap_line);
    convert_to_hex_string(bitmap[0x8A + 4*i + 2], bitmap_line, 4);
    printf("%s\n", bitmap_line);

    unsigned int pixel_data_1 = 0;
    pixel_data_1 |= ((bitmap[0x8A + 4*i + 0]>>6)&0b11);
    pixel_data_1 |= ((bitmap[0x8A + 4*i + 1]>>6)&0b11) << 2;
    pixel_data_1 |= ((bitmap[0x8A + 4*i + 2]>>6)&0b11) << 4;

    unsigned int pixel_data_2 = 0;
    pixel_data_2 |= ((bitmap[0x8A + 4*i + 4]>>6)&0b11);
    pixel_data_2 |= ((bitmap[0x8A + 4*i + 5]>>6)&0b11) << 2;
    pixel_data_2 |= ((bitmap[0x8A + 4*i + 6]>>6)&0b11) << 4;

    char bitmap_pl16[5];
    
    convert_to_hex_string(pixel_data_1, bitmap_pl16, 2);
    bitmap_pl16[2] = 0;
    fprintf(output_file, "%s", bitmap_pl16);

    convert_to_hex_string(pixel_data_2, bitmap_pl16, 2);
    bitmap_pl16[2] = 0;
    fprintf(output_file, "%s", bitmap_pl16);

    /*if(i%2==1)*/ fprintf(output_file, "\n");
  }

  close_files();

  printf("> File %s succesfully convertet into %s\n", argv[1], argv[2]);

  return 0;
}
