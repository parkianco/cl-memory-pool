;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package #:cl-memory-pool)

(defstruct pooled-resource
  value
  (in-use-p nil :type boolean))

(defstruct (resource-pool (:constructor %make-resource-pool))
  (factory (lambda () nil) :type function)
  (max-size 16 :type (integer 1 *))
  (resources nil :type list))

(defun create-pool (&key (factory (lambda () nil)) (initial-size 0) (max-size 16))
  "Create a reusable resource pool.

FACTORY is called to build new pooled values."
  (when (> initial-size max-size)
    (error "INITIAL-SIZE ~D exceeds MAX-SIZE ~D" initial-size max-size))
  (let ((pool (%make-resource-pool :factory factory :max-size max-size)))
    (dotimes (index initial-size pool)
      (push (make-pooled-resource :value (funcall factory))
            (resource-pool-resources pool)))))

(defun available-resource (pool)
  "Return the first idle resource in POOL."
  (find-if-not #'pooled-resource-in-use-p (resource-pool-resources pool)))

(defun acquire-connection (pool)
  "Acquire a pooled value from POOL."
  (let ((resource (available-resource pool)))
    (cond
      (resource
       (setf (pooled-resource-in-use-p resource) t)
       (pooled-resource-value resource))
      ((< (length (resource-pool-resources pool)) (resource-pool-max-size pool))
       (let ((fresh (make-pooled-resource
                     :value (funcall (resource-pool-factory pool))
                     :in-use-p t)))
         (push fresh (resource-pool-resources pool))
         (pooled-resource-value fresh)))
      (t
       (error "No resources available in pool")))))

(defun release-connection (pool resource-value)
  "Release RESOURCE-VALUE back to POOL."
  (let ((resource (find resource-value
                        (resource-pool-resources pool)
                        :key #'pooled-resource-value
                        :test #'equal)))
    (unless resource
      (error "Resource ~S does not belong to pool" resource-value))
    (setf (pooled-resource-in-use-p resource) nil)
    resource-value))


;;; Substantive API Implementations
(define-condition cl-memory-pool-error (cl-memory-pool-error) ())
(define-condition cl-memory-pool-validation-error (cl-memory-pool-error) ())


;;; ============================================================================
;;; Standard Toolkit for cl-memory-pool
;;; ============================================================================

(defmacro with-memory-pool-timing (&body body)
  "Executes BODY and logs the execution time specific to cl-memory-pool."
  (let ((start (gensym))
        (end (gensym)))
    `(let ((,start (get-internal-real-time)))
       (multiple-value-prog1
           (progn ,@body)
         (let ((,end (get-internal-real-time)))
           (format t "~&[cl-memory-pool] Execution time: ~A ms~%"
                   (/ (* (- ,end ,start) 1000.0) internal-time-units-per-second)))))))

(defun memory-pool-batch-process (items processor-fn)
  "Applies PROCESSOR-FN to each item in ITEMS, handling errors resiliently.
Returns (values processed-results error-alist)."
  (let ((results nil)
        (errors nil))
    (dolist (item items)
      (handler-case
          (push (funcall processor-fn item) results)
        (error (e)
          (push (cons item e) errors))))
    (values (nreverse results) (nreverse errors))))

(defun memory-pool-health-check ()
  "Performs a basic health check for the cl-memory-pool module."
  (let ((ctx (initialize-memory-pool)))
    (if (validate-memory-pool ctx)
        :healthy
        :degraded)))
