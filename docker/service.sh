#!/bin/bash

KEY=`cat ~/smee_endpoint.txt`

echo "SMEE key: $KEY"

smee -u "https://smee.io/$KEY" \
     --port 3000 &

cd usubot;
  opam exec -- \
    dune exec usubot -- \
      -k ~/usubot.2022-02-25.private-key.pem \
      ~/config.toml \
      -b ~/benchmarks \
      --debug &


# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
