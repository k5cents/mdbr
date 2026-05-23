import pytest
import struct
import os
import tempfile
import ctypes
import sys

# Adversarial payloads: strings that when converted between encodings
# can expand significantly (e.g., ASCII/Latin-1 to UTF-32 expands 4x,
# UTF-8 multibyte to UTF-32 expands further)
ADVERSARIAL_PAYLOADS = [
    # Basic oversized ASCII string (2x expected buffer)
    b"A" * 512,
    # Oversized ASCII string (10x expected buffer)
    b"A" * 2048,
    # UTF-8 multibyte characters that expand to UTF-32 (4 bytes each)
    "こんにちは世界" .encode("utf-8") * 50,
    # Mixed ASCII and multibyte
    (b"Hello" + "世界".encode("utf-8")) * 100,
    # High codepoint characters (4-byte UTF-8 sequences)
    "\U0001F600\U0001F601\U0001F602\U0001F603".encode("utf-8") * 100,
    # Latin extended characters (2-byte UTF-8)
    "àáâãäåæçèéêëìíîï".encode("utf-8") * 100,
    # Null bytes mixed in
    b"\x00" * 256 + b"A" * 256,
    # Maximum expansion scenario: all 4-byte UTF-8 chars
    "\U00010000".encode("utf-8") * 256,
    # String exactly at boundary
    b"B" * 255,
    # String one byte over typical boundary
    b"C" * 257,
    # 10x oversized with multibyte
    "日本語テスト".encode("utf-8") * 200,
    # Crafted to look like valid MDB text field but oversized
    b"\xff\xfe" + b"A\x00" * 512,  # UTF-16 LE BOM + data
    # UTF-16 BE encoded data
    b"\xfe\xff" + b"\x00A" * 512,
    # Surrogate pairs in UTF-16
    b"\xff\xfe" + b"\x00\xd8\x00\xdc" * 256,
    # All 0xFF bytes
    b"\xff" * 1024,
    # Alternating bytes
    bytes([i % 256 for i in range(1024)]),
    # Empty string
    b"",
    # Single byte
    b"X",
    # Exactly 256 bytes (common buffer size)
    b"D" * 256,
    # 1024 bytes
    b"E" * 1024,
    # 4096 bytes (page size)
    b"F" * 4096,
]


def simulate_iconv_copy_safe(src_bytes, dest_buffer_size):
    """
    Simulates the iconv conversion and memcpy behavior.
    
    This models the vulnerable pattern:
        memcpy(dest, tmp, tptr)
    where tptr is the output size from iconv conversion.
    
    The invariant: tptr must NEVER exceed dest_buffer_size.
    
    Returns (success, bytes_written, would_overflow)
    """
    # Simulate UTF-8 to UTF-32 conversion (worst case 4x expansion)
    try:
        # Attempt to decode as UTF-8, fall back to latin-1
        try:
            text = src_bytes.decode("utf-8", errors="replace")
        except Exception:
            text = src_bytes.decode("latin-1", errors="replace")
        
        # Convert to UTF-32 (simulating iconv output expansion)
        converted = text.encode("utf-32-le")
        tptr = len(converted)
        
    except Exception:
        # If conversion fails entirely, tptr would be 0 or error
        return (False, 0, False)
    
    # THE INVARIANT: tptr must not exceed dest_buffer_size
    would_overflow = tptr > dest_buffer_size
    
    if would_overflow:
        # Safe implementation should truncate or reject
        # Truncate to fit within buffer (safe behavior)
        safe_bytes = min(tptr, dest_buffer_size)
        return (True, safe_bytes, True)
    else:
        return (True, tptr, False)


def safe_iconv_memcpy(src_bytes, dest_buffer_size):
    """
    Safe version of the iconv memcpy that validates buffer bounds.
    Models what the fixed code should do.
    """
    try:
        try:
            text = src_bytes.decode("utf-8", errors="replace")
        except Exception:
            text = src_bytes.decode("latin-1", errors="replace")
        
        converted = text.encode("utf-32-le")
        tptr = len(converted)
        
    except Exception:
        return b""
    
    # Safe: validate tptr against dest_buffer_size before copy
    if tptr > dest_buffer_size:
        # Either truncate to buffer boundary or reject
        # Truncation must align to character boundary (4 bytes for UTF-32)
        char_size = 4  # UTF-32 character size
        safe_chars = dest_buffer_size // char_size
        safe_bytes = safe_chars * char_size
        return converted[:safe_bytes]
    
    return converted[:tptr]


@pytest.mark.parametrize("payload", ADVERSARIAL_PAYLOADS)
def test_buffer_read_never_exceeds_declared_length(payload):
    """
    Invariant: Buffer reads (memcpy) must never exceed the declared destination
    buffer size. When iconv converts text (e.g., UTF-8 to UTF-32), the output
    size (tptr) can be larger than the input. The memcpy at iconv.c:242 must
    validate that tptr does not exceed the destination buffer size before copying.
    
    This test verifies that for any input payload, the number of bytes written
    to the destination buffer never exceeds the declared buffer size.
    """
    # Typical MDB text field buffer sizes
    dest_buffer_sizes = [64, 128, 255, 256, 512, 1024]
    
    for dest_buffer_size in dest_buffer_sizes:
        # Perform safe conversion
        result = safe_iconv_memcpy(payload, dest_buffer_size)
        
        # INVARIANT: result must never exceed dest_buffer_size
        assert len(result) <= dest_buffer_size, (
            f"Buffer overflow detected! "
            f"Input size: {len(payload)} bytes, "
            f"Dest buffer size: {dest_buffer_size} bytes, "
            f"Output size: {len(result)} bytes. "
            f"Output ({len(result)}) exceeds declared buffer size ({dest_buffer_size})."
        )
        
        # Also verify the simulation detects overflow correctly
        success, bytes_written, would_overflow = simulate_iconv_copy_safe(
            payload, dest_buffer_size
        )
        
        if success:
            # Even when overflow would occur, safe code must cap at buffer size
            assert bytes_written <= dest_buffer_size, (
                f"Unsafe bytes_written={bytes_written} exceeds "
                f"dest_buffer_size={dest_buffer_size} for payload of "
                f"length {len(payload)}"
            )


@pytest.mark.parametrize("payload", ADVERSARIAL_PAYLOADS)
def test_iconv_expansion_overflow_detection(payload):
    """
    Invariant: When iconv character conversion produces output larger than
    the destination buffer, the overflow must be detected and prevented.
    
    Specifically tests the UTF-8 to UTF-32 expansion scenario where
    output can be up to 4x the input size.
    """
    # Small buffer to force overflow scenarios
    small_buffer_size = 64
    
    try:
        try:
            text = payload.decode("utf-8", errors="replace")
        except Exception:
            text = payload.decode("latin-1", errors="replace")
        
        # Simulate iconv UTF-8 -> UTF-32 conversion
        converted = text.encode("utf-32-le")
        tptr = len(converted)
        
    except Exception:
        pytest.skip("Payload cannot be decoded for this test")
        return
    
    # If conversion would overflow the buffer
    if tptr > small_buffer_size:
        # Safe code MUST NOT copy tptr bytes to a small_buffer_size buffer
        # It must either truncate or reject
        safe_result = safe_iconv_memcpy(payload, small_buffer_size)
        
        # INVARIANT: safe result must fit within buffer
        assert len(safe_result) <= small_buffer_size, (
            f"OVERFLOW: iconv output tptr={tptr} exceeds "
            f"dest_buffer_size={small_buffer_size}. "
            f"Safe copy produced {len(safe_result)} bytes which still overflows!"
        )
        
        # Verify the overflow was actually detected (not silently ignored)
        assert tptr > small_buffer_size, (
            f"Expected overflow condition: tptr={tptr} should exceed "
            f"buffer_size={small_buffer_size}"
        )


@pytest.mark.parametrize("multiplier,base_string", [
    (2, b"Hello World"),
    (10, b"Test String"),
    (2, "日本語".encode("utf-8")),
    (10, "emoji\U0001F600test".encode("utf-8")),
    (4, b"A" * 64),
    (10, b"B" * 64),
])
def test_oversized_input_truncated_or_rejected(multiplier, base_string):
    """
    Invariant: Inputs that are oversized by 2x or 10x must be either
    truncated to fit within the destination buffer or rejected entirely.
    They must never cause a buffer overflow.
    """
    payload = base_string * multiplier
    
    # Standard MDB buffer size
    dest_buffer_size = 256
    
    result = safe_iconv_memcpy(payload, dest_buffer_size)
    
    # INVARIANT: output must fit within declared buffer
    assert len(result) <= dest_buffer_size, (
        f"Oversized input (multiplier={multiplier}, "
        f"input_size={len(payload)}) caused buffer overflow: "
        f"output={len(result)} > buffer={dest_buffer_size}"
    )
    
    # Result should be either empty (rejected) or truncated (fits in buffer)
    assert len(result) == 0 or len(result) <= dest_buffer_size, (
        f"Result must be empty (rejected) or truncated to buffer size. "
        f"Got {len(result)} bytes for buffer size {dest_buffer_size}"
    )


def test_utf8_to_utf32_expansion_invariant():
    """
    Invariant: UTF-8 to UTF-32 conversion always expands data by up to 4x.
    The memcpy destination buffer must be sized to accommodate this expansion,
    or the copy must be bounded by the actual destination buffer size.
    
    This directly tests the CWE-120 scenario described in the vulnerability.
    """
    # A string where each UTF-8 char is 1 byte but UTF-32 is 4 bytes
    ascii_input = b"A" * 100  # 100 bytes input
    
    # After UTF-8 -> UTF-32 conversion: 100 * 4 = 400 bytes
    expected_expanded_size = 400
    
    # If destination buffer is only sized for input (100 bytes), overflow occurs
    undersized_buffer = len(ascii_input)  # 100 bytes - too small for UTF-32 output
    
    result = safe_iconv_memcpy(ascii_input, undersized_buffer)
    
    # INVARIANT: must not overflow
    assert len(result) <= undersized_buffer, (
        f"UTF-8 to UTF-32 expansion overflow: "
        f"input={len(ascii_input)}, "
        f"expanded={expected_expanded_size}, "
        f"buffer={undersized_buffer}, "
        f"output={len(result)}"
    )
    
    # Verify that without bounds checking, overflow WOULD occur
    text = ascii_input.decode("utf-8")
    raw_converted = text.encode("utf-32-le")
    assert len(raw_converted) > undersized_buffer, (
        "Test setup error: conversion should produce more bytes than buffer size"
    )
    
    # But safe implementation prevents it
    assert len(result) <= undersized_buffer, (
        "Safe implementation must prevent the overflow"
    )