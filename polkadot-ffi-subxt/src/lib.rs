use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::catch_unwind;
use std::sync::OnceLock;
use serde::{Deserialize, Serialize};
use sp_core::blake2_128;
use sp_core::crypto::{Pair, Ss58Codec};
use sp_core::sr25519;
use subxt::{OnlineClient, PolkadotConfig, dynamic::Value, ext::scale_value::Composite, tx};
use subxt_signer::{bip39::Mnemonic, sr25519::Keypair};
use std::str::FromStr;
use tokio::runtime::Runtime;
use hex;

static TOKIO: OnceLock<Runtime> = OnceLock::new();
fn tokio_rt() -> &'static Runtime {
    TOKIO.get_or_init(|| Runtime::new().expect("failed to start tokio"))
}

// Note: We'll add metadata generation later when we have the metadata file
// #[subxt::subxt(runtime_metadata_path = "./polkadot_metadata.scale")]
// pub mod polkadot {}

#[repr(C)]
pub struct ExtrinsicResult {
    pub success: bool,
    pub data: *mut c_char,
    pub error: *mut c_char,
}

#[repr(C)]
pub struct TransferResult {
    pub success: bool,
    pub tx_hash: *mut c_char,
    pub error: *mut c_char,
}

#[derive(Serialize, Deserialize)]
struct KeypairInfo {
    seed: String,
    public: String,
}

// Helper function to create ExtrinsicResult
fn create_result(success: bool, data: Option<String>, error: Option<String>) -> ExtrinsicResult {
    ExtrinsicResult {
        success,
        data: data.map(|s| CString::new(s).unwrap().into_raw()).unwrap_or(std::ptr::null_mut()),
        error: error.map(|s| CString::new(s).unwrap().into_raw()).unwrap_or(std::ptr::null_mut()),
    }
}

#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

// === Keypair Management ===

#[no_mangle]
pub extern "C" fn derive_sr25519_from_mnemonic(mnemonic_ptr: *const c_char) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let phrase = unsafe { CStr::from_ptr(mnemonic_ptr).to_string_lossy() };

        match sr25519::Pair::from_phrase(&phrase, None) {
            Ok((pair, _seed)) => {
                // Extract secret seed from raw vec (first 32 bytes)
                let raw = pair.to_raw_vec();
                if raw.len() < 32 {
                    return create_result(false, None, Some("Invalid raw key length".to_string()));
                }
                let seed_bytes = &raw[0..32];
                let pub_bytes = pair.public().0;
                let seed_hex = format!("0x{}", hex::encode(seed_bytes));
                let pub_hex = format!("0x{}", hex::encode(pub_bytes));
                let json_out = format!("{{\"seed\":\"{}\",\"public\":\"{}\"}}", seed_hex, pub_hex);
                create_result(true, Some(json_out), None)
            }
            Err(e) => create_result(false, None, Some(format!("Mnemonic error: {:?}", e))),
        }
    });
    
    result.unwrap_or_else(|_| create_result(false, None, Some("Panic occurred".to_string())))
}

#[no_mangle]
pub extern "C" fn derive_sr25519_public_key(seed_hex: *const c_char) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let seed_str = unsafe { CStr::from_ptr(seed_hex).to_string_lossy() };
        let seed_clean = seed_str.strip_prefix("0x").unwrap_or(&seed_str);
        
        match hex::decode(seed_clean) {
            Ok(seed_bytes) => {
                if seed_bytes.len() != 32 {
                    return create_result(false, None, Some("Seed must be 32 bytes".to_string()));
                }
                
                // Use sp_core::sr25519::Pair for compatibility
                let pair = sr25519::Pair::from_seed(&seed_bytes.try_into().unwrap());
                let public_hex = format!("0x{}", hex::encode(pair.public().0));
                create_result(true, Some(public_hex), None)
            }
            Err(e) => create_result(false, None, Some(format!("Hex decode error: {}", e))),
        }
    });
    
    result.unwrap_or_else(|_| create_result(false, None, Some("Panic occurred".to_string())))
}

// === Address Management ===

#[no_mangle]
pub extern "C" fn compute_ss58_address(public_key_hex: *const c_char, network_prefix: u16) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let pub_key_str = unsafe { CStr::from_ptr(public_key_hex).to_string_lossy() };
        let pub_key_clean = pub_key_str.strip_prefix("0x").unwrap_or(&pub_key_str);
        
        match hex::decode(pub_key_clean) {
            Ok(pub_key_bytes) => {
                if pub_key_bytes.len() != 32 {
                    return create_result(false, None, Some("Public key must be 32 bytes".to_string()));
                }

                let mut key_array = [0u8; 32];
                key_array.copy_from_slice(&pub_key_bytes);

                // Create AccountId32 and encode as SS58
                let account_id = sp_core::crypto::AccountId32::from(key_array);
                let ss58_address = account_id.to_ss58check_with_version(sp_core::crypto::Ss58AddressFormat::custom(network_prefix as u16));
                create_result(true, Some(ss58_address), None)
            }
            Err(e) => create_result(false, None, Some(format!("Hex decode error: {}", e))),
        }
    });
    
    result.unwrap_or_else(|_| create_result(false, None, Some("Panic occurred".to_string())))
}

#[no_mangle]
pub extern "C" fn decode_ss58_address(ss58_address: *const c_char) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let address_str = unsafe { CStr::from_ptr(ss58_address).to_string_lossy() };

        match sp_core::crypto::AccountId32::from_ss58check_with_version(&address_str) {
            Ok((account_id, _)) => {
                let public_key_bytes: &[u8] = account_id.as_ref();
                let public_key_hex = hex::encode(public_key_bytes);
                create_result(true, Some(public_key_hex), None)
            }
            Err(e) => create_result(false, None, Some(format!("SS58 decode error: {:?}", e))),
        }
    });
    
    result.unwrap_or_else(|_| create_result(false, None, Some("Panic occurred".to_string())))
}

// === Subxt-based Transaction Functions ===

/// Query account balance from a Substrate node
#[no_mangle]
pub extern "C" fn query_balance(
    node_url: *const c_char,
    address: *const c_char,
) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let node_url_str = unsafe { CStr::from_ptr(node_url).to_string_lossy() };
        let address_str = unsafe { CStr::from_ptr(address).to_string_lossy() };

        // Parse address
        let account_id = match subxt::utils::AccountId32::from_str(&address_str) {
            Ok(addr) => addr,
            Err(e) => return create_result(false, None, Some(format!("Address error: {}", e))),
        };

        // Connect to the node
        let client = match tokio_rt().block_on(async {
            OnlineClient::<PolkadotConfig>::from_url(&node_url_str).await
        }) {
            Ok(client) => client,
            Err(e) => return create_result(false, None, Some(format!("Connection error: {}", e))),
        };

        // Query account info
        let result: Result<Option<String>, subxt::Error> = tokio_rt().block_on(async {
            // Create storage address for System.Account
            let storage_address = subxt::dynamic::storage(
                "System",
                "Account",
                vec![Value::from_bytes(account_id.0.to_vec())],
            );
            
            let account_data = client.storage().at_latest().await?.fetch(&storage_address).await?;
            
            if let Some(data) = account_data {
                // Decode the account data value
                let value = data.to_value()?;
                Ok(Some(format!("{:?}", value)))
            } else {
                Ok(None)
            }
        });

        match result {
            Ok(Some(json)) => {
                create_result(true, Some(json), None)
            },
            Ok(None) => {
                // Account doesn't exist
                create_result(true, Some(String::from("{\"free\":0,\"reserved\":0,\"frozen\":0}")), None)
            },
            Err(e) => create_result(false, None, Some(format!("Query error: {}", e))),
        }
    });

    result.unwrap_or_else(|_| create_result(false, None, Some(String::from("Panic occurred"))))
}

/// Submit a balance transfer transaction
#[no_mangle]
pub extern "C" fn submit_balance_transfer_subxt(
    node_url: *const c_char,
    mnemonic: *const c_char,
    dest_address: *const c_char,
    amount: u128,
) -> TransferResult {
    let result = catch_unwind(|| {
        let node_url_str = unsafe { CStr::from_ptr(node_url).to_string_lossy() };
        let mnemonic_str = unsafe { CStr::from_ptr(mnemonic).to_string_lossy() };
        let dest_address_str = unsafe { CStr::from_ptr(dest_address).to_string_lossy() };

        // Parse mnemonic and create keypair
        let mnemonic = match Mnemonic::parse_normalized(&*mnemonic_str) {
            Ok(m) => m,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Mnemonic error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let sender_keypair = match Keypair::from_phrase(&mnemonic, None) {
            Ok(kp) => kp,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Keypair error: {}", e)).unwrap().into_raw(),
            },
        };

        // Parse destination address
        let dest = match subxt::utils::AccountId32::from_str(&dest_address_str) {
            Ok(d) => d,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Address error: {}", e)).unwrap().into_raw(),
            },
        };

        // Connect to the node using the static runtime
        let client = match tokio_rt().block_on(async {
            OnlineClient::<PolkadotConfig>::from_url(&node_url_str).await
        }) {
            Ok(client) => client,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Connection error: {}", e)).unwrap().into_raw(),
            },
        };

        // Wrap destination into a MultiAddress::Id variant for dynamic calls
        let dst = Value::variant(
            "Id",
            Composite::unnamed(vec![
                Value::from_bytes(dest.0.to_vec()),
            ]),
        );

        // Build the dynamic metadata extrinsic
        let tx = tx::dynamic(
            "Balances",
            "transfer_keep_alive",
            vec![
                dst,
                Value::u128(amount),
            ],
        );

        // Submit and wait for finalize
        let result = tokio_rt().block_on(async {
            let progress = client
                .tx()
                .sign_and_submit_then_watch_default(&tx, &sender_keypair, )
                .await;
            
            match progress {
                Ok(progress) => {
                    let events = progress.wait_for_finalized_success().await;
                    match events {
                        Ok(events) => {
                            let tx_hash = events.extrinsic_hash();
                            Ok(format!("0x{}", hex::encode(tx_hash.0)))
                        },
                        Err(e) => Err(format!("Finalization error: {}", e)),
                    }
                },
                Err(e) => Err(format!("Submit error: {}", e)),
            }
        });

        match result {
            Ok(tx_hash) => TransferResult {
                success: true,
                tx_hash: CString::new(tx_hash).unwrap().into_raw(),
                error: std::ptr::null_mut(),
            },
            Err(e) => TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(e).unwrap().into_raw(),
            },
        }
    });

    result.unwrap_or_else(|_| TransferResult {
        success: false,
        tx_hash: std::ptr::null_mut(),
        error: CString::new("Panic occurred").unwrap().into_raw(),
    })
}

// === Legacy Compatibility Functions ===

// These functions maintain compatibility with the existing Lua code
// but delegate to subxt implementations where possible

#[no_mangle]
pub extern "C" fn sign_extrinsic(
    seed_hex: *const c_char,
    extrinsic_hex: *const c_char,
) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let seed_str = unsafe { CStr::from_ptr(seed_hex).to_string_lossy() };
        let extrinsic_str = unsafe { CStr::from_ptr(extrinsic_hex).to_string_lossy() };
        
        let seed_clean = seed_str.strip_prefix("0x").unwrap_or(&seed_str);
        let extrinsic_clean = extrinsic_str.strip_prefix("0x").unwrap_or(&extrinsic_str);
        
        match (hex::decode(seed_clean), hex::decode(extrinsic_clean)) {
            (Ok(seed), Ok(extrinsic)) => {
                if seed.len() != 32 {
                    return create_result(false, None, Some("Seed must be 32 bytes".to_string()));
                }
                
                // Use sp_core::sr25519::Pair for signing
                let pair = sr25519::Pair::from_seed(&seed.try_into().unwrap());
                let signature = pair.sign(&extrinsic);
                let signature_hex = format!("0x{}", hex::encode(signature.0));
                create_result(true, Some(signature_hex), None)
            }
            _ => create_result(false, None, Some("Invalid hex input".to_string())),
        }
    });
    
    result.unwrap_or_else(|_| create_result(false, None, Some("Panic occurred".to_string())))
}

#[no_mangle]
pub extern "C" fn blake2_128_hash(data: *const c_char) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let data_str = unsafe { CStr::from_ptr(data).to_string_lossy() };
        let data_clean = data_str.strip_prefix("0x").unwrap_or(&data_str);
        
        match hex::decode(data_clean) {
            Ok(data_bytes) => {
                let hash = blake2_128(&data_bytes);
                let hash_hex = hex::encode(hash);
                create_result(true, Some(hash_hex), None)
            }
            Err(e) => create_result(false, None, Some(format!("Hex decode error: {}", e))),
        }
    });
    
    result.unwrap_or_else(|_| create_result(false, None, Some("Panic occurred".to_string())))
}

// === Metadata Management ===

#[no_mangle]
pub extern "C" fn download_metadata(_node_url: *const c_char) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        // This would use subxt-cli to download metadata
        // For now, return a placeholder
        create_result(false, None, Some("Metadata download requires subxt-cli integration".to_string()))
    });
    
    result.unwrap_or_else(|_| create_result(false, None, Some("Panic occurred".to_string())))
}

#[no_mangle]
pub extern "C" fn download_and_use_metadata(node_url: *const c_char) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let node_url_str = unsafe { CStr::from_ptr(node_url).to_string_lossy() };

        // Create a tokio runtime for async operations
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();
        
        let result = rt.block_on(async {
            // Connect to the node
            let api = OnlineClient::<PolkadotConfig>::from_url(&node_url_str).await
                .map_err(|e| format!("Connection error: {}", e))?;

            // Get the metadata using the correct method
            let _metadata = api.metadata();

            // For now, return basic metadata info
            let metadata_info = "Metadata downloaded successfully".to_string();
            Ok(metadata_info)
        });

        match result {
            Ok(info) => create_result(true, Some(info), None),
            Err(e) => create_result(false, None, Some(e)),
        }
    });

    result.unwrap_or_else(|_| create_result(false, None, Some("Panic occurred".to_string())))
}

// === Tests ===

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_derive_from_mnemonic() {
        let mnemonic = "helmet myself order all require large unusual verify ritual final apart nut";
        let c_str = std::ffi::CString::new(mnemonic).unwrap();
        let result = derive_sr25519_from_mnemonic(c_str.as_ptr());
        
        assert!(result.success);
        assert!(!result.data.is_null());
        assert!(result.error.is_null());
        
        unsafe {
            let json_str = CStr::from_ptr(result.data).to_string_lossy();
            let keypair_info: KeypairInfo = serde_json::from_str(&json_str).unwrap();
            assert!(keypair_info.seed.starts_with("0x"));
            assert!(keypair_info.public.starts_with("0x"));
            free_string(result.data);
        }
    }
}
