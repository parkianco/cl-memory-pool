;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0

;;;; package.lisp - Package definition for cl-memory-pool

(defpackage #:cl-memory-pool
  (:use #:cl)
  (:export
   ;; Memory Allocation
   #:allocate-memory
   #:free-memory
   #:allocate-temporary
   #:get-memory-stats
   #:reset-memory-stats

   ;; Memory Pool
   #:memory-pool
   #:create-memory-pool
   #:pool-acquire
   #:pool-release
   #:pool-stats
   #:pool-clear
   #:check-pool-health

   ;; Cache
   #:cache
   #:create-cache
   #:cache-get
   #:cache-put
   #:cache-remove
   #:cache-clear
   #:cache-stats
   #:check-cache-health

   ;; Cache Factories
   #:make-lru-cache
   #:make-fifo-cache

   ;; Registry
   #:register-pool
   #:get-pool
   #:list-pools
   #:register-cache
   #:get-cache
   #:list-caches
   #:get-all-pool-stats
   #:get-all-cache-stats
   #:clear-all-caches))
