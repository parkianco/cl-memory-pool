;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package #:cl-user)

(defpackage #:cl-memory-pool
  (:use #:cl)
  (:export
   #:memory-pool-context
   #:initialize-memory-pool
   #:memory-pool-execute
   #:memoize-function
   #:deep-copy-list
   #:group-by-count
   #:identity-list
   #:flatten
   #:map-keys
   #:now-timestamp
#:with-memory-pool-timing
   #:memory-pool-batch-process
   #:memory-pool-health-check#:cl-memory-pool-error
   #:cl-memory-pool-validation-error#:available-resource
   #:acquire-connection
   #:pooled-resource
   #:release-connection
   #:create-pool))
