# Memory Pool

Simple reusable object pool for Common Lisp resources.

## Features

- Pre-allocate a pool of reusable values
- Acquire idle resources or lazily create new ones up to a maximum
- Release resources back into the pool for reuse

## Installation

```lisp
(asdf:load-system :cl-memory-pool)
```

## Usage

```lisp
(let ((pool (cl-memory-pool:create-pool
             :initial-size 1
             :max-size 4
             :factory (lambda () (list :connection)))))
  (let ((resource (cl-memory-pool:acquire-connection pool)))
    (cl-memory-pool:release-connection pool resource)))
```

## Testing

```lisp
(asdf:test-system :cl-memory-pool)
```

## API

- `create-pool` constructs a resource pool.
- `acquire-connection` returns an existing idle resource or creates one if capacity remains.
- `release-connection` marks a resource as available again.

## License

Apache-2.0 License - See LICENSE file for details.

---
Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
SPDX-License-Identifier: Apache-2.0
