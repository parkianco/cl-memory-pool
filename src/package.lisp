;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package :cl-user)

(defpackage :cl-memory-pool
  (:use :cl)
  (:export #:create-pool
           #:acquire-connection
           #:release-connection))

(in-package :cl-memory-pool)
