#-------------------------------------------------------------------------------
#   BTree Implementation in x86_64 Assembly Language with C Interface
#   Copyright (C) 2025  J. McIntosh
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License along
#   with this program; if not, write to the Free Software Foundation, Inc.,
#   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#-------------------------------------------------------------------------------
#
libbtree.so: btree_asm.o btree.o
	gcc -march=x86-64 -m64 -z noexecstack -shared btree_asm.o btree.o -o libbtree.so
btree.o: btree.c
	gcc -march=x86-64 -m64 -Wall -fPIC -c btree.c -o btree.o
btree_asm.o: btree.asm
	nasm -f elf64 btree.asm -o btree_asm.o
clean:
	rm -f libbtree.so btree.o btree_asm.o
