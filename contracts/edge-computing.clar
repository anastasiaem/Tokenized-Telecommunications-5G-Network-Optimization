;; Edge Computing Contract
;; Manages 5G edge computing resources

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_NODE_NOT_FOUND (err u401))
(define-constant ERR_INSUFFICIENT_RESOURCES (err u402))
(define-constant ERR_DEPLOYMENT_NOT_FOUND (err u403))

;; Data structures
(define-map edge-nodes
  { node-id: uint }
  {
    operator-id: uint,
    location: (string-ascii 30),
    cpu-cores: uint,
    memory-gb: uint,
    storage-gb: uint,
    available-cpu: uint,
    available-memory: uint,
    available-storage: uint,
    status: (string-ascii 10)
  }
)

(define-map service-deployments
  { deployment-id: uint }
  {
    node-id: uint,
    service-name: (string-ascii 50),
    cpu-required: uint,
    memory-required: uint,
    storage-required: uint,
    deployed-at: uint,
    status: (string-ascii 10)
  }
)

(define-map compute-allocations
  { allocation-id: uint }
  {
    operator-id: uint,
    node-id: uint,
    cpu-allocated: uint,
    memory-allocated: uint,
    storage-allocated: uint,
    price-per-hour: uint,
    start-time: uint,
    duration-hours: uint
  }
)

(define-data-var next-node-id uint u1)
(define-data-var next-deployment-id uint u1)
(define-data-var next-allocation-id uint u1)

;; Public functions
(define-public (register-edge-node
  (operator-id uint)
  (location (string-ascii 30))
  (cpu-cores uint)
  (memory-gb uint)
  (storage-gb uint))
  (let ((node-id (var-get next-node-id)))
    (map-set edge-nodes
      { node-id: node-id }
      {
        operator-id: operator-id,
        location: location,
        cpu-cores: cpu-cores,
        memory-gb: memory-gb,
        storage-gb: storage-gb,
        available-cpu: cpu-cores,
        available-memory: memory-gb,
        available-storage: storage-gb,
        status: "active"
      }
    )

    (var-set next-node-id (+ node-id u1))
    (ok node-id)
  )
)

(define-public (deploy-service
  (node-id uint)
  (service-name (string-ascii 50))
  (cpu-required uint)
  (memory-required uint)
  (storage-required uint))
  (let (
    (deployment-id (var-get next-deployment-id))
    (node (unwrap! (map-get? edge-nodes { node-id: node-id }) ERR_NODE_NOT_FOUND))
  )
    (asserts! (>= (get available-cpu node) cpu-required) ERR_INSUFFICIENT_RESOURCES)
    (asserts! (>= (get available-memory node) memory-required) ERR_INSUFFICIENT_RESOURCES)
    (asserts! (>= (get available-storage node) storage-required) ERR_INSUFFICIENT_RESOURCES)

    ;; Update node resources
    (map-set edge-nodes
      { node-id: node-id }
      (merge node {
        available-cpu: (- (get available-cpu node) cpu-required),
        available-memory: (- (get available-memory node) memory-required),
        available-storage: (- (get available-storage node) storage-required)
      })
    )

    ;; Create deployment record
    (map-set service-deployments
      { deployment-id: deployment-id }
      {
        node-id: node-id,
        service-name: service-name,
        cpu-required: cpu-required,
        memory-required: memory-required,
        storage-required: storage-required,
        deployed-at: block-height,
        status: "running"
      }
    )

    (var-set next-deployment-id (+ deployment-id u1))
    (ok deployment-id)
  )
)

(define-public (allocate-compute-resources
  (operator-id uint)
  (node-id uint)
  (cpu-allocated uint)
  (memory-allocated uint)
  (storage-allocated uint)
  (price-per-hour uint)
  (duration-hours uint))
  (let (
    (allocation-id (var-get next-allocation-id))
    (node (unwrap! (map-get? edge-nodes { node-id: node-id }) ERR_NODE_NOT_FOUND))
  )
    (asserts! (>= (get available-cpu node) cpu-allocated) ERR_INSUFFICIENT_RESOURCES)
    (asserts! (>= (get available-memory node) memory-allocated) ERR_INSUFFICIENT_RESOURCES)
    (asserts! (>= (get available-storage node) storage-allocated) ERR_INSUFFICIENT_RESOURCES)

    (map-set compute-allocations
      { allocation-id: allocation-id }
      {
        operator-id: operator-id,
        node-id: node-id,
        cpu-allocated: cpu-allocated,
        memory-allocated: memory-allocated,
        storage-allocated: storage-allocated,
        price-per-hour: price-per-hour,
        start-time: block-height,
        duration-hours: duration-hours
      }
    )

    (var-set next-allocation-id (+ allocation-id u1))
    (ok allocation-id)
  )
)

;; Read-only functions
(define-read-only (get-edge-node (node-id uint))
  (map-get? edge-nodes { node-id: node-id })
)

(define-read-only (get-service-deployment (deployment-id uint))
  (map-get? service-deployments { deployment-id: deployment-id })
)

(define-read-only (get-compute-allocation (allocation-id uint))
  (map-get? compute-allocations { allocation-id: allocation-id })
)

(define-read-only (get-node-availability (node-id uint))
  (match (map-get? edge-nodes { node-id: node-id })
    node (some {
      available-cpu: (get available-cpu node),
      available-memory: (get available-memory node),
      available-storage: (get available-storage node)
    })
    none
  )
)
