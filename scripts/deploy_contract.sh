#!/bin/bash
# ZKPass — Deploy Soroban Contract to Stellar Testnet
#
# Prerequisites:
#   - Rust + soroban-cli installed
#   - STELLAR_SECRET_KEY set in .env
#
# Usage: bash scripts/deploy_contract.sh

set -e
source .env 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   ZKPass — Contract Deployment           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

CONTRACT_DIR="./contracts/zkpass-verifier"
NETWORK="testnet"
RPC_URL="https://soroban-testnet.stellar.org"

# --- Check soroban-cli ---
command -v soroban >/dev/null || {
  echo "ERROR: soroban-cli not found."
  echo "Install with: cargo install --locked soroban-cli"
  exit 1
}

# --- Check secret key ---
if [ -z "$STELLAR_SECRET_KEY" ]; then
  echo "ERROR: STELLAR_SECRET_KEY not set."
  echo "Add it to your .env file: STELLAR_SECRET_KEY=S..."
  exit 1
fi

# --- Build ---
echo "→ Building contract (release)..."
cd "$CONTRACT_DIR"
soroban contract build
cd ../..
echo "✓ Build complete."

# --- Deploy ---
echo ""
echo "→ Deploying to Stellar $NETWORK..."
CONTRACT_ID=$(soroban contract deploy \
  --wasm "$CONTRACT_DIR/target/wasm32-unknown-unknown/release/zkpass_verifier.wasm" \
  --source "$STELLAR_SECRET_KEY" \
  --network "$NETWORK" \
  --rpc-url "$RPC_URL" \
  --network-passphrase "Test SDF Network ; September 2015")

echo "✓ Contract deployed!"
echo ""
echo "  Contract ID: $CONTRACT_ID"
echo "  Network:     $NETWORK"
echo "  Explorer:    https://stellar.expert/explorer/testnet/contract/$CONTRACT_ID"
echo ""

# Save contract ID for frontend use
echo "VITE_CONTRACT_ID=$CONTRACT_ID" >> .env
echo "→ Contract ID saved to .env as VITE_CONTRACT_ID"
echo ""
echo "✅ Deployment complete. Update frontend/.env with the contract ID."
