;; Random Number Generator
;; A smart contract for generating pseudo-random numbers on the Stacks blockchain

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-RANGE (err u101))
(define-constant ERR-SEED-UNAVAILABLE (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-NO-SUCH-REQUEST (err u104))
(define-constant ERR-INVALID-FEE (err u105))
(define-constant ERR-INVALID-SEED (err u106))
(define-constant MAX-SEED-VALUE u1000000)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var fee-amount uint u1000)  ;; in microSTX
(define-data-var request-count uint u0)
(define-data-var entropy-accumulator uint u0)
(define-data-var last-burn-height uint u0)

;; Data maps
(define-map random-requests uint 
  {
    requester: principal,
    min: uint,
    max: uint,
    seed: (optional uint),
    request-burn-height: uint,
    fulfilled: bool,
    result: (optional uint)
  }
)

;; Public functions

;; Request a random number
(define-public (request-random-number (min uint) (max uint) (user-seed (optional uint)))
  (let (
        (request-id (var-get request-count))
        (checked-seed (if (is-some user-seed)
                          (let ((seed-value (unwrap-panic user-seed)))
                            ;; Cap the seed value to prevent attacks
                            (if (> seed-value MAX-SEED-VALUE)
                                (some MAX-SEED-VALUE)
                                user-seed))
                          none))
       )
    
    ;; Ensure the range is valid
    (asserts! (< min max) ERR-INVALID-RANGE)
    (asserts! (> max u0) ERR-INVALID-RANGE)
    
    ;; Collect the fee
    (asserts! (>= (stx-get-balance tx-sender) (var-get fee-amount)) ERR-INSUFFICIENT-FUNDS)
    (try! (stx-transfer? (var-get fee-amount) tx-sender (var-get contract-owner)))
    
    ;; Update entropy accumulator with a simple mixing function
    (var-set entropy-accumulator (xor 
                                   (var-get entropy-accumulator) 
                                   (xor 
                                     (+ burn-block-height (default-to u0 checked-seed))
                                     (bit-shift-left request-id u16))))
    
    ;; Store the request
    (map-set random-requests request-id 
      {
        requester: tx-sender,
        min: min,
        max: max,
        seed: checked-seed,
        request-burn-height: burn-block-height,
        fulfilled: false,
        result: none
      }
    )
    
    ;; Update last burn height seen
    (var-set last-burn-height burn-block-height)
    
    ;; Increment request counter
    (var-set request-count (+ request-id u1))
    
    ;; Return the request ID
    (ok request-id)
  )
)

;; Fulfill random number request
(define-public (fulfill-random-number (request-id uint))
  (let (
        (request (unwrap! (map-get? random-requests request-id) ERR-NO-SUCH-REQUEST))
       )
    
    ;; Ensure the request hasn't been fulfilled yet
    (asserts! (not (get fulfilled request)) ERR-UNAUTHORIZED)
    
    ;; Ensure at least one block has passed since the request
    (asserts! (> burn-block-height (get request-burn-height request)) ERR-SEED-UNAVAILABLE)
    
    ;; Generate random number
    (let ((random-value (generate-random 
                          (get min request) 
                          (get max request) 
                          request-id 
                          burn-block-height
                          (default-to u0 (get seed request)))))
      
      ;; Update the entropy accumulator using the random value
      (var-set entropy-accumulator (xor (var-get entropy-accumulator) random-value))
      
      ;; Update the request with the result
      (map-set random-requests request-id 
        (merge request 
          {
            fulfilled: true,
            result: (some random-value)
          }
        )
      )
      
      ;; Update last block seen
      (var-set last-burn-height burn-block-height)
      
      ;; Return the random value
      (ok random-value)
    )
  )
)

;; Read-only function to get request details
(define-read-only (get-request (request-id uint))
  (map-get? random-requests request-id)
)

;; Read-only function to get a random result
(define-read-only (get-random-result (request-id uint))
  (get result (default-to 
    { 
      requester: tx-sender, 
      min: u0, 
      max: u0, 
      seed: none, 
      request-burn-height: u0, 
      fulfilled: false, 
      result: none 
    } 
    (map-get? random-requests request-id)))
)

;; Private functions

;; Generate a random number within the specified range
(define-private (generate-random (min uint) (max uint) (request-id uint) (burn-height uint) (user-seed uint))
  (let (
        (range (- max min))
        (entropy-sources (+ (xor 
                             (xor burn-height user-seed)
                             (xor (var-get entropy-accumulator) request-id))
                           (xor 
                             (- burn-height (var-get last-burn-height))
                             (bit-shift-left user-seed u8))))
       )
    
    ;; Use a simple linear congruential generator algorithm
    (let (
          (a u1664525)  ;; multiplier
          (c u1013904223)  ;; increment
          (m u4294967296)  ;; modulus (2^32)
          (random-seed (mod (+ (* a entropy-sources) c) m))
         )
      
      ;; Map to the requested range
      (+ min (mod random-seed (+ u1 range)))
    )
  )
)

;; Administrative functions

;; Update fee amount
(define-public (set-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (> new-fee u0) ERR-INVALID-FEE)
    (var-set fee-amount new-fee)
    (ok true)
  )
)

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq new-owner tx-sender)) ERR-UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)