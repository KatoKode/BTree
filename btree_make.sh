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
clear;

sep="--------------------------------------------------------------------------------"

echo -e "${sep}"

builtin cd ./util/ || exit -1

make clean; make

test -e ./libutil.so || exit -1

echo -e "${sep}"

builtin cd ../btree/ || exit -1

make clean; make

test -e ./libbtree.so || exit -1

echo -e "${sep}"

builtin cd ../demo || exit -1

make clean; make

test -e ./demo || exit -1

chmod 744 ./go_demo.sh || exit -1

echo -e "${sep}"

echo -e "alls well that ends well.\n"
