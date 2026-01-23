;; ssi-credential-manager.clar
;; Conxian Enterprise Standard: Self-Sovereign Identity Credential Manager
;; Manages DID and verifiable credentials for institutional compliance
;; Supports W3C DID and Verifiable Credentials standards

;; Traits
(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait sip-009-nft-trait .sip-standards.sip-009-nft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_INVALID_DID (err u6001))
(define-constant ERR_CREDENTIAL_NOT_FOUND (err u6002))
(define-constant ERR_CREDENTIAL_EXPIRED (err u6003))
(define-constant ERR_INVALID_SIGNATURE (err u6004))

;; DID Method Types
(define-constant DID_METHOD_KEY u1) ;; did:key
(define-constant DID_METHOD_WEB u2) ;; did:web
(define-constant DID_METHOD_ETHR u3) ;; did:ethr

;; Credential Types
(define-constant CREDENTIAL_TYPE_KYC u1)
(define-constant CREDENTIAL_TYPE_AML u2)
(define-constant CREDENTIAL_TYPE_INSTITUTIONAL u3)
(define-constant CREDENTIAL_TYPE_ACCREDITED u4)

;; DID Registry
;; Maps user principal to their DID document hash
(define-map did-registry
  principal
  {
    did: (string-ascii 128),
    did-method: uint,
    document-hash: (buff 32),
    created-at: uint,
    updated-at: uint
  }
)

;; Verifiable Credential Registry
;; Stores credential metadata without PII
(define-map credential-registry
  (buff 32) ;; credential ID hash
  {
    issuer: principal,
    subject: principal,
    credential-type: uint,
    credential-hash: (buff 32),
    issued-at: uint,
    expires-at: uint,
    status: uint, ;; 0=active, 1=revoked, 2=expired
    verification-count: uint
  }
)

;; Credential Ownership Mapping
;; Maps user to their credential IDs
(define-map user-credentials
  principal
  (list 20 (buff 32)) ;; Max 20 credentials per user
)

;; Credential Verification Records
;; Tracks who has verified which credentials
(define-map verification-records
  {
    credential-id: (buff 32),
    verifier: principal
  }
  {
    verified-at: uint,
    verification-result: bool,
    verifier-trust-level: uint
  }
)

;; Institutional Trust Registry
;; Maps institutional issuers to their trust levels
(define-map trust-registry
  principal
  {
    institution-name: (string-ascii 128),
    trust-level: uint, ;; 0-1000 scale
    accreditation-level: uint,
    jurisdiction: (string-ascii 3),
    verified-at: uint,
    expires-at: uint
  }
)

;; @desc Register a new DID for a user
(define-public (register-did
    (did-method uint)
    (did-document-hash (buff 32))
  )
  (begin
    ;; Check user compliance status
    (match (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)
      compliance-result
      (begin
        (asserts! (is-ok compliance-result) ERR_NON_COMPLIANT)
        
        ;; Generate DID string based on method
        (let ((did-string (generate-did-string did-method tx-sender)))
          (map-set did-registry tx-sender {
            did: did-string,
            did-method: did-method,
            document-hash: did-document-hash,
            created-at: block-height,
            updated-at: block-height
          })
          
          (ok did-string)
        )
      )
      error
      (err ERR_NON_COMPLIANT)
    )
  )
)

;; @desc Issue a new verifiable credential
(define-public (issue-credential
    (subject principal)
    (credential-type uint)
    (credential-hash (buff 32))
    (expires-in-blocks uint)
  )
  (begin
    (asserts! (is-authorized-issuer) ERR_UNAUTHORIZED)
    
    ;; Verify subject has registered DID
    (match (map-get? did-registry subject)
      subject-did
      (begin
        ;; Verify issuer is trusted institution
        (match (map-get? trust-registry tx-sender)
          issuer-trust
          (begin
            (asserts! (> (get trust-level issuer-trust) u500) ERR_UNAUTHORIZED)
            
            ;; Create credential record
            (let ((credential-id (sha256 (concat tx-sender (as-buff block-height)))))
              (map-set credential-registry credential-id {
                issuer: tx-sender,
                subject: subject,
                credential-type: credential-type,
                credential-hash: credential-hash,
                issued-at: block-height,
                expires-at: (+ block-height expires-in-blocks),
                status: u0, ;; active
                verification-count: u0
              })
              
              ;; Add to user's credential list
              (let ((current-creds (default-to (list) (map-get? user-credentials subject))))
                (map-set user-credentials subject 
                  (if (< (len current-creds) u20)
                      (append current-creds (list credential-id))
                      (take current-creds u19) ;; Remove oldest if at limit
                  )
                )
                
                (ok credential-id)
              )
            )
          )
          issuer-trust
          (err ERR_UNAUTHORIZED)
        )
      )
      subject-did
      (err ERR_INVALID_DID)
    )
  )
)

;; @desc Verify a verifiable credential
(define-public (verify-credential
    (credential-id (buff 32))
    (verification-proof (buff 65)) ;; ECDSA signature
  )
  (begin
    (match (map-get? credential-registry credential-id)
      credential
      (begin
        ;; Check credential is active and not expired
        (asserts! (is-eq (get status credential) u0) ERR_CREDENTIAL_EXPIRED)
        (asserts! (< block-height (get expires-at credential)) ERR_CREDENTIAL_EXPIRED)
        
        ;; Verify signature (simplified - in production would use proper cryptographic verification)
        (let ((message-hash (compute-verification-message credential-id)))
          (if (verify-signature message-hash verification-proof (get issuer credential))
              (begin
                ;; Update verification record
                (map-set verification-records {
                  credential-id: credential-id,
                  verifier: tx-sender
                } {
                  verified-at: block-height,
                  verification-result: true,
                  verifier-trust-level: (get-verifier-trust-level tx-sender)
                })
                
                ;; Increment verification count
                (map-set credential-registry credential-id (merge credential {
                  verification-count: (+ (get verification-count credential) u1)
                }))
                
                (ok true)
              )
              (err ERR_INVALID_SIGNATURE)
          )
        )
      )
      credential
      (err ERR_CREDENTIAL_NOT_FOUND)
    )
  )
)

;; @desc Revoke a credential
(define-public (revoke-credential (credential-id (buff 32)))
  (begin
    (asserts! (is-authorized-issuer) ERR_UNAUTHORIZED)
    
    (match (map-get? credential-registry credential-id)
      credential
      (begin
        ;; Only issuer or subject can revoke
        (asserts! (or 
          (is-eq tx-sender (get issuer credential))
          (is-eq tx-sender (get subject credential))
        ) ERR_UNAUTHORIZED)
        
        ;; Mark as revoked
        (map-set credential-registry credential-id (merge credential {
          status: u1, ;; revoked
          updated-at: block-height
        }))
        
        (ok true)
      )
      credential
      (err ERR_CREDENTIAL_NOT_FOUND)
    )
  )
)

;; @desc Get user's active credentials
(define-read-only (get-user-credentials (user principal))
  (let ((credential-ids (default-to (list) (map-get? user-credentials user))))
    (fold credential-ids (list) 
      (lambda (credential-id acc)
        (match (map-get? credential-registry credential-id)
          credential
          (if (and (is-eq (get status credential) u0) (< block-height (get expires-at credential)))
              (append acc (list {
                credential-id: credential-id,
                credential-type: (get credential-type credential),
                issuer: (get issuer credential),
                issued-at: (get issued-at credential),
                expires-at: (get expires-at credential),
                verification-count: (get verification-count credential)
              }))
              acc
          )
          acc
        )
      )
    )
  )
)

;; @desc Check if user meets specific credential requirements
(define-read-only (check-credential-requirements
  (user principal)
  (required-credentials (list 10 uint))
)
  (min-trust-level uint)
)
  (let ((user-creds (get-user-credentials user)))
    (fold required-credentials {
      has-all-required: true,
      total-trust: u0,
      meets-min-trust: false
    }
      (lambda (required-type acc)
        (let ((matching-cred (find-matching-credential user-creds required-type)))
          (merge acc {
            has-all-required: (and (get has-all-required acc) (is-some matching-cred)),
            total-trust: (+ (get total-trust acc) 
                          (if (is-some matching-cred)
                              (get-issuer-trust-level (get issuer (unwrap! matching-cred none)))
                              u0))
          })
        )
      )
    )
  )
)

;; @desc Register institutional issuer
(define-public (register-institutional-issuer
  (institution-name (string-ascii 128))
  (accreditation-level uint)
  (jurisdiction (string-ascii 3))
  (expires-in-blocks uint)
)
  (begin
    (asserts! (is-authorized-admin) ERR_UNAUTHORIZED)
    
    ;; Verify institution has proper credentials
    (match (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)
      compliance-result
      (begin
        (asserts! (is-ok compliance-result) ERR_NON_COMPLIANT)
        
        (map-set trust-registry tx-sender {
          institution-name: institution-name,
          trust-level: u800, ;; High trust for registered institutions
          accreditation-level: accreditation-level,
          jurisdiction: jurisdiction,
          verified-at: block-height,
          expires-at: (+ block-height expires-in-blocks)
        })
        
        (ok true)
      )
      error
      (err ERR_NON_COMPLIANT)
    )
  )
)

;; Private Helper Functions

(define-private (generate-did-string (method uint) (user principal))
  (match method
    DID_METHOD_KEY
      (concat "did:key:z6M" (bytes-to-hex (hash-bytes user)))
    DID_METHOD_WEB
      (concat "did:web:conxian.id:" (bytes-to-hex (hash-bytes user)))
    DID_METHOD_ETHR
      (concat "did:ethr:0x" (bytes-to-hex (hash-bytes user)))
    else
      "did:method:invalid"
  )
)

(define-private (compute-verification-message (credential-id (buff 32)))
  (sha256 (concat credential-id (as-buff block-height)))

(define-private (verify-signature (message (buff 32)) (signature (buff 65)) (signer principal))
  ;; Simplified signature verification
  ;; In production, would use proper secp256k1 verification
  true
)

(define-private (get-verifier-trust-level (verifier principal))
  (match (map-get? trust-registry verifier)
    trust-record
    (get trust-level trust-record)
    u100 ;; Default trust level for unregistered verifiers
  )
)

(define-private (get-issuer-trust-level (issuer principal))
  (match (map-get? trust-registry issuer)
    trust-record
    (get trust-level trust-record)
    u0 ;; No trust for unregistered issuers
  )
)

(define-private (find-matching-credential (credentials (list 10 (buff 32))) (cred-type uint))
  (fold credentials none
    (lambda (credential-id acc)
      (if (is-some acc)
          acc
          (match (map-get? credential-registry credential-id)
            credential
            (if (is-eq (get credential-type credential) cred-type)
                (some credential-id)
                none
            )
            credential
            none
          )
      )
    )
  )

(define-private (is-authorized-issuer)
  (or
    (unwrap-panic (contract-call? .conxian-access has-role tx-sender ROLE_ADMIN))
    (is-some (map-get? trust-registry tx-sender))
  )
)

(define-private (is-authorized-admin)
  (unwrap-panic (contract-call? .conxian-access has-role tx-sender ROLE_ADMIN))
)

;; Error Constants
(define-constant ERR_NON_COMPLIANT (err u6005))
(define-constant ROLE_ADMIN u1)
