;; sip-018-signed-messages.clar
;; Conxian Protocol: SIP-018 signed messages implementation for off-chain data verification

;; Dependencies
(use-trait sip-018-signed-messages-trait .sip-standards.sip-018-signed-messages-trait)

;; Constants
(define-constant ERR_INVALID_SIGNATURE (err 32001))
(define-constant ERR_INVALID_MESSAGE (err 32002))
(define-constant ERR_EXPIRED_MESSAGE (err 32003))
(define-constant ERR_INVALID_DOMAIN (err 32004))
(define-constant ERR_INVALID_PUBLIC_KEY (err 32005))

;; SIP-018 parameters
(define-constant MESSAGE_VERSION u1)
(define-constant MAX_MESSAGE_SIZE u1024)
(define-constant SIGNATURE_EXPIRY_BLOCKS u1000) ;; 1000 blocks ~ 1 hour
(define-constant MAX_NONCE u4294967295) ;; 2^32 - 1
(define-constant DOMAIN_SEPARATOR "conxian-protocol")

;; Data variables
(define-data-var signing-active bool true)
(define-data-var total-messages_verified uint u0)
(define-data-var total_signatures_verified uint u0)

;; Storage maps
(define-map signed-messages { message-hash: (buff 32) } { 
  domain: (string-ascii 32),
  payload: (buff 1024),
  public-key: (buff 33),
  signature: (buff 65),
  timestamp: uint,
  nonce: uint,
  verified: bool,
  verification-count: uint
})

(define-map message-domains { domain: (string-ascii 32) } { 
  active: bool,
  created-at: uint,
  total-messages: uint,
  last-verified: uint
})

(define-map verification-records { verifier: principal } { 
  total-verifications: uint,
  successful-verifications: uint,
  failed-verifications: uint,
  last-verification: uint,
  domains-verified: (list 10 (string-ascii 32))
})

(define-map nonce-usage { public-key: (buff 33), nonce: uint } { 
  used: bool,
  timestamp: uint,
  message-hash: (buff 32)
})

;; Events
(define-event (message-verified (message-hash (buff 32)) (domain (string-ascii 32)) (verifier principal)))
(define-event (signature-invalid (message-hash (buff 32)) (reason (string-ascii 256))))
(define-event (domain-registered (domain (string-ascii 32))))
(define-event (domain-deactivated (domain (string-ascii 32))))
(define-event (nonce-reused (public-key (buff 33)) (nonce uint)))
(define-event (message-expired (message-hash (buff 32))))

;; Read-only functions

(define-read-only (get-signed-message (message-hash (buff 32)))
  (map-get? signed-messages { message-hash: message-hash }))

(define-read-only (get-message-domain (message-hash (buff 32)))
  (match (get-signed-message message-hash)
    message (ok (get message domain))
    none (ok "")
  )
)

(define-read-only (get-message-payload (message-hash (buff 32)))
  (match (get-signed-message message-hash)
    message (ok (get message payload))
    none (ok (buff 0))
  )
)

(define-read-only (get-message-public-key (message-hash (buff 32)))
  (match (get-signed-message message-hash)
    message (ok (get message public-key))
    none (ok (buff 0))
  )
)

(define-read-only (is-message-verified (message-hash (buff 32)))
  (match (get-signed-message message-hash)
    message (ok (get message verified))
    none (ok false)
  )
)

(define-read-only (get-domain-info (domain (string-ascii 32)))
  (map-get? message-domains { domain: domain }))

(define-read-only (is-domain-active (domain (string-ascii 32)))
  (match (get-domain-info domain)
    domain-info (ok (get domain-info active))
    none (ok false)
  )
)

(define-read-only (get-verification-record (verifier principal))
  (map-get? verification-records { verifier: verifier }))

(define-read-only (is-nonce-used (public-key (buff 33)) (nonce uint))
  (match (map-get? nonce-usage { public-key: public-key, nonce: nonce })
    usage (ok (get usage used))
    none (ok false)
  )
)

(define-read-only (is-signing-active)
  (var-get signing-active))

(define-read-only (get-total-messages-verified)
  (var-get total-messages_verified))

(define-read-only (get-total-signatures-verified)
  (var-get total-signatures_verified))

;; Public functions

(define-public (register-domain (domain (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len domain) u0) ERR_INVALID_DOMAIN)
    (asserts! (var-get signing-active) ERR_INVALID_DOMAIN)
    
    ;; Register domain
    (map-set message-domains { domain: domain } {
      active: true,
      created-at: block-height,
      total-messages: u0,
      last-verified: u0
    })
    
    ;; Emit event
    (emit-event (domain-registered domain))
    
    (ok true)
  )
)

(define-public (verify-signed-message 
  (domain (string-ascii 32))
  (payload (buff 1024))
  (public-key (buff 33))
  (signature (buff 65))
  (nonce uint)
)
  (begin
    ;; Validate inputs
    (asserts! (> (len domain) u0) ERR_INVALID_DOMAIN)
    (asserts! (> (len payload) u0) ERR_INVALID_MESSAGE)
    (asserts! (is-valid-public-key public-key) ERR_INVALID_PUBLIC_KEY)
    (asserts! (is-valid-signature signature) ERR_INVALID_SIGNATURE)
    (asserts! (var-get signing-active) ERR_INVALID_MESSAGE)
    
    ;; Check if domain is active
    (let ((domain-info (get-domain-info domain)))
      (asserts! (is-some domain-info) ERR_INVALID_DOMAIN)
      
      (let ((domain-active (unwrap-optional domain-info)))
        (asserts! (get domain-active active) ERR_INVALID_DOMAIN)
        
        ;; Check if nonce is already used
        (asserts! (not (unwrap-optional (is-nonce-used public-key nonce))) ERR_INVALID_MESSAGE)
        
        ;; Construct message hash
        (let ((message-hash (construct-message-hash domain payload public-key nonce)))
          
          ;; Check if message already exists
          (let ((existing-message (get-signed-message message-hash)))
            (if (is-some existing-message)
                (begin
                  ;; Update verification count
                  (let ((message (unwrap-optional existing-message)))
                    (map-set signed-messages { message-hash: message-hash } {
                      domain: (get message domain),
                      payload: (get message payload),
                      public-key: (get message public-key),
                      signature: (get message signature),
                      timestamp: (get message timestamp),
                      nonce: (get message nonce),
                      verified: (get message verified),
                      verification-count: (+ (get message verification-count) u1)
                    })
                  )
                  
                  ;; Return existing verification result
                  (ok {
                    message-hash: message-hash,
                    verified: (get message verified),
                    verification-count: (+ (get message verification-count) u1)
                  })
                )
                ;; New message, verify signature
                (begin
                  ;; Verify signature
                  (let ((signature-valid (verify-ecdsa-signature message-hash public-key signature)))
                    (if signature-valid
                        (begin
                          ;; Mark nonce as used
                          (map-set nonce-usage { public-key: public-key, nonce: nonce } {
                            used: true,
                            timestamp: block-height,
                            message-hash: message-hash
                          })
                          
                          ;; Store verified message
                          (map-set signed-messages { message-hash: message-hash } {
                            domain: domain,
                            payload: payload,
                            public-key: public-key,
                            signature: signature,
                            timestamp: block-height,
                            nonce: nonce,
                            verified: true,
                            verification-count: u1
                          })
                          
                          ;; Update domain statistics
                          (map-set message-domains { domain: domain } {
                            active: (get domain-active active),
                            created-at: (get domain-active created-at),
                            total-messages: (+ (get domain-active total-messages) u1),
                            last-verified: block-height
                          })
                          
                          ;; Update verifier record
                          (update-verifier-record tx-sender domain true)
                          
                          ;; Update global counters
                          (var-set total-messages_verified (+ (var-get total-messages_verified) u1))
                          (var-set total-signatures_verified (+ (var-get total-signatures_verified) u1))
                          
                          ;; Emit event
                          (emit-event (message-verified message-hash domain tx-sender))
                          
                          (ok {
                            message-hash: message-hash,
                            verified: true,
                            verification-count: u1
                          })
                        )
                        (begin
                          ;; Store unverified message
                          (map-set signed-messages { message-hash: message-hash } {
                            domain: domain,
                            payload: payload,
                            public-key: public-key,
                            signature: signature,
                            timestamp: block-height,
                            nonce: nonce,
                            verified: false,
                            verification-count: u1
                          })
                          
                          ;; Update verifier record
                          (update-verifier-record tx-sender domain false)
                          
                          ;; Update global counters
                          (var-set total-messages_verified (+ (var-get total-messages_verified) u1))
                          
                          ;; Emit event
                          (emit-event (signature-invalid message-hash "Invalid signature"))
                          
                          (ok {
                            message-hash: message-hash,
                            verified: false,
                            verification-count: u1
                          })
                        )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

(define-public (verify-message-expiry (message-hash (buff 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get signing-active) ERR_INVALID_MESSAGE)
    
    ;; Check if message exists
    (let ((message_info (get-signed-message message-hash)))
      (asserts! (is-some message_info) ERR_INVALID_MESSAGE)
      
      (let ((message (unwrap-optional message_info)))
        ;; Check if message has expired
        (let ((blocks-since-creation (- block-height (get message timestamp))))
          (if (>= blocks-since-creation SIGNATURE_EXPIRY_BLOCKS)
              (begin
                ;; Mark message as expired
                (map-set signed-messages { message-hash: message-hash } {
                  domain: (get message domain),
                  payload: (get message payload),
                  public-key: (get message public-key),
                  signature: (get message signature),
                  timestamp: (get message timestamp),
                  nonce: (get message nonce),
                  verified: false,
                  verification-count: (get message verification-count)
                })
                
                ;; Emit event
                (emit-event (message-expired message-hash))
                
                (ok true)
              )
              (ok false)
          )
        )
      )
    )
  )
)

(define-public (deactivate-domain (domain (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len domain) u0) ERR_INVALID_DOMAIN)
    (asserts! (var-get signing-active) ERR_INVALID_DOMAIN)
    
    ;; Check if domain exists
    (let ((domain_info (get-domain-info domain)))
      (asserts! (is-some domain_info) ERR_INVALID_DOMAIN)
      
      ;; Deactivate domain
      (map-set message-domains { domain: domain } {
        active: false,
        created-at: (get-optional domain_info).created-at,
        total-messages: (get-optional domain_info).total-messages,
        last-verified: (get-optional domain_info).last-verified
      })
      
      ;; Emit event
      (emit-event (domain-deactivated domain))
      
      (ok true)
    )
  )
)

(define-public (set-signing-active (active bool))
  (begin
    ;; Only admin can set signing status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INVALID_MESSAGE)
    
    (var-set signing-active active)
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { active: bool, created-at: uint, total-messages: uint, last-verified: uint } option))

(define-private (get-optional (option))
  (default-to u0 option))

(define-private (construct-message-hash (domain (string-ascii 32)) (payload (buff 1024)) (public-key (buff 33)) (nonce uint))
  (begin
    ;; Construct message according to SIP-018 specification
    ;; Message format: domain || version || nonce || payload || public-key
    
    (let ((domain-bytes (string-ascii domain))
          (version-bytes (int-to-buff MESSAGE_VERSION))
          (nonce-bytes (int-to-buff nonce)))
      
      (hash160 (concat (concat (concat (concat domain-bytes version-bytes) nonce-bytes) payload) public-key))
    )
  )
)

(define-private (is-valid-public-key (public-key (buff 33)))
  (begin
    ;; Check if public key is valid (33 bytes, starts with 0x02 or 0x03)
    (and 
      (is-eq (len public-key) u33)
      (or (is-eq (get public-key u0) u2) (is-eq (get public-key u0) u3))
    )
  )
)

(define-private (is-valid-signature (signature (buff 65)))
  (begin
    ;; Check if signature is valid (65 bytes)
    (is-eq (len signature) u65)
  )
)

(define-private (verify-ecdsa-signature (message-hash (buff 32)) (public-key (buff 33)) (signature (buff 65)))
  (begin
    ;; Simplified ECDSA signature verification
    ;; In practice, would use actual cryptographic verification
    
    ;; For now, return true for demonstration
    true
  )
)

(define-private (update-verifier-record (verifier principal) (domain (string-ascii 32)) (success bool))
  (begin
    ;; Get current verifier record
    (let ((verifier_info (get-verification-record verifier)))
      (if (is-some verifier_info)
          (begin
            (let ((record (unwrap-optional verifier_info))
                  (total-verifications (get record total-verifications)))
              
              ;; Update record
              (map-set verification-records { verifier: verifier } {
                total-verifications: (+ total-verifications u1),
                successful-verifications: (+ (get record successful-verifications) (if success u1 u0)),
                failed-verifications: (+ (get record failed-verifications) (if success u0 u1)),
                last-verification: block-height,
                domains-verified: (add-domain-to-list (get record domains-verified) domain)
              })
            )
          )
          ;; Create new verifier record
          (map-set verification-records { verifier: verifier } {
            total-verifications: u1,
            successful-verifications: (if success u1 u0),
            failed-verifications: (if success u0 u1),
            last-verification: block-height,
            domains-verified: (list domain)
          })
      )
    )
  )
)

(define-private (add-domain-to-list (domains (list 10 (string-ascii 32))) (domain (string-ascii 32)))
  (begin
    ;; Add domain to list if not already present
    (if (has-domain domains domain)
        domains
        (if (>= (len domains) u10)
            (append (slice domains u1 (- (len domains) u1)) domain)
            (append domains domain)
        )
    )
  )
)

(define-private (has-domain (domains (list 10 (string-ascii 32))) (domain (string-ascii 32)))
  (begin
    ;; Check if domain exists in list
    (fold domains false
      (lambda ((found bool) (current-domain (string-ascii 32)))
        (or found (is-eq current-domain domain))
      )
    )
  )
)

;; SIP-018 Trait Implementation

(define-read-only (verify-message (domain (string-ascii 32)) (payload (buff 1024)) (public-key (buff 33)) (signature (buff 65)) (nonce uint))
  (verify-signed-message domain payload public-key signature nonce)
)

(define-read-only (is-message-valid (message-hash (buff 32)))
  (begin
    ;; Check if message is valid (verified and not expired)
    (let ((message_info (get-signed-message message-hash)))
      (if (is-some message_info)
          (begin
            (let ((message (unwrap-optional message_info)))
              (and (get message verified)
                   (< (- block-height (get message timestamp)) SIGNATURE_EXPIRY_BLOCKS))
            )
          )
          false
      )
    )
  )
)

(define-read-only (get-message-domain (message-hash (buff 32)))
  (get-message-domain message-hash)
)

(define-read-only (get-message-payload (message-hash (buff 32)))
  (get-message-payload message-hash)
)

;; Utility functions

(define-read-only (get-signing-status)
  {
    active: (var-get signing-active),
    total-messages-verified: (var-get total-messages_verified),
    total-signatures-verified: (var-get total-signatures_verified),
    active-domains: u0
  }
)

(define-read-only (get-domain-statistics (domain (string-ascii 32)))
  (match (get-domain-info domain)
    domain-info
      (ok {
        active: (get domain-info active),
        total-messages: (get domain-info total-messages),
        created-at: (get domain_info created-at),
        last-verified: (get domain_info last-verified)
      })
    none (err ERR_INVALID_DOMAIN)
  )
)

(define-read-only (get-verifier-statistics (verifier principal))
  (match (get-verification-record verifier)
    record
      (ok {
        total-verifications: (get record total-verifications),
        successful-verifications: (get record successful-verifications),
        failed-verifications: (get record failed-verifications),
        success-rate: (if (> (get record total-verifications) u0)
                        (/ (* (get record successful-verifications) u10000) (get record total-verifications))
                        u0),
        last-verification: (get record last-verification)
      })
    none (ok { total-verifications: u0, successful-verifications: u0, failed-verifications: u0, success-rate: u0, last-verification: u0 })
  )
)
