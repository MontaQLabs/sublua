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

// === Advanced Cryptographic Features ===

/// Multi-signature account operations
#[no_mangle]
pub extern "C" fn create_multisig_address(
    signatories_json: *const c_char,  // JSON array of SS58 addresses
    threshold: u16,
) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let signatories_str = unsafe { CStr::from_ptr(signatories_json).to_string_lossy() };
        
        // Parse JSON array of addresses
        let signatories: Vec<String> = match serde_json::from_str(&signatories_str) {
            Ok(s) => s,
            Err(e) => return create_result(false, None, Some(format!("JSON parse error: {}", e))),
        };
        
        // Convert to AccountId32
        let mut account_ids: Vec<subxt::utils::AccountId32> = Vec::new();
        for addr in signatories {
            match subxt::utils::AccountId32::from_str(&addr) {
                Ok(id) => account_ids.push(id),
                Err(e) => return create_result(false, None, Some(format!("Invalid address {}: {}", addr, e))),
            }
        }
        
        // Sort signatories (required by Substrate multisig)
        account_ids.sort();
        
        // Create multisig address using sp_runtime::MultiSigner logic
        // The multisig address is derived from: blake2_256(b"modlpy/utilisuba" ++ threshold ++ signatories)
        let mut data = b"modlpy/utilisuba".to_vec();
        data.extend_from_slice(&threshold.to_le_bytes());
        for id in &account_ids {
            data.extend_from_slice(id.as_ref());
        }
        
        let hash = sp_core::blake2_256(&data);
        let multisig_account = subxt::utils::AccountId32::from(hash);
        
        // Return multisig info as JSON
        let multisig_info = serde_json::json!({
            "multisig_address": multisig_account.to_string(),
            "threshold": threshold,
            "signatories": account_ids.iter().map(|a| a.to_string()).collect::<Vec<_>>(),
        });
        
        create_result(true, Some(multisig_info.to_string()), None)
    });
    
    result.unwrap_or_else(|_| create_result(false, None, Some("Panic in create_multisig_address".to_string())))
}

/// Proxy account operations - Add a proxy
#[no_mangle]
pub extern "C" fn add_proxy(
    rpc_url: *const c_char,
    mnemonic: *const c_char,
    delegate: *const c_char,
    proxy_type: *const c_char,  // "Any", "NonTransfer", "Governance", etc.
    delay: u32,  // Block delay (0 for no delay)
) -> TransferResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        let mnem_str = unsafe { CStr::from_ptr(mnemonic).to_string_lossy().into_owned() };
        let delegate_str = unsafe { CStr::from_ptr(delegate).to_string_lossy().into_owned() };
        let proxy_type_str = unsafe { CStr::from_ptr(proxy_type).to_string_lossy().into_owned() };
        
        // Parse mnemonic and create keypair
        let mnemonic = match Mnemonic::parse_normalized(&mnem_str) {
            Ok(m) => m,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Mnemonic error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let signer = match Keypair::from_phrase(&mnemonic, None) {
            Ok(kp) => kp,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Keypair error: {}", e)).unwrap().into_raw(),
            },
        };
        
        // Parse delegate address
        let delegate_account = match subxt::utils::AccountId32::from_str(&delegate_str) {
            Ok(d) => d,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Address error: {}", e)).unwrap().into_raw(),
            },
        };
        
        // Connect to node
        let client = match tokio_rt().block_on(async {
            OnlineClient::<PolkadotConfig>::from_url(&url).await
        }) {
            Ok(client) => client,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Connection error: {}", e)).unwrap().into_raw(),
            },
        };
        
        // Create proxy type variant (using dynamic API)
        let proxy_type_value = Value::variant(proxy_type_str.as_str(), Composite::unnamed(vec![]));
        
        // Build the add_proxy call
        let tx = tx::dynamic(
            "Proxy",
            "add_proxy",
            vec![
                Value::variant("Id", Composite::unnamed(vec![Value::from_bytes(delegate_account.0.to_vec())])),
                proxy_type_value,
                Value::u128(delay as u128),
            ],
        );
        
        // Submit transaction
        let result = tokio_rt().block_on(async {
            let progress = client
                .tx()
                .sign_and_submit_then_watch_default(&tx, &signer)
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
        error: CString::new("Panic in add_proxy".to_string()).unwrap().into_raw(),
    })
}

/// Remove a proxy
#[no_mangle]
pub extern "C" fn remove_proxy(
    rpc_url: *const c_char,
    mnemonic: *const c_char,
    delegate: *const c_char,
    proxy_type: *const c_char,
    delay: u32,
) -> TransferResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        let mnem_str = unsafe { CStr::from_ptr(mnemonic).to_string_lossy().into_owned() };
        let delegate_str = unsafe { CStr::from_ptr(delegate).to_string_lossy().into_owned() };
        let proxy_type_str = unsafe { CStr::from_ptr(proxy_type).to_string_lossy().into_owned() };
        
        let mnemonic = match Mnemonic::parse_normalized(&mnem_str) {
            Ok(m) => m,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Mnemonic error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let signer = match Keypair::from_phrase(&mnemonic, None) {
            Ok(kp) => kp,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Keypair error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let delegate_account = match subxt::utils::AccountId32::from_str(&delegate_str) {
            Ok(d) => d,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Address error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let client = match tokio_rt().block_on(async {
            OnlineClient::<PolkadotConfig>::from_url(&url).await
        }) {
            Ok(client) => client,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Connection error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let proxy_type_value = Value::variant(proxy_type_str.as_str(), Composite::unnamed(vec![]));
        
        let tx = tx::dynamic(
            "Proxy",
            "remove_proxy",
            vec![
                Value::variant("Id", Composite::unnamed(vec![Value::from_bytes(delegate_account.0.to_vec())])),
                proxy_type_value,
                Value::u128(delay as u128),
            ],
        );
        
        let result = tokio_rt().block_on(async {
            let progress = client
                .tx()
                .sign_and_submit_then_watch_default(&tx, &signer)
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
        error: CString::new("Panic in remove_proxy".to_string()).unwrap().into_raw(),
    })
}

/// Execute a call through a proxy
#[no_mangle]
pub extern "C" fn proxy_call(
    rpc_url: *const c_char,
    proxy_mnemonic: *const c_char,  // The proxy account's mnemonic
    real_account: *const c_char,    // The real account we're acting on behalf of
    pallet_name: *const c_char,
    call_name: *const c_char,
    call_args_json: *const c_char,  // JSON encoded call arguments
) -> TransferResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        let mnem_str = unsafe { CStr::from_ptr(proxy_mnemonic).to_string_lossy().into_owned() };
        let real_str = unsafe { CStr::from_ptr(real_account).to_string_lossy().into_owned() };
        let pallet = unsafe { CStr::from_ptr(pallet_name).to_string_lossy().into_owned() };
        let call = unsafe { CStr::from_ptr(call_name).to_string_lossy().into_owned() };
        let args_json = unsafe { CStr::from_ptr(call_args_json).to_string_lossy().into_owned() };
        
        let mnemonic = match Mnemonic::parse_normalized(&mnem_str) {
            Ok(m) => m,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Mnemonic error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let signer = match Keypair::from_phrase(&mnemonic, None) {
            Ok(kp) => kp,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Keypair error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let real_account_id = match subxt::utils::AccountId32::from_str(&real_str) {
            Ok(d) => d,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Address error: {}", e)).unwrap().into_raw(),
            },
        };
        
        // Parse call arguments (simplified - in production you'd want better arg parsing)
        let _call_args: serde_json::Value = match serde_json::from_str(&args_json) {
            Ok(args) => args,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Args parse error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let client = match tokio_rt().block_on(async {
            OnlineClient::<PolkadotConfig>::from_url(&url).await
        }) {
            Ok(client) => client,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Connection error: {}", e)).unwrap().into_raw(),
            },
        };
        
        // For simplicity, this example implements a balance transfer through proxy
        // In production, you'd want to support arbitrary calls
        if pallet == "Balances" && call == "transfer_keep_alive" {
            // Parse destination and amount from args_json
            let args: serde_json::Value = serde_json::from_str(&args_json).unwrap();
            let dest_str = args["dest"].as_str().unwrap_or("");
            let amount = args["amount"].as_u64().unwrap_or(0) as u128;
            
            let dest = match subxt::utils::AccountId32::from_str(dest_str) {
                Ok(d) => d,
                Err(e) => return TransferResult {
                    success: false,
                    tx_hash: std::ptr::null_mut(),
                    error: CString::new(format!("Dest address error: {}", e)).unwrap().into_raw(),
                },
            };
            
            // Create the inner transfer call
            let inner_call = tx::dynamic(
                "Balances",
                "transfer_keep_alive",
                vec![
                    Value::variant("Id", Composite::unnamed(vec![Value::from_bytes(dest.0.to_vec())])),
                    Value::u128(amount),
                ],
            );
            
            // Encode the inner call
            let encoded_call = client.tx().call_data(&inner_call).unwrap();
            
            // Create the proxy call
            let proxy_tx = tx::dynamic(
                "Proxy",
                "proxy",
                vec![
                    Value::variant("Id", Composite::unnamed(vec![Value::from_bytes(real_account_id.0.to_vec())])),
                    Value::variant("None", Composite::unnamed(vec![])),  // force_proxy_type = None
                    Value::unnamed_composite(vec![Value::from_bytes(encoded_call)]),
                ],
            );
            
            let result = tokio_rt().block_on(async {
                let progress = client
                    .tx()
                    .sign_and_submit_then_watch_default(&proxy_tx, &signer)
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
        } else {
            TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new("Unsupported pallet/call for proxy - currently only supports Balances::transfer_keep_alive".to_string()).unwrap().into_raw(),
            }
        }
    });
    
    result.unwrap_or_else(|_| TransferResult {
        success: false,
        tx_hash: std::ptr::null_mut(),
        error: CString::new("Panic in proxy_call".to_string()).unwrap().into_raw(),
    })
}

/// Query proxies for an account
#[no_mangle]
pub extern "C" fn query_proxies(
    rpc_url: *const c_char,
    account: *const c_char,
) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        let account_str = unsafe { CStr::from_ptr(account).to_string_lossy().into_owned() };
        
        let account_id = match subxt::utils::AccountId32::from_str(&account_str) {
            Ok(id) => id,
            Err(e) => return create_result(false, None, Some(format!("Address error: {}", e))),
        };
        
        let client = match tokio_rt().block_on(async {
            OnlineClient::<PolkadotConfig>::from_url(&url).await
        }) {
            Ok(client) => client,
            Err(e) => return create_result(false, None, Some(format!("Connection error: {}", e))),
        };
        
        let result: Result<Option<String>, subxt::Error> = tokio_rt().block_on(async {
            let storage_address = subxt::dynamic::storage(
                "Proxy",
                "Proxies",
                vec![Value::from_bytes(account_id.0.to_vec())],
            );
            
            let proxies_data = client.storage().at_latest().await?.fetch(&storage_address).await?;
            
            if let Some(data) = proxies_data {
                let value = data.to_value()?;
                Ok(Some(format!("{:?}", value)))
            } else {
                Ok(Some("[]".to_string()))
            }
        });
        
        match result {
            Ok(Some(json)) => create_result(true, Some(json), None),
            Ok(None) => create_result(true, Some("[]".to_string()), None),
            Err(e) => create_result(false, None, Some(format!("Query error: {}", e))),
        }
    });
    
    result.unwrap_or_else(|_| create_result(false, None, Some("Panic in query_proxies".to_string())))
}

/// Set identity information
#[no_mangle]
pub extern "C" fn set_identity(
    rpc_url: *const c_char,
    mnemonic: *const c_char,
    display_name: *const c_char,
    legal_name: *const c_char,
    web: *const c_char,
    email: *const c_char,
    twitter: *const c_char,
) -> TransferResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        let mnem_str = unsafe { CStr::from_ptr(mnemonic).to_string_lossy().into_owned() };
        let display = unsafe { CStr::from_ptr(display_name).to_string_lossy().into_owned() };
        let legal = unsafe { CStr::from_ptr(legal_name).to_string_lossy().into_owned() };
        let web_str = unsafe { CStr::from_ptr(web).to_string_lossy().into_owned() };
        let email_str = unsafe { CStr::from_ptr(email).to_string_lossy().into_owned() };
        let twitter_str = unsafe { CStr::from_ptr(twitter).to_string_lossy().into_owned() };
        
        let mnemonic = match Mnemonic::parse_normalized(&mnem_str) {
            Ok(m) => m,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Mnemonic error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let signer = match Keypair::from_phrase(&mnemonic, None) {
            Ok(kp) => kp,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Keypair error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let client = match tokio_rt().block_on(async {
            OnlineClient::<PolkadotConfig>::from_url(&url).await
        }) {
            Ok(client) => client,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Connection error: {}", e)).unwrap().into_raw(),
            },
        };
        
        // Helper to create Data::Raw value
        let create_data_field = |s: &str| {
            if s.is_empty() {
                Value::variant("None", Composite::unnamed(vec![]))
            } else {
                Value::variant(
                    "Raw",
                    Composite::unnamed(vec![Value::from_bytes(s.as_bytes().to_vec())])
                )
            }
        };
        
        // Create identity info struct
        let identity_info = Value::unnamed_composite(vec![
            Value::unnamed_composite(vec![]),  // additional (empty)
            create_data_field(&display),
            create_data_field(&legal),
            create_data_field(&web_str),
            Value::variant("None", Composite::unnamed(vec![])),  // riot (deprecated)
            create_data_field(&email_str),
            Value::variant("None", Composite::unnamed(vec![])),  // pgp_fingerprint
            Value::variant("None", Composite::unnamed(vec![])),  // image
            create_data_field(&twitter_str),
        ]);
        
        let tx = tx::dynamic(
            "Identity",
            "set_identity",
            vec![identity_info],
        );
        
        let result = tokio_rt().block_on(async {
            let progress = client
                .tx()
                .sign_and_submit_then_watch_default(&tx, &signer)
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
        error: CString::new("Panic in set_identity".to_string()).unwrap().into_raw(),
    })
}

/// Clear identity
#[no_mangle]
pub extern "C" fn clear_identity(
    rpc_url: *const c_char,
    mnemonic: *const c_char,
) -> TransferResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        let mnem_str = unsafe { CStr::from_ptr(mnemonic).to_string_lossy().into_owned() };
        
        let mnemonic = match Mnemonic::parse_normalized(&mnem_str) {
            Ok(m) => m,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Mnemonic error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let signer = match Keypair::from_phrase(&mnemonic, None) {
            Ok(kp) => kp,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Keypair error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let client = match tokio_rt().block_on(async {
            OnlineClient::<PolkadotConfig>::from_url(&url).await
        }) {
            Ok(client) => client,
            Err(e) => return TransferResult {
                success: false,
                tx_hash: std::ptr::null_mut(),
                error: CString::new(format!("Connection error: {}", e)).unwrap().into_raw(),
            },
        };
        
        let tx = tx::dynamic("Identity", "clear_identity", Vec::<Value>::new());
        
        let result = tokio_rt().block_on(async {
            let progress = client
                .tx()
                .sign_and_submit_then_watch_default(&tx, &signer)
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
        error: CString::new("Panic in clear_identity".to_string()).unwrap().into_raw(),
    })
}

/// Query identity information
#[no_mangle]
pub extern "C" fn query_identity(
    rpc_url: *const c_char,
    account: *const c_char,
) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        let account_str = unsafe { CStr::from_ptr(account).to_string_lossy().into_owned() };
        
        let account_id = match subxt::utils::AccountId32::from_str(&account_str) {
            Ok(id) => id,
            Err(e) => return create_result(false, None, Some(format!("Address error: {}", e))),
        };
        
        let client = match tokio_rt().block_on(async {
            OnlineClient::<PolkadotConfig>::from_url(&url).await
        }) {
            Ok(client) => client,
            Err(e) => return create_result(false, None, Some(format!("Connection error: {}", e))),
        };
        
        let result: Result<Option<String>, subxt::Error> = tokio_rt().block_on(async {
            let storage_address = subxt::dynamic::storage(
                "Identity",
                "IdentityOf",
                vec![Value::from_bytes(account_id.0.to_vec())],
            );
            
            let identity_data = client.storage().at_latest().await?.fetch(&storage_address).await?;
            
            if let Some(data) = identity_data {
                let value = data.to_value()?;
                Ok(Some(format!("{:?}", value)))
            } else {
                Ok(None)
            }
        });
        
        match result {
            Ok(Some(json)) => create_result(true, Some(json), None),
            Ok(None) => create_result(true, Some("null".to_string()), None),
            Err(e) => create_result(false, None, Some(format!("Query error: {}", e))),
        }
    });
    
    result.unwrap_or_else(|_| create_result(false, None, Some("Panic in query_identity".to_string())))
}

// === Tests ===

/// Fetch and parse runtime metadata from a chain
#[no_mangle]
pub extern "C" fn fetch_chain_metadata(rpc_url: *const c_char) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        
        tokio_rt().block_on(async {
            let api = OnlineClient::<PolkadotConfig>::from_url(&url).await
                .map_err(|e| format!("Failed to connect: {}", e))?;
            
            let metadata = api.metadata();
            
            // Get runtime version
            let runtime_version = api.runtime_version();
            
            // Create metadata info JSON
            let metadata_info = serde_json::json!({
                "spec_version": runtime_version.spec_version,
                "transaction_version": runtime_version.transaction_version,
                "pallet_count": metadata.pallets().count(),
            });
            
            Ok::<String, String>(metadata_info.to_string())
        })
    });
    
    match result {
        Ok(Ok(json)) => create_result(true, Some(json), None),
        Ok(Err(e)) => create_result(false, None, Some(e)),
        Err(_) => create_result(false, None, Some("Panic in fetch_chain_metadata".to_string())),
    }
}

/// Get all pallets from chain metadata
#[no_mangle]
pub extern "C" fn get_metadata_pallets(rpc_url: *const c_char) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        
        tokio_rt().block_on(async {
            let api = OnlineClient::<PolkadotConfig>::from_url(&url).await
                .map_err(|e| format!("Failed to connect: {}", e))?;
            
            let metadata = api.metadata();
            
            // Collect all pallet names
            let pallets: Vec<String> = metadata.pallets()
                .map(|p| p.name().to_string())
                .collect();
            
            let pallets_json = serde_json::json!({
                "pallets": pallets,
                "count": pallets.len()
            });
            
            Ok::<String, String>(pallets_json.to_string())
        })
    });
    
    match result {
        Ok(Ok(json)) => create_result(true, Some(json), None),
        Ok(Err(e)) => create_result(false, None, Some(e)),
        Err(_) => create_result(false, None, Some("Panic in get_metadata_pallets".to_string())),
    }
}

/// Get call index for a specific pallet and call name
#[no_mangle]
pub extern "C" fn get_call_index(
    rpc_url: *const c_char,
    pallet_name: *const c_char,
    call_name: *const c_char,
) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        let pallet = unsafe { CStr::from_ptr(pallet_name).to_string_lossy().into_owned() };
        let call = unsafe { CStr::from_ptr(call_name).to_string_lossy().into_owned() };
        
        tokio_rt().block_on(async {
            let api = OnlineClient::<PolkadotConfig>::from_url(&url).await
                .map_err(|e| format!("Failed to connect: {}", e))?;
            
            let metadata = api.metadata();
            
            // Find the pallet
            let pallet_metadata = metadata.pallet_by_name(&pallet)
                .ok_or_else(|| format!("Pallet '{}' not found", pallet))?;
            
            let pallet_index = pallet_metadata.index();
            
            // Find the call variant
            let call_metadata = pallet_metadata.call_variant_by_name(&call)
                .ok_or_else(|| format!("Call '{}' not found in pallet '{}'", call, pallet))?;
            
            let call_index = call_metadata.index;
            
            // Return as JSON
            let index_json = serde_json::json!({
                "pallet_index": pallet_index,
                "call_index": call_index,
                "pallet_name": pallet,
                "call_name": call
            });
            
            Ok::<String, String>(index_json.to_string())
        })
    });
    
    match result {
        Ok(Ok(json)) => create_result(true, Some(json), None),
        Ok(Err(e)) => create_result(false, None, Some(e)),
        Err(_) => create_result(false, None, Some("Panic in get_call_index".to_string())),
    }
}

/// Get all calls for a specific pallet
#[no_mangle]
pub extern "C" fn get_pallet_calls(
    rpc_url: *const c_char,
    pallet_name: *const c_char,
) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        let pallet = unsafe { CStr::from_ptr(pallet_name).to_string_lossy().into_owned() };
        
        tokio_rt().block_on(async {
            let api = OnlineClient::<PolkadotConfig>::from_url(&url).await
                .map_err(|e| format!("Failed to connect: {}", e))?;
            
            let metadata = api.metadata();
            
            // Find the pallet
            let pallet_metadata = metadata.pallet_by_name(&pallet)
                .ok_or_else(|| format!("Pallet '{}' not found", pallet))?;
            
            // Get all call variants
            let calls: Vec<serde_json::Value> = if let Some(call_variants) = pallet_metadata.call_variants() {
                call_variants.iter().map(|variant| {
                    serde_json::json!({
                        "name": variant.name,
                        "index": variant.index,
                        "docs": variant.docs.join(" ")
                    })
                }).collect()
            } else {
                vec![]
            };
            
            let calls_json = serde_json::json!({
                "pallet": pallet,
                "calls": calls,
                "count": calls.len()
            });
            
            Ok::<String, String>(calls_json.to_string())
        })
    });
    
    match result {
        Ok(Ok(json)) => create_result(true, Some(json), None),
        Ok(Err(e)) => create_result(false, None, Some(e)),
        Err(_) => create_result(false, None, Some("Panic in get_pallet_calls".to_string())),
    }
}

/// Check runtime compatibility between two versions
#[no_mangle]
pub extern "C" fn check_runtime_compatibility(
    rpc_url: *const c_char,
    expected_spec_version: u32,
) -> ExtrinsicResult {
    let result = catch_unwind(|| {
        let url = unsafe { CStr::from_ptr(rpc_url).to_string_lossy().into_owned() };
        
        tokio_rt().block_on(async {
            let api = OnlineClient::<PolkadotConfig>::from_url(&url).await
                .map_err(|e| format!("Failed to connect: {}", e))?;
            
            let runtime_version = api.runtime_version();
            let current_version = runtime_version.spec_version;
            
            let compatible = current_version == expected_spec_version;
            
            let compat_json = serde_json::json!({
                "compatible": compatible,
                "current_version": current_version,
                "expected_version": expected_spec_version,
                "message": if compatible {
                    "Runtime versions match"
                } else {
                    "Runtime version mismatch - metadata may need updating"
                }
            });
            
            Ok::<String, String>(compat_json.to_string())
        })
    });
    
    match result {
        Ok(Ok(json)) => create_result(true, Some(json), None),
        Ok(Err(e)) => create_result(false, None, Some(e)),
        Err(_) => create_result(false, None, Some("Panic in check_runtime_compatibility".to_string())),
    }
}

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
