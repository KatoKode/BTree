
---

BTree Implementation in x86_64 Assembly Language with C interface

by Jerry McIntosh
katokode@proton.me

---

# INTRODUCTION
This is an Assembly Language implementation of a BTree (Multiway-Tree).  The BTree is implemented as a shared-library with a C interface.  There is also a C demo program.

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

# THINGS TO KNOW
You can modify a couple defines in the C header file `main.h`:
```c
#define DATA_COUNT    128
#define DELETE_COUNT    0
#defines MINIMUM_DEGREE 255
```

Modifying these defines will change the behavior of the demo program.

Modifying MINIMUM_DEGREE should done with care.  More will be provided on this in the future.

NOTE: The demo program will not check for negative values or `DELETE_COUNT` having a larger value than `DATA_COUNT`.

There are calls to `printf` in the `btree.asm` file.  They are for demo purposes only and can be removed or commented out.  The `printf` code sections are marked with comment lines: `BEGIN PRINTF`; and `END PRINTF`.  The format and text strings passed to `printf` are in the `.data` section of the `btree.asm` file.

---

# LEAVE A STAR
If you like the KatoKode BTree repository by all means leave a STAR to encourage others to visit.

Thanks, and Have Fun!

---

