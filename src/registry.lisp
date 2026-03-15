;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0

;;;; registry.lisp - Global pool and cache registry

(in-package #:cl-memory-pool)

(defvar *pool-registry* (make-hash-table :test 'equal)
  "Global registry of memory pools.")

(defvar *cache-registry* (make-hash-table :test 'equal)
  "Global registry of caches.")

(defvar *registry-lock* (sb-thread:make-mutex :name "registry-lock")
  "Lock for registry operations.")

;;; Pool Registry

(defun register-pool (pool)
  "Register a memory pool in the global registry.

  PARAMETERS:
    pool - MEMORY-POOL instance

  RETURNS:
    POOL"
  (sb-thread:with-mutex (*registry-lock*)
    (setf (gethash (memory-pool-name pool) *pool-registry*) pool))
  pool)

(defun get-pool (name)
  "Retrieve a registered pool by name.

  PARAMETERS:
    name - Pool identifier

  RETURNS:
    MEMORY-POOL instance or NIL"
  (sb-thread:with-mutex (*registry-lock*)
    (gethash name *pool-registry*)))

(defun list-pools ()
  "Get list of all registered pool names.

  RETURNS:
    List of pool identifier strings"
  (sb-thread:with-mutex (*registry-lock*)
    (loop for k being the hash-keys of *pool-registry* collect k)))

(defun get-all-pool-stats ()
  "Get statistics for all registered pools.

  RETURNS:
    List of property lists, one per pool"
  (sb-thread:with-mutex (*registry-lock*)
    (loop for pool being the hash-values of *pool-registry*
          collect (pool-stats pool))))

;;; Cache Registry

(defun register-cache (cache)
  "Register a cache in the global registry.

  PARAMETERS:
    cache - CACHE instance

  RETURNS:
    CACHE"
  (sb-thread:with-mutex (*registry-lock*)
    (setf (gethash (cache-name cache) *cache-registry*) cache))
  cache)

(defun get-cache (name)
  "Retrieve a registered cache by name.

  PARAMETERS:
    name - Cache identifier

  RETURNS:
    CACHE instance or NIL"
  (sb-thread:with-mutex (*registry-lock*)
    (gethash name *cache-registry*)))

(defun list-caches ()
  "Get list of all registered cache names.

  RETURNS:
    List of cache identifier strings"
  (sb-thread:with-mutex (*registry-lock*)
    (loop for k being the hash-keys of *cache-registry* collect k)))

(defun get-all-cache-stats ()
  "Get statistics for all registered caches.

  RETURNS:
    List of property lists, one per cache"
  (sb-thread:with-mutex (*registry-lock*)
    (loop for cache being the hash-values of *cache-registry*
          collect (cache-stats cache))))

(defun clear-all-caches ()
  "Clear all entries from all registered caches.

  RETURNS:
    NIL"
  (sb-thread:with-mutex (*registry-lock*)
    (loop for cache being the hash-values of *cache-registry*
          do (cache-clear cache))))

;;; Global Monitoring and Management

(defun global-pool-health ()
  "Check health status of all registered pools.

  RETURNS:
    Property list with aggregated health metrics"
  (sb-thread:with-mutex (*registry-lock*)
    (let ((pools (loop for pool being the hash-values of *pool-registry*
                       collect pool)))
      (if (null pools)
          (list :status :healthy :pool-count 0)
          (let* ((hit-rates (loop for pool in pools
                                  collect (getf (pool-stats pool) :hit-rate)))
                 (avg-hit-rate (if hit-rates
                                   (/ (apply #'+ hit-rates) (length hit-rates))
                                   0.0))
                 (min-hit-rate (if hit-rates (apply #'min hit-rates) 0.0))
                 (status (cond
                           ((and (>= avg-hit-rate 0.6) (>= min-hit-rate 0.4)) :healthy)
                           ((>= avg-hit-rate 0.4) :degraded)
                           (t :critical))))
            (list :status status
                  :pool-count (length pools)
                  :avg-hit-rate avg-hit-rate
                  :min-hit-rate min-hit-rate))))))

(defun global-cache-health ()
  "Check health status of all registered caches.

  RETURNS:
    Property list with aggregated cache health metrics"
  (sb-thread:with-mutex (*registry-lock*)
    (let ((caches (loop for cache being the hash-values of *cache-registry*
                        collect cache)))
      (if (null caches)
          (list :status :healthy :cache-count 0)
          (let* ((hit-rates (loop for cache in caches
                                  collect (getf (cache-stats cache) :hit-rate)))
                 (avg-hit-rate (if hit-rates
                                   (/ (apply #'+ hit-rates) (length hit-rates))
                                   0.0))
                 (status (cond
                           ((>= avg-hit-rate 0.7) :healthy)
                           ((>= avg-hit-rate 0.5) :degraded)
                           (t :critical))))
            (list :status status
                  :cache-count (length caches)
                  :avg-hit-rate avg-hit-rate))))))

(defun print-global-stats (&optional (stream t))
  "Print comprehensive statistics for all pools and caches.

  PARAMETERS:
    stream - Output stream (default: T for standard output)"
  (format stream "~&=== Global Memory Pool and Cache Registry ===~%")
  (format stream "~%Pools (~D registered):~%" (length (list-pools)))
  (loop for pool-stats in (get-all-pool-stats)
        do (format stream "  ~A: ~A (hit-rate: ~5,1F%)~%"
                   (getf pool-stats :name)
                   (getf pool-stats :type)
                   (* 100.0 (getf pool-stats :hit-rate))))
  (format stream "~%Caches (~D registered):~%" (length (list-caches)))
  (loop for cache-stats in (get-all-cache-stats)
        do (format stream "  ~A: ~D/~D entries (hit-rate: ~5,1F%)~%"
                   (getf cache-stats :name)
                   (getf cache-stats :entries)
                   (getf cache-stats :capacity)
                   (* 100.0 (getf cache-stats :hit-rate))))
  (format stream "~%Pool Health: ~A~%" (global-pool-health))
  (format stream "Cache Health: ~A~%" (global-cache-health)))

;;; Periodic Maintenance

(defvar *maintenance-thread* nil
  "Thread for periodic maintenance operations.")

(defvar *maintenance-active-p* nil
  "Flag indicating if maintenance is active.")

(defun start-maintenance (&key (interval-seconds 300))
  "Start periodic maintenance of pools and caches.

  PARAMETERS:
    interval-seconds - How often to run maintenance (default: 300)"
  (unless *maintenance-thread*
    (setf *maintenance-active-p* t)
    (setf *maintenance-thread*
          (sb-thread:make-thread
           (lambda ()
             (loop while *maintenance-active-p*
                   do (progn
                        (sb-thread:with-mutex (*registry-lock*)
                          ;; Analyze fragmentation
                          (loop for pool being the hash-values of *pool-registry*
                                do (check-pool-health pool)))
                        (sleep interval-seconds))))
           :name "memory-pool-maintenance"))))

(defun stop-maintenance ()
  "Stop periodic maintenance."
  (setf *maintenance-active-p* nil)
  (when *maintenance-thread*
    (sb-thread:join-thread *maintenance-thread*)
    (setf *maintenance-thread* nil)))

;;; Leak Detection

(defstruct allocation-tracker
  "Track allocations for leak detection.
SLOTS:
  allocations - Hash of active allocations
  lock        - Mutex for synchronization"
  (allocations (make-hash-table :test 'eq))
  (lock (sb-thread:make-mutex :name "allocation-tracker-lock")))

(defvar *leak-tracker* (make-allocation-tracker)
  "Global allocation tracker for leak detection.")

(defun track-allocation (obj)
  "Record allocation for leak detection."
  (sb-thread:with-mutex ((allocation-tracker-lock *leak-tracker*))
    (setf (gethash (sb-kernel:get-lisp-obj-address obj)
                   (allocation-tracker-allocations *leak-tracker*))
          (get-universal-time)))
  obj)

(defun untrack-allocation (obj)
  "Remove allocation from leak detection."
  (sb-thread:with-mutex ((allocation-tracker-lock *leak-tracker*))
    (remhash (sb-kernel:get-lisp-obj-address obj)
             (allocation-tracker-allocations *leak-tracker*))))

(defun detect-leaks (&key (age-threshold 3600))
  "Detect potential memory leaks (allocations older than threshold).

  PARAMETERS:
    age-threshold - Age in seconds (default: 3600)

  RETURNS:
    List of leak objects with their allocation time"
  (let ((now (get-universal-time)))
    (sb-thread:with-mutex ((allocation-tracker-lock *leak-tracker*))
      (loop for addr being the hash-keys of (allocation-tracker-allocations *leak-tracker*)
            for alloc-time being the hash-values of (allocation-tracker-allocations *leak-tracker*)
            when (>= (- now alloc-time) age-threshold)
            collect (list :address addr :allocated-at alloc-time :age-seconds (- now alloc-time))))))
