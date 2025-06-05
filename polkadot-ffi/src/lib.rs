use schnorrkel::{Keypair, MiniSecretKey, PublicKey, SecretKey, Signature};
use sp_core::crypto::Pair;
use sp_core::sr25519;
use sp_core::{blake2_256, crypto::Ss58Codec};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::catch_unwind;

mod extrinsic;
pub use extrinsic::*;

#[repr(C)]
pub struct ExtrinsicResult {
    pub success: bool,
    pub data: *mut c_char,
    pub error: *mut c_char,
}

// Helper function to clamp a scalar for Sr25519
fn clamp_scalar(mut bytes: [u8; 32]) -> [u8; 32] {
    bytes[0] &= 248;
    bytes[31] &= 127;
    bytes[31] |= 64;
    bytes
}

#[no_mangle]
pub extern "C" fn sign_extrinsic(
    seed_hex: *const c_char,
    extrinsic_hex: *const c_char,
) -> ExtrinsicResult {
    let result = unsafe {
        let seed_str = CStr::from_ptr(seed_hex).to_string_lossy();
        let extrinsic_str = CStr::from_ptr(extrinsic_hex).to_string_lossy();

        // Remove 0x prefix if present
        let seed_str = if seed_str.starts_with("0x") {
            &seed_str[2..]
        } else {
            &seed_str
        };

        let extrinsic_str = if extrinsic_str.starts_with("0x") {
            &extrinsic_str[2..]
        } else {
            &extrinsic_str
        };

        match (
            hex::decode(seed_str.as_bytes()),
            hex::decode(extrinsic_str.as_bytes()),
        ) {
            (Ok(seed), Ok(extrinsic)) => {
                // Convert seed to MiniSecretKey
                match MiniSecretKey::from_bytes(&seed) {
                    Ok(mini_secret) => {
                        // Expand the mini secret key into a full keypair
                        let keypair =
                            mini_secret.expand_to_keypair(schnorrkel::ExpansionMode::Ed25519);
                        let context = b"substrate";
                        let signature = keypair.sign_simple(context, &extrinsic);
                        let signature_bytes = signature.to_bytes();
                        let hex_result = hex::encode(signature_bytes);

                        ExtrinsicResult {
                            success: true,
                            data: CString::new(hex_result).unwrap().into_raw(),
                            error: std::ptr::null_mut(),
                        }
                    }
                    Err(e) => ExtrinsicResult {
                        success: false,
                        data: std::ptr::null_mut(),
                        error: CString::new(format!("Failed to create keypair: {}", e))
                            .unwrap()
                            .into_raw(),
                    },
                }
            }
            _ => ExtrinsicResult {
                success: false,
                data: std::ptr::null_mut(),
                error: CString::new("Invalid hex input").unwrap().into_raw(),
            },
        }
    };
    result
}

#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

pub fn add(left: u64, right: u64) -> u64 {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
}

// === derive_sr25519_public_key ===
#[no_mangle]
pub extern "C" fn derive_sr25519_public_key(seed_hex: *const c_char) -> ExtrinsicResult {
    // SAFETY: seed_hex must be a valid C string.
    let seed_str = unsafe { CStr::from_ptr(seed_hex).to_string_lossy() };

    // Strip 0x if present
    let seed_clean = if seed_str.starts_with("0x") {
        &seed_str[2..]
    } else {
        &seed_str
    };

    match hex::decode(seed_clean) {
        Ok(seed_bytes) => match MiniSecretKey::from_bytes(&seed_bytes) {
            Ok(mini) => {
                let kp = mini.expand_to_keypair(schnorrkel::ExpansionMode::Ed25519);
                let pub_key_bytes = kp.public.to_bytes();
                let hex_pub = hex::encode(pub_key_bytes);
                ExtrinsicResult {
                    success: true,
                    data: CString::new(hex_pub).unwrap().into_raw(),
                    error: std::ptr::null_mut(),
                }
            }
            Err(e) => ExtrinsicResult {
                success: false,
                data: std::ptr::null_mut(),
                error: CString::new(format!("MiniSecretKey error: {}", e))
                    .unwrap()
                    .into_raw(),
            },
        },
        Err(e) => ExtrinsicResult {
            success: false,
            data: std::ptr::null_mut(),
            error: CString::new(format!("Hex decode error: {}", e))
                .unwrap()
                .into_raw(),
        },
    }
}

// Re-export the signing payload builder from extrinsic.rs
extern "C" {
    pub fn make_signing_payload(
        module_index: u8,
        function_index: u8,
        arguments_ptr: *const u8,
        arguments_len: usize,
        nonce: u32,
        tip_low: u64,
        tip_high: u64,
        era_mortal: bool,
        era_period: u8,
        era_phase: u8,
        spec_version: u32,
        transaction_version: u32,
        genesis_hash_ptr: *const u8,
        block_hash_ptr: *const u8,
        out_ptr: *mut *mut u8,
        out_len: *mut usize,
    ) -> i32;

}

// === compute_ss58_address ===
#[no_mangle]
pub extern "C" fn compute_ss58_address(
    public_key_hex: *const c_char,
    network_prefix: u16,
) -> ExtrinsicResult {
    let pub_key_str = unsafe { CStr::from_ptr(public_key_hex).to_string_lossy() };

    // Strip 0x if present
    let pub_key_clean = if pub_key_str.starts_with("0x") {
        &pub_key_str[2..]
    } else {
        &pub_key_str
    };

    match hex::decode(pub_key_clean) {
        Ok(pub_key_bytes) => {
            if pub_key_bytes.len() != 32 {
                return ExtrinsicResult {
                    success: false,
                    data: std::ptr::null_mut(),
                    error: CString::new("Public key must be 32 bytes")
                        .unwrap()
                        .into_raw(),
                };
            }

            let mut key_array = [0u8; 32];
            key_array.copy_from_slice(&pub_key_bytes);

            // Create AccountId32 and encode as SS58
            let account_id = sp_core::crypto::AccountId32::from(key_array);
            let ss58_address = account_id.to_ss58check_with_version(network_prefix.into());

            ExtrinsicResult {
                success: true,
                data: CString::new(ss58_address).unwrap().into_raw(),
                error: std::ptr::null_mut(),
            }
        }
        Err(e) => ExtrinsicResult {
            success: false,
            data: std::ptr::null_mut(),
            error: CString::new(format!("Hex decode error: {}", e))
                .unwrap()
                .into_raw(),
        },
    }
}

// === derive_sr25519_from_mnemonic ===
#[no_mangle]
pub extern "C" fn derive_sr25519_from_mnemonic(mnemonic_ptr: *const c_char) -> ExtrinsicResult {
    // SAFETY: mnemonic_ptr must be a valid C string
    let phrase = unsafe { CStr::from_ptr(mnemonic_ptr).to_string_lossy() };

    match sr25519::Pair::from_phrase(&phrase, None) {
        Ok((pair, _seed)) => {
            // Extract secret seed from raw vec (first 32 bytes)
            let raw = pair.to_raw_vec();
            if raw.len() < 32 {
                return ExtrinsicResult {
                    success: false,
                    data: std::ptr::null_mut(),
                    error: CString::new("Invalid raw key length").unwrap().into_raw(),
                };
            }
            let seed_bytes = &raw[0..32];
            let pub_bytes = pair.public().0;
            let seed_hex = format!("0x{}", hex::encode(seed_bytes));
            let pub_hex = format!("0x{}", hex::encode(pub_bytes));
            let json_out = format!("{{\"seed\":\"{}\",\"public\":\"{}\"}}", seed_hex, pub_hex);
            ExtrinsicResult {
                success: true,
                data: CString::new(json_out).unwrap().into_raw(),
                error: std::ptr::null_mut(),
            }
        }
        Err(e) => ExtrinsicResult {
            success: false,
            data: std::ptr::null_mut(),
            error: CString::new(format!("Mnemonic error: {}", e))
                .unwrap()
                .into_raw(),
        },
    }
}

// === decode_ss58_address ===
#[no_mangle]
pub extern "C" fn decode_ss58_address(ss58_address: *const c_char) -> ExtrinsicResult {
    let address_str = unsafe { CStr::from_ptr(ss58_address).to_string_lossy() };

    match sp_core::crypto::AccountId32::from_ss58check(&address_str) {
        Ok(account_id) => {
            let public_key_bytes: &[u8] = account_id.as_ref();
            let public_key_hex = hex::encode(public_key_bytes);
            ExtrinsicResult {
                success: true,
                data: CString::new(public_key_hex).unwrap().into_raw(),
                error: std::ptr::null_mut(),
            }
        }
        Err(e) => ExtrinsicResult {
            success: false,
            data: std::ptr::null_mut(),
            error: CString::new(format!("SS58 decode error: {}", e))
                .unwrap()
                .into_raw(),
        },
    }
}

#[no_mangle]
pub extern "C" fn blake2_128_hash(data: *const c_char) -> ExtrinsicResult {
    let data_str = unsafe { CStr::from_ptr(data).to_string_lossy() };

    // Strip 0x if present
    let data_clean = if data_str.starts_with("0x") {
        &data_str[2..]
    } else {
        &data_str
    };

    match hex::decode(data_clean) {
        Ok(data_bytes) => {
            let hash = sp_core::blake2_128(&data_bytes);
            let hash_hex = hex::encode(hash);
            ExtrinsicResult {
                success: true,
                data: CString::new(hash_hex).unwrap().into_raw(),
                error: std::ptr::null_mut(),
            }
        }
        Err(e) => ExtrinsicResult {
            success: false,
            data: std::ptr::null_mut(),
            error: CString::new(format!("Hex decode error: {}", e))
                .unwrap()
                .into_raw(),
        },
    }
}
