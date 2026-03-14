;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: BSD-3-Clause

;;;; test/package.lisp - Test package for cl-memory-pool

(defpackage #:cl-memory-pool.test
  (:use #:cl #:cl-memory-pool)
  (:export #:run-tests))
