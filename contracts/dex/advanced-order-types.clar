;; advanced-order-types.clar
;; Conxian Standard: Advanced Order Types for Institutional DeFi
;; Implements Iceberg, Limit, Stop, and TWAP orders with Bitcoin anchoring

;; Traits
(use-trait ft-trait .sip-standards.sip-010-ft-trait)
(use-trait rbac-trait .core-traits.rbac-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_ORDER (err u1001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))
(define-constant ERR_ORDER_EXPIRED (err u1003))
(define-constant ERR_ORDER_FILLED (err u1004))
(define-constant ERR_INVALID_AMOUNT (err u1005))
(define-constant ERR_INVALID_PRICE (err u1006))

;; Order Types
(define-constant ORDER_TYPE_LIMIT u1)
(define-constant ORDER_TYPE_STOP u2)
(define-constant ORDER_TYPE_ICEBERG u3)
(define-constant ORDER_TYPE_TAKE_PROFIT u4)
(define-constant ORDER_TYPE_STOP_LIMIT u5)
(define-constant ORDER_TYPE_Twap u6)

;; Order Sides
(define-constant SIDE_BUY u1)
(define-constant SIDE_SELL u2)

;; Order Status
(define-constant STATUS_PENDING u1)
(define-constant STATUS_PARTIAL u2)
(define-constant STATUS_FILLED u3)
(define-constant STATUS_CANCELLED u4)
(define-constant STATUS_EXPIRED u5)

;; State - Order Registry
(define-map orders
    uint ;; order-id
    {
        owner: principal,
        order-type: uint,
        side: uint,
        token-in: principal,
        token-out: principal,
        amount-total: uint,
        amount-filled: uint,
        price-limit: uint,
        stop-price: uint,
        status: uint,
        created-at: uint,
        expires-at: uint,
        iceberg-visible: uint,
        iceberg-hidden: uint,
        twap-slices: uint,
        twap-interval: uint,
        next-twap: uint,
    }
)

;; State - Order History
(define-map order-history
    uint ;; order-id
    {
        filled-amount: uint,
        filled-price: uint,
        filled-at: uint,
        tx-hash: (buff 32),
    }
)

;; State - Global Counters
(define-data-var next-order-id uint u1)
(define-data-var total-orders uint u0)
(define-data-var active-orders uint u0)

;; State - Bitcoin Anchoring
(define-data-var last-anchor-height uint u0)
(define-data-var tenure-id uint u0)

;; @desc Initialize advanced order types system
(define-public (initialize)
    (begin
        (asserts! (is-eq tx-sender .protocol-owner) ERR_UNAUTHORIZED)
        
        (var-set last-anchor-height burn-block-height)
        (var-set tenure-id (contract-call? .block-utils get-current-tenure-id))
        
        (print {
            event: "advanced-orders-initialized",
            timestamp: block-height,
            tenure-id: (var-get tenure-id),
            anchor-height: (var-get last-anchor-height),
        })
        (ok true)
    )
)

;; @desc Create a limit order
(define-public (create-limit-order
        (token-in principal)
        (token-out principal)
        (side uint)
        (amount uint)
        (price-limit uint)
        (expires-at uint)
    )
    (let (
        (order-id (+ (var-get next-order-id) u1))
        (current-tenure-id (contract-call? .block-utils get-current-tenure-id))
    )
        (asserts! (not (contract-call? .conxian-protocol is-paused)) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (> price-limit u0) ERR_INVALID_PRICE)
        (asserts! (or (is-eq side SIDE_BUY) (is-eq side SIDE_SELL)) ERR_INVALID_ORDER)
        
        ;; Check user balance for sell orders
        (if (is-eq side SIDE_SELL)
            (asserts! (>= (contract-call? token-in get-balance tx-sender) amount) ERR_INSUFFICIENT_BALANCE)
            true
        )
        
        ;; Create order
        (map-set orders order-id {
            owner: tx-sender,
            order-type: ORDER_TYPE_LIMIT,
            side: side,
            token-in: token-in,
            token-out: token-out,
            amount-total: amount,
            amount-filled: u0,
            price-limit: price-limit,
            stop-price: u0,
            status: STATUS_PENDING,
            created-at: block-height,
            expires-at: expires-at,
            iceberg-visible: u0,
            iceberg-hidden: u0,
            twap-slices: u0,
            twap-interval: u0,
            next-twap: u0,
        })
        
        ;; Escrow tokens for sell orders
        (if (is-eq side SIDE_SELL)
            (contract-call? token-in transfer-from amount tx-sender as-contract tx-sender)
            true
        )
        
        (var-set next-order-id order-id)
        (var-set total-orders (+ (var-get total-orders) u1))
        (var-set active-orders (+ (var-get active-orders) u1))
        (var-set tenure-id current-tenure-id)
        
        (print {
            event: "limit-order-created",
            order-id: order-id,
            owner: tx-sender,
            token-in: token-in,
            token-out: token-out,
            side: side,
            amount: amount,
            price-limit: price-limit,
            expires-at: expires-at,
            tenure-id: current-tenure-id,
        })
        (ok order-id)
    )
)

;; @desc Create a stop order
(define-public (create-stop-order
        (token-in principal)
        (token-out principal)
        (side uint)
        (amount uint)
        (stop-price uint)
        (expires-at uint)
    )
    (let (
        (order-id (+ (var-get next-order-id) u1))
        (current-tenure-id (contract-call? .block-utils get-current-tenure-id))
    )
        (asserts! (not (contract-call? .conxian-protocol is-paused)) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (> stop-price u0) ERR_INVALID_PRICE)
        (asserts! (or (is-eq side SIDE_BUY) (is-eq side SIDE_SELL)) ERR_INVALID_ORDER)
        
        ;; Check user balance for sell orders
        (if (is-eq side SIDE_SELL)
            (asserts! (>= (contract-call? token-in get-balance tx-sender) amount) ERR_INSUFFICIENT_BALANCE)
            true
        )
        
        ;; Create order
        (map-set orders order-id {
            owner: tx-sender,
            order-type: ORDER_TYPE_STOP,
            side: side,
            token-in: token-in,
            token-out: token-out,
            amount-total: amount,
            amount-filled: u0,
            price-limit: u0,
            stop-price: stop-price,
            status: STATUS_PENDING,
            created-at: block-height,
            expires-at: expires-at,
            iceberg-visible: u0,
            iceberg-hidden: u0,
            twap-slices: u0,
            twap-interval: u0,
            next-twap: u0,
        })
        
        ;; Escrow tokens for sell orders
        (if (is-eq side SIDE_SELL)
            (contract-call? token-in transfer-from amount tx-sender as-contract tx-sender)
            true
        )
        
        (var-set next-order-id order-id)
        (var-set total-orders (+ (var-get total-orders) u1))
        (var-set active-orders (+ (var-get active-orders) u1))
        (var-set tenure-id current-tenure-id)
        
        (print {
            event: "stop-order-created",
            order-id: order-id,
            owner: tx-sender,
            token-in: token-in,
            token-out: token-out,
            side: side,
            amount: amount,
            stop-price: stop-price,
            expires-at: expires-at,
            tenure-id: current-tenure-id,
        })
        (ok order-id)
    )
)

;; @desc Create an iceberg order
(define-public (create-iceberg-order
        (token-in principal)
        (token-out principal)
        (side uint)
        (amount-total uint)
        (visible-amount uint)
        (price-limit uint)
        (expires-at uint)
    )
    (let (
        (order-id (+ (var-get next-order-id) u1))
        (current-tenure-id (contract-call? .block-utils get-current-tenure-id))
    )
        (asserts! (not (contract-call? .conxian-protocol is-paused)) ERR_UNAUTHORIZED)
        (asserts! (> amount-total u0) ERR_INVALID_AMOUNT)
        (asserts! (> visible-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (>= amount-total visible-amount) ERR_INVALID_AMOUNT)
        (asserts! (> price-limit u0) ERR_INVALID_PRICE)
        (asserts! (or (is-eq side SIDE_BUY) (is-eq side SIDE_SELL)) ERR_INVALID_ORDER)
        
        ;; Check user balance for sell orders
        (if (is-eq side SIDE_SELL)
            (asserts! (>= (contract-call? token-in get-balance tx-sender) amount-total) ERR_INSUFFICIENT_BALANCE)
            true
        )
        
        ;; Create order
        (map-set orders order-id {
            owner: tx-sender,
            order-type: ORDER_TYPE_ICEBERG,
            side: side,
            token-in: token-in,
            token-out: token-out,
            amount-total: amount-total,
            amount-filled: u0,
            price-limit: price-limit,
            stop-price: u0,
            status: STATUS_PENDING,
            created-at: block-height,
            expires-at: expires-at,
            iceberg-visible: visible-amount,
            iceberg-hidden: (- amount-total visible-amount),
            twap-slices: u0,
            twap-interval: u0,
            next-twap: u0,
        })
        
        ;; Escrow tokens for sell orders
        (if (is-eq side SIDE_SELL)
            (contract-call? token-in transfer-from amount-total tx-sender as-contract tx-sender)
            true
        )
        
        (var-set next-order-id order-id)
        (var-set total-orders (+ (var-get total-orders) u1))
        (var-set active-orders (+ (var-get active-orders) u1))
        (var-set tenure-id current-tenure-id)
        
        (print {
            event: "iceberg-order-created",
            order-id: order-id,
            owner: tx-sender,
            token-in: token-in,
            token-out: token-out,
            side: side,
            amount-total: amount-total,
            visible-amount: visible-amount,
            price-limit: price-limit,
            expires-at: expires-at,
            tenure-id: current-tenure-id,
        })
        (ok order-id)
    )
)

;; @desc Create a TWAP (Time-Weighted Average Price) order
(define-public (create-twap-order
        (token-in principal)
        (token-out principal)
        (side uint)
        (amount uint)
        (slices uint)
        (interval uint)
        (price-limit uint)
        (expires-at uint)
    )
    (let (
        (order-id (+ (var-get next-order-id) u1))
        (current-tenure-id (contract-call? .block-utils get-current-tenure-id))
    )
        (asserts! (not (contract-call? .conxian-protocol is-paused)) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (> slices u0) ERR_INVALID_AMOUNT)
        (asserts! (> interval u0) ERR_INVALID_AMOUNT)
        (asserts! (> price-limit u0) ERR_INVALID_PRICE)
        (asserts! (or (is-eq side SIDE_BUY) (is-eq side SIDE_SELL)) ERR_INVALID_ORDER)
        
        ;; Check user balance for sell orders
        (if (is-eq side SIDE_SELL)
            (asserts! (>= (contract-call? token-in get-balance tx-sender) amount) ERR_INSUFFICIENT_BALANCE)
            true
        )
        
        ;; Create order
        (map-set orders order-id {
            owner: tx-sender,
            order-type: ORDER_TYPE_Twap,
            side: side,
            token-in: token-in,
            token-out: token-out,
            amount-total: amount,
            amount-filled: u0,
            price-limit: price-limit,
            stop-price: u0,
            status: STATUS_PENDING,
            created-at: block-height,
            expires-at: expires-at,
            iceberg-visible: u0,
            iceberg-hidden: u0,
            twap-slices: slices,
            twap-interval: interval,
            next-twap: block-height,
        })
        
        ;; Escrow tokens for sell orders
        (if (is-eq side SIDE_SELL)
            (contract-call? token-in transfer-from amount tx-sender as-contract tx-sender)
            true
        )
        
        (var-set next-order-id order-id)
        (var-set total-orders (+ (var-get total-orders) u1))
        (var-set active-orders (+ (var-get active-orders) u1))
        (var-set tenure-id current-tenure-id)
        
        (print {
            event: "twap-order-created",
            order-id: order-id,
            owner: tx-sender,
            token-in: token-in,
            token-out: token-out,
            side: side,
            amount: amount,
            slices: slices,
            interval: interval,
            price-limit: price-limit,
            expires-at: expires-at,
            tenure-id: current-tenure-id,
        })
        (ok order-id)
    )
)

;; @desc Cancel an order
(define-public (cancel-order (order-id uint))
    (let (
        (order (map-get? orders order-id))
        (current-tenure-id (contract-call? .block-utils get-current-tenure-id))
    )
        (asserts! (not (contract-call? .conxian-protocol is-paused)) ERR_UNAUTHORIZED)
        
        (match order-info order
            (begin
                (asserts! (is-eq (get owner order-info) tx-sender) ERR_UNAUTHORIZED)
                (asserts! (or (is-eq (get status order-info) STATUS_PENDING) 
                             (is-eq (get status order-info) STATUS_PARTIAL)) ERR_ORDER_FILLED)
                
                ;; Return escrowed tokens for sell orders
                (if (is-eq (get side order-info) SIDE_SELL)
                    (let (
                        (remaining-amount (- (get amount-total order-info) (get amount-filled order-info)))
                    )
                        (contract-call? (get token-in order-info) transfer 
                            remaining-amount as-contract tx-sender)
                    )
                    true
                )
                
                ;; Update order status
                (map-set orders order-id {
                    owner: (get owner order-info),
                    order-type: (get order-type order-info),
                    side: (get side order-info),
                    token-in: (get token-in order-info),
                    token-out: (get token-out order-info),
                    amount-total: (get amount-total order-info),
                    amount-filled: (get amount-filled order-info),
                    price-limit: (get price-limit order-info),
                    stop-price: (get stop-price order-info),
                    status: STATUS_CANCELLED,
                    created-at: (get created-at order-info),
                    expires-at: (get expires-at order-info),
                    iceberg-visible: (get iceberg-visible order-info),
                    iceberg-hidden: (get iceberg-hidden order-info),
                    twap-slices: (get twap-slices order-info),
                    twap-interval: (get twap-interval order-info),
                    next-twap: (get next-twap order-info),
                })
                
                (var-set active-orders (- (var-get active-orders) u1))
                (var-set tenure-id current-tenure-id)
                
                (print {
                    event: "order-cancelled",
                    order-id: order-id,
                    owner: tx-sender,
                    tenure-id: current-tenure-id,
                })
                (ok true)
            )
            (err ERR_INVALID_ORDER)
        )
    )
)

;; @desc Execute order matching (called by DEX)
(define-public (execute-order
        (order-id uint)
        (amount-to-fill uint)
        (execution-price uint)
    )
    (let (
        (order (map-get? orders order-id))
        (current-tenure-id (contract-call? .block-utils get-current-tenure-id))
    )
        (asserts! (is-eq tx-sender .dex-facade) ERR_UNAUTHORIZED)
        
        (match order-info order
            (begin
                (asserts! (or (is-eq (get status order-info) STATUS_PENDING) 
                             (is-eq (get status order-info) STATUS_PARTIAL)) ERR_ORDER_FILLED)
                (asserts! (<= block-height (get expires-at order-info)) ERR_ORDER_EXPIRED)
                
                ;; Validate price constraints
                (if (is-eq (get order-type order-info) ORDER_TYPE_LIMIT)
                    (if (is-eq (get side order-info) SIDE_BUY)
                        (asserts! (<= execution-price (get price-limit order-info)) ERR_INVALID_PRICE)
                        (asserts! (>= execution-price (get price-limit order-info)) ERR_INVALID_PRICE)
                    )
                    true
                )
                
                ;; Validate stop price if applicable
                (if (is-eq (get order-type order-info) ORDER_TYPE_STOP)
                    (if (is-eq (get side order-info) SIDE_BUY)
                        (asserts! (>= execution-price (get stop-price order-info)) ERR_INVALID_PRICE)
                        (asserts! (<= execution-price (get stop-price order-info)) ERR_INVALID_PRICE)
                    )
                    true
                )
                
                ;; Calculate fillable amount
                (let (
                    (remaining-amount (- (get amount-total order-info) (get amount-filled order-info)))
                    (actual-fill (min amount-to-fill remaining-amount))
                    (new-filled (+ (get amount-filled order-info) actual-fill))
                )
                    ;; Update order
                    (map-set orders order-id {
                        owner: (get owner order-info),
                        order-type: (get order-type order-info),
                        side: (get side order-info),
                        token-in: (get token-in order-info),
                        token-out: (get token-out order-info),
                        amount-total: (get amount-total order-info),
                        amount-filled: new-filled,
                        price-limit: (get price-limit order-info),
                        stop-price: (get stop-price order-info),
                        status: (if (>= new-filled (get amount-total order-info)) STATUS_FILLED STATUS_PARTIAL),
                        created-at: (get created-at order-info),
                        expires-at: (get expires-at order-info),
                        iceberg-visible: (get iceberg-visible order-info),
                        iceberg-hidden: (get iceberg-hidden order-info),
                        twap-slices: (get twap-slices order-info),
                        twap-interval: (get twap-interval order-info),
                        next-twap: (get next-twap order-info),
                    })
                    
                    ;; Record in history
                    (map-set order-history order-id {
                        filled-amount: actual-fill,
                        filled-price: execution-price,
                        filled-at: block-height,
                        tx-hash: tx-id,
                    })
                    
                    ;; Update active orders count if fully filled
                    (if (>= new-filled (get amount-total order-info))
                        (var-set active-orders (- (var-get active-orders) u1))
                        true
                    )
                    
                    (var-set tenure-id current-tenure-id)
                    
                    (print {
                        event: "order-executed",
                        order-id: order-id,
                        filled-amount: actual-fill,
                        execution-price: execution-price,
                        total-filled: new-filled,
                        status: (if (>= new-filled (get amount-total order-info)) STATUS_FILLED STATUS_PARTIAL),
                        tenure-id: current-tenure-id,
                    })
                    (ok actual-fill)
                )
            )
            (err ERR_INVALID_ORDER)
        )
    )
)

;; @desc Get order information
(define-read-only (get-order-info (order-id uint))
    (map-get? orders order-id)
)

;; @desc Get order history
(define-read-only (get-order-history (order-id uint))
    (map-get? order-history order-id)
)

;; @desc Get user's active orders
(define-read-only (get-user-orders (user principal))
    (let (
        (user-orders (list))
    )
        ;; This would iterate through all orders and filter by user
        ;; Simplified for this example
        (ok user-orders)
    )
)

;; @desc Get market depth for a token pair
(define-read-only (get-market-depth
        (token-in principal)
        (token-out principal)
        (side uint)
    )
    (let (
        (buy-orders (list))
        (sell-orders (list))
    )
        ;; This would aggregate all limit orders for the pair
        ;; Simplified for this example
        (if (is-eq side SIDE_BUY)
            (ok buy-orders)
            (ok sell-orders)
        )
    )
)

;; @desc Check if order can be executed
(define-read-only (can-execute-order
        (order-id uint)
        (current-price uint)
    )
    (let (
        (order (map-get? orders order-id))
    )
        (match order-info order
            (begin
                (if (is-eq (get status order-info) STATUS_PENDING)
                    (begin
                        (if (is-eq (get order-type order-info) ORDER_TYPE_LIMIT)
                            (if (is-eq (get side order-info) SIDE_BUY)
                                (ok (<= current-price (get price-limit order-info)))
                                (ok (>= current-price (get price-limit order-info)))
                            )
                            (if (is-eq (get order-type order-info) ORDER_TYPE_STOP)
                                (if (is-eq (get side order-info) SIDE_BUY)
                                    (ok (>= current-price (get stop-price order-info)))
                                    (ok (<= current-price (get stop-price order-info)))
                                )
                                (ok true) ;; Other order types
                            )
                        )
                    )
                    (ok false) ;; Order not pending
                )
            )
            (ok false) ;; Order not found
        )
    )
)

;; @desc Get system statistics
(define-read-only (get-stats)
    (ok {
        total-orders: (var-get total-orders),
        active-orders: (var-get active-orders),
        next-order-id: (var-get next-order-id),
        last-anchor-height: (var-get last-anchor-height),
        tenure-id: (var-get tenure-id),
    })
)

;; @desc Clean up expired orders
(define-public (cleanup-expired-orders)
    (let (
        (current-tenure-id (contract-call? .block-utils get-current-tenure-id))
        (cleaned-count u0)
    )
        (asserts! (is-eq tx-sender .protocol-owner) ERR_UNAUTHORIZED)
        
        ;; This would iterate through all orders and clean up expired ones
        ;; Simplified for this example
        
        (var-set tenure-id current-tenure-id)
        
        (print {
            event: "expired-orders-cleaned",
            cleaned-count: cleaned-count,
            tenure-id: current-tenure-id,
        })
        (ok cleaned-count)
    )
)
