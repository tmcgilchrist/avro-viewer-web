#!/usr/bin/env bash
# Run the Avro Viewer web server

set -euo pipefail

echo "=== Starting Avro Viewer Web Server ==="
echo ""

# Build the JavaScript if it doesn't exist
if [ ! -f "_build/default/src/main.bc.js" ]; then
    echo "Building web application..."
    opam exec -- dune build src/main.bc.js
    echo "✓ Web application built"
    echo ""
fi

# Build the server
echo "Building server..."
opam exec -- dune build server/server.exe
echo "✓ Server built"
echo ""

# Run the server
echo "Starting server on http://localhost:8080"
echo "Press Ctrl+C to stop"
echo ""
opam exec -- dune exec server/server.exe
