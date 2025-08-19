#-------------------------------------------------------------------------------
#   BTree (BTREE) Implementation in x86_64 Assembly Language with C Interface
#   Copyright (C) 2025  J. McIntosh
#
#   BTREE is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   BTREE is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License along
#   with BTREE; if not, write to the Free Software Foundation, Inc.,
#   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#-------------------------------------------------------------------------------
#
libutil.so: memmove64.o util.o
	gcc -march=x86-64 -m64 -z noexecstack -shared memmove64.o util.o -o libutil.so
util.o: util.c
	gcc -march=x86-64 -m64 -Wall -fPIC -c util.c -o util.o
memmove64.o: memmove64.asm
	nasm -f elf64 memmove64.asm
.PHONY: clean
clean:
	rm -f libutil.so util.o memmove64.o
