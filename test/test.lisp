;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(defpackage :cl-memory-pool.test
  (:use :cl :cl-memory-pool)
  (:export :run-tests))

(in-package :cl-memory-pool.test)

(defmacro check (condition format-string &rest args)
  `(unless ,condition
     (error ,format-string ,@args)))

(defun run-tests ()
  "Run the resource pool regression suite."
  (let* ((counter 0)
         (pool (create-pool
                :initial-size 1
                :max-size 2
                :factory (lambda ()
                           (incf counter)
                           (format nil "conn-~D" counter)))))
    (let ((first (acquire-connection pool)))
      (check (string= "conn-1" first) "Expected first pooled resource, got ~S" first)
      (let ((second (acquire-connection pool)))
        (check (string= "conn-2" second) "Expected second pooled resource, got ~S" second)
        (check (handler-case
                    (progn (acquire-connection pool) nil)
                  (error () t))
               "Expected pool exhaustion to signal")
        (release-connection pool first)
        (let ((reused (acquire-connection pool)))
          (check (string= "conn-1" reused) "Expected released resource to be reused"))
        (check (handler-case
                    (progn (release-connection pool "missing") nil)
                  (error () t))
               "Expected releasing foreign resource to signal"))))
  t)
