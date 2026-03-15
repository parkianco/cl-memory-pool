;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(load "cl-memory-pool.asd")
(handler-case
  (progn
    (asdf:test-system :cl-memory-pool/test)
    (format t "PASS~%"))
  (error (e)
    (format t "FAIL~%")))
(quit)
