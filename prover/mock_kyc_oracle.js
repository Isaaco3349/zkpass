/**
 * ZKPass — Mock KYC Oracle
 *
 * In production this would call a real KYC provider (e.g. Smile Identity,
 * Jumio, or Onfido) and return a signed attestation. For this hackathon
 * we simulate the oracle response with structured mock data.
 *
 * The oracle returns PRIVATE data that the user feeds into the circuit.
 * None of this data ever leaves the user's browser or machine.
 */

const { buildPoseidon } = require("circomlibjs");
const crypto = require("crypto");

/**
 * Simulates a KYC provider response for a given user.
 * Returns the raw private data needed to generate a ZK proof.
 *
 * @param {string} userId  - opaque identifier (not stored anywhere)
 * @returns {object}       - private KYC data + commitment hash
 */
async function getKYCAttestation(userId) {
  const poseidon = await buildPoseidon();

  // --- Simulated KYC provider response ---
  // In production: replace with API call to Smile Identity or similar
  const kycData = {
    age: 26,                  // user's verified age
    countryCode: 566,         // Nigeria — ISO 3166-1 numeric
    kycScore: 85,             // compliance score (0-100)
    salt: BigInt("0x" + crypto.randomBytes(16).toString("hex")), // random salt
  };

  // Compute Poseidon commitment — this is the ONLY thing that goes on-chain
  // It binds the proof to these exact private inputs
  const commitment = poseidon([
    BigInt(kycData.age),
    BigInt(kycData.countryCode),
    BigInt(kycData.kycScore),
    kycData.salt,
  ]);

  const commitmentHex = "0x" + poseidon.F.toString(commitment, 16).padStart(64, "0");

  console.log("✓ KYC attestation generated");
  console.log("  Age:          ", kycData.age);
  console.log("  Country code: ", kycData.countryCode, "(Nigeria)");
  console.log("  KYC score:    ", kycData.kycScore);
  console.log("  Commitment:   ", commitmentHex);
  console.log("  (Private inputs are NOT logged in production)");

  return {
    // Private inputs — for the ZK circuit only
    privateInputs: {
      age: kycData.age,
      countryCode: kycData.countryCode,
      kycScore: kycData.kycScore,
      salt: kycData.salt.toString(),
    },
    // Public commitment — safe to share / post on-chain
    commitment: commitmentHex,
  };
}

module.exports = { getKYCAttestation };
