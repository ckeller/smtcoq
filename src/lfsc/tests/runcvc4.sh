#!/bin/bash

count=1
i=$1
file=$(echo "$i" | sed "s/.smt2/.lfsc/")

cvc4 --lang smt2 --proof --dump-proofs --no-simplification --fewer-preprocessing-holes --no-bv-eq --no-bv-ineq --no-bv-algebraic $i > $file
