;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

;;;; test/tests.lisp - Tests for cl-memory-pool

(in-package #:cl-memory-pool.test)

(defvar *test-failures* nil)
(defvar *test-count* 0)

(defmacro deftest (name &body body)
  `(progn
     (incf *test-count*)
     (handler-case
         (progn ,@body
                (format t "~&  [PASS] ~A~%" ',name))
       (error (e)
         (push (cons ',name e) *test-failures*)
         (format t "~&  [FAIL] ~A: ~A~%" ',name e)))))

(defmacro assert-equal (expected actual)
  `(unless (equal ,expected ,actual)
     (error "Expected ~S but got ~S" ,expected ,actual)))

(defmacro assert-true (form)
  `(unless ,form
     (error "Expected true but got ~S" ,form)))

(defmacro assert-nil (form)
  `(when ,form
     (error "Expected NIL but got ~S" ,form)))

(defun run-tests ()
  "Run all tests and return T on success, NIL on failure."
  (setf *test-failures* nil
        *test-count* 0)
  (format t "~&Running cl-memory-pool tests...~%")

  ;; Allocation tests
  (deftest allocate-memory-bytes
    (let ((buf (allocate-memory :bytes 64)))
      (assert-equal 64 (length buf))
      (assert-true (typep buf '(simple-array (unsigned-byte 8) (*))))))

  (deftest allocate-memory-uint32
    (let ((buf (allocate-memory :uint32 100)))
      (assert-equal 100 (length buf))
      (assert-true (typep buf '(simple-array (unsigned-byte 32) (*))))))

  (deftest allocate-temporary-cleanup
    (let ((freed nil))
      (allocate-temporary :bytes 32
        (setf freed nil))
      ;; Memory tracked in stats
      (assert-true (> (length (get-memory-stats)) 0))))

  ;; Pool tests
  (deftest pool-basic
    (let ((pool (create-memory-pool :bytes 64 :max-size 10)))
      (let ((buf (pool-acquire pool)))
        (assert-equal 64 (length buf))
        (pool-release pool buf))))

  (deftest pool-reuse
    (let ((pool (create-memory-pool :bytes 64 :max-size 10)))
      (let ((buf1 (pool-acquire pool)))
        (pool-release pool buf1)
        (let ((buf2 (pool-acquire pool)))
          ;; Should get the same buffer back
          (assert-true (eq buf1 buf2))
          (pool-release pool buf2)))))

  (deftest pool-stats-hit-rate
    (let ((pool (create-memory-pool :bytes 64 :max-size 10)))
      ;; Acquire and release multiple times
      (loop repeat 20
            do (pool-release pool (pool-acquire pool)))
      (let ((stats (pool-stats pool)))
        ;; Should have good hit rate
        (assert-true (> (getf stats :hit-rate) 0.5)))))

  (deftest pool-overflow
    (let ((pool (create-memory-pool :bytes 64 :max-size 2)))
      ;; Pre-fill pool
      (let ((bufs (loop repeat 5 collect (pool-acquire pool))))
        ;; Release all - only 2 should fit
        (dolist (buf bufs)
          (pool-release pool buf)))
      (let ((stats (pool-stats pool)))
        ;; Should have some discards
        (assert-true (>= (getf stats :total-discards) 3)))))

  (deftest pool-health
    (let ((pool (create-memory-pool :bytes 64 :max-size 10)))
      ;; New pool with pre-allocated buffers should be healthy
      (loop repeat 10 do (pool-release pool (pool-acquire pool)))
      (assert-equal :healthy (check-pool-health pool))))

  ;; Cache tests
  (deftest cache-basic
    (let ((cache (create-cache "test" :size 10)))
      (cache-put cache "key1" "value1")
      (assert-equal "value1" (cache-get cache "key1"))))

  (deftest cache-miss
    (let ((cache (create-cache "test" :size 10)))
      (assert-nil (cache-get cache "nonexistent"))))

  (deftest cache-remove
    (let ((cache (create-cache "test" :size 10)))
      (cache-put cache "key1" "value1")
      (assert-true (cache-remove cache "key1"))
      (assert-nil (cache-get cache "key1"))))

  (deftest cache-lru-eviction
    (let ((cache (create-cache "test" :size 3 :policy :lru)))
      (cache-put cache "a" 1)
      (cache-put cache "b" 2)
      (cache-put cache "c" 3)
      ;; Access "a" to make it recently used
      (cache-get cache "a")
      ;; Add "d" - should evict "b" (least recently used)
      (cache-put cache "d" 4)
      (assert-equal 1 (cache-get cache "a"))
      (assert-nil (cache-get cache "b"))
      (assert-equal 3 (cache-get cache "c"))
      (assert-equal 4 (cache-get cache "d"))))

  (deftest cache-stats
    (let ((cache (create-cache "test" :size 10)))
      (cache-put cache "a" 1)
      (cache-get cache "a")
      (cache-get cache "b")
      (let ((stats (cache-stats cache)))
        (assert-equal 1 (getf stats :hits))
        (assert-equal 1 (getf stats :misses))
        (assert-equal 0.5 (getf stats :hit-rate)))))

  (deftest cache-clear
    (let ((cache (create-cache "test" :size 10)))
      (cache-put cache "a" 1)
      (cache-put cache "b" 2)
      (cache-clear cache)
      (let ((stats (cache-stats cache)))
        (assert-equal 0 (getf stats :entries))
        (assert-equal 0 (getf stats :hits)))))

  ;; Registry tests
  (deftest registry-pool
    (let ((pool (create-memory-pool :bytes 32 :max-size 5 :name "test-pool")))
      (register-pool pool)
      (assert-true (eq pool (get-pool "test-pool")))
      (assert-true (member "test-pool" (list-pools) :test #'string=))))

  (deftest registry-cache
    (let ((cache (create-cache "test-cache" :size 10)))
      (register-cache cache)
      (assert-true (eq cache (get-cache "test-cache")))
      (assert-true (member "test-cache" (list-caches) :test #'string=))))

  ;; Print summary
  (format t "~&~%Tests completed: ~D passed, ~D failed~%"
          (- *test-count* (length *test-failures*))
          (length *test-failures*))
  (null *test-failures*))
