;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0

;;;; allocation.lisp - Memory allocation utilities with tracking

(in-package #:cl-memory-pool)

(defvar *memory-allocation-stats* (make-hash-table :test 'equal)
  "Memory allocation statistics for monitoring.")

(defvar *allocation-stats-lock* (sb-thread:make-mutex :name "allocation-stats-lock")
  "Lock for thread-safe allocation tracking.")

(defmacro allocate-temporary (type size &body body)
  "Allocate temporary memory with automatic cleanup on exit.

  PARAMETERS:
    type - Type of memory: :bytes, :string, :uint32, :uint64, or T
    size - Number of elements to allocate
    body - Code to execute (memory valid during execution)

  RETURNS:
    Result of BODY evaluation

  EXAMPLE:
    (allocate-temporary :bytes 64
      (process-buffer buffer)
      (length buffer))"
  `(let ((obj (allocate-memory ,type ,size)))
     (unwind-protect
          (progn ,@body)
       (free-memory obj))))

(defun allocate-memory (type size)
  "Allocate typed memory block and track allocation statistics.

  PARAMETERS:
    type - Type of memory: :bytes, :string, :uint32, :uint64, or T
    size - Number of elements to allocate

  RETURNS:
    Allocated array of appropriate element type and size"
  (declare (optimize (speed 3) (safety 1)))
  (let ((obj (ecase type
               (:bytes (make-array size :element-type '(unsigned-byte 8)))
               (:string (make-array size :element-type 'character))
               (:uint32 (make-array size :element-type '(unsigned-byte 32)))
               (:uint64 (make-array size :element-type '(unsigned-byte 64)))
               (t (make-array size :element-type t))))
        (key (format nil "~A-~A" type size)))
    (sb-thread:with-mutex (*allocation-stats-lock*)
      (setf (gethash key *memory-allocation-stats*)
            (list :type type :size size :timestamp (get-universal-time))))
    obj))

(defun free-memory (obj)
  "Free memory and record deallocation in statistics.

  PARAMETERS:
    obj - Memory array to deallocate

  RETURNS:
    NIL"
  (let ((key (format nil "~A-~A" (type-of obj) (length obj))))
    (sb-thread:with-mutex (*allocation-stats-lock*)
      (setf (gethash key *memory-allocation-stats*)
            (append (gethash key *memory-allocation-stats*)
                    (list :freed t :timestamp (get-universal-time)))))))

(defun get-memory-stats ()
  "Retrieve all recorded memory allocation/deallocation statistics."
  (let ((result nil))
    (sb-thread:with-mutex (*allocation-stats-lock*)
      (maphash (lambda (k v) (push (cons k v) result))
               *memory-allocation-stats*))
    result))

(defun reset-memory-stats ()
  "Clear all recorded memory allocation statistics."
  (sb-thread:with-mutex (*allocation-stats-lock*)
    (clrhash *memory-allocation-stats*)))
