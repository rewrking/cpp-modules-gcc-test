#!/usr/bin/env bash

# not yet :(
# clang++ -std=c++20 -stdlib=libc++ -fmodules -fmodules-ts -fbuiltin-module-map -Xclang -emit-module-interface -o build/modules-test -c main.cpp
# -fno-module-lazy
# -flang-info-include-translate

CC="g++-13"
CC_SYSTEM_INCLUDE="/opt/homebrew/Cellar/gcc/13.1.0/include/c++/13"

CXX_FLAGS="-std=c++20 -O3 -Wall -Wextra -Wpedantic -fdiagnostics-color=always -fmodules-ts -Isrc"

OUTPUT_DIR="build"
MAP_DIR="map"
MODULE_ID="e545ab910d1ddd09"

ERROR_COLOR="\x1b[0;91m"
COLOR="\x1b[0;96m"
RESET="\x1b[0m"

SYSTEM_HEADER_UNITS="iostream cstdlib"
INPUT_FILES=$(find src -type f -name '*.cpp')

count=0
input_file_count="$(printf "$SYSTEM_HEADER_UNITS $INPUT_FILES\n" | sed 's/ /\n/g' | wc -l)"
((total_count=input_file_count+1))

do_cmd()
{
	CMD=$1
	echo $CMD
	$CMD
	RESULT=$?
	if [[ $RESULT != 0 ]]; then
		printf "${ERROR_COLOR}ERROR:$RESET $CMD\n"
		exit 1
	fi
}

do_cmd "which $CC"

flags_system_header_unit()
{
	((count=count+1))
	printf "[$count/$total_count] ${COLOR}$1$RESET\n"
	do_cmd "$CC -x c++-system-header -MT $OUTPUT_DIR/$1_$MODULE_ID.gcm -MMD -MP -MF $OUTPUT_DIR/$1_$MODULE_ID.d $CXX_FLAGS -fmodule-mapper=$MAP_DIR/$1.txt -c $1"
	# do_cmd "$CC -x c++-system-header $CXX_FLAGS -o $OUTPUT_DIR/$1_$MODULE_ID.gcm -c $1"
}

flags_header_unit()
{
	((count=count+1))
	printf "[$count/$total_count] ${COLOR}$1$RESET\n"
	do_cmd "$CC -x c++-system-header -MT $OUTPUT_DIR/$1_$MODULE_ID.gcm -MMD -MP -MF $OUTPUT_DIR/$1_$MODULE_ID.d $CXX_FLAGS -fmodule-mapper=$MAP_DIR/$1.txt -c $1"
	# do_cmd "$CC -x c++-system-header $CXX_FLAGS -o $OUTPUT_DIR/$1_$MODULE_ID.gcm -c $1"
}
flags_module_unit()
{
	((count=count+1))
	printf "[$count/$total_count] ${COLOR}src/$1$RESET\n"
	do_cmd "$CC -x c++ -MT $OUTPUT_DIR/$1.gcm -MMD -MP -MF $OUTPUT_DIR/$1.d $CXX_FLAGS -fmodule-mapper=$MAP_DIR/$1.txt -o build/$1.o -c src/$1"
	# do_cmd "$CC -x c++ $CXX_FLAGS -o $OUTPUT_DIR/$1.o -c src/$1"
}

$CC --version | grep -i "$CC"

rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR
mkdir "$OUTPUT_DIR/$MAP_DIR"
# cp -r $MAP_DIR $OUTPUT_DIR

printf "\n"

sleep 2

for file in $SYSTEM_HEADER_UNITS; do
	printf "$CC_SYSTEM_INCLUDE/$file $OUTPUT_DIR/${file}_$MODULE_ID.gcm\n" > "$OUTPUT_DIR/$MAP_DIR/$file.txt"
done

for file in $INPUT_FILES; do
	printf "$file:\n"
	cat $file | grep -E "(export module|import)"  | sed -E 's/^(export module|import|export import) (.+);(.*)$/\2/g' | sed -E 's/^<(.+)(\.)(.+)>$/\1\2\3/g' | sed -E "s/^<(.+)>$/\1 $OUTPUT_DIR\/\1_$MODULE_ID.gcm/g" | sed -E 's/^(.+)$/  \1/g'
	printf "\n"
done

# System Header-units
for file in $SYSTEM_HEADER_UNITS; do
	flags_system_header_unit $file
done


# Note: These must be ordered correctly

# Local Header-units
# flags_header_unit "header.hpp"
# Modules
flags_module_unit "test-impl.cpp"
flags_module_unit "test.cpp"

# Root
flags_module_unit "main.cpp"

# Link
((count=count+1))
printf "[$count/$total_count] ${COLOR}Linking $OUTPUT_DIR/modules-test$RESET\n"
do_cmd "$CC -o $OUTPUT_DIR/modules-test $(find $OUTPUT_DIR -type f -name '*.o')"

printf "\n"

./build/modules-test

exit 0
