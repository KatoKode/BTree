


Just Another Armchair Programmer

B-Tree Implementation in x86_64 Assembly Language with C interface

by Jerry McIntosh
# INTRODUCTION
This is an Assembly Language implementation of a B-Tree (Multiway-Tree).  The B-Tree is implemented as a shared-library with a C interface.  There is also a C demo program.

The B-Tree implementaton is based on a C++ implementation found at:

[GeeksforGeeks: Delete Operation in B-Tree](https://www.geeksforgeeks.org/delete-operation-in-b-tree/?ref=lbp)

LIST OF REQUIREMENTS:

+ Linux OS
+ Programming languages: C and Assembly
+ Netwide Assembler (NASM), the GCC compiler, and the make utility
+ your favorite text editor
+ and working at the command line

FILE STRUCTURE:

util/
+ memmove64.asm
+ util.h
+ util.c
+ makefile

btree/
+ btree.asm
+ btree.inc
+ btree.h
+ btree.c
+ makefile

btest/
+ main.h
+ main.c
+ makefile
+ go_btest.sh
# CREATE THE DEMO WITH THE MAKE UTILITY:
Run the following command combo in each folder.
```bash
make clean; make
```

# RUN THE DEMO:
```bash
./go_btest.sh
```
# THINGS TO KNOW:
You can modify a couple defines in the C header file `main.h`:
```c
#define DATA_COUNT    128
#define DELETE_COUNT    0
```
Modifying these defines will change the behavior of the demo program.

NOTE: The demo program will not check for negative values or DELETE_COUNT having a larger value than DATA_COUNT.

There are calls to `printf` in the `btree.asm` file.  They are for demo purposes only and can be removed or commented out.  The `printf` code sections are marked with comment lines: `BEGIN PRINTF`; and `END PRINTF`.  The format and text strings passed to `printf` are in the `.data` section of the `btree.asm` file.

Have Fun!
