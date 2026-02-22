clear
if ! gcc image_to_pl16/main.c -o main -std=c17 -Os; then
  exit -1
fi
echo -e "\n\n"
strip main
echo -e "\n\n"
if ! ./main image_rectui.bmp img_out.txt; then
  exit -1
fi
echo -e "\n\n"