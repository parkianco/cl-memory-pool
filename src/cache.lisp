;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0

;;;; cache.lisp - Thread-safe multi-policy cache

(in-package #:cl-memory-pool)

(defstruct (cache (:constructor %make-cache))
  "Thread-safe multi-policy cache for storing frequently accessed data.

  SLOTS:
    name              - Unique cache identifier
    max-entries       - Maximum entries before eviction
    entries           - Hash table mapping keys to values
    access-order      - List tracking access order for LRU/FIFO
    lock              - Mutex for synchronization
    hits              - Cumulative successful lookups
    misses            - Cumulative failed lookups
    eviction-policy   - :lru, :fifo, or :random"
  (name nil :type string)
  (max-entries 100 :type integer)
  (entries (make-hash-table :test 'equal))
  (access-order '() :type list)
  (lock (sb-thread:make-mutex :name "cache"))
  (hits 0 :type integer)
  (misses 0 :type integer)
  (eviction-policy :lru :type keyword))

(defun create-cache (name &key (size 100) (policy :lru))
  "Create a thread-safe cache.

  PARAMETERS:
    name   - Unique cache identifier
    size   - Maximum number of entries (default 100)
    policy - Eviction policy: :lru (default), :fifo, or :random

  RETURNS:
    CACHE instance ready for get/put operations

  EXAMPLE:
    (let ((cache (create-cache \"my-cache\" :size 1000 :policy :lru)))
      (cache-put cache \"key\" \"value\")
      (cache-get cache \"key\"))"
  (%make-cache
   :name name
   :max-entries size
   :entries (make-hash-table :test 'equal)
   :lock (sb-thread:make-mutex :name name)
   :eviction-policy policy))

(defun make-lru-cache (name size)
  "Create an LRU cache."
  (create-cache name :size size :policy :lru))

(defun make-fifo-cache (name size)
  "Create a FIFO cache."
  (create-cache name :size size :policy :fifo))

(defun cache-get (cache key)
  "Retrieve value from cache and update access tracking.

  PARAMETERS:
    cache - CACHE instance
    key   - Key to lookup

  RETURNS:
    Value associated with KEY, or NIL if not found"
  (sb-thread:with-mutex ((cache-lock cache))
    (let ((value (gethash key (cache-entries cache))))
      (if value
          (progn
            ;; Move to front (most recently used)
            (setf (cache-access-order cache)
                  (cons key (remove key (cache-access-order cache))))
            (incf (cache-hits cache))
            value)
          (progn
            (incf (cache-misses cache))
            nil)))))

(defun cache-put (cache key value)
  "Store value in cache, evicting if at capacity.

  PARAMETERS:
    cache - CACHE instance
    key   - Key to store
    value - Value to associate with key

  RETURNS:
    VALUE"
  (sb-thread:with-mutex ((cache-lock cache))
    (setf (gethash key (cache-entries cache)) value)
    (setf (cache-access-order cache)
          (cons key (remove key (cache-access-order cache))))
    (when (> (hash-table-count (cache-entries cache)) (cache-max-entries cache))
      (evict-cache-entry cache (cache-eviction-policy cache))))
  value)

(defun cache-remove (cache key)
  "Remove an entry from the cache.

  PARAMETERS:
    cache - CACHE instance
    key   - Key to remove

  RETURNS:
    T if removed, NIL if not found"
  (sb-thread:with-mutex ((cache-lock cache))
    (when (gethash key (cache-entries cache))
      (remhash key (cache-entries cache))
      (setf (cache-access-order cache)
            (remove key (cache-access-order cache)))
      t)))

(defun evict-cache-entry (cache policy)
  "Internal function to remove an entry based on eviction policy."
  (case policy
    (:lru
     (let ((oldest-key (car (last (cache-access-order cache)))))
       (when oldest-key
         (remhash oldest-key (cache-entries cache))
         (setf (cache-access-order cache)
               (remove oldest-key (cache-access-order cache))))))
    (:fifo
     (let ((oldest-key (car (cache-access-order cache))))
       (when oldest-key
         (remhash oldest-key (cache-entries cache))
         (setf (cache-access-order cache)
               (cdr (cache-access-order cache))))))
    (:random
     (let ((keys (loop for k being the hash-keys of (cache-entries cache)
                       collect k)))
       (when keys
         (let ((random-key (elt keys (random (length keys)))))
           (remhash random-key (cache-entries cache))
           (setf (cache-access-order cache)
                 (remove random-key (cache-access-order cache)))))))))

(defun cache-clear (cache)
  "Remove all entries from cache and reset statistics.

  PARAMETERS:
    cache - CACHE instance

  RETURNS:
    NIL"
  (sb-thread:with-mutex ((cache-lock cache))
    (clrhash (cache-entries cache))
    (setf (cache-access-order cache) '())
    (setf (cache-hits cache) 0)
    (setf (cache-misses cache) 0)))

(defun cache-stats (cache)
  "Get comprehensive cache performance statistics.

  PARAMETERS:
    cache - CACHE instance

  RETURNS:
    Property list with:
      :name          - Cache identifier
      :entries       - Current number of entries
      :max-entries   - Maximum capacity
      :hits          - Total successful lookups
      :misses        - Total failed lookups
      :hit-rate      - Ratio of hits / total requests (0.0-1.0)
      :policy        - Eviction policy"
  (sb-thread:with-mutex ((cache-lock cache))
    (let ((total-requests (+ (cache-hits cache) (cache-misses cache))))
      (list :name (cache-name cache)
            :entries (hash-table-count (cache-entries cache))
            :max-entries (cache-max-entries cache)
            :hits (cache-hits cache)
            :misses (cache-misses cache)
            :hit-rate (if (plusp total-requests)
                          (/ (float (cache-hits cache)) total-requests)
                          0.0)
            :policy (cache-eviction-policy cache)))))

(defun check-cache-health (cache &key (threshold 0.5))
  "Check health status of a cache based on hit rate.

  PARAMETERS:
    cache     - CACHE instance
    threshold - Minimum acceptable hit rate (default 0.5)

  RETURNS:
    Keyword indicating health status:
      :healthy  - Hit rate >= 2x threshold
      :degraded - Hit rate >= threshold but < 2x
      :critical - Hit rate < threshold"
  (let* ((stats (cache-stats cache))
         (hit-rate (getf stats :hit-rate)))
    (cond
      ((>= hit-rate (* 2.0 threshold)) :healthy)
      ((>= hit-rate threshold) :degraded)
      (t :critical))))
