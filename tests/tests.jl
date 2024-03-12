#!/usr/bin/env -S julia  --threads auto --gcthreads=3 --compile=all --output-asm determinist.s --optimize=3

using Test

@test true
