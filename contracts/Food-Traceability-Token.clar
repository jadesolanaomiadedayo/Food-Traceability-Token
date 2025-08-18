(define-non-fungible-token food-batch uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-batch (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-stage (err u104))
(define-constant err-unauthorized-oracle (err u105))
(define-constant err-invalid-score (err u106))

(define-data-var token-id-nonce uint u1)

(define-map batch-info
  uint
  {
    producer: principal,
    product-name: (string-ascii 50),
    harvest-date: uint,
    origin-location: (string-ascii 100),
    current-stage: uint,
    created-at: uint,
    certified: bool
  }
)

(define-map supply-chain-stages
  { batch-id: uint, stage-id: uint }
  {
    location: (string-ascii 100),
    handler: principal,
    timestamp: uint,
    temperature: (optional int),
    humidity: (optional uint),
    notes: (string-ascii 200),
    verified: bool
  }
)

(define-map authorized-oracles principal bool)

(define-map batch-certifications
  { batch-id: uint, cert-type: (string-ascii 30) }
  {
    issuer: principal,
    valid-until: uint,
    cert-data: (string-ascii 200)
  }
)

(define-map quality-scores
  uint
  {
    base-score: uint,
    temperature-penalty: uint,
    time-penalty: uint,
    certification-bonus: uint,
    final-score: uint,
    grade: (string-ascii 1),
    calculated-at: uint
  }
)

(define-read-only (get-last-token-id)
  (ok (- (var-get token-id-nonce) u1))
)

(define-read-only (get-token-uri (token-id uint))
  (ok none)
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? food-batch token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (nft-transfer? food-batch token-id sender recipient)
  )
)

(define-public (add-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set authorized-oracles oracle true))
  )
)

(define-public (remove-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-delete authorized-oracles oracle))
  )
)

(define-public (create-batch 
    (product-name (string-ascii 50))
    (origin-location (string-ascii 100))
    (harvest-date uint))
  (let
    (
      (token-id (var-get token-id-nonce))
    )
    (try! (nft-mint? food-batch token-id tx-sender))
    (map-set batch-info token-id
      {
        producer: tx-sender,
        product-name: product-name,
        harvest-date: harvest-date,
        origin-location: origin-location,
        current-stage: u1,
        created-at: stacks-block-height,
        certified: false
      }
    )
    (map-set supply-chain-stages { batch-id: token-id, stage-id: u1 }
      {
        location: origin-location,
        handler: tx-sender,
        timestamp: stacks-block-height,
        temperature: none,
        humidity: none,
        notes: "Initial harvest/production",
        verified: true
      }
    )
    (var-set token-id-nonce (+ token-id u1))
    (ok token-id)
  )
)

(define-public (update-batch-stage
    (batch-id uint)
    (location (string-ascii 100))
    (temperature (optional int))
    (humidity (optional uint))
    (notes (string-ascii 200)))
  (let
    (
      (batch-data (unwrap! (map-get? batch-info batch-id) err-invalid-batch))
      (current-stage (get current-stage batch-data))
      (new-stage (+ current-stage u1))
      (is-oracle (default-to false (map-get? authorized-oracles tx-sender)))
      (is-owner (is-eq tx-sender (unwrap! (nft-get-owner? food-batch batch-id) err-invalid-batch)))
    )
    (asserts! (or is-oracle is-owner) err-unauthorized-oracle)
    (map-set supply-chain-stages { batch-id: batch-id, stage-id: new-stage }
      {
        location: location,
        handler: tx-sender,
        timestamp: stacks-block-height,
        temperature: temperature,
        humidity: humidity,
        notes: notes,
        verified: is-oracle
      }
    )
    (map-set batch-info batch-id
      (merge batch-data { current-stage: new-stage })
    )
    (ok new-stage)
  )
)

(define-public (add-certification
    (batch-id uint)
    (cert-type (string-ascii 30))
    (valid-until uint)
    (cert-data (string-ascii 200)))
  (let
    (
      (is-oracle (default-to false (map-get? authorized-oracles tx-sender)))
      (batch-data (unwrap! (map-get? batch-info batch-id) err-invalid-batch))
    )
    (asserts! is-oracle err-unauthorized-oracle)
    (map-set batch-certifications { batch-id: batch-id, cert-type: cert-type }
      {
        issuer: tx-sender,
        valid-until: valid-until,
        cert-data: cert-data
      }
    )
    (map-set batch-info batch-id
      (merge batch-data { certified: true })
    )
    (ok true)
  )
)

(define-read-only (get-batch-info (batch-id uint))
  (map-get? batch-info batch-id)
)

(define-read-only (get-stage-info (batch-id uint) (stage-id uint))
  (map-get? supply-chain-stages { batch-id: batch-id, stage-id: stage-id })
)

(define-read-only (get-certification (batch-id uint) (cert-type (string-ascii 30)))
  (map-get? batch-certifications { batch-id: batch-id, cert-type: cert-type })
)

(define-read-only (is-oracle (address principal))
  (default-to false (map-get? authorized-oracles address))
)

(define-read-only (verify-batch-freshness (batch-id uint) (max-age uint))
  (match (map-get? batch-info batch-id)
    batch-data
      (let
        (
          (harvest-date (get harvest-date batch-data))
          (current-block stacks-block-height)
          (age (- current-block harvest-date))
        )
        (ok (< age max-age))
      )
    (err err-invalid-batch)
  )
)

(define-read-only (get-batch-journey (batch-id uint))
  (match (map-get? batch-info batch-id)
    batch-data
      (ok {
        batch-info: (some batch-data),
        total-stages: (get current-stage batch-data)
      })
    (ok {
      batch-info: none,
      total-stages: u0
    })
  )
)

(define-read-only (verify-supply-chain (batch-id uint))
  (match (map-get? batch-info batch-id)
    batch-data
      (let
        (
          (current-stage (get current-stage batch-data))
          (verification-results (fold check-stage-verification 
            (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) 
            { batch-id: batch-id, max-stage: current-stage, all-verified: true }))
        )
        (ok (get all-verified verification-results))
      )
    (err err-invalid-batch)
  )
)

(define-private (check-stage-verification (stage-id uint) (acc { batch-id: uint, max-stage: uint, all-verified: bool }))
  (if (<= stage-id (get max-stage acc))
    (match (map-get? supply-chain-stages { batch-id: (get batch-id acc), stage-id: stage-id })
      stage-data
        (merge acc { all-verified: (and (get all-verified acc) (get verified stage-data)) })
      acc
    )
    acc
  )
)

(define-read-only (get-batch-temperature-history (batch-id uint))
  (match (map-get? batch-info batch-id)
    batch-data
      (ok (get current-stage batch-data))
    (err err-invalid-batch)
  )
)

(define-public (calculate-quality-score (batch-id uint))
  (let
    (
      (batch-data (unwrap! (map-get? batch-info batch-id) err-invalid-batch))
      (current-stage (get current-stage batch-data))
      (base-score u100)
      (temp-penalty (calculate-temperature-penalty batch-id current-stage))
      (time-penalty (calculate-time-penalty batch-id))
      (cert-bonus (if (get certified batch-data) u10 u0))
      (total-penalty (+ temp-penalty time-penalty))
      (raw-score (if (>= base-score total-penalty) (- base-score total-penalty) u0))
      (final-score (+ raw-score cert-bonus))
      (grade (get-quality-grade final-score))
    )
    (map-set quality-scores batch-id
      {
        base-score: base-score,
        temperature-penalty: temp-penalty,
        time-penalty: time-penalty,
        certification-bonus: cert-bonus,
        final-score: final-score,
        grade: grade,
        calculated-at: stacks-block-height
      }
    )
    (ok final-score)
  )
)

(define-private (calculate-temperature-penalty (batch-id uint) (max-stage uint))
  (get penalty (fold check-temperature-violations 
    (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) 
    { batch-id: batch-id, max-stage: max-stage, penalty: u0 }
  ))
)

(define-private (check-temperature-violations (stage-id uint) (acc { batch-id: uint, max-stage: uint, penalty: uint }))
  (if (<= stage-id (get max-stage acc))
    (match (map-get? supply-chain-stages { batch-id: (get batch-id acc), stage-id: stage-id })
      stage-data
        (match (get temperature stage-data)
          temp-value
            (if (or (< temp-value -5) (> temp-value 25))
              (merge acc { penalty: (+ (get penalty acc) u5) })
              acc
            )
          acc
        )
      acc
    )
    acc
  )
)

(define-private (calculate-time-penalty (batch-id uint))
  (match (map-get? batch-info batch-id)
    batch-data
      (let
        (
          (harvest-date (get harvest-date batch-data))
          (current-block stacks-block-height)
          (age (- current-block harvest-date))
        )
        (if (> age u2016) 
          (if (> age u4032) u20 u10)
          u0
        )
      )
    u0
  )
)

(define-private (get-quality-grade (score uint))
  (if (>= score u90) "A"
    (if (>= score u80) "B"
      (if (>= score u70) "C"
        (if (>= score u60) "D"
          "F"
        )
      )
    )
  )
)

(define-read-only (get-quality-score (batch-id uint))
  (map-get? quality-scores batch-id)
)

(define-read-only (get-batch-quality-summary (batch-id uint))
  (match (map-get? quality-scores batch-id)
    score-data
      (ok {
        score: (get final-score score-data),
        grade: (get grade score-data),
        calculated-at: (get calculated-at score-data)
      })
    (err err-invalid-batch)
  )
)
