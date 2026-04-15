#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "  ModelicaRag devcontainer setup"
echo "========================================"
echo ""

# Clone the Modelica Standard Library into data/msl/.
# Only the .mo source files are needed — no OpenModelica compiler required.
MSL_DIR="$(pwd)/data/msl"
if [ -d "$MSL_DIR/.git" ]; then
    echo "Modelica Standard Library already present — skipping clone."
else
    echo "Cloning Modelica Standard Library (shallow clone)..."
    git clone --depth 1 https://github.com/modelica/ModelicaStandardLibrary.git "$MSL_DIR"
    echo "Cloned to $MSL_DIR"
fi

echo ""
echo "Installing Julia package dependencies..."
julia --project -e 'import Pkg; Pkg.instantiate()'

echo ""
echo "========================================"
echo "  Setup complete."
echo ""
echo "  GITHUB_TOKEN is provided automatically by Codespaces."
echo ""
echo "  Run the playground:"
echo "    julia --project playground.jl"
echo "========================================"
