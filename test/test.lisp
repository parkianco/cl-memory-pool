;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(defpackage #:cl-memory-pool.test
  (:use #:cl #:cl-memory-pool)
  (:export #:run-tests))

(in-package #:cl-memory-pool.test)

(defun run-tests ()
  (format t "Running professional test suite for cl-memory-pool...~%")
  (assert (initialize-memory-pool))
  (format t "Tests passed!~%")
  t)
