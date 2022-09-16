#!/bin/bash

BENCHMARKS=/home/eval/benchmarks
PRIVATE_KEY=/home/eval/usubot.private-key.pem
CONFIG=/home/eval/config.toml

KEY=`sed -nE 's/.*domain="https:\/\/smee.io\/([^"]+)".*/\1/p' $CONFIG`

echo "SMEE key: $KEY"

smee -u "https://smee.io/$KEY" \
     --port 3000 &

cd usubot;
  opam exec -- \
    dune exec usubot -- \
      -k $PRIVATE_KEY \
      $CONFIG \
      -b $BENCHMARKS \
      --debug &


# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
