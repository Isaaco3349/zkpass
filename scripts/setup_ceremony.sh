#!/bin/bash
# ZKPass — Day 1 Setup Script
# Run this FIRST before anything else. It downloads the Powers of Tau
# ceremony file and compiles the circuit. Takes 30–90 min on slow connections.
#
# Usage: bash scripts/setup_ceremony.sh

set -e
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   ZKPass — Trusted Setup (Day 1)         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# --- Config ---
PTAU_URL="https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_16.ptau"
PTAU_FILE="powersOfTau28_hez_final_16.ptau"
CIRCUIT_DIR="./circuits"
CIRCUIT_NAME="kyc_proof"

# --- Step 1: Check dependencies ---
echo "→ Checking dependencies..."
command -v node >/dev/null || { echo "ERROR: node not found. Install Node.js first."; exit 1; }
command -v npx >/dev/null || { echo "ERROR: npx not found."; exit 1; }

# Install snarkjs and circom globally if not present
if ! command -v snarkjs &>/dev/null; then
  echo "→ Installing snarkjs..."
  npm install -g snarkjs
fi

if ! command -v circom &>/dev/null; then
  echo "→ Installing circom..."
  npm install -g circom
fi

# Install circomlib for circuit dependencies
echo "→ Installing circomlib..."
cd "$CIRCUIT_DIR" && npm install circomlib 2>/dev/null || (npm init -y && npm install circomlib)
cd ..

# --- Step 2: Download Powers of Tau ---
if [ -f "$PTAU_FILE" ]; then
  echo "→ Powers of Tau file already exists, skipping download."
else
  echo "→ Downloading Powers of Tau (this may take a while on slow connections)..."
  echo "  URL: $PTAU_URL"
  echo "  Tip: If this stalls, use a VPN or download on a faster connection."
  wget -c "$PTAU_URL" -O "$PTAU_FILE" || curl -L -C - "$PTAU_URL" -o "$PTAU_FILE"
  echo "✓ Download complete."
fi

# --- Step 3: Compile the circuit ---
echo ""
echo "→ Compiling Circom circuit..."
circom "$CIRCUIT_DIR/$CIRCUIT_NAME.circom" \
  --r1cs \
  --wasm \
  --sym \
  --output "$CIRCUIT_DIR"
echo "✓ Circuit compiled."

# --- Step 4: Groth16 setup (generate proving key) ---
echo ""
echo "→ Running Groth16 trusted setup (phase 2)..."

snarkjs groth16 setup \
  "$CIRCUIT_DIR/$CIRCUIT_NAME.r1cs" \
  "$PTAU_FILE" \
  "$CIRCUIT_DIR/${CIRCUIT_NAME}_0000.zkey"

# Contribute randomness (in production: multiple parties contribute)
echo "zkpass_contribution_$(date +%s)" | \
  snarkjs zkey contribute \
    "$CIRCUIT_DIR/${CIRCUIT_NAME}_0000.zkey" \
    "$CIRCUIT_DIR/${CIRCUIT_NAME}_final.zkey" \
    --name="ZKPass Initial Contribution"

echo "✓ Proving key generated: circuits/${CIRCUIT_NAME}_final.zkey"

# --- Step 5: Export verification key ---
echo ""
echo "→ Exporting verification key..."
snarkjs zkey export verificationkey \
  "$CIRCUIT_DIR/${CIRCUIT_NAME}_final.zkey" \
  "$CIRCUIT_DIR/verification_key.json"

echo "✓ Verification key exported: circuits/verification_key.json"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   ✅ Setup complete!                     ║"
echo "║                                          ║"
echo "║   Next steps:                            ║"
echo "║   1. cd prover && npm install            ║"
echo "║   2. node generate_proof.js              ║"
echo "║   3. bash scripts/deploy_contract.sh     ║"
echo "╚══════════════════════════════════════════╝"
echo ""
