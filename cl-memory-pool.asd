(asdf:defsystem #:cl-memory-pool
  :depends-on (#:alexandria #:bordeaux-threads)
  :components ((:module "src"
                :components ((:file "package")
                             (:file "cl-memory-pool" :depends-on ("package"))))))