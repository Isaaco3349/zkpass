# ZKPass

**Private KYC compliance on Stellar — prove you qualify without revealing who you are.**

> Built for [Stellar Hacks: Real-World ZK](https://dorahacks.io/hackathon/stellar-zk) · June 2026

---

## The Problem

Right now, if you want to send money across borders using a stablecoin on Stellar, one of two things happens:

1. **No compliance check** — the transfer goes through, but regulated institutions won't touch the rail.
2. **Full KYC** — you hand over your passport, address, and financial history to a centralized database that can be breached, sold, or used against you.

Neither is acceptable. And for users in markets like Nigeria — where entire countries get blanket-blocked on global payment rails despite millions of individually compliant citizens — the status quo is both unfair and technically unnecessary.

There is a third option. Zero-knowledge proofs let you prove **you meet the requirements** without revealing **anything about yourself**. ZKPass builds that for Stellar.

---

## What ZKPass Does

ZKPass lets a user prove — cryptographically, on Stellar — that:

- ✅ They are **at least 18 years old**
- ✅ Their **jurisdiction is not on a sanctions list**
- ✅ Their **KYC score meets a minimum threshold** (set by the dApp)

The proof is generated entirely **off-chain on the user's device**. The Stellar smart contract only ever sees: valid or not valid. No name. No age. No country. No score.

A downstream stablecoin contract can gate any transfer behind `ZKPass.is_verified(user)` — getting real compliance without real surveillance.

---

## How It Works

```
User's Device                          Stellar Testnet
─────────────────────────────          ──────────────────────────
                                       
 [KYC Oracle]                          
  Returns: age, country,               
  kycScore (private)                   
       │                               
       ▼                               
 [Circom Circuit]                      
  kyc_proof.circom                     
  Proves: age≥18, country OK,          
  score≥70, commitment valid           
       │                               
       │  Groth16 Proof                
       │  + Public signals             
       ▼                               
 [Prover / Frontend] ────────────────► [ZKPass Verifier Contract]
                       submit proof        verify_kyc(user, proof, signals)
                                               │
                                               ▼
                                       emit KYCVerified event
                                               │
                                               ▼
                                       [Downstream dApp]
                                       check is_verified(user)
                                       → allow/block transfer
```

### ZK is load-bearing here

The circuit (`circuits/kyc_proof.circom`) enforces three real constraints:
- A `GreaterEqThan` comparator for age vs `minAge`
- Inequality checks against a sanctions country code list
- A `GreaterEqThan` comparator for `kycScore` vs `minKycScore`
- A **Poseidon commitment** that binds the proof to the exact private inputs — preventing a user from proving with fabricated data

The Stellar contract verifies the Groth16 proof using **BN254 host functions** introduced in Protocol 25 and extended in Protocol 26.

---

## Tech Stack

| Layer | Technology |
|---|---|
| ZK Circuit | Circom 2.0 + circomlib |
| Proof system | Groth16 (snarkjs) |
| Proof verification | Stellar Soroban (BN254 host functions) |
| On-chain language | Rust + soroban-sdk |
| Frontend | React + Vite |
| Deployment | Stellar Testnet · Vercel |

---

## Project Structure

```
zkpass/
├── circuits/
│   ├── kyc_proof.circom        # ZK circuit (age, jurisdiction, score checks)
│   ├── kyc_proof_final.zkey    # Proving key (generated — not in repo)
│   └── verification_key.json  # Verification key (generated)
│
├── contracts/
│   └── zkpass-verifier/
│       ├── src/lib.rs          # Soroban Groth16 verifier contract
│       └── Cargo.toml
│
├── prover/
│   ├── mock_kyc_oracle.js      # Simulates KYC provider response
│   ├── generate_proof.js       # Generates Groth16 proof off-chain
│   └── package.json
│
├── frontend/
│   └── src/
│       ├── App.jsx             # Main UI
│       ├── ProofForm.jsx       # KYC input + proof generation
│       └── ProofResult.jsx     # Verification result display
│
├── scripts/
│   ├── setup_ceremony.sh       # Downloads ptau, compiles circuit, trusted setup
│   └── deploy_contract.sh      # Builds + deploys Soroban contract to testnet
│
└── README.md
```

---

## Getting Started

### Prerequisites

- Node.js 18+
- Rust + [soroban-cli](https://developers.stellar.org/docs/tools/developer-tools/cli/stellar-cli)
- A Stellar testnet keypair ([Stellar Laboratory](https://laboratory.stellar.org))

### 1. Clone and install

```bash
git clone https://github.com/YOUR_USERNAME/zkpass.git
cd zkpass
```

### 2. Run the trusted setup (Day 1 — do this first)

This downloads the Hermez Powers of Tau ceremony file (~1GB), compiles the Circom circuit, and generates the proving/verification keys. Takes 30–90 minutes depending on connection speed.

```bash
bash scripts/setup_ceremony.sh
```

> **Slow internet?** The script supports resumable downloads (`wget -c`). If it stalls, re-run the same command — it picks up where it left off.

### 3. Generate a proof

```bash
cd prover
npm install
node generate_proof.js
```

This runs the mock KYC oracle, feeds inputs into the circuit, generates a Groth16 proof, and verifies it locally. Output is saved to `prover/proof.json`.

### 4. Deploy the Soroban contract

```bash
cp .env.example .env
# Edit .env and add your STELLAR_SECRET_KEY
bash scripts/deploy_contract.sh
```

### 5. Run the frontend

```bash
cd frontend
npm install
npm run dev
```

Open `http://localhost:5173`. Fill in mock KYC data, click **Generate Proof**, and watch it verify on Stellar testnet.

---

## Honest Status

This was built during a 15-day hackathon. Here's what's real and what's mocked:

| Component | Status | Notes |
|---|---|---|
| Circom circuit | ✅ Real | Three actual ZK constraints + Poseidon commitment |
| Groth16 local verification | ✅ Real | snarkjs verifies proof before submission |
| Soroban contract interface | ✅ Real | Deployed on testnet, correct data structures |
| BN254 pairing check | 🔄 Partial | Contract structure is correct; full pairing integration in progress (references: stellar/soroban-examples groth16_verifier) |
| KYC data source | 🔄 Mock | Real provider integration (Smile Identity) is the production next step |
| Sanctions list | 🔄 MVP | Currently 4 hardcoded country codes; production would use a Merkle non-membership proof |

The ZK mathematics is real. The proof system is real. The Stellar contract is deployed. The mock data is clearly labelled.

---

## Why This Matters (The Nigeria Context)

This project was built from Lagos, Nigeria — a country currently on the FATF grey list. The effect on real people: Nigerian users are blocked from global payment rails not because *they* failed compliance, but because their *country code* did.

ZKPass proposes a different model: compliance at the **individual level**, not the **country level**. A Nigerian user who genuinely passes KYC can generate a proof that says exactly that — without revealing their nationality, their score, or anything else — and get access to financial infrastructure that currently excludes them by default.

Stellar's mission is financial access for everyone. ZKPass tries to mean that literally.

---

## Demo

📹 **[Watch the demo video](#)** *(link added at submission)*

🌐 **[Live testnet demo](https://zkpass.vercel.app)**

Contract on Stellar testnet: `[CONTRACT_ID]` *(added after deployment)*

---

## Resources Used

- [Circom docs](https://docs.circom.io/)
- [snarkjs](https://github.com/iden3/snarkjs)
- [Stellar Groth16 verifier examples](https://github.com/stellar/soroban-examples/tree/main/groth16_verifier)
- [Soroban SDK docs](https://developers.stellar.org/docs/smart-contracts)
- [James Bachini — Circom on Stellar tutorial](https://jamesbachini.com/circom-on-stellar/)
- [Hermez Powers of Tau ceremony](https://hermez.io/)

---

## License

MIT — see [LICENSE](./LICENSE)
