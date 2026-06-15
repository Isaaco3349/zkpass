/**
 * ZKPass — Proof Generator
 *
 * Takes private KYC data from the mock oracle and generates
 * a Groth16 zero-knowledge proof using snarkjs.
 *
 * The proof says: "I know private inputs (age, country, score, salt)
 * such that: age >= minAge, country not sanctioned, score >= minKycScore,
 * and Poseidon(age, country, score, salt) == commitment"
 *
 * Usage:
 *   node generate_proof.js
 */

const snarkjs = require("snarkjs");
const fs = require("fs");
const path = require("path");
const { getKYCAttestation } = require("./mock_kyc_oracle");

// --- Public parameters (set by the dApp / verifier contract) ---
const MIN_AGE = 18;
const MIN_KYC_SCORE = 70;

async function generateKYCProof() {
  console.log("\n🔐 ZKPass — Generating KYC Proof\n");

  // Step 1: Get KYC attestation from oracle
  const { privateInputs, commitment } = await getKYCAttestation("user_demo");

  // Step 2: Prepare circuit inputs
  const circuitInputs = {
    // Private
    age:         privateInputs.age.toString(),
    countryCode: privateInputs.countryCode.toString(),
    kycScore:    privateInputs.kycScore.toString(),
    salt:        privateInputs.salt,
    // Public
    minAge:      MIN_AGE.toString(),
    minKycScore: MIN_KYC_SCORE.toString(),
    commitment:  BigInt(commitment).toString(),
  };

  console.log("\n📋 Circuit inputs prepared");
  console.log("  Public: minAge =", MIN_AGE, "| minKycScore =", MIN_KYC_SCORE);

  // Step 3: Generate witness
  console.log("\n⚙️  Generating witness...");
  const wasmPath = path.join(__dirname, "../circuits/kyc_proof_js/kyc_proof.wasm");
  const zkeyPath = path.join(__dirname, "../circuits/kyc_proof_final.zkey");

  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    circuitInputs,
    wasmPath,
    zkeyPath
  );

  console.log("✓ Proof generated");

  // Step 4: Verify locally before sending to Stellar
  console.log("\n🔍 Verifying proof locally...");
  const vkeyPath = path.join(__dirname, "../circuits/verification_key.json");
  const vkey = JSON.parse(fs.readFileSync(vkeyPath));
  const isValid = await snarkjs.groth16.verify(vkey, publicSignals, proof);

  if (!isValid) {
    console.error("❌ Local verification FAILED — proof is invalid");
    process.exit(1);
  }

  console.log("✓ Local verification passed");

  // Step 5: Export Stellar-compatible calldata
  // The Soroban verifier contract expects the proof in this format
  const calldata = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
  // Note: we parse this to get the raw arrays for Soroban
  const calldataParsed = JSON.parse("[" + calldata + "]");

  const output = {
    proof,
    publicSignals,
    commitment,
    stellarCalldata: {
      pi_a: calldataParsed[0],
      pi_b: calldataParsed[1],
      pi_c: calldataParsed[2],
      pubSignals: calldataParsed[3],
    },
    timestamp: new Date().toISOString(),
  };

  // Save proof artifacts
  fs.writeFileSync(
    path.join(__dirname, "proof.json"),
    JSON.stringify(output, null, 2)
  );

  console.log("\n✅ Proof saved to prover/proof.json");
  console.log("\n📤 Ready to submit to Stellar testnet");
  console.log("   Run: node scripts/submit_to_stellar.js\n");

  return output;
}

generateKYCProof().catch((err) => {
  console.error("Proof generation failed:", err);
  process.exit(1);
});
