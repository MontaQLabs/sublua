use parity_scale_codec::Encode as _;
use parity_scale_codec::{Compact as ScaleCompact, Decode, Encode};
use sp_core::blake2_256;
use std::panic::catch_unwind; // bring encode method into scope

#[derive(Encode, Decode)]
pub struct ExtrinsicV4 {
    pub signature: Option<ExtrinsicSignature>,
    pub function: Call,
}

#[derive(Encode, Decode)]
pub struct ExtrinsicSignature {
    pub signer: MultiAddress,
    pub signature: MultiSignature,
    pub era: Era,
    pub nonce: ScaleCompact<u32>,
    pub tip: ScaleCompact<u128>,
}

#[derive(Encode, Decode)]
pub enum MultiAddress {
    Id([u8; 32]),
    Index(ScaleCompact<u32>),
    Raw(Vec<u8>),
    Address32([u8; 32]),
    Address20([u8; 20]),
}

#[derive(Encode, Decode)]
pub enum MultiSignature {
    Ed25519([u8; 64]),
    Sr25519([u8; 64]),
    Ecdsa([u8; 65]),
}

#[derive(Encode, Decode)]
pub struct Call {
    pub module_index: u8,
    pub function_index: u8,
    pub arguments: Vec<u8>,
}

#[derive(Encode, Decode)]
pub enum Era {
    Immortal,
    Mortal(u8, u8),
}

#[no_mangle]
pub extern "C" fn encode_unsigned_extrinsic(
    module_index: u8,
    function_index: u8,
    arguments_ptr: *const u8,
    arguments_len: usize,
    out_ptr: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    let result = catch_unwind(|| {
        if arguments_ptr.is_null() || out_ptr.is_null() || out_len.is_null() {
            return Err("Null pointer provided");
        }

        // SAFETY: pointers were checked for null above
        let arguments = unsafe { std::slice::from_raw_parts(arguments_ptr, arguments_len) };

        // ------------- build call bytes -------------
        let mut call_bytes = Vec::with_capacity(2 + arguments.len());
        call_bytes.push(module_index);
        call_bytes.push(function_index);
        call_bytes.extend_from_slice(arguments);

        // ------------- build extrinsic bytes -------------
        let mut extrinsic_bytes = Vec::with_capacity(1 + call_bytes.len());
        extrinsic_bytes.push(0x04); // version: 4 (unsigned)
        extrinsic_bytes.extend_from_slice(&call_bytes);

        // ------------- prefix with length -------------
        let mut output = ScaleCompact(extrinsic_bytes.len() as u32).encode();
        output.extend_from_slice(&extrinsic_bytes);

        // copy to C
        let boxed = output.into_boxed_slice();
        let len = boxed.len();
        let ptr = Box::into_raw(boxed) as *mut u8;

        unsafe {
            *out_ptr = ptr;
            *out_len = len;
        }
        Ok(())
    });

    match result {
        Ok(Ok(())) => 0,
        _ => 1,
    }
}

#[no_mangle]
pub extern "C" fn encode_signed_extrinsic(
    module_index: u8,
    function_index: u8,
    arguments_ptr: *const u8,
    arguments_len: usize,
    signer_ptr: *const u8,
    signature_ptr: *const u8,
    nonce: u32,
    tip_low: u64,
    tip_high: u64,
    era_mortal: bool,
    era_period: u8,
    era_phase: u8,
    out_ptr: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    let result = catch_unwind(|| {
        if arguments_ptr.is_null()
            || signer_ptr.is_null()
            || signature_ptr.is_null()
            || out_ptr.is_null()
            || out_len.is_null()
        {
            return Err("Null pointer provided");
        }

        // SAFETY: pointers were checked for null above
        let arguments = unsafe { std::slice::from_raw_parts(arguments_ptr, arguments_len) };
        let signer = unsafe { std::slice::from_raw_parts(signer_ptr, 32) };
        let signature = unsafe { std::slice::from_raw_parts(signature_ptr, 64) };

        // Build Call
        let call = Call {
            module_index,
            function_index,
            arguments: arguments.to_vec(),
        };

        // Build Era
        let era = if era_mortal {
            Era::Mortal(era_period, era_phase)
        } else {
            Era::Immortal
        };

        // Build signature payload
        let tip: u128 = ((tip_high as u128) << 64) | (tip_low as u128);
        let mut signer_array = [0u8; 32];
        signer_array.copy_from_slice(signer);
        let mut signature_array = [0u8; 64];
        signature_array.copy_from_slice(signature);

        let signature_payload = ExtrinsicSignature {
            signer: MultiAddress::Id(signer_array),
            signature: MultiSignature::Sr25519(signature_array),
            era,
            nonce: ScaleCompact(nonce),
            tip: ScaleCompact(tip),
        };

        // FIXED: Build transaction with version byte first, then extrinsic data
        // The structure should be: [version_byte][signature][call]
        let mut final_tx = vec![0x84]; // Version 4 with signed bit (0x80 | 0x04)

        // Manually encode the signature and call parts
        // Signature part: MultiAddress + MultiSignature + Era + Nonce + Tip
        final_tx.extend_from_slice(&signature_payload.encode());

        // Call part: module_index + function_index + arguments
        final_tx.push(module_index);
        final_tx.push(function_index);
        final_tx.extend_from_slice(arguments);

        // Add length prefix
        let mut output = ScaleCompact(final_tx.len() as u32).encode();
        output.extend_from_slice(&final_tx);

        // copy to C
        let boxed = output.into_boxed_slice();
        let len = boxed.len();
        let ptr = Box::into_raw(boxed) as *mut u8;

        unsafe {
            *out_ptr = ptr;
            *out_len = len;
        }
        Ok(())
    });

    match result {
        Ok(Ok(())) => 0,
        _ => 1,
    }
}

#[no_mangle]
pub extern "C" fn free_encoded_extrinsic(ptr: *mut u8, len: usize) {
    if !ptr.is_null() {
        unsafe {
            let _ = Box::from_raw(std::slice::from_raw_parts_mut(ptr, len));
        }
    }
}

// === signing payload builder ===
#[no_mangle]
pub extern "C" fn make_signing_payload(
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
) -> i32 {
    let result = catch_unwind(|| {
        if arguments_ptr.is_null()
            || genesis_hash_ptr.is_null()
            || block_hash_ptr.is_null()
            || out_ptr.is_null()
            || out_len.is_null()
        {
            return Err("Null pointer provided");
        }

        // SAFETY: checked for null
        let arguments = unsafe { std::slice::from_raw_parts(arguments_ptr, arguments_len) };
        let genesis_hash = unsafe { std::slice::from_raw_parts(genesis_hash_ptr, 32) };
        let block_hash = unsafe { std::slice::from_raw_parts(block_hash_ptr, 32) };

        // Copy into fixed arrays
        let mut genesis_arr = [0u8; 32];
        genesis_arr.copy_from_slice(genesis_hash);
        let mut block_arr = [0u8; 32];
        block_arr.copy_from_slice(block_hash);

        // Build Call
        let call = Call {
            module_index,
            function_index,
            arguments: arguments.to_vec(),
        };

        // Build Era
        let era = if era_mortal {
            Era::Mortal(era_period, era_phase)
        } else {
            Era::Immortal
        };

        // Compose payload tuple following SignedPayload format
        let tip: u128 = ((tip_high as u128) << 64) | (tip_low as u128);
        let mut payload = (
            call,
            era,
            ScaleCompact(nonce),
            ScaleCompact(tip),
            spec_version,
            transaction_version,
            genesis_arr,
            block_arr,
        )
            .encode();
        if payload.len() > 256 {
            payload = blake2_256(&payload).to_vec();
        }

        // Return through FFI
        let boxed = payload.into_boxed_slice();
        let len = boxed.len();
        let ptr = Box::into_raw(boxed) as *mut u8;
        unsafe {
            *out_ptr = ptr;
            *out_len = len;
        }
        Ok(())
    });

    match result {
        Ok(Ok(())) => 0,
        _ => 1,
    }
}
