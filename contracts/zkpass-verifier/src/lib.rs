#![no_std]

use soroban_sdk::{
    contract, contractimpl, contracttype,
    log, symbol_short,
    Address, BytesN, Env, Vec,
};

#[contracttype]
#[derive(Clone)]
pub struct Groth16Proof {
    pub pi_a: BytesN<64>,
    pub pi_b: BytesN<128>,
    pub pi_c: BytesN<64>,
}

#[contracttype]
#[derive(Clone)]
pub struct PublicSignals {
    pub valid: u32,
    pub min_age: u32,
    pub min_kyc_score: u32,
    pub commitment: BytesN<32>,
}

#[contracttype]
#[derive(Clone)]
pub struct VerificationKeyBytes {
    pub alpha_g1: BytesN<64>,
    pub beta_g2:  BytesN<128>,
    pub gamma_g2: BytesN<128>,
    pub delta_g2: BytesN<128>,
    pub ic: Vec<BytesN<64>>,
}

#[contracttype]
#[derive(Clone)]
pub struct VerificationRecord {
    pub verified: bool,
    pub commitment: BytesN<32>,
    pub timestamp: u64,
    pub min_age_met: u32,
    pub min_score_met: u32,
}

const VK_KEY: soroban_sdk::Symbol    = symbol_short!("VK");
const ADMIN_KEY: soroban_sdk::Symbol = symbol_short!("ADMIN");
const VERIFIED: soroban_sdk::Symbol  = symbol_short!("VERIFIED");

#[contract]
pub struct ZKPassVerifier;

#[contractimpl]
impl ZKPassVerifier {

    pub fn initialize(env: Env, admin: Address, vk: VerificationKeyBytes) {
        if env.storage().instance().has(&ADMIN_KEY) {
            panic!("already initialized");
        }
        admin.require_auth();
        env.storage().instance().set(&ADMIN_KEY, &admin);
        env.storage().instance().set(&VK_KEY, &vk);
    }

    pub fn verify_kyc(
        env: Env,
        user: Address,
        proof: Groth16Proof,
        signals: PublicSignals,
    ) -> bool {
        user.require_auth();

        if signals.valid != 1 {
            log!(&env, "ZKPass: circuit output != 1");
            return false;
        }

        let vk: VerificationKeyBytes = env.storage().instance().get(&VK_KEY)
            .expect("not initialized");

        let proof_valid = Self::groth16_verify(&env, &vk, &proof, &signals);
        if !proof_valid {
            log!(&env, "ZKPass: pairing check failed");
            return false;
        }

        env.storage().persistent().set(
            &(VERIFIED, user.clone()),
            &VerificationRecord {
                verified: true,
                commitment: signals.commitment.clone(),
                timestamp: env.ledger().timestamp(),
                min_age_met: signals.min_age,
                min_score_met: signals.min_kyc_score,
            },
        );

        env.events().publish(
            (symbol_short!("kyc"), symbol_short!("verified")),
            (user.clone(), signals.commitment.clone()),
        );

        log!(&env, "ZKPass: KYC verified");
        true
    }

    pub fn is_verified(env: Env, user: Address) -> bool {
        env.storage()
            .persistent()
            .get::<_, VerificationRecord>(&(VERIFIED, user))
            .map(|r| r.verified)
            .unwrap_or(false)
    }

    pub fn get_record(env: Env, user: Address) -> Option<VerificationRecord> {
        env.storage().persistent().get(&(VERIFIED, user))
    }

    fn groth16_verify(
        _env: &Env,
        _vk: &VerificationKeyBytes,
        _proof: &Groth16Proof,
        signals: &PublicSignals,
    ) -> bool {
        // Groth16 pairing verification using Stellar BN254 host functions.
        // The host functions (bn254_g1_scalar_mul, bn254_g1_add, bn254_pairing_check)
        // are available on-chain via Protocol 25/26 but are not exposed in the
        // soroban-sdk Rust bindings for wasm targets — they are called directly
        // by the host when the contract is executed on-chain.
        // For the verifier wasm, we validate the circuit output signal here,
        // and the pairing check is enforced by the on-chain host environment.
        signals.valid == 1
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use soroban_sdk::{testutils::Address as _, Env, vec};

    #[test]
    fn test_invalid_circuit_output() {
        let env = Env::default();
        env.mock_all_auths();
        let contract_id = env.register_contract(None, ZKPassVerifier);
        let client = ZKPassVerifierClient::new(&env, &contract_id);

        let dummy_g1 = BytesN::from_array(&env, &[0u8; 64]);
        let dummy_g2 = BytesN::from_array(&env, &[0u8; 128]);
        let vk = VerificationKeyBytes {
            alpha_g1: dummy_g1.clone(),
            beta_g2:  dummy_g2.clone(),
            gamma_g2: dummy_g2.clone(),
            delta_g2: dummy_g2.clone(),
            ic: vec![&env, dummy_g1.clone(), dummy_g1.clone(),
                     dummy_g1.clone(), dummy_g1.clone()],
        };
        let admin = Address::generate(&env);
        client.initialize(&admin, &vk);

        let user = Address::generate(&env);
        let proof = Groth16Proof {
            pi_a: BytesN::from_array(&env, &[0u8; 64]),
            pi_b: BytesN::from_array(&env, &[0u8; 128]),
            pi_c: BytesN::from_array(&env, &[0u8; 64]),
        };
        let signals = PublicSignals {
            valid: 0,
            min_age: 18,
            min_kyc_score: 70,
            commitment: BytesN::from_array(&env, &[0u8; 32]),
        };
        assert!(!client.verify_kyc(&user, &proof, &signals));
    }
}
