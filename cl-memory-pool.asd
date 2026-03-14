(defsystem "CL_MEMORY_POOL"
  :name "CL_MEMORY_POOL"
  :version "0.1.0"
  :author "Park Ian Co"
  :license "MIT"
  :description "Memory Pool"
  :depends-on ()
  :components ((:module "src"
                :components ((:file "package")
                             (:file "impl" :depends-on ("package"))))
               (:module "test"
                :components ((:file "test"))))
  :in-order-to ((test-op (test-op "CL_MEMORY_POOL/test")))
  :defsystem-depends-on ("prove")
  :perform (test-op (op c) (symbol-call :prove 'run c)))

(defsystem "CL_MEMORY_POOL/test"
  :name "CL_MEMORY_POOL/test"
  :depends-on ("CL_MEMORY_POOL" "prove")
  :components ((:module "test"
                :components ((:file "test")))))
