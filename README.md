# BTree Implementation in x86_64 Assembly Language with C interface as a Shared-Library

[![License: GPL-2.0](https://img.shields.io/badge/License-GPL%202.0-blue.svg)](https://opensource.org/licenses/GPL-2.0)
[![Stars](https://img.shields.io/github/stars/KatoKode/BTree?style=social)](https://github.com/KatoKode/BTree/stargazers)

by JD McIntosh

## INTRODUCTION
The BTree is implemented as a shared-library with a C interface and a C demo program.

The BTree implementaton is based on a C++ implementation found at:

[GeeksforGeeks: Delete Operation in B-Tree](https://www.geeksforgeeks.org/delete-operation-in-b-tree/?ref=lbp)

---

## FEATURES

Generic B-Tree Structure:

+ Supports arbitrary object sizes (user-specified o_size, automatically aligned to 8-byte boundary).
+ Configurable minimum degree (mindeg, enforced ≥2).
+ Separate comparison callbacks for full objects (o_cmp_cb) and keys to full objects (k_cmp_cb).
+ Key extraction callback (k_get_cb) for searching with keys only.
+ Object deletion callback (o_del_cb) for cleanup during removal/termination.

Core Operations:

+ Insertion with duplicate prevention (returns -1 if key exists).
+ Deletion by key with full B-tree balancing (borrow/merge).
+ Search by key returning copied object (or NULL if not found).
+ In-order traversal via user-provided walk callback.

Balancing Mechanisms:

+ Node splitting during insertion when full (2*mindeg-1 objects).
+ Borrowing from siblings during deletion underflow.
+ Merging nodes during deletion when under minimum.
+ Root handling for growth/shrinkage (new root on split, demotion on empty).

Performance Optimizations:

+ Critical paths (most operations) implemented in x86-64 Assembly.
+ Custom 64-bit aligned memmove64 in Assembly (uses rep movsq + rep movsb, assumes non-overlapping).
+ Hybrid key search: linear hunt for small nodes (≤9 objects), binary search for larger.
+ Stack alignment to 16-byte boundary before C/lib calls from Assembly.
+ Compact node layout: children and objects in contiguous buffer (non-leaves store children first).

Memory Management:

+ Dynamic allocation via calloc for nodes and buffers.
+ Proper cleanup: recursive termination frees all nodes and calls o_del_cb on objects.
+ Zero-initialization of structures.

Single-Threaded Design:

+ No synchronization primitives — optimized for sequential use.
+ Suitable as baseline for future concurrency extensions.

Demo/Testing:

+ Included main program inserts ~8M random long keys (with string payload), deletes 75%, (enable walks tree for verification).
+ Handles large-scale testing (configurable counts and degree).

### Benchmarks (Single-Threaded)

**Workload**: 8,388,608 random inserts followed by 6,291,456 random deletes  
(total: 14,680,064 operations) on 24-byte objects (8-byte key + 16-byte payload).

| Minimum Degree (t) | Average Real Time (10 runs) | Throughput          | Improvement |
|--------------------|-----------------------------|---------------------|-------------|
| 2                  | 24.78 s                    | \~593,000 ops/sec   | Baseline    |
| 48                 | 15.83 s                    | \~927,000 ops/sec   | **+37% faster** |

**Notes**:
- All benchmarks are single-threaded on the same x86-64 Assembly B-Tree implementation with full rebalancing and generic callbacks.
- `t = 48` hits the sweet spot for this 24-byte object size (shallower tree + better cache behavior).
- The original `mindeg=2` results remain excellent for workloads with much larger payloads.

### Benchmark:
+ Minimum Degree (t) = 2
+ Object Size = 24-bytes with 8-byte key
+ 8,388,608 insert operations
+ 6,291,456 delete operations

This x86-64 Assembly B-Tree implementation delivered excellent single-threaded performance on mixed insert/delete workloads with (24-byte) objects. Benchmark (single-threaded, minimum degree 2, random keys): 8,388,608 insertions followed by 6,291,456 deletions (14,680,064 total operations):

Average time (10 runs): 24.78 seconds

Throughput: ~593,000 operations per second

These results are competitive with optimized in-memory B-Trees, especially considering full rebalancing (borrow/merge on delete) and generic callbacks. The mindeg=2 configuration excels with larger payloads due to reduced data movement during structural changes.

### Benchmark:
+ Minimum Degree (t) = 48
+ Object Size = 24-bytes with 8-byte key
+ 8,388,608 insert operations
+ 6,291,456 delete operations

This x86-64 Assembly B-Tree implementation continues to deliver excellent single-threaded performance on mixed insert/delete workloads with 24-byte objects (8-byte key + 16-byte payload).
New results with minimum degree t = 48 (optimized fanout):
8,388,608 random inserts followed by 6,291,456 random deletes
(total 14,680,064 operations)

Average real time (10 runs): 15.5 seconds

Throughput: ~947,000 operations per second

This is a ~37% speedup over the previously published minimum-degree=2 baseline (24.78 s / ~593k ops/sec) while still using the same full-rebalancing classic B-Tree with generic callbacks.
(The earlier t=2 configuration remains excellent for very large payloads; t=48 hits the sweet spot for this 24-byte object size.)

### Valgrind-certified leak-free
HEAP SUMMARY:
    in use at exit: 0 bytes in 0 blocks
  total heap usage: 406,633 allocs, 406,633 frees, 300,808,344 bytes allocated

All heap blocks were freed -- no leaks are possible

ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)

---

## LIST OF REQUIREMENTS
+ Linux OS
+ Programming languages: C and Assembly
+ Netwide Assembler (NASM), the GCC compiler, and the Make utility
+ your favorite text editor
+ and working at the command line

---

## BUILD THE DEMO
Run the following command in the `BTree-main` folder:
```bash
sh ./btree_make.sh
```

---

## RUN THE DEMO
In folder `demo` enter the following command:
```bash
./go_demo.sh
```

---

## THINGS TO KNOW
You can modify the defines listed below in the C header file `main.h` in folder `demo`.  The initial minimum degree is 2. The demo will insert 8192 objects into the tree.  Then delete 6144 (75%) of the objects.  So, in the output file `out.txt` in the `demo` folder search for `8191:`, then search for `2047:`.  Those are the totals for insertion and deletion.
```c
#define DATA_COUNT      (8 * 1024)
#define DELETE_COUNT    (DATA_COUNT * 0.75)
#define MINIMUM_DEGREE  2
#define INS_MOD_BY      64
#define DEL_MOD_BY      64
```
Modifying these defines will change the behavior of the demo program.

NOTE: The demo program will not check for negative values or `DELETE_COUNT` having a larger value than `DATA_COUNT`.

Have Fun!

---

