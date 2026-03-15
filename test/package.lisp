;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

;;;; test/package.lisp - Test package for cl-memory-pool

(defpackage #:cl-memory-pool.test
  (:use #:cl #:cl-memory-pool)
  (:export #:run-tests))
