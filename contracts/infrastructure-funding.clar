;; Infrastructure Funding Contract
;; Manages crowdfunded school construction and improvement projects

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-PROJECT-NOT-FOUND (err u201))
(define-constant ERR-PROJECT-EXPIRED (err u202))
(define-constant ERR-PROJECT-COMPLETED (err u203))
(define-constant ERR-INSUFFICIENT-CONTRIBUTION (err u204))
(define-constant ERR-GOAL-NOT-REACHED (err u205))
(define-constant ERR-ALREADY-WITHDRAWN (err u206))
(define-constant ERR-INVALID-MILESTONE (err u207))

;; Data Variables
(define-data-var next-project-id uint u1)
(define-data-var total-projects-funded uint u0)
(define-data-var total-amount-raised uint u0)

;; Data Maps
(define-map projects
  { project-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    funding-goal: uint,
    current-funding: uint,
    deadline: uint,
    created-at: uint,
    completed: bool,
    funds-withdrawn: bool,
    milestone-count: uint,
    current-milestone: uint
  }
)

(define-map contributions
  { project-id: uint, contributor: principal }
  { amount: uint, contribution-block: uint }
)

(define-map project-milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-ascii 200),
    funding-percentage: uint,
    completed: bool,
    completion-block: uint
  }
)

(define-map project-votes
  { project-id: uint, voter: principal }
  { vote: bool, voting-block: uint }
)

;; Private Functions
(define-private (is-project-active (project-id uint))
  (match (map-get? projects { project-id: project-id })
    project-data
    (and
      (< block-height (get deadline project-data))
      (not (get completed project-data))
    )
    false
  )
)

(define-private (calculate-milestone-amount (project-id uint) (milestone-id uint))
  (match (map-get? projects { project-id: project-id })
    project-data
    (match (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id })
      milestone-data
      (/ (* (get funding-goal project-data) (get funding-percentage milestone-data)) u100)
      u0
    )
    u0
  )
)

;; Public Functions
(define-public (create-project (title (string-ascii 100)) (description (string-ascii 500)) (funding-goal uint) (duration-days uint))
  (let
    (
      (project-id (var-get next-project-id))
      (deadline (+ block-height (* duration-days u144))) ;; Assuming ~10 min blocks
    )
    (asserts! (> funding-goal u0) ERR-INSUFFICIENT-CONTRIBUTION)
    (asserts! (> duration-days u0) ERR-PROJECT-EXPIRED)

    (map-set projects
      { project-id: project-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        funding-goal: funding-goal,
        current-funding: u0,
        deadline: deadline,
        created-at: block-height,
        completed: false,
        funds-withdrawn: false,
        milestone-count: u0,
        current-milestone: u0
      }
    )

    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

(define-public (contribute-to-project (project-id uint) (amount uint))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (existing-contribution (default-to u0 (get amount (map-get? contributions { project-id: project-id, contributor: tx-sender }))))
    )
    (asserts! (is-project-active project-id) ERR-PROJECT-EXPIRED)
    (asserts! (> amount u0) ERR-INSUFFICIENT-CONTRIBUTION)

    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    (map-set contributions
      { project-id: project-id, contributor: tx-sender }
      { amount: (+ existing-contribution amount), contribution-block: block-height }
    )

    (map-set projects
      { project-id: project-id }
      (merge project-data { current-funding: (+ (get current-funding project-data) amount) })
    )

    (var-set total-amount-raised (+ (var-get total-amount-raised) amount))
    (ok true)
  )
)

(define-public (add-milestone (project-id uint) (description (string-ascii 200)) (funding-percentage uint))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (milestone-id (+ (get milestone-count project-data) u1))
    )
    (asserts! (is-eq tx-sender (get creator project-data)) ERR-NOT-AUTHORIZED)
    (asserts! (<= funding-percentage u100) ERR-INVALID-MILESTONE)

    (map-set project-milestones
      { project-id: project-id, milestone-id: milestone-id }
      {
        description: description,
        funding-percentage: funding-percentage,
        completed: false,
        completion-block: u0
      }
    )

    (map-set projects
      { project-id: project-id }
      (merge project-data { milestone-count: milestone-id })
    )

    (ok milestone-id)
  )
)

(define-public (complete-milestone (project-id uint) (milestone-id uint))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (milestone-data (unwrap! (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id }) ERR-INVALID-MILESTONE))
    )
    (asserts! (is-eq tx-sender (get creator project-data)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get completed milestone-data)) ERR-PROJECT-COMPLETED)

    (map-set project-milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone-data { completed: true, completion-block: block-height })
    )

    (ok true)
  )
)

(define-public (withdraw-milestone-funds (project-id uint) (milestone-id uint))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (milestone-data (unwrap! (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id }) ERR-INVALID-MILESTONE))
      (withdrawal-amount (calculate-milestone-amount project-id milestone-id))
    )
    (asserts! (is-eq tx-sender (get creator project-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get completed milestone-data) ERR-INVALID-MILESTONE)
    (asserts! (>= (get current-funding project-data) (get funding-goal project-data)) ERR-GOAL-NOT-REACHED)

    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender (get creator project-data))))

    (map-set projects
      { project-id: project-id }
      (merge project-data { current-milestone: milestone-id })
    )

    (ok withdrawal-amount)
  )
)

(define-public (vote-on-project (project-id uint) (approve bool))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
    )
    (asserts! (is-project-active project-id) ERR-PROJECT-EXPIRED)

    (map-set project-votes
      { project-id: project-id, voter: tx-sender }
      { vote: approve, voting-block: block-height }
    )

    (ok true)
  )
)

(define-public (refund-contribution (project-id uint))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (contribution-data (unwrap! (map-get? contributions { project-id: project-id, contributor: tx-sender }) ERR-INSUFFICIENT-CONTRIBUTION))
      (refund-amount (get amount contribution-data))
    )
    (asserts! (>= block-height (get deadline project-data)) ERR-PROJECT-EXPIRED)
    (asserts! (< (get current-funding project-data) (get funding-goal project-data)) ERR-GOAL-NOT-REACHED)

    (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))

    (map-delete contributions { project-id: project-id, contributor: tx-sender })

    (ok refund-amount)
  )
)

;; Read-only Functions
(define-read-only (get-project-info (project-id uint))
  (map-get? projects { project-id: project-id })
)

(define-read-only (get-contribution-info (project-id uint) (contributor principal))
  (map-get? contributions { project-id: project-id, contributor: contributor })
)

(define-read-only (get-milestone-info (project-id uint) (milestone-id uint))
  (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-project-vote (project-id uint) (voter principal))
  (map-get? project-votes { project-id: project-id, voter: voter })
)

(define-read-only (get-funding-stats)
  {
    total-projects: (- (var-get next-project-id) u1),
    total-funded: (var-get total-projects-funded),
    total-raised: (var-get total-amount-raised),
    contract-balance: (stx-get-balance (as-contract tx-sender))
  }
)

(define-read-only (is-funding-goal-reached (project-id uint))
  (match (map-get? projects { project-id: project-id })
    project-data (>= (get current-funding project-data) (get funding-goal project-data))
    false
  )
)
