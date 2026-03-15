;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package #:cl-memory-pool)

;;; Core types for cl-memory-pool
(deftype cl-memory-pool-id () '(unsigned-byte 64))
(deftype cl-memory-pool-status () '(member :ready :active :error :shutdown))
