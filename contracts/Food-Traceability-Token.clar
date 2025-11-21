(define-non-fungible-token food-batch uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-batch (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-stage (err u104))
(define-constant err-unauthorized-oracle (err u105))
(define-constant err-invalid-score (err u106))
(define-constant err-batch-already-recalled (err u107))
(define-constant err-invalid-recall-reason (err u108))
(define-constant err-recall-not-found (err u109))
(define-constant err-audit-access-denied (err u110))
(define-constant err-invalid-audit-period (err u111))
(define-constant err-audit-not-found (err u112))
(define-constant err-expired-batch (err u113))
(define-constant err-invalid-expiration (err u114))
(define-constant err-expiration-exists (err u115))

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

(define-map batch-recalls
  uint
  {
    recalled: bool,
    recall-reason: (string-ascii 200),
    severity-level: uint,
    recalled-by: principal,
    recall-date: uint,
    affected-consumers: uint,
    recall-id: (string-ascii 50)
  }
)

(define-map recall-notifications
  { batch-id: uint, notification-id: uint }
  {
    recipient: principal,
    message: (string-ascii 300),
    sent-at: uint,
    acknowledged: bool,
    urgency: uint
  }
)

(define-data-var notification-id-nonce uint u1)
(define-data-var audit-id-nonce uint u1)
(define-data-var expiration-alert-nonce uint u1)

;; Audit trail system for compliance and transparency
(define-map audit-trail
  uint
  {
    operation-type: (string-ascii 50),
    actor: principal,
    target-batch: (optional uint),
    operation-data: (string-ascii 300),
    timestamp: uint,
    block-height: uint,
    gas-cost: uint,
    success: bool,
    error-code: (optional uint)
  }
)

(define-map audit-permissions principal bool)

(define-map batch-expiration
  uint
  {
    shelf-life-days: uint,
    expiration-date: uint,
    product-category: (string-ascii 30),
    storage-conditions: (string-ascii 100),
    set-by: principal,
    set-at: uint
  }
)

(define-map expiration-alerts
  uint
  {
    batch-id: uint,
    alert-type: (string-ascii 20),
    days-until-expiration: int,
    triggered-at: uint,
    notified-parties: (list 5 principal),
    resolved: bool
  }
)

(define-map compliance-reports
  { period-start: uint, period-end: uint }
  {
    total-operations: uint,
    successful-operations: uint,
    failed-operations: uint,
    unique-actors: uint,
    batch-operations: uint,
    oracle-operations: uint,
    recall-operations: uint,
    quality-assessments: uint,
    generated-by: principal,
    generated-at: uint
  }
)

;; Audit trail utility functions
(define-private (log-operation 
    (op-type (string-ascii 50))
    (batch-id (optional uint))
    (op-data (string-ascii 300))
    (success bool)
    (error-code (optional uint)))
  (let
    (
      (audit-id (var-get audit-id-nonce))
    )
    (map-set audit-trail audit-id
      {
        operation-type: op-type,
        actor: tx-sender,
        target-batch: batch-id,
        operation-data: op-data,
        timestamp: stacks-block-height,
        block-height: stacks-block-height,
        gas-cost: u0,
        success: success,
        error-code: error-code
      }
    )
    (var-set audit-id-nonce (+ audit-id u1))
    audit-id
  )
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

;; Audit management functions
(define-public (grant-audit-access (auditor principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (log-operation "GRANT_AUDIT_ACCESS" none 
      "Granted audit access to new auditor" true none)
    (ok (map-set audit-permissions auditor true))
  )
)

(define-public (revoke-audit-access (auditor principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (log-operation "REVOKE_AUDIT_ACCESS" none 
      "Revoked audit access from auditor" true none)
    (ok (map-delete audit-permissions auditor))
  )
)

(define-public (add-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (log-operation "ADD_ORACLE" none 
      "Added new oracle to system" true none)
    (ok (map-set authorized-oracles oracle true))
  )
)

(define-public (remove-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (log-operation "REMOVE_ORACLE" none 
      "Removed oracle from system" true none)
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
    (log-operation "CREATE_BATCH" (some token-id)
      (concat "Created batch: " product-name) true none)
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
    (log-operation "UPDATE_STAGE" (some batch-id)
      (concat "Stage updated to: " location) true none)
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
    (log-operation "ADD_CERTIFICATION" (some batch-id)
      (concat "Added certification: " cert-type) true none)
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
    (log-operation "CALCULATE_QUALITY" (some batch-id)
      (concat "Quality score calculated: " (get grade (unwrap-panic (map-get? quality-scores batch-id)))) true none)
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

(define-public (initiate-batch-recall
    (batch-id uint)
    (recall-reason (string-ascii 200))
    (severity-level uint)
    (affected-consumers uint)
    (recall-id (string-ascii 50)))
  (let
    (
      (batch-data (unwrap! (map-get? batch-info batch-id) err-invalid-batch))
      (is-oracle (default-to false (map-get? authorized-oracles tx-sender)))
      (existing-recall (map-get? batch-recalls batch-id))
    )
    (asserts! (or is-oracle (is-eq tx-sender contract-owner)) err-unauthorized-oracle)
    (asserts! (and (>= severity-level u1) (<= severity-level u5)) err-invalid-recall-reason)
    (asserts! (is-none existing-recall) err-batch-already-recalled)
    (map-set batch-recalls batch-id
      {
        recalled: true,
        recall-reason: recall-reason,
        severity-level: severity-level,
        recalled-by: tx-sender,
        recall-date: stacks-block-height,
        affected-consumers: affected-consumers,
        recall-id: recall-id
      }
    )
    (log-operation "INITIATE_RECALL" (some batch-id)
      (concat "Batch recalled: " recall-reason) true none)
    (ok true)
  )
)

(define-public (send-recall-notification
    (batch-id uint)
    (recipient principal)
    (message (string-ascii 300))
    (urgency uint))
  (let
    (
      (recall-data (unwrap! (map-get? batch-recalls batch-id) err-recall-not-found))
      (is-oracle (default-to false (map-get? authorized-oracles tx-sender)))
      (notification-id (var-get notification-id-nonce))
    )
    (asserts! (or is-oracle (is-eq tx-sender contract-owner)) err-unauthorized-oracle)
    (asserts! (get recalled recall-data) err-recall-not-found)
    (asserts! (and (>= urgency u1) (<= urgency u3)) err-invalid-recall-reason)
    (map-set recall-notifications { batch-id: batch-id, notification-id: notification-id }
      {
        recipient: recipient,
        message: message,
        sent-at: stacks-block-height,
        acknowledged: false,
        urgency: urgency
      }
    )
    (var-set notification-id-nonce (+ notification-id u1))
    (log-operation "SEND_RECALL_NOTIFICATION" (some batch-id)
      "Recall notification sent" true none)
    (ok notification-id)
  )
)

(define-public (acknowledge-recall-notification
    (batch-id uint)
    (notification-id uint))
  (let
    (
      (notification-data (unwrap! (map-get? recall-notifications { batch-id: batch-id, notification-id: notification-id }) err-recall-not-found))
    )
    (asserts! (is-eq tx-sender (get recipient notification-data)) err-not-token-owner)
    (map-set recall-notifications { batch-id: batch-id, notification-id: notification-id }
      (merge notification-data { acknowledged: true })
    )
    (ok true)
  )
)

(define-public (update-recall-status
    (batch-id uint)
    (new-severity uint)
    (additional-info (string-ascii 200)))
  (let
    (
      (recall-data (unwrap! (map-get? batch-recalls batch-id) err-recall-not-found))
      (is-oracle (default-to false (map-get? authorized-oracles tx-sender)))
    )
    (asserts! (or is-oracle (is-eq tx-sender contract-owner)) err-unauthorized-oracle)
    (asserts! (get recalled recall-data) err-recall-not-found)
    (asserts! (and (>= new-severity u1) (<= new-severity u5)) err-invalid-recall-reason)
    (map-set batch-recalls batch-id
      (merge recall-data {
        severity-level: new-severity,
        recall-reason: additional-info
      })
    )
    (ok true)
  )
)

(define-read-only (get-batch-recall-status (batch-id uint))
  (map-get? batch-recalls batch-id)
)

(define-read-only (is-batch-recalled (batch-id uint))
  (match (map-get? batch-recalls batch-id)
    recall-data (ok (get recalled recall-data))
    (ok false)
  )
)

(define-read-only (get-recall-notification (batch-id uint) (notification-id uint))
  (map-get? recall-notifications { batch-id: batch-id, notification-id: notification-id })
)

(define-read-only (check-batch-safety (batch-id uint))
  (let
    (
      (batch-data (unwrap! (map-get? batch-info batch-id) err-invalid-batch))
      (recall-status (map-get? batch-recalls batch-id))
      (quality-data (map-get? quality-scores batch-id))
    )
    (ok {
      exists: true,
      recalled: (match recall-status
        recall-info (get recalled recall-info)
        false
      ),
      certified: (get certified batch-data),
      quality-grade: (match quality-data
        score-info (get grade score-info)
        "N/A"
      ),
      safe-for-consumption: (and
        (not (match recall-status
          recall-info (get recalled recall-info)
          false
        ))
        (get certified batch-data)
        (match quality-data
          score-info (>= (get final-score score-info) u70)
          false
        )
      )
    })
  )
)

;; Audit trail query functions
(define-read-only (get-audit-entry (audit-id uint))
  (map-get? audit-trail audit-id)
)

(define-read-only (get-batch-audit-trail (batch-id uint))
  (let
    (
      (current-audit-id (var-get audit-id-nonce))
      (audit-entries (fold collect-batch-audit-entries
        (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20)
        { target-batch: batch-id, max-id: current-audit-id, entries: (list) }
      ))
    )
    (ok (get entries audit-entries))
  )
)

(define-private (collect-batch-audit-entries (id uint) (acc { target-batch: uint, max-id: uint, entries: (list 20 uint) }))
  (if (<= id (get max-id acc))
    (match (map-get? audit-trail id)
      audit-entry
        (if (is-eq (get target-batch acc) (default-to u0 (get target-batch audit-entry)))
          (merge acc { entries: (unwrap-panic (as-max-len? (append (get entries acc) id) u20)) })
          acc
        )
      acc
    )
    acc
  )
)

(define-read-only (get-actor-audit-trail (actor principal) (limit uint))
  (let
    (
      (current-audit-id (var-get audit-id-nonce))
      (audit-entries (fold collect-actor-audit-entries
        (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20)
        { target-actor: actor, max-id: current-audit-id, limit: limit, entries: (list) }
      ))
    )
    (ok (get entries audit-entries))
  )
)

(define-private (collect-actor-audit-entries (id uint) (acc { target-actor: principal, max-id: uint, limit: uint, entries: (list 20 uint) }))
  (if (and (<= id (get max-id acc)) (< (len (get entries acc)) (get limit acc)))
    (match (map-get? audit-trail id)
      audit-entry
        (if (is-eq (get target-actor acc) (get actor audit-entry))
          (merge acc { entries: (unwrap-panic (as-max-len? (append (get entries acc) id) u20)) })
          acc
        )
      acc
    )
    acc
  )
)

(define-public (generate-compliance-report (period-start uint) (period-end uint))
  (let
    (
      (is-auditor (or (is-eq tx-sender contract-owner) 
                     (default-to false (map-get? audit-permissions tx-sender))))
      (current-audit-id (var-get audit-id-nonce))
    )
    (asserts! is-auditor err-audit-access-denied)
    (asserts! (< period-start period-end) err-invalid-audit-period)
    
    (let
      (
        (report-data (fold analyze-audit-entry
          (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50)
          {
            period-start: period-start,
            period-end: period-end,
            max-id: current-audit-id,
            total-ops: u0,
            success-ops: u0,
            failed-ops: u0,
            batch-ops: u0,
            oracle-ops: u0,
            recall-ops: u0,
            quality-ops: u0,
            unique-actors: (list)
          }
        ))
      )
      (map-set compliance-reports { period-start: period-start, period-end: period-end }
        {
          total-operations: (get total-ops report-data),
          successful-operations: (get success-ops report-data),
          failed-operations: (get failed-ops report-data),
          unique-actors: (len (get unique-actors report-data)),
          batch-operations: (get batch-ops report-data),
          oracle-operations: (get oracle-ops report-data),
          recall-operations: (get recall-ops report-data),
          quality-assessments: (get quality-ops report-data),
          generated-by: tx-sender,
          generated-at: stacks-block-height
        }
      )
      (log-operation "GENERATE_COMPLIANCE_REPORT" none
        "Compliance report generated for specified period" true none)
      (ok true)
    )
  )
)

(define-private (analyze-audit-entry (id uint) 
    (acc { 
      period-start: uint, 
      period-end: uint, 
      max-id: uint, 
      total-ops: uint, 
      success-ops: uint, 
      failed-ops: uint, 
      batch-ops: uint, 
      oracle-ops: uint, 
      recall-ops: uint, 
      quality-ops: uint, 
      unique-actors: (list 50 principal) 
    }))
  (if (<= id (get max-id acc))
    (match (map-get? audit-trail id)
      audit-entry
        (if (and (>= (get timestamp audit-entry) (get period-start acc))
                 (<= (get timestamp audit-entry) (get period-end acc)))
          (let
            (
              (op-type (get operation-type audit-entry))
              (is-success (get success audit-entry))
              (actor (get actor audit-entry))
              (updated-actors (if (is-none (index-of (get unique-actors acc) actor))
                               (unwrap-panic (as-max-len? (append (get unique-actors acc) actor) u50))
                               (get unique-actors acc)))
            )
            (merge acc {
              total-ops: (+ (get total-ops acc) u1),
              success-ops: (if is-success (+ (get success-ops acc) u1) (get success-ops acc)),
              failed-ops: (if (not is-success) (+ (get failed-ops acc) u1) (get failed-ops acc)),
              batch-ops: (if (or (is-eq op-type "CREATE_BATCH") (is-eq op-type "UPDATE_STAGE"))
                           (+ (get batch-ops acc) u1) (get batch-ops acc)),
              oracle-ops: (if (or (is-eq op-type "ADD_ORACLE") (is-eq op-type "REMOVE_ORACLE") 
                                 (is-eq op-type "ADD_CERTIFICATION"))
                            (+ (get oracle-ops acc) u1) (get oracle-ops acc)),
              recall-ops: (if (or (is-eq op-type "INITIATE_RECALL") (is-eq op-type "SEND_RECALL_NOTIFICATION"))
                            (+ (get recall-ops acc) u1) (get recall-ops acc)),
              quality-ops: (if (is-eq op-type "CALCULATE_QUALITY")
                             (+ (get quality-ops acc) u1) (get quality-ops acc)),
              unique-actors: updated-actors
            })
          )
          acc
        )
      acc
    )
    acc
  )
)

(define-read-only (get-compliance-report (period-start uint) (period-end uint))
  (map-get? compliance-reports { period-start: period-start, period-end: period-end })
)

(define-read-only (is-auditor (address principal))
  (or (is-eq address contract-owner) 
      (default-to false (map-get? audit-permissions address)))
)

(define-read-only (get-audit-statistics)
  (let
    (
      (total-audits (- (var-get audit-id-nonce) u1))
    )
    (ok {
      total-audit-entries: total-audits,
      contract-owner: contract-owner,
      current-block: stacks-block-height
    })
  )
)

(define-public (set-batch-expiration
    (batch-id uint)
    (shelf-life-days uint)
    (product-category (string-ascii 30))
    (storage-conditions (string-ascii 100)))
  (let
    (
      (batch-data (unwrap! (map-get? batch-info batch-id) err-invalid-batch))
      (is-oracle (default-to false (map-get? authorized-oracles tx-sender)))
      (is-owner (is-eq tx-sender (unwrap! (nft-get-owner? food-batch batch-id) err-invalid-batch)))
      (harvest-date (get harvest-date batch-data))
      (expiration-date (+ harvest-date shelf-life-days))
      (existing-expiration (map-get? batch-expiration batch-id))
    )
    (asserts! (or is-oracle is-owner (is-eq tx-sender contract-owner)) err-unauthorized-oracle)
    (asserts! (> shelf-life-days u0) err-invalid-expiration)
    (asserts! (is-none existing-expiration) err-expiration-exists)
    (map-set batch-expiration batch-id
      {
        shelf-life-days: shelf-life-days,
        expiration-date: expiration-date,
        product-category: product-category,
        storage-conditions: storage-conditions,
        set-by: tx-sender,
        set-at: stacks-block-height
      }
    )
    (log-operation "SET_EXPIRATION" (some batch-id)
      (concat "Expiration set for category: " product-category) true none)
    (ok expiration-date)
  )
)

(define-public (update-batch-expiration
    (batch-id uint)
    (new-shelf-life-days uint)
    (new-storage-conditions (string-ascii 100)))
  (let
    (
      (batch-data (unwrap! (map-get? batch-info batch-id) err-invalid-batch))
      (expiration-data (unwrap! (map-get? batch-expiration batch-id) err-invalid-batch))
      (is-oracle (default-to false (map-get? authorized-oracles tx-sender)))
      (harvest-date (get harvest-date batch-data))
      (new-expiration-date (+ harvest-date new-shelf-life-days))
    )
    (asserts! (or is-oracle (is-eq tx-sender contract-owner)) err-unauthorized-oracle)
    (asserts! (> new-shelf-life-days u0) err-invalid-expiration)
    (map-set batch-expiration batch-id
      (merge expiration-data {
        shelf-life-days: new-shelf-life-days,
        expiration-date: new-expiration-date,
        storage-conditions: new-storage-conditions
      })
    )
    (log-operation "UPDATE_EXPIRATION" (some batch-id)
      "Expiration settings updated" true none)
    (ok new-expiration-date)
  )
)

(define-public (trigger-expiration-alert
    (batch-id uint)
    (alert-type (string-ascii 20))
    (notified-parties (list 5 principal)))
  (let
    (
      (batch-data (unwrap! (map-get? batch-info batch-id) err-invalid-batch))
      (expiration-data (unwrap! (map-get? batch-expiration batch-id) err-invalid-batch))
      (is-oracle (default-to false (map-get? authorized-oracles tx-sender)))
      (expiration-date (get expiration-date expiration-data))
      (current-block stacks-block-height)
      (days-until-expiration (- (to-int expiration-date) (to-int current-block)))
      (alert-id (var-get expiration-alert-nonce))
    )
    (asserts! (or is-oracle (is-eq tx-sender contract-owner)) err-unauthorized-oracle)
    (map-set expiration-alerts alert-id
      {
        batch-id: batch-id,
        alert-type: alert-type,
        days-until-expiration: days-until-expiration,
        triggered-at: current-block,
        notified-parties: notified-parties,
        resolved: false
      }
    )
    (var-set expiration-alert-nonce (+ alert-id u1))
    (log-operation "TRIGGER_EXPIRATION_ALERT" (some batch-id)
      (concat "Expiration alert: " alert-type) true none)
    (ok alert-id)
  )
)

(define-public (resolve-expiration-alert (alert-id uint))
  (let
    (
      (alert-data (unwrap! (map-get? expiration-alerts alert-id) err-invalid-batch))
      (is-oracle (default-to false (map-get? authorized-oracles tx-sender)))
    )
    (asserts! (or is-oracle (is-eq tx-sender contract-owner)) err-unauthorized-oracle)
    (map-set expiration-alerts alert-id
      (merge alert-data { resolved: true })
    )
    (ok true)
  )
)

(define-read-only (get-batch-expiration (batch-id uint))
  (map-get? batch-expiration batch-id)
)

(define-read-only (check-batch-expiration-status (batch-id uint))
  (match (map-get? batch-expiration batch-id)
    expiration-data
      (let
        (
          (expiration-date (get expiration-date expiration-data))
          (current-block stacks-block-height)
          (days-until-expiration (- (to-int expiration-date) (to-int current-block)))
          (is-expired (>= current-block expiration-date))
          (is-near-expiration (and (not is-expired) (<= days-until-expiration 7)))
        )
        (ok {
          is-expired: is-expired,
          is-near-expiration: is-near-expiration,
          days-until-expiration: days-until-expiration,
          expiration-date: expiration-date,
          product-category: (get product-category expiration-data)
        })
      )
    (err err-invalid-batch)
  )
)

(define-read-only (get-expiration-alert (alert-id uint))
  (map-get? expiration-alerts alert-id)
)

(define-read-only (is-batch-expired (batch-id uint))
  (match (map-get? batch-expiration batch-id)
    expiration-data
      (ok (>= stacks-block-height (get expiration-date expiration-data)))
    (ok false)
  )
)

(define-read-only (get-batches-expiring-soon (threshold-days uint))
  (let
    (
      (current-token-id (var-get token-id-nonce))
      (expiring-batches (fold check-batch-expiration-threshold
        (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
        { threshold: threshold-days, current-block: stacks-block-height, max-id: current-token-id, batches: (list) }
      ))
    )
    (ok (get batches expiring-batches))
  )
)

(define-private (check-batch-expiration-threshold (batch-id uint) 
    (acc { threshold: uint, current-block: uint, max-id: uint, batches: (list 10 uint) }))
  (if (< batch-id (get max-id acc))
    (match (map-get? batch-expiration batch-id)
      expiration-data
        (let
          (
            (expiration-date (get expiration-date expiration-data))
            (days-until (if (>= (get current-block acc) expiration-date)
                         u0
                         (- expiration-date (get current-block acc))))
          )
          (if (and (> days-until u0) (<= days-until (get threshold acc)))
            (merge acc { batches: (unwrap-panic (as-max-len? (append (get batches acc) batch-id) u10)) })
            acc
          )
        )
      acc
    )
    acc
  )
)

(define-read-only (get-batch-with-expiration-info (batch-id uint))
  (match (map-get? batch-info batch-id)
    batch-data
      (match (map-get? batch-expiration batch-id)
        expiration-data
          (let
            (
              (current-block stacks-block-height)
              (expiration-date (get expiration-date expiration-data))
              (is-expired (>= current-block expiration-date))
            )
            (ok {
              batch-info: batch-data,
              expiration-info: (some expiration-data),
              is-expired: is-expired,
              current-status: (if is-expired "EXPIRED" "ACTIVE")
            })
          )
        (ok {
          batch-info: batch-data,
          expiration-info: none,
          is-expired: false,
          current-status: "NO_EXPIRATION_SET"
        })
      )
    (err err-invalid-batch)
  )
)
