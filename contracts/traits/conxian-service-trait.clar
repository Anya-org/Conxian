;; conxian-service-trait.clar
;; Standardized Trait for Conxian Business Services
;; Ensures plug-and-play integration with the Operations Engine

(define-trait conxian-service-trait
    (
        ;; @desc execute a service-specific operation
        ;; @param context: opaque buffer for service-specific arguments
        ;; @return ok/err
        (execute-service-op ((buff 2048)) (response bool uint))

        ;; @desc get the service status (active, paused, maintenance)
        ;; @return (string-ascii 20)
        (get-service-status () (response (string-ascii 20) uint))

        ;; @desc get service health metrics for Ops Engine monitoring
        ;; @return { uptime: uint, error-rate: uint, last-heartbeat: uint }
        (get-health-metrics () (response { uptime: uint, error-rate: uint, last-heartbeat: uint } uint))

        ;; @desc emergency pause trigger by Ops Engine
        ;; @return ok/err
        (set-service-paused (bool) (response bool uint))
    )
)
