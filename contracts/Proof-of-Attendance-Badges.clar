(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-claimed (err u102))
(define-constant err-insufficient-badges (err u103))
(define-constant err-invalid-training (err u104))
(define-constant err-grant-not-available (err u105))

(define-data-var next-badge-id uint u1)
(define-data-var next-training-id uint u1)
(define-data-var next-grant-id uint u1)

(define-map badges
  { badge-id: uint }
  {
    owner: principal,
    training-id: uint,
    issued-at: uint,
    metadata: (string-ascii 256)
  }
)

(define-map trainings
  { training-id: uint }
  {
    name: (string-ascii 128),
    instructor: principal,
    start-block: uint,
    end-block: uint,
    max-attendees: uint,
    current-attendees: uint,
    is-active: bool
  }
)

(define-map grants
  { grant-id: uint }
  {
    amount: uint,
    required-badges: uint,
    available-funds: uint,
    creator: principal,
    is-active: bool,
    expiry-block: uint
  }
)

(define-map user-badges
  { user: principal }
  { badge-count: uint, badge-ids: (list 100 uint) }
)

(define-map training-attendees
  { training-id: uint, attendee: principal }
  { attended: bool, badge-id: uint }
)

(define-map grant-claims
  { grant-id: uint, claimer: principal }
  { claimed: bool, claim-block: uint }
)

(define-public (create-training (name (string-ascii 128)) (duration-blocks uint) (max-attendees uint))
  (let (
    (training-id (var-get next-training-id))
    (current-block stacks-block-height)
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set trainings
      { training-id: training-id }
      {
        name: name,
        instructor: tx-sender,
        start-block: current-block,
        end-block: (+ current-block duration-blocks),
        max-attendees: max-attendees,
        current-attendees: u0,
        is-active: true
      }
    )
    (var-set next-training-id (+ training-id u1))
    (ok training-id)
  )
)

(define-public (register-attendance (training-id uint) (attendee principal))
  (let (
    (training (unwrap! (map-get? trainings { training-id: training-id }) err-not-found))
    (current-block stacks-block-height)
  )
    (asserts! (is-eq tx-sender (get instructor training)) err-owner-only)
    (asserts! (get is-active training) err-invalid-training)
    (asserts! (<= current-block (get end-block training)) err-invalid-training)
    (asserts! (< (get current-attendees training) (get max-attendees training)) err-invalid-training)
    (asserts! (is-none (map-get? training-attendees { training-id: training-id, attendee: attendee })) err-already-claimed)
    
    (map-set training-attendees
      { training-id: training-id, attendee: attendee }
      { attended: true, badge-id: u0 }
    )
    
    (map-set trainings
      { training-id: training-id }
      (merge training { current-attendees: (+ (get current-attendees training) u1) })
    )
    (ok true)
  )
)

(define-public (mint-badge (training-id uint) (metadata (string-ascii 256)))
  (let (
    (badge-id (var-get next-badge-id))
    (training (unwrap! (map-get? trainings { training-id: training-id }) err-not-found))
    (attendance (unwrap! (map-get? training-attendees { training-id: training-id, attendee: tx-sender }) err-not-found))
    (current-block stacks-block-height)
    (user-badge-data (default-to { badge-count: u0, badge-ids: (list) } (map-get? user-badges { user: tx-sender })))
  )
    (asserts! (get attended attendance) err-not-found)
    (asserts! (is-eq (get badge-id attendance) u0) err-already-claimed)
    (asserts! (> current-block (get end-block training)) err-invalid-training)
    
    (map-set badges
      { badge-id: badge-id }
      {
        owner: tx-sender,
        training-id: training-id,
        issued-at: current-block,
        metadata: metadata
      }
    )
    
    (map-set training-attendees
      { training-id: training-id, attendee: tx-sender }
      (merge attendance { badge-id: badge-id })
    )
    
    (map-set user-badges
      { user: tx-sender }
      {
        badge-count: (+ (get badge-count user-badge-data) u1),
        badge-ids: (unwrap! (as-max-len? (append (get badge-ids user-badge-data) badge-id) u100) (err u999))
      }
    )
    
    (var-set next-badge-id (+ badge-id u1))
    (ok badge-id)
  )
)

(define-public (create-grant (amount uint) (required-badges uint) (duration-blocks uint))
  (let (
    (grant-id (var-get next-grant-id))
    (current-block stacks-block-height)
  )
    (asserts! (> amount u0) (err u106))
    (asserts! (> required-badges u0) (err u107))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set grants
      { grant-id: grant-id }
      {
        amount: amount,
        required-badges: required-badges,
        available-funds: amount,
        creator: tx-sender,
        is-active: true,
        expiry-block: (+ current-block duration-blocks)
      }
    )
    (var-set next-grant-id (+ grant-id u1))
    (ok grant-id)
  )
)

(define-public (claim-grant (grant-id uint))
  (let (
    (grant (unwrap! (map-get? grants { grant-id: grant-id }) err-not-found))
    (user-badges-data (unwrap! (map-get? user-badges { user: tx-sender }) err-insufficient-badges))
    (current-block stacks-block-height)
  )
    (asserts! (get is-active grant) err-grant-not-available)
    (asserts! (<= current-block (get expiry-block grant)) err-grant-not-available)
    (asserts! (>= (get badge-count user-badges-data) (get required-badges grant)) err-insufficient-badges)
    (asserts! (is-none (map-get? grant-claims { grant-id: grant-id, claimer: tx-sender })) err-already-claimed)
    (asserts! (>= (get available-funds grant) (get amount grant)) err-grant-not-available)
    
    (try! (as-contract (stx-transfer? (get amount grant) tx-sender tx-sender)))
    
    (map-set grant-claims
      { grant-id: grant-id, claimer: tx-sender }
      { claimed: true, claim-block: current-block }
    )
    
    (map-set grants
      { grant-id: grant-id }
      (merge grant { available-funds: (- (get available-funds grant) (get amount grant)) })
    )
    (ok (get amount grant))
  )
)

(define-read-only (get-badge (badge-id uint))
  (map-get? badges { badge-id: badge-id })
)

(define-read-only (get-training (training-id uint))
  (map-get? trainings { training-id: training-id })
)

(define-read-only (get-grant (grant-id uint))
  (map-get? grants { grant-id: grant-id })
)

(define-read-only (get-user-badges (user principal))
  (map-get? user-badges { user: user })
)

(define-read-only (get-attendance (training-id uint) (attendee principal))
  (map-get? training-attendees { training-id: training-id, attendee: attendee })
)

(define-read-only (has-claimed-grant (grant-id uint) (claimer principal))
  (is-some (map-get? grant-claims { grant-id: grant-id, claimer: claimer }))
)

(define-read-only (get-current-badge-id)
  (var-get next-badge-id)
)

(define-read-only (get-current-training-id)
  (var-get next-training-id)
)

(define-read-only (get-current-grant-id)
  (var-get next-grant-id)
)
