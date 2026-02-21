;; encoding.clar
;; Standardized encoding utilities for Conxian Protocol
;; Conforms to SDK 3.9+ Standards

;; @desc Wraps a value in the standard consensus buffering format
;; @param value (buff 128) - The raw value to encode
;; @returns (buff 128) - The encoded buffer
(define-read-only (to-consensus-buff-wrapper (value (buff 128)))
  (ok (to-consensus-buff? value))
)

;; @desc Deterministic SHA256 hash of any buffer
;; @param data (buff 2048)
;; @returns (buff 32)
(define-read-only (hash-data (data (buff 2048)))
  (sha256 data)
)

;; @desc Integer serialization to big-endian buffer
;; @param value uint
;; @returns (buff 16)
(define-read-only (uint-to-buff (value uint))
  (unwrap-panic (to-consensus-buff value))
  ;; Placeholder
)
