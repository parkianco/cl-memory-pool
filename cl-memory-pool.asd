;;;; cl-memory-pool.asd - Thread-safe object pooling for SBCL

(asdf:defsystem #:cl-memory-pool
  :description "Thread-safe object pooling and memory management using SBCL native threading"
  :author "Parkian Company LLC"
  :license "BSD-3-Clause"
  :version "1.0.0"
  :depends-on ()
  :serial t
  :components ((:file "package")
               (:module "src"
                :serial t
                :components ((:file "allocation")
                             (:file "pool")
                             (:file "cache")
                             (:file "registry"))))
  :in-order-to ((test-op (test-op #:cl-memory-pool/test))))

(asdf:defsystem #:cl-memory-pool/test
  :description "Tests for cl-memory-pool"
  :depends-on (#:cl-memory-pool)
  :serial t
  :components ((:module "test"
                :serial t
                :components ((:file "package")
                             (:file "tests"))))
  :perform (test-op (o c)
             (let ((result (uiop:symbol-call :cl-memory-pool.test :run-tests)))
               (unless result
                 (error "Tests failed")))))
