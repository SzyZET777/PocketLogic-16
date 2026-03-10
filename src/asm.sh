clear
if ! gcc assembler/main.c -o main -std=c17 -Os; then
  exit -1
fi
echo -e "\n\n"
strip main
echo -e "\n\n"
if ! ./main main.asm asm_out.txt; then
  exit -1
fi
echo -e "\n\n"