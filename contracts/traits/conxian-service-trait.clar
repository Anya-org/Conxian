;; conxian-service-trait.clar
(define-trait conxian-service-trait (
  (get-service-status () (response (string-ascii 32) uint))
  (get-health-metrics () (response { uptime: uint  error-rate: uint  last-heartbeat: uint } uint))
  (set-service-paused (bool) (response bool uint))
  (execute-service-op ((buff 2048)) (response bool uint))
))
