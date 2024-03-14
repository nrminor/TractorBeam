#!/usr/bin/bash

mkdir -p tests/results
echo "Hello world!" > tests/results/successful_test.txt

mkdir -p tests/results/nested_results
echo "Hello world!" > tests/results/nested_results/successful_nested_test.txt
