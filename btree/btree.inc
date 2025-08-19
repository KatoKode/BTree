;-------------------------------------------------------------------------------
;   BTree (BTREE) Implementation in x86_64 Assembly Language with C Interface
;   Copyright (C) 2025  J. McIntosh
;
;   BTREE is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation; either version 2 of the License, or
;   (at your option) any later version.
;
;   BTREE is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License along
;   with BTREE; if not, write to the Free Software Foundation, Inc.,
;   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
;-------------------------------------------------------------------------------
%ifndef BTREE_INC
%define BTREE_INC  1
;
struc b_node
  .nobj:        resq    1   ; number of objects
  .tree:        resq    1   ; pointer to parent tree
  .child:       resq    1   ; array of child pointers
  .object:      resq    1   ; array of objects
  .leaf:        resb    1   ; 0 (false) | 1 (true)
endstruc
;
struc b_tree
  .mindeg:      resq    1   ; minimum-degree of the tree
  .o_size:      resq    1   ; size of each object stored in the tree
  .o_cmp_cb:    resq    1   ; user supplied function
  .k_cmp_cb:    resq    1   ; user supplied function
  .o_del_cb:    resq    1   ; user supplied function
  .k_get_cb:    resq    1   ; user supplied function
  .root:        resq    1   ; pointer to root node of tree
endstruc
;
%endif
