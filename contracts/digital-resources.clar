;; Digital Learning Resources Contract
;; Manages access to educational content in local languages

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-RESOURCE-NOT-FOUND (err u501))
(define-constant ERR-RESOURCE-EXISTS (err u502))
(define-constant ERR-INVALID-ACCESS-LEVEL (err u503))
(define-constant ERR-ACCESS-DENIED (err u504))
(define-constant ERR-INVALID-RATING (err u505))
(define-constant ERR-ALREADY-RATED (err u506))

;; Data Variables
(define-data-var total-resources uint u0)
(define-data-var next-resource-id uint u1)
(define-data-var total-downloads uint u0)

;; Data Maps
(define-map digital-resources
  { resource-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    content-type: (string-ascii 20),
    language: (string-ascii 20),
    subject: (string-ascii 30),
    grade-level: uint,
    creator: principal,
    content-hash: (string-ascii 64),
    access-level: uint,
    download-count: uint,
    rating-sum: uint,
    rating-count: uint,
    created-at: uint,
    active: bool
  }
)

(define-map resource-access
  { resource-id: uint, user: principal }
  {
    access-granted: bool,
    access-date: uint,
    download-count: uint,
    last-accessed: uint
  }
)

(define-map resource-ratings
  { resource-id: uint, rater: principal }
  {
    rating: uint,
    comment: (string-ascii 200),
    rating-date: uint
  }
)

(define-map user-contributions
  { contributor: principal }
  {
    total-resources: uint,
    total-downloads: uint,
    average-rating: uint,
    contribution-score: uint
  }
)

(define-map language-collections
  { language: (string-ascii 20), subject: (string-ascii 30) }
  {
    resource-count: uint,
    total-downloads: uint,
    average-rating: uint,
    last-updated: uint
  }
)

;; Private Functions
(define-private (is-valid-access-level (level uint))
  (and (>= level u1) (<= level u3))
)

(define-private (is-valid-rating (rating uint))
  (and (>= rating u1) (<= rating u5))
)

(define-private (calculate-average-rating (rating-sum uint) (rating-count uint))
  (if (> rating-count u0)
    (/ rating-sum rating-count)
    u0
  )
)

(define-private (has-resource-access (resource-id uint) (user principal))
  (match (map-get? digital-resources { resource-id: resource-id })
    resource-data
    (or
      (is-eq (get access-level resource-data) u1) ;; Public access
      (is-eq (get creator resource-data) user)     ;; Creator access
      (match (map-get? resource-access { resource-id: resource-id, user: user })
        access-data (get access-granted access-data)
        false
      )
    )
    false
  )
)

;; Public Functions
(define-public (create-resource (title (string-ascii 100)) (description (string-ascii 300)) (content-type (string-ascii 20)) (language (string-ascii 20)) (subject (string-ascii 30)) (grade-level uint) (content-hash (string-ascii 64)) (access-level uint))
  (let
    (
      (resource-id (var-get next-resource-id))
    )
    (asserts! (is-valid-access-level access-level) ERR-INVALID-ACCESS-LEVEL)
    (asserts! (and (>= grade-level u1) (<= grade-level u12)) ERR-INVALID-ACCESS-LEVEL)

    (map-set digital-resources
      { resource-id: resource-id }
      {
        title: title,
        description: description,
        content-type: content-type,
        language: language,
        subject: subject,
        grade-level: grade-level,
        creator: tx-sender,
        content-hash: content-hash,
        access-level: access-level,
        download-count: u0,
        rating-sum: u0,
        rating-count: u0,
        created-at: block-height,
        active: true
      }
    )

    ;; Update contributor stats
    (match (map-get? user-contributions { contributor: tx-sender })
      existing-contrib
      (map-set user-contributions
        { contributor: tx-sender }
        (merge existing-contrib { total-resources: (+ (get total-resources existing-contrib) u1) })
      )
      (map-set user-contributions
        { contributor: tx-sender }
        { total-resources: u1, total-downloads: u0, average-rating: u0, contribution-score: u0 }
      )
    )

    ;; Update language collection stats
    (match (map-get? language-collections { language: language, subject: subject })
      existing-collection
      (map-set language-collections
        { language: language, subject: subject }
        (merge existing-collection {
          resource-count: (+ (get resource-count existing-collection) u1),
          last-updated: block-height
        })
      )
      (map-set language-collections
        { language: language, subject: subject }
        { resource-count: u1, total-downloads: u0, average-rating: u0, last-updated: block-height }
      )
    )

    (var-set next-resource-id (+ resource-id u1))
    (var-set total-resources (+ (var-get total-resources) u1))
    (ok resource-id)
  )
)

(define-public (grant-resource-access (resource-id uint) (user principal))
  (let
    (
      (resource-data (unwrap! (map-get? digital-resources { resource-id: resource-id }) ERR-RESOURCE-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get creator resource-data)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)

    (map-set resource-access
      { resource-id: resource-id, user: user }
      {
        access-granted: true,
        access-date: block-height,
        download-count: u0,
        last-accessed: u0
      }
    )

    (ok true)
  )
)

(define-public (download-resource (resource-id uint))
  (let
    (
      (resource-data (unwrap! (map-get? digital-resources { resource-id: resource-id }) ERR-RESOURCE-NOT-FOUND))
      (existing-access (map-get? resource-access { resource-id: resource-id, user: tx-sender }))
    )
    (asserts! (get active resource-data) ERR-RESOURCE-NOT-FOUND)
    (asserts! (has-resource-access resource-id tx-sender) ERR-ACCESS-DENIED)

    ;; Update resource download count
    (map-set digital-resources
      { resource-id: resource-id }
      (merge resource-data { download-count: (+ (get download-count resource-data) u1) })
    )

    ;; Update user access stats
    (match existing-access
      access-data
      (map-set resource-access
        { resource-id: resource-id, user: tx-sender }
        (merge access-data {
          download-count: (+ (get download-count access-data) u1),
          last-accessed: block-height
        })
      )
      (map-set resource-access
        { resource-id: resource-id, user: tx-sender }
        { access-granted: true, access-date: block-height, download-count: u1, last-accessed: block-height }
      )
    )

    (var-set total-downloads (+ (var-get total-downloads) u1))
    (ok true)
  )
)

(define-public (rate-resource (resource-id uint) (rating uint) (comment (string-ascii 200)))
  (let
    (
      (resource-data (unwrap! (map-get? digital-resources { resource-id: resource-id }) ERR-RESOURCE-NOT-FOUND))
    )
    (asserts! (is-valid-rating rating) ERR-INVALID-RATING)
    (asserts! (has-resource-access resource-id tx-sender) ERR-ACCESS-DENIED)
    (asserts! (is-none (map-get? resource-ratings { resource-id: resource-id, rater: tx-sender })) ERR-ALREADY-RATED)

    (map-set resource-ratings
      { resource-id: resource-id, rater: tx-sender }
      {
        rating: rating,
        comment: comment,
        rating-date: block-height
      }
    )

    (map-set digital-resources
      { resource-id: resource-id }
      (merge resource-data {
        rating-sum: (+ (get rating-sum resource-data) rating),
        rating-count: (+ (get rating-count resource-data) u1)
      })
    )

    (ok true)
  )
)

(define-public (update-resource-status (resource-id uint) (active bool))
  (let
    (
      (resource-data (unwrap! (map-get? digital-resources { resource-id: resource-id }) ERR-RESOURCE-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get creator resource-data)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)

    (map-set digital-resources
      { resource-id: resource-id }
      (merge resource-data { active: active })
    )

    (ok true)
  )
)

(define-public (revoke-resource-access (resource-id uint) (user principal))
  (let
    (
      (resource-data (unwrap! (map-get? digital-resources { resource-id: resource-id }) ERR-RESOURCE-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get creator resource-data)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)

    (match (map-get? resource-access { resource-id: resource-id, user: user })
      access-data
      (map-set resource-access
        { resource-id: resource-id, user: user }
        (merge access-data { access-granted: false })
      )
      false
    )

    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-resource-info (resource-id uint))
  (map-get? digital-resources { resource-id: resource-id })
)

(define-read-only (get-resource-access-info (resource-id uint) (user principal))
  (map-get? resource-access { resource-id: resource-id, user: user })
)

(define-read-only (get-resource-rating (resource-id uint) (rater principal))
  (map-get? resource-ratings { resource-id: resource-id, rater: rater })
)

(define-read-only (get-user-contributions (contributor principal))
  (map-get? user-contributions { contributor: contributor })
)

(define-read-only (get-language-collection-stats (language (string-ascii 20)) (subject (string-ascii 30)))
  (map-get? language-collections { language: language, subject: subject })
)

(define-read-only (get-resource-average-rating (resource-id uint))
  (match (map-get? digital-resources { resource-id: resource-id })
    resource-data
    (calculate-average-rating (get rating-sum resource-data) (get rating-count resource-data))
    u0
  )
)

(define-read-only (check-resource-access (resource-id uint) (user principal))
  (has-resource-access resource-id user)
)

(define-read-only (get-platform-stats)
  {
    total-resources: (var-get total-resources),
    total-downloads: (var-get total-downloads),
    active-resources: (- (var-get next-resource-id) u1)
  }
)

(define-read-only (get-resources-by-language (language (string-ascii 20)))
  (match (map-get? language-collections { language: language, subject: "general" })
    collection-data (get resource-count collection-data)
    u0
  )
)
