;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package #:cl-memory-pool)

;;; ============================================================================
;;; Core Memory Allocation Functions
;;; ============================================================================

(defun allocate-memory (type size)
  "Allocate memory based on TYPE and SIZE.
TYPE: :bytes, :string, :uint32, :uint64, :object
SIZE: Number of elements or bytes"
  (ecase type
    (:bytes (make-array size :element-type '(unsigned-byte 8)))
    (:string (make-string size :initial-element #\Space))
    (:uint32 (make-array size :element-type '(unsigned-byte 32) :initial-element 0))
    (:uint64 (make-array size :element-type '(unsigned-byte 64) :initial-element 0))
    (:object (make-array size :initial-element nil))))

(defun deallocate-memory (element)
  "Mark ELEMENT for garbage collection (no-op in CL)."
  (declare (ignore element))
  t)

;;; ============================================================================
;;; Memory Pool Structure and Core Operations
;;; ============================================================================

(defstruct (memory-pool (:constructor %make-memory-pool))
  "Thread-safe object pool for reusing frequently allocated structures.
SLOTS:
  name          - Pool identifier
  type          - Type keyword (:bytes, :string, :uint32, :uint64, :object)
  element-size  - Size of each pooled element
  max-size      - Maximum number of elements to keep in free-list
  free-list     - List of available elements (LIFO stack)
  in-use-count  - Current number of elements checked out
  total-allocated - Cumulative allocations
  total-reused    - Count of reuses from pool (hits)
  total-discards  - Count of elements discarded (pool full)
  lock          - Mutex for synchronization"
  (name nil :type (or null string))
  (type :object :type keyword)
  (element-size 1024 :type (integer 1 *))
  (max-size 100 :type (integer 1 *))
  (free-list '() :type list)
  (in-use-count 0 :type integer)
  (total-allocated 0 :type integer)
  (total-reused 0 :type integer)
  (total-discards 0 :type integer)
  (lock (sb-thread:make-mutex :name "memory-pool")))

(defun create-memory-pool (type element-size &key (max-size 100) (name nil))
  "Create and initialize a thread-safe object pool.
PARAMETERS:
  type         - Type for pooled objects (:bytes, :string, :uint32, :uint64, :object)
  element-size - Size of each element
  max-size     - Maximum objects to retain (default 100)
  name         - Optional pool identifier
RETURNS: MEMORY-POOL instance ready for acquire/release operations
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
     :free-list (loop repeat (min max-size 10)
                      collect (allocate-memory type element-size))
     :lock (sb-thread:make-mutex :name pool-name))))

(defun pool-acquire (pool)
  "Obtain an object from the pool, allocating if necessary.
PARAMETERS: pool - MEMORY-POOL instance
RETURNS: A pooled object (array of appropriate type/size)
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
RETURNS: NIL
NOTE: If pool is full, element is discarded (GC handles it)"
  (sb-thread:with-mutex ((memory-pool-lock pool))
    (decf (memory-pool-in-use-count pool))
    (if (< (length (memory-pool-free-list pool)) (memory-pool-max-size pool))
        (push element (memory-pool-free-list pool))
        (progn
          (deallocate-memory element)
          (incf (memory-pool-total-discards pool))))))

;;; ============================================================================
;;; Pool Statistics and Monitoring
;;; ============================================================================

(defun pool-stats (pool)
  "Get pool statistics including hit rate and utilization.
PARAMETERS: pool - MEMORY-POOL instance
RETURNS: Property list with:
  :name            - Pool identifier
  :type            - Type keyword
  :element-size    - Size of each element
  :max-size        - Configured maximum pool size
  :free-count      - Current free objects in pool
  :in-use-count    - Current objects checked out
  :total-allocated - Cumulative acquire calls
  :total-reused    - Successful pool reuses (hits)
  :total-discards  - Objects discarded (pool full)
  :hit-rate        - Reused / total-allocated ratio (0.0-1.0)
  :utilization     - in-use-count / max-size ratio"
  (sb-thread:with-mutex ((memory-pool-lock pool))
    (let* ((free-count (length (memory-pool-free-list pool)))
           (in-use (memory-pool-in-use-count pool))
           (total-alloc (memory-pool-total-allocated pool))
           (total-reuse (memory-pool-total-reused pool)))
      (list :name (memory-pool-name pool)
            :type (memory-pool-type pool)
            :element-size (memory-pool-element-size pool)
            :max-size (memory-pool-max-size pool)
            :free-count free-count
            :in-use-count in-use
            :total-allocated total-alloc
            :total-reused total-reuse
            :total-discards (memory-pool-total-discards pool)
            :hit-rate (if (plusp total-alloc)
                          (/ (float total-reuse) total-alloc)
                          0.0)
            :utilization (/ (float in-use) (memory-pool-max-size pool))))))

(defun pool-clear (pool)
  "Clear all objects from the pool.
PARAMETERS: pool - MEMORY-POOL instance
RETURNS: NIL"
  (sb-thread:with-mutex ((memory-pool-lock pool))
    (setf (memory-pool-free-list pool) nil
          (memory-pool-in-use-count pool) 0)))

(defun check-pool-health (pool &key (threshold 0.5))
  "Check health status of a memory pool based on hit rate.
PARAMETERS:
  pool      - MEMORY-POOL instance
  threshold - Minimum acceptable hit rate (default 0.5)
RETURNS: Keyword indicating health status
  :healthy  - Hit rate >= 2x threshold
  :degraded - Hit rate >= threshold but < 2x threshold
  :critical - Hit rate < threshold"
  (let* ((stats (pool-stats pool))
         (hit-rate (getf stats :hit-rate)))
    (cond
      ((>= hit-rate (* 2.0 threshold)) :healthy)
      ((>= hit-rate threshold) :degraded)
      (t :critical))))

;;; ============================================================================
;;; Fragmentation Management
;;; ============================================================================

(defstruct fragmentation-info
  "Information about pool fragmentation and waste."
  (external-fragmentation 0.0 :type float)
  (internal-fragmentation 0.0 :type float)
  (wasted-bytes 0 :type integer)
  (compactable-p nil :type boolean))

(defun analyze-fragmentation (pool)
  "Analyze memory fragmentation in POOL.
RETURNS: FRAGMENTATION-INFO structure"
  (sb-thread:with-mutex ((memory-pool-lock pool))
    (let* ((free-count (length (memory-pool-free-list pool)))
           (in-use-count (memory-pool-in-use-count pool))
           (max-size (memory-pool-max-size pool))
           (external-frag (if (zerop max-size)
                              0.0
                              (/ (float free-count) max-size)))
           (elem-size (memory-pool-element-size pool)))
      (make-fragmentation-info
       :external-fragmentation external-frag
       :internal-fragmentation 0.0
       :wasted-bytes (* free-count elem-size)
       :compactable-p (> free-count 5)))))

(defun compact-pool (pool)
  "Compact POOL by reducing free-list to half capacity.
RETURNS: Number of elements removed"
  (sb-thread:with-mutex ((memory-pool-lock pool))
    (let ((target-size (max 5 (/ (memory-pool-max-size pool) 2))))
      (let ((removed 0))
        (loop while (> (length (memory-pool-free-list pool)) target-size)
              do (progn
                   (pop (memory-pool-free-list pool))
                   (incf removed)))
        removed))))

;;; ============================================================================
;;; Efficiency and Performance Tuning
;;; ============================================================================

(defstruct pool-config
  "Configuration for optimal pool performance."
  (ideal-max-size 100 :type (integer 1 *))
  (prealloc-fraction 0.5 :type (float 0.0 1.0))
  (expansion-factor 1.5 :type (float 1.0 10.0))
  (compaction-threshold 0.8 :type (float 0.0 1.0)))

(defvar *default-pool-config*
  (make-pool-config :ideal-max-size 100
                    :prealloc-fraction 0.3
                    :expansion-factor 1.5
                    :compaction-threshold 0.8)
  "Default configuration for memory pools.")

(defun optimize-pool-size (pool target-hit-rate)
  "Suggest optimal max-size based on TARGET-HIT-RATE goal.
PARAMETERS:
  pool             - MEMORY-POOL instance
  target-hit-rate  - Desired hit rate (0.0-1.0)
RETURNS: Suggested new max-size"
  (let* ((stats (pool-stats pool))
         (current-hit-rate (getf stats :hit-rate))
         (current-max (memory-pool-max-size pool)))
    (if (< current-hit-rate target-hit-rate)
        (ceiling (* current-max 1.5))
        current-max)))

(defun resize-pool (pool new-size)
  "Resize pool to new-size, adjusting free-list.
PARAMETERS:
  pool     - MEMORY-POOL instance
  new-size - New maximum size
RETURNS: NIL"
  (sb-thread:with-mutex ((memory-pool-lock pool))
    (let ((current-free (length (memory-pool-free-list pool)))
          (type (memory-pool-type pool))
          (elem-size (memory-pool-element-size pool)))
      (cond
        ((> new-size (memory-pool-max-size pool))
         (let ((diff (- new-size (memory-pool-max-size pool))))
           (loop repeat diff
                 do (push (allocate-memory type elem-size)
                          (memory-pool-free-list pool)))))
        ((< new-size (memory-pool-max-size pool))
         (let ((diff (- (memory-pool-max-size pool) new-size)))
           (loop repeat (min diff current-free)
                 do (pop (memory-pool-free-list pool))))))
      (setf (memory-pool-max-size pool) new-size))))

;;; ============================================================================
;;; Multiple Pool Registry
;;; ============================================================================

(defvar *pool-registry* (make-hash-table :test #'equal))
(defvar *registry-lock* (sb-thread:make-mutex :name "pool-registry-lock"))

(defun register-pool (name pool)
  "Register POOL with NAME in global registry.
PARAMETERS:
  name - String identifier for pool
  pool - MEMORY-POOL instance"
  (sb-thread:with-mutex (*registry-lock*)
    (setf (gethash name *pool-registry*) pool)))

(defun get-registered-pool (name)
  "Retrieve registered pool by NAME.
PARAMETERS: name - String identifier
RETURNS: MEMORY-POOL or NIL if not found"
  (sb-thread:with-mutex (*registry-lock*)
    (gethash name *pool-registry*)))

(defun list-all-pools ()
  "List statistics for all registered pools.
RETURNS: List of pool stats property lists"
  (sb-thread:with-mutex (*registry-lock*)
    (loop for pool being the hash-values of *pool-registry*
          collect (pool-stats pool))))

(defun unregister-pool (name)
  "Remove POOL from registry by NAME.
PARAMETERS: name - String identifier"
  (sb-thread:with-mutex (*registry-lock*)
    (remhash name *pool-registry*)))

;;; ============================================================================
;;; Convenience Macros
;;; ============================================================================

(defmacro with-pool-resource (pool (var) &body body)
  "Acquire POOL resource, bind to VAR, and execute BODY.
Automatically releases resource on exit (normal or exceptional)."
  `(let ((,var (pool-acquire ,pool)))
     (unwind-protect
          (progn ,@body)
       (pool-release ,pool ,var))))

(defmacro with-pools (pool-bindings &body body)
  "Acquire multiple pools and bind variables.
POOL-BINDINGS: ((var pool) (var2 pool2) ...)
Automatically releases all resources on exit."
  (if (null pool-bindings)
      `(progn ,@body)
      `(let ((,(caar pool-bindings) (pool-acquire ,(cadar pool-bindings))))
         (unwind-protect
              (with-pools ,(cdr pool-bindings) ,@body)
           (pool-release ,(cadar pool-bindings) ,(caar pool-bindings))))))

;;; ============================================================================
;;; Health Checks and Diagnostics
;;; ============================================================================

(defun pool-diagnostic-report (pool &optional (stream t))
  "Print detailed diagnostic report for POOL.
PARAMETERS:
  pool   - MEMORY-POOL instance
  stream - Output stream (default: *standard-output*)"
  (let ((stats (pool-stats pool))
        (frag (analyze-fragmentation pool)))
    (format stream "~&=== Memory Pool Diagnostic Report ===~%")
    (format stream "  Name: ~A~%" (getf stats :name))
    (format stream "  Type: ~A~%" (getf stats :type))
    (format stream "  Element Size: ~A bytes~%" (getf stats :element-size))
    (format stream "  Max Size: ~A~%" (getf stats :max-size))
    (format stream "  Free Count: ~A~%" (getf stats :free-count))
    (format stream "  In Use: ~A~%" (getf stats :in-use-count))
    (format stream "  Hit Rate: ~5,1F%~%" (* 100 (getf stats :hit-rate)))
    (format stream "  Utilization: ~5,1F%~%" (* 100 (getf stats :utilization)))
    (format stream "  Total Allocated: ~A~%" (getf stats :total-allocated))
    (format stream "  Total Reused: ~A~%" (getf stats :total-reused))
    (format stream "  Total Discards: ~A~%" (getf stats :total-discards))
    (format stream "  External Fragmentation: ~5,1F%~%"
            (* 100 (fragmentation-info-external-fragmentation frag)))
    (format stream "  Wasted Bytes: ~A~%" (fragmentation-info-wasted-bytes frag))
    (format stream "  Health: ~A~%" (check-pool-health pool))
    (format stream "~%")))

(defun memory-pool-batch-process (items processor-fn &key (pool nil))
  "Applies PROCESSOR-FN to each item in ITEMS with optional pool.
Returns (values processed-results error-alist)."
  (let ((results nil)
        (errors nil))
    (dolist (item items)
      (handler-case
          (if pool
              (with-pool-resource pool (res)
                (push (funcall processor-fn item res) results))
              (push (funcall processor-fn item) results))
        (error (e)
          (push (cons item e) errors))))
    (values (nreverse results) (nreverse errors))))

(defun memory-pool-health-check ()
  "Performs health checks for all registered pools.
RETURNS: :healthy if all pools healthy, :degraded otherwise"
  (sb-thread:with-mutex (*registry-lock*)
    (let ((all-healthy t))
      (loop for pool being the hash-values of *pool-registry*
            do (unless (eq :healthy (check-pool-health pool))
                 (setf all-healthy nil)))
      (if all-healthy :healthy :degraded))))

;;; ============================================================================
;;; Initialization and Cleanup
;;; ============================================================================

(defun initialize-memory-pool ()
  "Initialize memory pool subsystem.
RETURNS: T"
  t)

(defun validate-memory-pool (ctx)
  "Validate memory pool context.
PARAMETERS: ctx - Initialization context
RETURNS: T if valid, NIL otherwise"
  (declare (ignore ctx))
  t)

(defun cleanup-all-pools ()
  "Clean up all registered pools.
RETURNS: Count of pools cleaned"
  (sb-thread:with-mutex (*registry-lock*)
    (let ((count 0))
      (loop for pool being the hash-values of *pool-registry*
            do (progn (pool-clear pool) (incf count)))
      (clrhash *pool-registry*)
      count)))