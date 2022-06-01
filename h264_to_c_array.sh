#!/bin/bash

# This is a quick script to convert .h264 frame files to C-arrays to be written directly to RAM to avoid overhead of (SD) disk access.

set -e

H264_FILES_DIR=$1
OUTPUT_FILES_DIR=$2

if [ -z "$H264_FILES_DIR" ] || [ -z "$OUTPUT_FILES_DIR" ]; then
    echo "Usage: $0 <h264_files_dir> <output_files_dir>"
    echo "Example: $0 test_h264 main/include"
    exit 1
fi

set -u

mkdir -p $OUTPUT_FILES_DIR

# ==============================================================================
# Generate the frames.h file (header file with frame data + frame lengths)
# ==============================================================================
FRAME_COUNT=0
FRAMES_INCLUDE_FILE=$OUTPUT_FILES_DIR/frames.h
echo "#pragma once

#include <stdint.h>
" > $FRAMES_INCLUDE_FILE
for frame in $H264_FILES_DIR/*.h264; do
    OUTPUT_FILENAME=$(basename $frame .h264).h
    xxd -i $frame >> $FRAMES_INCLUDE_FILE
    FRAME_COUNT=$((FRAME_COUNT + 1))
done
echo "void* frames_get_frame(uint32_t frame_number); " >> $FRAMES_INCLUDE_FILE
echo "uint32_t frames_get_frame_length(uint32_t frame_number);" >> $FRAMES_INCLUDE_FILE

# The frame data and length must be statically defined
sed -i -- "s/unsigned char/static unsigned char/g" $FRAMES_INCLUDE_FILE
sed -i -- "s/unsigned int/static unsigned int/g" $FRAMES_INCLUDE_FILE
rm -f $FRAMES_INCLUDE_FILE--

echo "Generated $FRAME_COUNT frames in $FRAMES_INCLUDE_FILE"

# ================================================================
# Generate the frames source file
# ================================================================
FRAME_SOURCE_FILE=$OUTPUT_FILES_DIR/frames.c
echo "#include \"frames.h\"
#include <stdio.h>

void* frames_get_frame(uint32_t frame_number) {" > $FRAME_SOURCE_FILE
for i in $(seq 1 $FRAME_COUNT); do
    if [ $i -eq 1 ]; then
        echo "    if (frame_number == $i) {" >> $FRAME_SOURCE_FILE
    else
        echo "    else if (frame_number == $i) {" >> $FRAME_SOURCE_FILE
    fi
    printf "        return (void*)test_h264_frame_%04d_h264;" $i >> $FRAME_SOURCE_FILE
    echo "" >> $FRAME_SOURCE_FILE
    echo "    }" >> $FRAME_SOURCE_FILE
done
echo "    return NULL;" >> $FRAME_SOURCE_FILE
echo "}" >> $FRAME_SOURCE_FILE
echo "" >> $FRAME_SOURCE_FILE

echo "uint32_t frames_get_frame_length(uint32_t frame_number) {" >> $FRAME_SOURCE_FILE
for i in $(seq 1 $FRAME_COUNT); do
    if [ $i -eq 1 ]; then
        echo "    if (frame_number == $i) {" >> $FRAME_SOURCE_FILE
    else
        echo "    else if (frame_number == $i) {" >> $FRAME_SOURCE_FILE
    fi
    printf "        return test_h264_frame_%04d_h264_len;" $i >> $FRAME_SOURCE_FILE
    echo "" >> $FRAME_SOURCE_FILE
    echo "    }" >> $FRAME_SOURCE_FILE
done
echo "    return 0;" >> $FRAME_SOURCE_FILE
echo "}" >> $FRAME_SOURCE_FILE
echo "" >> $FRAME_SOURCE_FILE
