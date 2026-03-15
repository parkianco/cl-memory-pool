;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package #:cl-memory-pool)

(define-condition cl-memory-pool-error (error)
  ((message :initarg :message :reader cl-memory-pool-error-message))
  (:report (lambda (condition stream)
             (format stream "cl-memory-pool error: ~A" (cl-memory-pool-error-message condition)))))
