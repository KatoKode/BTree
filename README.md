
---

KatoKode: BTree Implementation in x86_64 Assembly Language with C interface

by Jerry McIntosh

---

# INTRODUCTION
The BTree is implemented as a shared-library with a C interface with a C demo program.

The BTree implementaton is based on a C++ implementation found at:

[GeeksforGeeks: Delete Operation in B-Tree](https://www.geeksforgeeks.org/delete-operation-in-b-tree/?ref=lbp)

## LIST OF REQUIREMENTS

+ Linux OS
+ Programming languages: C and Assembly
+ Netwide Assembler (NASM), the GCC compiler, and the make utility
+ your favorite text editor
+ and working at the command line

---

# CREATE THE DEMO
Run the following command in the `BTree-main` folder:
```bash
sh ./btree_make.sh
```

---

# RUN THE DEMO
In folder `demo` enter the following command:
```bash
./go_demo.sh
```

---

### Benchmarks (Single-Threaded)

14,336 operations (8192 inserts + 6144 deletes)  
Minimum degree t=2 (maximum splits/merges/borrows)  

+ Average wall time: ~22.93 seconds  
+ Throughput: ~625 ops/second  
+ Variance: Extremely low (±0.11s across 10 runs)

---

# THINGS TO KNOW
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

