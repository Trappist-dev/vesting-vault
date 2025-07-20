;; Vesting Vault Contract
;; A time-locked contract for token/equity vesting on Stacks blockchain

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-VESTING-NOT-FOUND (err u102))
(define-constant ERR-NOTHING-TO-CLAIM (err u103))
(define-constant ERR-INVALID-DURATION (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))
(define-constant ERR-INSUFFICIENT-BALANCE (err u106))

;; Data Variables
(define-data-var contract-balance uint u0)

;; Data Maps
(define-map vesting-schedules
  { beneficiary: principal }
  {
    total-amount: uint,
    claimed-amount: uint,
    start-block: uint,
    cliff-duration: uint,
    vesting-duration: uint,
    created-by: principal
  }
)

(define-map authorized-managers principal bool)

;; Private Functions
(define-private (calculate-vested-amount (beneficiary principal))
  (let (
    (schedule (unwrap! (map-get? vesting-schedules {beneficiary: beneficiary}) u0))
    (current-block block-height)
    (start-block (get start-block schedule))
    (cliff-duration (get cliff-duration schedule))
    (vesting-duration (get vesting-duration schedule))
    (total-amount (get total-amount schedule))
  )
    (if (< current-block (+ start-block cliff-duration))
      u0  ;; Before cliff, nothing vested
      (if (>= current-block (+ start-block vesting-duration))
        total-amount  ;; After vesting period, everything vested
        ;; Linear vesting calculation
        (let (
          (elapsed-blocks (- current-block (+ start-block cliff-duration)))
          (remaining-duration (- vesting-duration cliff-duration))
        )
          (/ (* total-amount elapsed-blocks) remaining-duration)
        )
      )
    )
  )
)

(define-private (get-claimable-amount (beneficiary principal))
  (let (
    (schedule (unwrap! (map-get? vesting-schedules {beneficiary: beneficiary}) u0))
    (vested-amount (calculate-vested-amount beneficiary))
    (claimed-amount (get claimed-amount schedule))
  )
    (if (> vested-amount claimed-amount)
      (- vested-amount claimed-amount)
      u0
    )
  )
)

;; Public Functions

;; Initialize contract and set up managers
(define-public (initialize-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set authorized-managers CONTRACT-OWNER true)
    (ok true)
  )
)

;; Add authorized manager
(define-public (add-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set authorized-managers manager true)
    (ok true)
  )
)

;; Remove authorized manager
(define-public (remove-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-delete authorized-managers manager)
    (ok true)
  )
)

;; Create vesting schedule
(define-public (create-vesting-schedule
  (beneficiary principal)
  (total-amount uint)
  (cliff-duration uint)
  (vesting-duration uint)
)
  (let (
    (is-authorized (default-to false (map-get? authorized-managers tx-sender)))
  )
    (asserts! is-authorized ERR-UNAUTHORIZED)
    (asserts! (> total-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> vesting-duration cliff-duration) ERR-INVALID-DURATION)
    (asserts! (is-none (map-get? vesting-schedules {beneficiary: beneficiary})) ERR-ALREADY-EXISTS)
    
    ;; Create vesting schedule
    (map-set vesting-schedules
      {beneficiary: beneficiary}
      {
        total-amount: total-amount,
        claimed-amount: u0,
        start-block: block-height,
        cliff-duration: cliff-duration,
        vesting-duration: vesting-duration,
        created-by: tx-sender
      }
    )
    
    ;; Update contract balance
    (var-set contract-balance (+ (var-get contract-balance) total-amount))
    
    (ok true)
  )
)

;; Claim vested tokens
(define-public (claim-vested-tokens)
  (let (
    (claimable-amount (get-claimable-amount tx-sender))
    (schedule (unwrap! (map-get? vesting-schedules {beneficiary: tx-sender}) ERR-VESTING-NOT-FOUND))
  )
    (asserts! (> claimable-amount u0) ERR-NOTHING-TO-CLAIM)
    
    ;; Update claimed amount
    (map-set vesting-schedules
      {beneficiary: tx-sender}
      (merge schedule {claimed-amount: (+ (get claimed-amount schedule) claimable-amount)})
    )
    
    ;; Update contract balance
    (var-set contract-balance (- (var-get contract-balance) claimable-amount))
    
    ;; Transfer tokens (in a real implementation, this would transfer actual tokens)
    ;; For now, we'll just emit an event-like response
    (ok claimable-amount)
  )
)

;; Emergency withdraw (only owner)
(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (<= amount (var-get contract-balance)) ERR-INSUFFICIENT-BALANCE)
    
    (var-set contract-balance (- (var-get contract-balance) amount))
    (ok amount)
  )
)

;; Revoke vesting schedule (only creator or owner)
(define-public (revoke-vesting (beneficiary principal))
  (let (
    (schedule (unwrap! (map-get? vesting-schedules {beneficiary: beneficiary}) ERR-VESTING-NOT-FOUND))
    (is-creator (is-eq tx-sender (get created-by schedule)))
    (is-owner (is-eq tx-sender CONTRACT-OWNER))
  )
    (asserts! (or is-creator is-owner) ERR-UNAUTHORIZED)
    
    ;; Calculate remaining amount to return to contract balance
    (let (
      (remaining-amount (- (get total-amount schedule) (get claimed-amount schedule)))
    )
      ;; Remove vesting schedule
      (map-delete vesting-schedules {beneficiary: beneficiary})
      
      ;; Update contract balance (remove remaining unvested amount)
      (var-set contract-balance (- (var-get contract-balance) remaining-amount))
      
      (ok remaining-amount)
    )
  )
)

;; Read-only Functions

;; Get vesting schedule details
(define-read-only (get-vesting-schedule (beneficiary principal))
  (map-get? vesting-schedules {beneficiary: beneficiary})
)

;; Get vested amount for beneficiary
(define-read-only (get-vested-amount (beneficiary principal))
  (calculate-vested-amount beneficiary)
)

;; Get claimable amount for beneficiary
(define-read-only (get-claimable-tokens (beneficiary principal))
  (get-claimable-amount beneficiary)
)

;; Get contract balance
(define-read-only (get-contract-balance)
  (var-get contract-balance)
)

;; Check if address is authorized manager
(define-read-only (is-manager (address principal))
  (default-to false (map-get? authorized-managers address))
)

;; Get contract owner
(define-read-only (get-contract-owner)
  CONTRACT-OWNER
)

;; Get current block height (helper function)
(define-read-only (get-current-block)
  block-height
)