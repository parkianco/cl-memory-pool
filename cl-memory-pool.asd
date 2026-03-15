(asdf:defsystem #:cl-memory-pool
  :name "cl-memory-pool"
  :version "0.1.0"
  :author "Park Ian Co"
  :license "Apache-2.0"
  :description "Simple reusable object pool for Common Lisp resources"
  :serial t
  :components ((:module "src"
                :components ((:file "package")
                             (:file "conditions" :depends-on ("package"))
                             (:file "types" :depends-on ("package"))
                             (:file "allocation" :depends-on ("package"))
                             (:file "pool" :depends-on ("package" "conditions"))
                             (:file "cache" :depends-on ("package" "pool"))
                             (:file "registry" :depends-on ("package" "pool"))
                             (:file "cl-memory-pool" :depends-on ("package" "conditions" "types" "allocation" "pool" "cache" "registry")))))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-memory-pool/test))))

(asdf:defsystem #:cl-memory-pool/test
  :name "cl-memory-pool"
  :depends-on (#:cl-memory-pool)
  :serial t
  :components ((:module "test"
                :serial t
                :components ((:file "test"))))
  :perform (asdf:test-op (op c)
             (declare (ignore op c))
             (unless (uiop:symbol-call :cl-memory-pool.test :run-tests)
               (error "Tests failed"))))
