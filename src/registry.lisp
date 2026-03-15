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
