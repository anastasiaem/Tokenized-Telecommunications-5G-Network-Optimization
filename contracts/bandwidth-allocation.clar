;; Bandwidth Allocation Contract
;; Manages 5G bandwidth resource allocation

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INSUFFICIENT_BANDWIDTH (err u201))
(define-constant ERR_ALLOCATION_NOT_FOUND (err u202))
(define-constant ERR_INVALID_OPERATOR (err u203))

;; Data structures
(define-map bandwidth-pools
  { pool-id: uint }
  {
    total-bandwidth-gb: uint,
    allocated-bandwidth-gb: uint,
    available-bandwidth-gb: uint,
    frequency-band: (string-ascii 10),
    location: (string-ascii 30)
  }
)

(define-map bandwidth-allocations
  { allocation-id: uint }
  {
    operator-id: uint,
    pool-id: uint,
    allocated-gb: uint,
    start-time: uint,
    duration-blocks: uint,
    price-per-gb: uint,
    status: (string-ascii 10)
  }
)

(define-data-var next-pool-id uint u1)
(define-data-var next-allocation-id uint u1)

;; Public functions
(define-public (create-bandwidth-pool
  (total-bandwidth-gb uint)
  (frequency-band (string-ascii 10))
  (location (string-ascii 30)))
  (let ((pool-id (var-get next-pool-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set bandwidth-pools
      { pool-id: pool-id }
      {
        total-bandwidth-gb: total-bandwidth-gb,
        allocated-bandwidth-gb: u0,
        available-bandwidth-gb: total-bandwidth-gb,
        frequency-band: frequency-band,
        location: location
      }
    )

    (var-set next-pool-id (+ pool-id u1))
    (ok pool-id)
  )
)

(define-public (allocate-bandwidth
  (operator-id uint)
  (pool-id uint)
  (requested-gb uint)
  (duration-blocks uint)
  (price-per-gb uint))
  (let (
    (allocation-id (var-get next-allocation-id))
    (pool (unwrap! (map-get? bandwidth-pools { pool-id: pool-id }) ERR_ALLOCATION_NOT_FOUND))
  )
    (asserts! (>= (get available-bandwidth-gb pool) requested-gb) ERR_INSUFFICIENT_BANDWIDTH)

    ;; Update pool availability
    (map-set bandwidth-pools
      { pool-id: pool-id }
      (merge pool {
        allocated-bandwidth-gb: (+ (get allocated-bandwidth-gb pool) requested-gb),
        available-bandwidth-gb: (- (get available-bandwidth-gb pool) requested-gb)
      })
    )

    ;; Create allocation record
    (map-set bandwidth-allocations
      { allocation-id: allocation-id }
      {
        operator-id: operator-id,
        pool-id: pool-id,
        allocated-gb: requested-gb,
        start-time: block-height,
        duration-blocks: duration-blocks,
        price-per-gb: price-per-gb,
        status: "active"
      }
    )

    (var-set next-allocation-id (+ allocation-id u1))
    (ok allocation-id)
  )
)

(define-public (release-bandwidth (allocation-id uint))
  (let (
    (allocation (unwrap! (map-get? bandwidth-allocations { allocation-id: allocation-id }) ERR_ALLOCATION_NOT_FOUND))
    (pool (unwrap! (map-get? bandwidth-pools { pool-id: (get pool-id allocation) }) ERR_ALLOCATION_NOT_FOUND))
  )
    ;; Update allocation status
    (map-set bandwidth-allocations
      { allocation-id: allocation-id }
      (merge allocation { status: "released" })
    )

    ;; Return bandwidth to pool
    (map-set bandwidth-pools
      { pool-id: (get pool-id allocation) }
      (merge pool {
        allocated-bandwidth-gb: (- (get allocated-bandwidth-gb pool) (get allocated-gb allocation)),
        available-bandwidth-gb: (+ (get available-bandwidth-gb pool) (get allocated-gb allocation))
      })
    )

    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-bandwidth-pool (pool-id uint))
  (map-get? bandwidth-pools { pool-id: pool-id })
)

(define-read-only (get-allocation (allocation-id uint))
  (map-get? bandwidth-allocations { allocation-id: allocation-id })
)

(define-read-only (get-available-bandwidth (pool-id uint))
  (match (map-get? bandwidth-pools { pool-id: pool-id })
    pool (some (get available-bandwidth-gb pool))
    none
  )
)
