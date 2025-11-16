#!/usr/bin/env bash
# Build script for Avro Viewer Web

set -euo pipefail

echo "=== Building Avro Viewer Web ==="
echo

# Check if avro-simple is available
if ! ocamlfind query avro-simple &> /dev/null; then
    echo "Error: avro-simple not found. Please install it first:"
    echo "  cd ../avro-simple && dune install"
    exit 1
fi

# Build test data generator
echo "Building test data generator..."
dune build test/generate_test_data.exe
echo "✓ Test data generator built"
echo

# Build web application
echo "Building web application (compiling OCaml to JavaScript)..."
dune build src/main.bc.js
echo "✓ Web application built"
echo

# Copy to static directory
echo "Copying JavaScript bundle to static/..."
cp _build/default/src/main.bc.js static/
echo "✓ Bundle copied"
echo

echo "=== Build Complete! ==="
echo
echo "Next steps:"
echo "  1. Generate test data:"
echo "     dune exec test/generate_test_data.exe -- --output static/sample.avro --count 1000"
echo
echo "  2. Start local server:"
echo "     cd static && python3 -m http.server 8000"
echo
echo "  3. Open in browser:"
echo "     http://localhost:8000"
echo
