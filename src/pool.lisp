;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0

;;;; pool.lisp - Thread-safe object pooling

(in-package #:cl-memory-pool)

(defstruct (memory-pool (:constructor %make-memory-pool))
  "Thread-safe object pool for reusing frequently allocated structures.

  SLOTS:
    name             - Pool identifier
    type             - Type keyword (:bytes, :string, :uint32, :uint64, T)
    element-size     - Size of each pooled element
    max-size         - Maximum number of elements to keep in free-list
    free-list        - List of available elements (LIFO stack)
    in-use-count     - Current number of elements checked out
    total-allocated  - Cumulative allocations
    total-reused     - Count of reuses from pool (hits)
    total-discards   - Count of elements discarded (pool full)
    lock             - Mutex for synchronization"
  (name nil :type (or null string))
  (type nil :type keyword)
  (element-size 0 :type integer)
  (max-size 100 :type integer)
  (free-list '() :type list)
  (in-use-count 0 :type integer)
  (total-allocated 0 :type integer)
  (total-reused 0 :type integer)
  (total-discards 0 :type integer)
  (lock (sb-thread:make-mutex :name "memory-pool")))

(defun create-memory-pool (type element-size &key (max-size 100) name)
  "Create and initialize a thread-safe object pool.

  PARAMETERS:
    type         - Type for pooled objects (:bytes, :string, :uint32, :uint64, T)
    element-size - Size of each element
    max-size     - Maximum objects to retain (default 100)
    name         - Optional pool identifier

  RETURNS:
    MEMORY-POOL instance ready for acquire/release operations

  EXAMPLE:
    (let ((pool (create-memory-pool :bytes 256 :max-size 50)))
      (let ((buf (pool-acquire pool)))
        (process-buffer buf)
        (pool-release pool buf)))"
  (let ((pool-name (or name (format nil "pool-~A-~A" type element-size))))
    (%make-memory-pool
     :name pool-name
     :type type
     :element-size element-size
     :max-size max-size
     :free-list (loop repeat max-size
                      collect (allocate-memory type element-size))
     :lock (sb-thread:make-mutex :name pool-name))))

(defun pool-acquire (pool)
  "Obtain an object from the pool, allocating if necessary.

  PARAMETERS:
    pool - MEMORY-POOL instance

  RETURNS:
    A pooled object (array of appropriate type/size)

  BEHAVIOR:
    If free-list non-empty: pop and return (HIT)
    If free-list empty: allocate new object (MISS)"
  (sb-thread:with-mutex ((memory-pool-lock pool))
    (incf (memory-pool-total-allocated pool))
    (if (memory-pool-free-list pool)
        (progn
          (incf (memory-pool-in-use-count pool))
          (incf (memory-pool-total-reused pool))
          (pop (memory-pool-free-list pool)))
        (progn
          (incf (memory-pool-in-use-count pool))
          (allocate-memory (memory-pool-type pool)
                           (memory-pool-element-size pool))))))

(defun pool-release (pool element)
  "Return an object to the pool for reuse.

  PARAMETERS:
    pool    - MEMORY-POOL instance
    element - Object to return

  RETURNS:
    NIL

  NOTE:
    If pool is full, element is discarded (GC handles it)"
  (sb-thread:with-mutex ((memory-pool-lock pool))
    (decf (memory-pool-in-use-count pool))
    (if (< (length (memory-pool-free-list pool)) (memory-pool-max-size pool))
        (push element (memory-pool-free-list pool))
        (incf (memory-pool-total-discards pool)))))

(defun pool-stats (pool)
  "Get pool statistics including hit rate and utilization.

  PARAMETERS:
    pool - MEMORY-POOL instance

  RETURNS:
    Property list with:
      :name            - Pool identifier
      :type            - Type keyword
      :element-size    - Size of each element
      :max-size        - Configured maximum pool size
      :free-count      - Current free objects in pool
      :in-use-count    - Current objects checked out
      :total-allocated - Cumulative acquire calls
      :total-reused    - Successful pool reuses (hits)
      :total-discards  - Objects discarded (pool full)
      :hit-rate        - Reused / total-allocated ratio (0.0-1.0)"
  (sb-thread:with-mutex ((memory-pool-lock pool))
    (list :name (memory-pool-name pool)
          :type (memory-pool-type pool)
          :element-size (memory-pool-element-size pool)
          :max-size (memory-pool-max-size pool)
          :free-count (length (memory-pool-free-list pool))
          :in-use-count (memory-pool-in-use-count pool)
          :total-allocated (memory-pool-total-allocated pool)
          :total-reused (memory-pool-total-reused pool)
          :total-discards (memory-pool-total-discards pool)
          :hit-rate (if (plusp (memory-pool-total-allocated pool))
                        (/ (float (memory-pool-total-reused pool))
                           (memory-pool-total-allocated pool))
                        0.0))))

(defun pool-clear (pool)
  "Clear all objects from the pool.

  PARAMETERS:
    pool - MEMORY-POOL instance

  RETURNS:
    NIL"
  (sb-thread:with-mutex ((memory-pool-lock pool))
    (setf (memory-pool-free-list pool) nil
          (memory-pool-in-use-count pool) 0)))

(defun check-pool-health (pool &key (threshold 0.5))
  "Check health status of a memory pool based on hit rate.

  PARAMETERS:
    pool      - MEMORY-POOL instance
    threshold - Minimum acceptable hit rate (default 0.5)

  RETURNS:
    Keyword indicating health status:
      :healthy  - Hit rate >= 2x threshold
      :degraded - Hit rate >= threshold but < 2x
      :critical - Hit rate < threshold"
  (let* ((stats (pool-stats pool))
         (hit-rate (getf stats :hit-rate)))
    (cond
      ((>= hit-rate (* 2.0 threshold)) :healthy)
      ((>= hit-rate threshold) :degraded)
      (t :critical))))
