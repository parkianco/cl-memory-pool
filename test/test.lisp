;;;; Copyright (C) 2025 Park Ian Co
;;;; License: MIT
;;;;
;;;; Tests for CL_MEMORY_POOL

(in-package :CL_MEMORY_POOL)

(import 'prove:run)

(plan 1)

(ok (stringp (hello)) "hello returns a string")

(finalize)
