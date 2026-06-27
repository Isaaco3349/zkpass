pragma circom 2.0.0;

/*
 * ZKPass — KYC Compliance Circuit
 *
 * Proves the following WITHOUT revealing identity:
 *   1. User age >= minimum required age (e.g. 18)
 *   2. User jurisdiction is not sanctioned (country code not in blocklist)
 *   3. User KYC score meets minimum threshold (e.g. score >= 70)
 *
 * The prover (user) knows: age, countryCode, kycScore, salt
 * The verifier (Stellar contract) only learns: the proof is valid or not
 *
 * Inputs are private by default in Circom unless marked `public`.
 * Only the commitment hash is public — it anchors the proof to
 * a specific KYC attestation without revealing the underlying data.
 */

include "node_modules/circomlib/circuits/comparators.circom";
include "node_modules/circomlib/circuits/poseidon.circom";

template KYCProof() {

    // --- Private inputs (never leave the user's machine) ---
    signal input age;           // e.g. 25
    signal input countryCode;   // e.g. 566 (Nigeria's ISO 3166-1 numeric)
    signal input kycScore;      // e.g. 85  (0–100 scale from KYC provider)
    signal input salt;          // random value to prevent brute-force of commitment

    // --- Public inputs (visible to the Stellar verifier contract) ---
    signal input minAge;        // e.g. 18  — set by the dApp
    signal input minKycScore;   // e.g. 70  — set by the dApp
    signal input commitment;    // Poseidon(age, countryCode, kycScore, salt)

    // --- Output ---
    signal output valid;        // 1 if all checks pass, 0 otherwise

    // -------------------------------------------------------
    // Check 1: age >= minAge
    // -------------------------------------------------------
    component ageCheck = GreaterEqThan(8); // 8-bit comparison (supports 0–255)
    ageCheck.in[0] <== age;
    ageCheck.in[1] <== minAge;

    // -------------------------------------------------------
    // Check 2: countryCode is not sanctioned
    // We check: countryCode != each sanctioned code
    // Sanctioned list (ISO numeric): 364=Iran, 408=North Korea, 760=Syria, 192=Cuba
    // In production this would be a Merkle non-membership proof.
    // For this MVP: simple inequality checks.
    // -------------------------------------------------------
    signal notIran;
    signal notNorthKorea;
    signal notSyria;
    signal notCuba;

    notIran      <== (countryCode - 364) * (countryCode - 364);
    notNorthKorea <== (countryCode - 408) * (countryCode - 408);
    notSyria     <== (countryCode - 760) * (countryCode - 760);
    notCuba      <== (countryCode - 192) * (countryCode - 192);

    // All must be non-zero (i.e. countryCode does not equal any sanctioned code)
    // We enforce this via a product — if any is 0, product is 0
    signal jurisdictionProduct;
    jurisdictionProduct <== notIran * notNorthKorea;
    signal jurisdictionProduct2;
    jurisdictionProduct2 <== jurisdictionProduct * notSyria;
    signal jurisdictionCheck;
    jurisdictionCheck <== jurisdictionProduct2 * notCuba;

    // -------------------------------------------------------
    // Check 3: kycScore >= minKycScore
    // -------------------------------------------------------
    component scoreCheck = GreaterEqThan(7); // 7-bit (supports 0–127)
    scoreCheck.in[0] <== kycScore;
    scoreCheck.in[1] <== minKycScore;

    // -------------------------------------------------------
    // Commitment verification
    // Ensures the private inputs match the public commitment
    // Prevents a user from proving with fake inputs
    // -------------------------------------------------------
    component hasher = Poseidon(4);
    hasher.inputs[0] <== age;
    hasher.inputs[1] <== countryCode;
    hasher.inputs[2] <== kycScore;
    hasher.inputs[3] <== salt;

    commitment === hasher.out;

    // -------------------------------------------------------
    // Final output: all three checks must pass
    // jurisdictionCheck > 0 means no sanctioned country matched
    // We convert to binary: 1 if nonzero, 0 if zero
    // -------------------------------------------------------
    component jurisdictionBool = IsZero();
    jurisdictionBool.in <== jurisdictionCheck;
    // jurisdictionBool.out == 1 means it IS zero (sanctioned) — we want the opposite
    signal jurisdictionPass;
    jurisdictionPass <== 1 - jurisdictionBool.out;

    signal intermediate;
    intermediate <== ageCheck.out * scoreCheck.out;
    valid <== intermediate * jurisdictionPass;
}

component main {public [minAge, minKycScore, commitment]} = KYCProof();
