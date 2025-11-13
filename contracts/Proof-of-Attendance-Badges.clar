(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-claimed (err u102))
(define-constant err-insufficient-badges (err u103))
(define-constant err-invalid-training (err u104))
(define-constant err-grant-not-available (err u105))

(define-constant err-not-badge-owner (err u108))
(define-constant err-transfer-to-self (err u109))
(define-constant err-invalid-delegation (err u110))

(define-constant tier-bronze u100)
(define-constant tier-silver u250)
(define-constant tier-gold u500)
(define-constant tier-platinum u1000)
(define-constant err-tier-too-low (err u111))

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


(define-map badge-delegations
  { badge-id: uint }
  { delegate: (optional principal), delegated-at: uint }
)

(define-map transfer-history
  { badge-id: uint, transfer-index: uint }
  { from: principal, to: principal, transferred-at: uint }
)

(define-data-var next-transfer-index uint u0)

(define-public (transfer-badge (badge-id uint) (recipient principal))
  (let (
    (badge (unwrap! (map-get? badges { badge-id: badge-id }) err-not-found))
    (current-block stacks-block-height)
    (current-owner (get owner badge))
    (sender-badge-data (unwrap! (map-get? user-badges { user: tx-sender }) err-not-badge-owner))
    (recipient-badge-data (default-to { badge-count: u0, badge-ids: (list) } (map-get? user-badges { user: recipient })))
    (transfer-idx (var-get next-transfer-index))
  )
    (asserts! (is-eq tx-sender current-owner) err-not-badge-owner)
    (asserts! (not (is-eq tx-sender recipient)) err-transfer-to-self)
    
    (map-set badges
      { badge-id: badge-id }
      (merge badge { owner: recipient })
    )
    
    (map-set user-badges
      { user: tx-sender }
      {
        badge-count: (- (get badge-count sender-badge-data) u1),
        badge-ids: (filter filter-badge-id (get badge-ids sender-badge-data))
      }
    )
    
    (map-set user-badges
      { user: recipient }
      {
        badge-count: (+ (get badge-count recipient-badge-data) u1),
        badge-ids: (unwrap! (as-max-len? (append (get badge-ids recipient-badge-data) badge-id) u100) (err u999))
      }
    )
    
    (map-set transfer-history
      { badge-id: badge-id, transfer-index: transfer-idx }
      { from: tx-sender, to: recipient, transferred-at: current-block }
    )
    
    (var-set next-transfer-index (+ transfer-idx u1))
    (ok true)
  )
)

(define-public (delegate-badge (badge-id uint) (delegate principal))
  (let (
    (badge (unwrap! (map-get? badges { badge-id: badge-id }) err-not-found))
    (current-block stacks-block-height)
  )
    (asserts! (is-eq tx-sender (get owner badge)) err-not-badge-owner)
    (map-set badge-delegations
      { badge-id: badge-id }
      { delegate: (some delegate), delegated-at: current-block }
    )
    (ok true)
  )
)

(define-public (revoke-delegation (badge-id uint))
  (let (
    (badge (unwrap! (map-get? badges { badge-id: badge-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender (get owner badge)) err-not-badge-owner)
    (map-delete badge-delegations { badge-id: badge-id })
    (ok true)
  )
)

(define-private (filter-badge-id (id uint))
  (not (is-eq id (var-get next-badge-id)))
)

(define-read-only (get-badge-delegation (badge-id uint))
  (map-get? badge-delegations { badge-id: badge-id })
)

(define-read-only (get-transfer-history (badge-id uint) (transfer-index uint))
  (map-get? transfer-history { badge-id: badge-id, transfer-index: transfer-index })
)

(define-read-only (is-delegated-to (badge-id uint) (checker principal))
  (match (map-get? badge-delegations { badge-id: badge-id })
    delegation (is-eq (some checker) (get delegate delegation))
    false
  )
)

(define-map user-reputation
  { user: principal }
  { 
    reputation-score: uint,
    current-tier: (string-ascii 16),
    last-updated: uint,
    unique-trainings: uint
  }
)

(define-map tiered-grants
  { tiered-grant-id: uint }
  {
    amount: uint,
    required-tier: (string-ascii 16),
    available-slots: uint,
    creator: principal,
    expiry-block: uint
  }
)

(define-data-var next-tiered-grant-id uint u1)

(define-map tiered-grant-claims
  { tiered-grant-id: uint, claimer: principal }
  { claimed: bool }
)

(define-public (calculate-reputation)
  (let (
    (user-data (default-to { badge-count: u0, badge-ids: (list) } (map-get? user-badges { user: tx-sender })))
    (badge-count (get badge-count user-data))
    (reputation-score (* badge-count u50))
    (tier (if (>= reputation-score tier-platinum) "platinum"
           (if (>= reputation-score tier-gold) "gold"
           (if (>= reputation-score tier-silver) "silver" "bronze"))))
  )
    (map-set user-reputation
      { user: tx-sender }
      {
        reputation-score: reputation-score,
        current-tier: tier,
        last-updated: stacks-block-height,
        unique-trainings: badge-count
      }
    )
    (ok { score: reputation-score, tier: tier })
  )
)

(define-public (create-tiered-grant (amount uint) (required-tier (string-ascii 16)) (slots uint) (duration uint))
  (let (
    (tiered-grant-id (var-get next-tiered-grant-id))
  )
    (try! (stx-transfer? (* amount slots) tx-sender (as-contract tx-sender)))
    (map-set tiered-grants
      { tiered-grant-id: tiered-grant-id }
      {
        amount: amount,
        required-tier: required-tier,
        available-slots: slots,
        creator: tx-sender,
        expiry-block: (+ stacks-block-height duration)
      }
    )
    (var-set next-tiered-grant-id (+ tiered-grant-id u1))
    (ok tiered-grant-id)
  )
)

(define-public (claim-tiered-grant (tiered-grant-id uint))
  (let (
    (grant (unwrap! (map-get? tiered-grants { tiered-grant-id: tiered-grant-id }) err-not-found))
    (user-rep (unwrap! (map-get? user-reputation { user: tx-sender }) err-not-found))
  )
    (asserts! (<= stacks-block-height (get expiry-block grant)) err-grant-not-available)
    (asserts! (> (get available-slots grant) u0) err-grant-not-available)
    (asserts! (is-none (map-get? tiered-grant-claims { tiered-grant-id: tiered-grant-id, claimer: tx-sender })) err-already-claimed)
    (asserts! (is-eq (get current-tier user-rep) (get required-tier grant)) err-tier-too-low)
    
    (try! (as-contract (stx-transfer? (get amount grant) tx-sender tx-sender)))
    (map-set tiered-grant-claims
      { tiered-grant-id: tiered-grant-id, claimer: tx-sender }
      { claimed: true }
    )
    (map-set tiered-grants
      { tiered-grant-id: tiered-grant-id }
      (merge grant { available-slots: (- (get available-slots grant) u1) })
    )
    (ok (get amount grant))
  )
)

(define-read-only (get-user-reputation (user principal))
  (map-get? user-reputation { user: user })
)

(define-read-only (get-tiered-grant (tiered-grant-id uint))
  (map-get? tiered-grants { tiered-grant-id: tiered-grant-id })
)