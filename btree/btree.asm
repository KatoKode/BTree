;-------------------------------------------------------------------------------
;   BTree Implementation in x86_64 Assembly Language with C Interface
;   Copyright (C) 2025  J. McIntosh
;
;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation; either version 2 of the License, or
;   (at your option) any later version.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License along
;   with this program; if not, write to the Free Software Foundation, Inc.,
;   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
;-------------------------------------------------------------------------------
%ifndef BTREE_ASM
%define BTREE_ASM  1
;
extern calloc
extern free
extern memset
extern memmove64
;
;-------------------------------------------------------------------------------
;
QW_SIZE       EQU     8
;
HUNT_MAX      EQU     9
;
ALIGN_SIZE    EQU     16
ALIGN_WITH    EQU     (ALIGN_SIZE - 1)
ALIGN_MASK    EQU     ~(ALIGN_WITH)
;
ALIGN_SIZE_8  EQU     8
ALIGN_WITH_8  EQU     (ALIGN_SIZE_8 - 1)
ALIGN_MASK_8  EQU     ~(ALIGN_WITH_8)
;
;-------------------------------------------------------------------------------
;
%macro ALIGN_STACK_AND_CALL 2-4
      mov     %1, rsp               ; backup stack pointer (rsp)
      and     rsp, QWORD ALIGN_MASK ; align stack pointer (rsp) to
                                    ; 16-byte boundary
      call    %2 %3 %4              ; call C function
      mov     rsp, %1               ; restore stack pointer (rsp)
%endmacro
;
; Example: Call LIBC function
;         ALIGN_STACK_AND_CALL r15, calloc, wrt, ..plt
;
; Example: Call C callback function with address in register (rcx)
;         ALIGH_STACK_AND_CALL r12, rcx
;-------------------------------------------------------------------------------
;
%include "btree.inc"
;
section .text
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_borrow_from_next (b_node_t *node, size_t const i);
;
; param:
;
;   rdi = node
;   rsi = i
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (i)
;   QWORD [rbp - 24]  = (b_node_t *child)
;   QWORD [rbp - 32]  = (b_node_t *sibling)
;   QWORD [rbp - 40]  = (size_t o_size)
;   QWORD [rbp - 48]  = rbx (callee saved)
;-------------------------------------------------------------------------------
;
      static b_borrow_from_next
b_borrow_from_next:
; prologue:
      push      rbp
      mov       rbp, rsp
      sub       rsp, 56
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 48], rbx
; size_t o_size = node->tree->o_size;
      mov       rbx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rbx + b_tree.o_size]
      mov       QWORD [rbp - 40], rax
; b_node_t *child = node->child[i];
      call      b_child_at
      mov       rbx, QWORD [rax]
      mov       QWORD [rbp - 24], rbx
; b_node_t *sibling = node->child[i + 1L];
      inc       rsi
      call      b_child_at
      mov       rbx, QWORD [rax]
      mov       QWORD [rbp - 32], rbx
;
; child->object[child->nobj] = node->object[i];
;
; (void)memmove64(&child->object[child->nobj], &node->object[i],
;     node->tree->o_size);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      call      b_object_at
      push      rax
      mov       rdi, QWORD [rbp - 24]
      mov       rsi, QWORD [rdi + b_node.nobj]
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
; if (child->leaf == false)
      mov       rdi, QWORD [rbp - 24]
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .child_is_leaf
;   child->child[child->nobj + 1L] = sibling->child[0];
      mov       rdi, QWORD [rbp - 32]
      mov       rax, QWORD [rdi + b_node.child]
      push      QWORD [rax]
      mov       rdi, QWORD [rbp - 24]
      mov       rsi, QWORD [rdi + b_node.nobj]
      inc       rsi
      call      b_child_at
      pop       QWORD [rax]
.child_is_leaf:
;
; node->object[i] = sibling->object[0];
;
; (void)memmove64(&node->object[i], sibling->object, node->tree->o_size);
      mov       rdi, QWORD [rbp - 32]
      mov       rax, QWORD [rdi + b_node.object]
      push      rax
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
; for (size_t x = 1; x < sibling->nobj; ++x) {
      xor       rbx, rbx
.object_move_loop:
      inc       rbx
      mov       rdi, QWORD [rbp - 32]
      cmp       rbx, QWORD [rdi + b_node.nobj]
      jae       .object_move_break
;   sibling->object[x - 1] = sibling->object[x];
      mov       rsi, rbx
      call      b_object_at
      push      rax
      dec       rsi
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
      jmp       .object_move_loop
; }
.object_move_break:
; if (sibling->leaf == false) {
      mov       rdi, QWORD [rbp - 32]
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .sibling_is_leaf
;   for (size_t x = 1; i <= sibling->nobj; ++i) {
      xor       rbx, rbx
.child_move_loop:
      inc       rbx
      mov       rdi, QWORD [rbp - 32]
      cmp       rbx, QWORD [rdi + b_node.nobj]
      ja        .child_move_break
;     sibling->child[x - 1] = sibling->child[x];
      mov       rsi, rbx
      call      b_child_at
      push      QWORD [rax]
      dec       rsi
      call      b_child_at
      pop       QWORD [rax]
      jmp       .child_move_loop
;   }
.child_move_break:
; }
.sibling_is_leaf:
; child->nobj += 1;
      mov       rdi, QWORD [rbp - 24]
      inc       QWORD [rdi + b_node.nobj]
; sibling->nobj -= 1;
      mov       rdi, QWORD [rbp - 32]
      dec       QWORD [rdi + b_node.nobj]
; epilogue
      mov       rbx, QWORD [rbp - 48]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_borrow_from_prev (b_node_t *node, size_t const i);
;
; param:
;
;   rdi = node
;   rsi = i
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (i)
;   QWORD [rbp - 24]  = (b_node_t *child)
;   QWORD [rbp - 32]  = (b_node_t *sibling)
;   QWORD [rbp - 40]  = (size_t o_size)
;   QWORD [rbp - 48]  = rbx (callee saved)
;-------------------------------------------------------------------------------
;
      static b_borrow_from_prev
b_borrow_from_prev:
; prologue:
      push      rbp
      mov       rbp, rsp
      sub       rsp, 56
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 48], rbx
; size_t o_size = node->tree->o_size;
      mov       rbx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rbx + b_tree.o_size]
      mov       QWORD [rbp - 40], rax
; b_node_t *child = node->child[i];
      call      b_child_at
      mov       rbx, QWORD [rax]
      mov       QWORD [rbp - 24], rbx
; b_node_t *sibling = node->child[i - 1];
      dec       rsi
      call      b_child_at
      mov       rbx, QWORD [rax]
      mov       QWORD [rbp - 32], rbx
; for (ssize_t x = child->nobj - 1; x >= 0; --x) {
      mov       rdi, QWORD [rbp - 24]
      mov       rbx, QWORD [rdi + b_node.nobj]
.object_move_loop:
      dec       rbx
      cmp       rbx, 0
      jl        .object_move_break
;   child->object[x + 1] = child->object[x];
      mov       rdi, QWORD [rbp - 24]
      mov       rsi, rbx
      call      b_object_at
      push      rax
      inc       rsi
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
      jmp       .object_move_loop
; }
.object_move_break:
;
; if (child->leaf == false) {
      mov       rdi, QWORD [rbp - 24]
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .child_is_leaf
;   for (ssize_t x = child->nobj; x >= 0; --x) {
      mov       rbx, QWORD [rdi + b_node.nobj]
.child_move_loop:
      cmp       rbx, 0
      jl        .child_move_break
;     child->child[x + 1] = child->child[x];
      mov       rsi, rbx
      call      b_child_at
      push      QWORD [rax]
      inc       rsi
      call      b_child_at
      pop       QWORD [rax]
      dec       rbx
      jmp       .child_move_loop
; }
.child_move_break:
; }
.child_is_leaf:
;
; child->object[0] = node->object[i - 1];
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      dec       rsi
      call      b_object_at
      mov       rsi, rax
      mov       rbx, QWORD [rbp - 24]
      mov       rdi, QWORD [rbx + b_node.object]
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
; if (child->leaf == false) {
      mov       rdi, QWORD [rbp - 24]
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .child_is_leaf_2
;   child->child[0] = sibling->child[sibling->nobj];
      mov       rdi, QWORD [rbp - 32]
      mov       rsi, QWORD [rdi + b_node.nobj]
      call      b_child_at
      push      QWORD [rax]
      mov       rdi, QWORD [rbp - 24]
      mov       rax, QWORD [rdi + b_node.child]
      pop       QWORD [rax]
; }
.child_is_leaf_2:
;
; node->object[i - 1] = sibling->object[sibling->n - 1];
      mov       rdi, QWORD [rbp - 32]
      mov       rsi, QWORD [rdi + b_node.nobj]
      dec       rsi
      call      b_object_at
      push      rax
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      dec       rsi
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
; child->nobj += 1;
      mov       rdi, QWORD [rbp - 24]
      mov       rax, QWORD [rdi + b_node.nobj]
      inc       rax
      mov       QWORD [rdi + b_node.nobj], rax
; sibling->nobj -= 1;
      mov       rdi, QWORD [rbp - 32]
      mov       rax, QWORD [rdi + b_node.nobj]
      dec       rax
      mov       QWORD [rdi + b_node.nobj], rax
; epilogue
      mov       rbx, QWORD [rbp - 48]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_child_at (b_node_t *node, size_t const i);
;
; param:
;
; rdi = node
; rsi = i
;-------------------------------------------------------------------------------
;
      static b_child_at
b_child_at:
; return node->child[i]
      mov       rax, QW_SIZE
      mul       rsi
      add       rax, QWORD [rdi + b_node.child]
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_delete (b_node_t *node, void const *key);
;
; param:
;
; rdi = node
; rsi = key
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (key)
;   DWORD [rbp - 24]  = (int cond)
;   DWORD [rbp - 32]  = (int flag)
;   QWORD [rbp - 40]  = (ssize_t const i)
;-------------------------------------------------------------------------------
;
      static b_delete
b_delete:
      push      rbp
      mov       rbp, rsp
      sub       rsp, 56
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
; int cond;
; ssize_t const i = b_find_key(node, key, &cond);
      lea       rdx, [rbp - 24]
      call      b_find_key
      mov       QWORD [rbp - 40], rax
; if (i < node->nobj && cond == 0) {
      mov       rdi, QWORD [rbp - 8]
      cmp       rax, QWORD [rdi + b_node.nobj]
      jae       .else
      mov       eax, DWORD [rbp - 24]
      test      eax, eax
      jnz       .else
;   if (node->leaf == true)
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jz        .else_2
;     b_delete_from_leaf(node, i);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 40]
      call      b_delete_from_leaf
      jmp       .epilogue
;   else
.else_2:
;     b_delete_from_non_leaf(node, i);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 40]
      call      b_delete_from_non_leaf
      jmp       .epilogue
; } else {
.else:
;   if (node->leaf == true) return;
      mov       rdi, QWORD [rbp - 8]
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .epilogue
;   the flag indicates whether the (key) may be present in the sub-tree
;   rooted by the last child of node (node).  while (i) does not change
;   (node)->nobj may change if b_fill is called below.
;   int const flag = ((i == node->nobj) ? true : false);
      mov       eax, 1
      mov       DWORD [rbp - 32], eax
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rdi + b_node.nobj]
      cmp       QWORD [rbp - 40], rax
      je        .i_eq_nobj
      xor       eax, eax
      mov       DWORD [rbp - 32], eax
.i_eq_nobj:
;   if (node->child[i]->nobj < node->tree->mindeg)
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rsi + b_tree.mindeg]
      push      rax
      mov       rsi, QWORD [rbp - 40]
      call      b_child_at
      mov       rdi, QWORD [rax]
      pop       rax
      cmp       QWORD [rdi + b_node.nobj], rax
      jae       .end_if
;     b_fill(node, i);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 40]
      call      b_fill
.end_if:
;   if (flag && i > node->nobj)
      mov       eax, DWORD [rbp - 32]
      test      eax, eax
      jz        .else_3
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rbp - 40]
      cmp       rax, QWORD [rdi + b_node.nobj]
      jbe       .else_3
;     b_delete(node->child[i - 1], key);
      dec       rax
      mov       rsi, rax
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rsi, QWORD [rbp - 16]
      call      b_delete
      jmp       .epilogue
;   else
.else_3:
;     b_delete(node->child[i], key);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 40]
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rsi, QWORD [rbp - 16]
      call      b_delete
; }
.epilogue:
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_delete_from_leaf (b_node_t *node, size_t const i);
;
; param:
;
;   rdi = node
;   rsi = i
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (i)
;   QWORD [rbp - 24]  = (size_t o_size)
;   QWORD [rbp - 32]  = rbx (callee saved)
;-------------------------------------------------------------------------------
;
      static b_delete_from_leaf
b_delete_from_leaf:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 40
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 32], rbx
;   QWORD [rbp - 24]  = (size_t o_size)
      mov       rbx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rbx + b_tree.o_size]
      mov       QWORD [rbp - 24], rax
; node->tree->o_del_cb(&node->object[i]);
      call      b_object_at
      push      rax
      mov       rax, QWORD [rdi + b_node.tree]
      mov       rcx, QWORD [rax + b_tree.o_del_cb]
      pop       rdi
      ALIGN_STACK_AND_CALL rbx, rcx
; for (int x = i + 1; x < node->nobj; ++x) {
      mov       rbx, QWORD [rbp - 16]
.shift_object_loop:
      mov       rdi, QWORD [rbp - 8]
      inc       rbx   ; covers both: x = i + 1 and ++x
      cmp       rbx, QWORD [rdi + b_node.nobj]
      jae       .shift_object_break
;   node->object[x - 1] = node->object[x];
      mov       rsi, rbx 
      call      b_object_at
      push      rax
      dec       rsi
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 24]
      call      memmove64 wrt ..plt
      jmp       .shift_object_loop
; }
.shift_object_break:
; node->nobj -= 1;
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rdi + b_node.nobj]
      dec       rax
      mov       QWORD [rdi + b_node.nobj], rax
; epilogue
      mov       rbx, QWORD [rbp - 32]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_delete_from_non_leaf (b_node_t *node, size_t const i);
;
; param:
;
;   rdi = node
;   rsi = i
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (i)
;   QWORD [rbp - 24]  = (child)
;   QWORD [rbp - 32]  = (sibling)
;   QWORD [rbp - 40]  = (size_t o_size)
;   QWORD [rbp - 48]  = (size_t mindeg)
;   QWORD [rbp - 56]  = (object_t *prev, *next)
;   QWORD [rbp - 64]  = (object_t *target)
;   QWORD [rbp - 72]  = rbx (callee saved)
;-------------------------------------------------------------------------------
;
      static b_delete_from_non_leaf
b_delete_from_non_leaf:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 72
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 72], rbx
; if ((target = calloc(1, node->tree->o_size)) == NULL) return;
      mov       rbx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rbx + b_tree.o_size]
      mov       rdi, 1
      mov       rsi, rax
      ALIGN_STACK_AND_CALL rbx, calloc, wrt, ..plt
      mov       QWORD [rbp - 64], rax
      test      rax, rax
      jz        .epilogue
; b_node_t *child = node->child[i];
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      call      b_child_at
      mov       rbx, QWORD [rax]
      mov       QWORD [rbp - 24], rbx
; b_node_t *sibling = node->child[i + 1];
      inc       rsi
      call      b_child_at
      mov       rbx, QWORD [rax]
      mov       QWORD [rbp - 32], rbx
; size_t o_size = node->tree->o_size;
      mov       rbx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rbx + b_tree.o_size]
      mov       QWORD [rbp - 40], rax
; size_t mindeg = node->tree->mindeg;
      mov       rax, QWORD [rbx + b_tree.mindeg]
      mov       QWORD [rbp - 48], rax
; memmove64(target, &node->object[i], node->tree->o_size);
      mov       rsi, QWORD [rbp - 16]
      call      b_object_at
      mov       rsi, rax
      mov       rdi, QWORD [rbp - 64]
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
; if (node->child[i]->nobj >= node->tree->mindeg) {
      mov       rax, QWORD [rbp - 48]
      mov       rdi, QWORD [rbp - 24]
      cmp       QWORD [rdi + b_node.nobj], rax
      jb        .else_if
;   if ((prev = calloc(1, node->tree->o_size)) == NULL) return;
      mov       rdi, QWORD [rbp - 8]
      mov       rbx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rbx + b_tree.o_size]
      mov       rdi, 1
      mov       rsi, rax
      ALIGN_STACK_AND_CALL rbx, calloc, wrt, ..plt
      mov       QWORD [rbp - 56], rax
      test      rax, rax
      jz        .penultimate
;   node->tree->o_del_cb(&target);  // call delete object callback on (i)th object
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rdi + b_node.tree]
      mov       rcx, QWORD [rax + b_tree.o_del_cb]
      mov       rdi, QWORD [rbp - 64]
      ALIGN_STACK_AND_CALL rbx, rcx
;   memmove64(prev, b_prev_object(node, i), node->tree->o_size);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      call      b_prev_object
      mov       rsi, rax
      mov       rdi, QWORD [rbp - 56]
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
;   memmove64(&node->object[i], prev, node->tree->o_size);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      call      b_object_at
      mov       rdi, rax
      mov       rsi, QWORD [rbp - 56]
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
;   b_delete(child, node->tree->k_get_cb(prev));
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rdi + b_node.tree]
      mov       rcx, QWORD [rax + b_tree.k_get_cb]
      mov       rdi, QWORD [rbp - 56]
      ALIGN_STACK_AND_CALL rbx, rcx
      mov       rsi, rax
      mov       rdi, QWORD [rbp - 24]
      call      b_delete
;   free(prev);
      mov       rdi, QWORD [rbp - 56]
      ALIGN_STACK_AND_CALL rbx, free, wrt, ..plt
      jmp       .penultimate
; } else if (sibling->nobj >= node->tree->mindeg) {
.else_if:
      mov       rax, QWORD [rbp - 48]
      mov       rdi, QWORD [rbp - 32]
      cmp       QWORD [rdi + b_node.nobj], rax
      jb        .else
;   if ((next = calloc(1, node->tree->o_size)) == NULL) return;
      mov       rdi, QWORD [rbp - 8]
      mov       rbx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rbx + b_tree.o_size]
      mov       rdi, 1
      mov       rsi, rax
      ALIGN_STACK_AND_CALL rbx, calloc, wrt, ..plt
      mov       QWORD [rbp - 56], rax
      test      rax, rax
      jz        .penultimate
;   node->tree->o_del_cb(&target);  // call delete object callback on (i)th object
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rdi + b_node.tree]
      mov       rcx, QWORD [rax + b_tree.o_del_cb]
      mov       rdi, QWORD [rbp - 64]
      ALIGN_STACK_AND_CALL rbx, rcx
;   memmove64(next, b_next_object(node, i), node->tree->o_size);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      call      b_next_object
      mov       rsi, rax
      mov       rdi, QWORD [rbp - 56]
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
;   memmove64(&node->object[i], next, node->tree->o_size);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      call      b_object_at
      mov       rdi, rax
      mov       rsi, QWORD [rbp - 56]
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
;   b_delete(sibling, node->tree->k_get_cb(next));
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rdi + b_node.tree]
      mov       rcx, QWORD [rax + b_tree.k_get_cb]
      mov       rdi, QWORD [rbp - 56]
      ALIGN_STACK_AND_CALL rbx, rcx
      mov       rsi, rax
      mov       rdi, QWORD [rbp - 32]
      call      b_delete
;   free(next);
      mov       rdi, QWORD [rbp - 56]
      ALIGN_STACK_AND_CALL rbx, free, wrt, ..plt
      jmp       .penultimate
; }
; else {
.else:
;   b_merge(node, i);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      call      b_merge
;   b_delete(child, node->tree->k_get_cb(target));
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rdi + b_node.tree]
      mov       rcx, QWORD [rax + b_tree.k_get_cb]
      mov       rdi, QWORD [rbp - 64]
      ALIGN_STACK_AND_CALL rbx, rcx
      mov       rsi, rax
      mov       rdi, QWORD [rbp - 24]
      call      b_delete
; }
.penultimate:
      mov       rdi, QWORD [rbp - 64]
      ALIGN_STACK_AND_CALL rbx, free, wrt, ..plt
.epilogue:
      mov       rbx, QWORD [rbp - 72]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_fill (b_node_t *node, size_t const i);
;
; param:
;
;   rdi = node
;   rsi = i
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (i)
;   QWORD [rbp - 24]  = (size_t mindeg)
;-------------------------------------------------------------------------------
;
      static b_fill
b_fill:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 24
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
; size_t mindeg = node->tree->mindeg;
      mov       rcx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rcx + b_tree.mindeg]
      mov       QWORD [rbp - 24], rax
; if (i != 0 && node->child[i - 1]->nobj >= node->tree->mindeg) {
      test      rsi, rsi
      jz        .else_if
      dec       rsi
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rax, QWORD [rdi + b_node.nobj]
      cmp       rax, QWORD [rbp - 24]
      jb        .else_if
;   b_borrow_from_prev(node, i);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      call      b_borrow_from_prev
      jmp       .epilogue
; } else if (i != node->nobj &&
;           node->child[i + 1]->nobj >= node->tree->mindeg) {
.else_if:
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      cmp       rsi, QWORD [rdi + b_node.nobj]
      je        .else
      inc       rsi
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rax, QWORD [rdi + b_node.nobj]
      cmp       rax, QWORD [rbp - 24]
      jb        .else
;   b_borrow_from_next(node, i);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      call      b_borrow_from_next
      jmp       .epilogue
; }
.else:
; else {
;   if (i != node->nobj)
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      cmp       rsi, QWORD [rdi + b_node.nobj]
      je        .else_2
;     b_merge(node, i);
      call      b_merge
      jmp       .epilogue
.else_2:
;   else
;     b_merge(node, i - 1);
      dec       rsi
      call      b_merge
; }
.epilogue:
      mov       rsp, rbp
      pop       rbp
      ret
;-------------------------------------------------------------------------------
; C definition:
;
;   size_t b_find_key (b_node_t *node, void const *key, int *cond)
;
; param:
;
;   rdi = node
;   rsi = key
;   rdx = cond
;
; return:
;
;   rax = index
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (key)
;   QWORD [rbp - 24]  = rdx (cond)
;   QWORD [rbp - 32]  = (k_cmp_cb)
;   QWORD [rbp - 40]  = (ssize_t lo)
;   QWORD [rbp - 48]  = (ssize_t hi)
;   QWORD [rbp - 56]  = (size_t mid)
;   QWORD [rbp - 64]  = (size_t alt_mid)
;   QWORD [rbp - 72]  = rbx (callee saved)
;-------------------------------------------------------------------------------
;
      static b_find_key
b_find_key:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 72
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 24], rdx
      mov       QWORD [rbp - 72], rbx
; if (node->nobj <= 9) return b_hunt_key(node, key, cond);
      cmp       QWORD [rdi + b_node.nobj], HUNT_MAX
      ja        .no_hunting
      call      b_hunt_key
      jmp       .epilogue
.no_hunting:
; b_compare_cb k_cmp_cb = node->tree->k_cmp_cb;
      mov       rbx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rbx + b_tree.k_cmp_cb]
      mov       QWORD [rbp - 32], rax
; ssize_t lo = 0;
      xor       rax, rax
      mov       QWORD [rbp - 40], rax
; size_t alt_mid = node->nobj;
      mov       rax, QWORD [rdi + b_node.nobj]
      mov       QWORD [rbp - 64], rax
; ssize_t hi = node->nobj - 1;
      dec       rax
      mov       QWORD [rbp - 48], rax
; while (lo <= hi) {
.loop:
      cmp       QWORD [rbp - 40], rax
      jg        .break
;   size_t mid = (lo + hi) / 2;
      xor       rdx, rdx
      add       rax, QWORD [rbp - 40]
      shr       rax, 1
      mov       QWORD [rbp - 56], rax
;   *cond = node->tree->k_cmp_cb(key, &node->object[mid]);
      mov       rsi, rax
      call      b_object_at
      mov       rsi, rax
      mov       rdi, QWORD [rbp - 16]
      mov       rcx, QWORD [rbp - 32]
      ALIGN_STACK_AND_CALL rbx, rcx
      mov       rcx, QWORD [rbp - 24]
      mov       DWORD [rcx], eax
;   if (*cond == 0) return mid;
      test      eax, eax
      jnz       .else_if
      mov       rax, QWORD [rbp - 56]
      jmp       .epilogue
;   else if (*cond < 0) {
.else_if:
      cmp       eax, 0
      jge       .else
;     alt_mid = mid;
      mov       rax, QWORD [rbp - 56]
      mov       QWORD [rbp - 64], rax
;     hi = mid - 1;
      dec       rax
      mov       QWORD [rbp - 48], rax
      jmp       .cont_01
;   } else lo = mid + 1;
.else:
      mov       rax, QWORD [rbp - 56]
      inc       rax
      mov       QWORD [rbp - 40], rax
.cont_01:
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rbp - 48]
      jmp       .loop
; }
.break:
; return alt_mid;
      mov       rax, QWORD [rbp - 64]
.epilogue:
      mov       rbx, QWORD [rbp - 72]
      mov       rsp, rbp
      pop       rbp
      ret
;-------------------------------------------------------------------------------
; C definition:
;
;   size_t b_hunt_key (b_node_t *node, void const *key, int *cond)
;
; param:
;
;   rdi = node
;   rsi = key
;   rdx = cond
;
; return:
;
;   rax = index
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (key)
;   QWORD [rbp - 24]  = rdx (cond)
;   QWORD [rbp - 32]  = (b_compare_cb k_cmp_cb)
;   QWORD [rbp - 40]  = (size_t i)
;   QWORD [rbp - 48]  = rbx (callee saved)
;-------------------------------------------------------------------------------
;
      static b_hunt_key
b_hunt_key:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 56
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 24], rdx
      mov       QWORD [rbp - 48], rbx
; b_compare_cb k_cmp_cb = node->tree->k_cmp_cb;
      mov       rsi, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rsi + b_tree.k_cmp_cb]
      mov       QWORD [rbp - 32], rax
; size_t i = 0;
      xor       rax, rax
      mov       QWORD [rbp - 40], rax
; while (i < node->nobj &&
;     (*cond = node->tree->k_cmp_cb(key, &node->object[i])) > 0)
.loop:
      cmp       rax, QWORD [rdi + b_node.nobj]
      jae       .break
      mov       rsi, rax
      call      b_object_at
      mov       rsi, rax
      mov       rdi, QWORD [rbp - 16]
      mov       rcx, QWORD [rbp - 32]
      ALIGN_STACK_AND_CALL rbx, rcx
      mov       rcx, QWORD [rbp - 24]
      mov       DWORD [rcx], eax
      cmp       eax, 0
      jle       .break
;   ++i;
      inc       QWORD [rbp - 40]
      mov       rax, QWORD [rbp - 40]
      mov       rdi, QWORD [rbp - 8]
      jmp       .loop
.break:
; return i;
      mov       rax, QWORD [rbp - 40]
.epilogue:
      mov       rbx, QWORD [rbp - 48]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   int b_insert (b_tree_t *tree, void const *object);
;
; param:
;   rdi = tree
;   rsi = object
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (tree)
;   QWORD [rbp - 16]  = rsi (object)
;   QWORD [rbp - 24]  = (b_node_t *root)
;   QWORD [rbp - 32]  = (size_t i)
;   DWORD [rbp - 40]  = (int retval)
;   QWORD [rbp - 48]  = rbx (callee saved)
;-------------------------------------------------------------------------------
;
      global b_insert:function
b_insert:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 56
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 48], rbx
; int retval = 0;
      xor       eax, eax
      mov       DWORD [rbp - 40], eax
; ; if (b_probe(tree->root, key) == 0) retval = -1;
      mov       rdi, QWORD [rbp - 8]
      mov       rcx, [rdi + b_tree.k_get_cb]
      mov       rdi, QWORD [rbp - 16]
      ALIGN_STACK_AND_CALL rbx, rcx
      mov       rsi, rax
      mov       rdi, QWORD [rbp - 8]
      mov       rax, [rdi + b_tree.root]
      mov       rdi, rax
      call      b_probe
      test      eax, eax
      jnz       .end_if_1
      mov       eax, -1
      mov       DWORD [rbp - 40], eax
      jmp       .epilogue
.end_if_1:
; if (tree->root == NULL) {
      mov       rdi, QWORD [rbp - 8]
      xor       rax, rax
      cmp       QWORD [rdi + b_tree.root], rax
      jne       .else
;   tree->root = b_node_alloc();
      mov       rdi, 1
      mov       rsi, b_node_size
      ALIGN_STACK_AND_CALL rbx, calloc, wrt, ..plt
      mov       rdi, QWORD [rbp - 8]
      mov       QWORD [rdi + b_tree.root], rax
;   b_node_init(tree->root, tree, true);
      mov       edx, 1
      mov       rsi, QWORD [rbp - 8]
      mov       rdi, QWORD [rdi + b_tree.root]
      call      b_node_init
;   (void)memmove64(tree->root->object, object, tree->o_size);
      mov       rdi, QWORD [rbp - 8]
      mov       rdx, QWORD [rdi + b_tree.o_size]
      mov       rsi, QWORD [rbp - 16]
      mov       rdi, QWORD [rdi + b_tree.root]
      mov       rdi, QWORD [rdi + b_node.object]
      call      memmove64 wrt ..plt
;   tree->root->nobj = 1;
      mov       rax, 1
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rdi + b_tree.root]
      mov       QWORD [rsi + b_node.nobj], rax
      jmp       .epilogue
; } else {
.else:
;   if (tree->root->nobj >= (tree->mindeg * 2 - 1)) {
      mov       rax, QWORD [rdi + b_tree.mindeg]
      mov       rcx, 2
      mul       rcx
      dec       rax
      mov       rsi, QWORD [rdi + b_tree.root]
      cmp       QWORD [rsi + b_node.nobj], rax
      jb        .else_2
;     b_node_t *root = b_node_alloc();
      mov       rdi, 1
      mov       rsi, b_node_size
      ALIGN_STACK_AND_CALL rbx, calloc, wrt, ..plt
      mov       QWORD [rbp - 24], rax
;     b_node_init(root, tree, false);
      xor       edx, edx
      mov       rsi, QWORD [rbp - 8]
      mov       rdi, rax
      call      b_node_init
;     root->child[0] = tree->root;
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rdi + b_tree.root]
      mov       rdi, QWORD [rbp - 24]
      mov       rsi, QWORD [rdi + b_node.child]
      mov       QWORD [rsi], rax
;     b_split_child(root, 0, tree->root);
      mov       rdi, QWORD [rbp - 8]
      mov       rdx, QWORD [rdi + b_tree.root]
      xor       rsi, rsi
      mov       rdi, QWORD [rbp - 24]
      call      b_split_child
;     size_t i = 0;
      xor       rax, rax
      mov       QWORD [rbp - 32], rax
;     if (tree->o_cmp_cb(root->object, object) < 0)
      mov       rdi, QWORD [rbp - 8]
      mov       rcx, QWORD [rdi + b_tree.o_cmp_cb]
      mov       rsi, QWORD [rbp - 16]
      mov       rdi, QWORD [rbp - 24]
      mov       rdi, QWORD [rdi + b_node.object]
      ALIGN_STACK_AND_CALL rbx, rcx
      test      eax, eax
      jns       .skip_inc
;       ++i;
      inc       QWORD [rbp - 32]
.skip_inc:
;     b_insert_non_full(root->child[i], object);
      mov       rdi, QWORD [rbp - 24]
      mov       rsi, QWORD [rbp - 32]
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rsi, QWORD [rbp - 16]
      call      b_insert_non_full
;     tree->root = root;
      mov       rax, QWORD [rbp - 24]
      mov       rdi, QWORD [rbp - 8]
      mov       QWORD [rdi + b_tree.root], rax
      jmp       .epilogue
;   } else
.else_2:
;     b_insert_non_full(tree->root, object);
      mov       rsi, QWORD [rbp - 16]
      mov       rdi, QWORD [rbp - 8]
      mov       rdi, QWORD [rdi + b_tree.root]
      call      b_insert_non_full
; }
.epilogue:
      mov       eax, DWORD [rbp - 40]
      mov       rbx, QWORD [rbp - 48]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_insert_non_full (b_node_t *node, void const *object);
;
; param:
;   rdi = node
;   rsi = object
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (object)
;   QWORD [rbp - 24]  = (ssize_t i)
;   QWORD [rbp - 32]  = (b_compare_cb o_cmp_cb)
;   QWORD [rbp - 40]  = (size_t o_size)
;   QWORD [rbp - 48]  = rbx (callee saved)
;   QWORD [rbp - 56]  = r12 (callee saved)
;-------------------------------------------------------------------------------
;
      static b_insert_non_full
b_insert_non_full:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 56
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 48], rbx
      mov       QWORD [rbp - 56], r12
; b_compare_cb o_cmp_cb = node->tree->o_cmp_cb
      mov       rbx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rbx + b_tree.o_cmp_cb]
      mov       QWORD [rbp - 32], rax
; size_t o_size = node->tree->o_size;
      mov       rax, QWORD [rbx + b_tree.o_size]
      mov       QWORD [rbp - 40], rax
; ssize_t i = node->nobj -1 ;
      mov       rax, QWORD [rdi + b_node.nobj]
      dec       rax
      mov       QWORD [rbp - 24], rax
; if (node->leaf == true) {
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jz        .else
;   for (; i >= 0 && node->tree->o_cmp_cb(&node->object[i], object) > 0; --i) {
      mov       rbx, QWORD [rbp - 24]
.object_move_loop:
      cmp       rbx, 0
      jl        .object_move_break
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, rbx
      call      b_object_at
      mov       rdi, rax
      mov       rsi, QWORD [rbp - 16]
      mov       rcx, QWORD [rbp - 32]
      ALIGN_STACK_AND_CALL r12, rcx
      cmp       eax, 0
      jle       .object_move_break
;     node->object[i + 1] = node->object[i];
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, rbx
      call      b_object_at
      push      rax
      inc       rsi
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
      dec       rbx
      mov       QWORD [rbp - 24], rbx
      jmp       .object_move_loop
;   }
.object_move_break:
;   (void)memmove64(node->object[i + 1], object, node->tree->o_size);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 24]
      inc       rsi
      call      b_object_at
      mov       rdi, rax
      mov       rsi, QWORD [rbp - 16]
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
;   node->nobj += 1;
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rdi + b_node.nobj]
      inc       rax
      mov       QWORD [rdi + b_node.nobj], rax
      jmp       .epilogue
; } else {
.else:
;   while (i >= 0 && node->tree->o_cmp_cb(&node->object[i], object) > 0)
.child_find_loop:
      mov       rbx, QWORD [rbp - 24]
      cmp       rbx, 0
      jl        .child_find_break
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, rbx
      call      b_object_at
      mov       rdi, rax
      mov       rsi, QWORD [rbp - 16]
      mov       rcx, QWORD [rbp - 32]
      ALIGN_STACK_AND_CALL r12, rcx
      cmp       eax, 0
      jle       .child_find_break
;     --i;
      dec       rbx
      mov       QWORD [rbp - 24], rbx
      jmp       .child_find_loop
.child_find_break:
;   if (node->child[i + 1]->nobj == node->tree->mindeg * 2 - 1) {
      mov       rdi, QWORD [rbp - 8]
      mov       rbx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rbx + b_tree.mindeg]
      mov       rbx, 2
      mul       rbx
      dec       rax
      push      rax
      mov       rsi, QWORD [rbp - 24]
      inc       rsi
      call      b_child_at
      mov       rsi, QWORD [rax]
      mov       rax, QWORD [rsi + b_node.nobj]
      pop       rbx
      cmp       rax, rbx
      jne       .end_if
;     b_split_child(node, (i + 1), node->child[i + 1]);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 24]
      inc       rsi
      call      b_child_at
      mov       rdx, QWORD [rax]
      call      b_split_child
;     if (node->tree->o_cmp_cb(&node->object)[i + 1], object) < 0)
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 24]
      inc       rsi
      call      b_object_at
      mov       rdi, rax
      mov       rsi, QWORD [rbp - 16]
      mov       rcx, QWORD [rbp - 32]
      ALIGN_STACK_AND_CALL r12, rcx
      cmp       eax, 0
      jge       .skip_inc
;       i++;
      inc       QWORD [rbp - 24]
.skip_inc:
;   }
.end_if:
;   b_insert_non_full(node->child[i + 1], object);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 24]
      inc       rsi
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rsi, QWORD [rbp - 16]
      call      b_insert_non_full
; }
.epilogue:
      mov       rbx, QWORD [rbp - 48]
      mov       r12, QWORD [rbp - 56]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_merge (b_node_t *node, size_t const i);
;
; param:
;
;   rdi = node
;   rsi = i
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (i)
;   QWORD [rbp - 24]  = (child)
;   QWORD [rbp - 32]  = (sibling)
;   QWORD [rbp - 40]  = (size_t o_size)
;   QWORD [rbp - 48]  = (size_t mindeg)
;   QWORD [rbp - 56]  = rbx (callee saved)
;-------------------------------------------------------------------------------
;
      static b_merge
b_merge:
      push      rbp
      mov       rbp, rsp
      sub       rsp, 56
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 56], rbx
; b_node_t *child = node->child[i];
      call      b_child_at
      mov       rbx, QWORD [rax]
      mov       QWORD [rbp - 24], rbx
; b_node_t *sibling = node->child[i + 1];
      inc       rsi
      call      b_child_at
      mov       rbx, QWORD [rax]
      mov       QWORD [rbp - 32], rbx
; size_t o_size = node->tree->o_size;
      mov       rbx, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rbx + b_tree.o_size]
      mov       QWORD [rbp - 40], rax
; size_t mindeg = node->tree->mindeg;
      mov       rax, QWORD [rbx + b_tree.mindeg]
      mov       QWORD [rbp - 48], rax
; child->object[mindeg - 1] = node->object[i];
      mov       rsi, QWORD [rbp - 16]
      call      b_object_at
      push      rax
      mov       rdi, QWORD [rbp - 24]
      mov       rsi, QWORD [rbp - 48]
      dec       rsi
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
; for (size_t x = 0; x < sibling->nobj; ++x) {
      xor       rbx, rbx
.for_loop_1:
      mov       rdi, QWORD [rbp - 32]
      cmp       rbx, QWORD [rdi + b_node.nobj]
      jae       .for_break_1
;   child->object[x + mindeg] = sibling->object[x]
      mov       rsi, rbx
      call      b_object_at
      push      rax
      mov       rdi, QWORD [rbp - 24]
      add       rsi, QWORD [rbp - 48]
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
      inc       rbx
      jmp       .for_loop_1
; }
.for_break_1:
; if (child->leaf == false) {
      mov       rdi, QWORD [rbp - 24]
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .child_is_leaf
;   for (size_t x = 0; x <= sibling->nobj; ++x) {
      xor       rbx, rbx
.for_loop_2:
      mov       rdi, QWORD [rbp - 32]
      cmp       rbx, QWORD [rdi + b_node.nobj]
      ja        .for_break_2
;     child->child[x + mindeg] = sibling->child[x];
      mov       rsi, rbx
      call      b_child_at
      push      QWORD [rax]
      mov       rdi, QWORD [rbp - 24]
      add       rsi, QWORD [rbp - 48]
      call      b_child_at
      pop       QWORD [rax]
      inc       rbx
      jmp       .for_loop_2
;   }
.for_break_2:
; }
.child_is_leaf:
;
; for (size_t x = i + 1; x < node->nobj; ++x) {
      mov       rbx, QWORD [rbp - 16]
      inc       rbx
.for_loop_3:
      mov       rdi, QWORD [rbp - 8]
      cmp       rbx, QWORD [rdi + b_node.nobj]
      jae       .for_break_3
;   node->object[x - 1] = node->object[x];
      mov       rsi, rbx
      call      b_object_at
      push      rax
      dec       rsi
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
      inc       rbx
      jmp       .for_loop_3
.for_break_3:
; }
;
; for (size_t x = i + 2; x <= node->nobj; ++x) {
      mov       rbx, QWORD [rbp - 16]
      inc       rbx
      inc       rbx
.for_loop_4:
      mov       rdi, QWORD [rbp - 8]
      cmp       rbx, QWORD [rdi + b_node.nobj]
      ja        .for_break_4
;   node->child[x - 1] = node->child[x];
      mov       rsi, rbx
      call      b_child_at
      push      QWORD [rax]
      dec       rsi
      call      b_child_at
      pop       QWORD [rax]
      inc       rbx
      jmp       .for_loop_4
; }
.for_break_4:
; child->nobj += sibling->nobj + 1;
      mov       rdi, QWORD [rbp - 32]
      mov       rax, QWORD [rdi + b_node.nobj]
      inc       rax
      mov       rdi, QWORD [rbp - 24]
      mov       rcx, QWORD [rdi + b_node.nobj]
      add       rax, rcx
      mov       QWORD [rdi + b_node.nobj], rax
; node->nobj -= 1;
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rdi + b_node.nobj]
      dec       rax
      mov       QWORD [rdi + b_node.nobj], rax
; b_node_term(sibling);
      mov       rdi, QWORD [rbp - 32]
      call      b_node_term
; b_node_free(sibling);
      mov       rdi, QWORD [rbp - 32]
      ALIGN_STACK_AND_CALL rbx, free, wrt, ..plt
; epilogue
      mov       rbx, QWORD [rbp - 56]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void * b_next_object (b_node_t *node, size_t const i)
;
; param:
;
;   rdi = node
;   rsi = i
;-------------------------------------------------------------------------------
;
      static b_next_object
b_next_object:
; b_node_t *nc = nn->child[i + 1]
      mov       rax, rsi
      inc       rax
      mov       rcx, QW_SIZE
      mul       rcx
      add       rax, QWORD [rdi + b_node.child]
      mov       rdi, QWORD [rax]
; while (nc->leaf == false) nc = nc->child[0]
.loop:
      movzx     ecx, BYTE [rdi + b_node.leaf]
      test      ecx, ecx
      jnz       .leaf_node
      mov       rax, QWORD [rdi + b_node.child]
      mov       rdi, QWORD [rax]
      jmp       .loop
.leaf_node:
; return nc->object
      mov       rax, QWORD [rdi + b_node.object]
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_node_init (b_node_t *node, b_tree_t *tree, uint32_t const leaf);
;
; param:
;
;   rdi = node
;   rsi = tree
;   edx = leaf
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = (size_t max_child)
;   QWORD [rbp - 24]  = (size_t max_object)
;   QWORD [rbp - 32]  = (size_t buf_size)
;   QWORD [rbp - 40]  = rbx (callee saved)
;-------------------------------------------------------------------------------
;
      static b_node_init
b_node_init:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 40
      push      rbx
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 40], rbx
; node->leaf = leaf
      mov       BYTE [rdi + b_node.leaf], dl
; node->nobj = 0
      xor       rax, rax
      mov       QWORD [rdi + b_node.nobj], rax
; node->tree = tree
      mov       QWORD [rdi + b_node.tree], rsi
; size_t max_child = 0
      mov       QWORD [rbp - 16], rax
; if (leaf == false) max_child = tree->mindeg * 2
      test      edx, edx
      jnz       .leaf_node
      mov       rax, QWORD [rsi + b_tree.mindeg]
      mov       rcx, QWORD 2
      mul       rcx
      mov       QWORD [rbp - 16], rax
.leaf_node:
; max_object = tree->mindeg * 2 - 1
      mov       rax, QWORD [rsi + b_tree.mindeg]
      mov       rcx, QWORD 2
      mul       rcx
      dec       rax
      mov       QWORD [rbp - 24], rax
; size_t bufsize = (sizeof(b_node_t *) * max_child)
;   + (tree->o_size * max_object)
      mov       rax, QWORD [rbp - 16]
      mov       rcx, QW_SIZE
;      mov       rcx, b_node_size
      mul       rcx
      mov       QWORD [rbp - 32], rax
      mov       rax, QWORD [rsi + b_tree.o_size]
      mul       QWORD [rbp - 24]
      add       QWORD [rbp - 32], rax
; node->child = NULL
      xor       rax, rax
      mov       QWORD [rdi + b_node.child], rax
; node->object = calloc(1, bufsize)
      mov       rsi, QWORD [rbp - 32]
      mov       rdi, 1
      ALIGN_STACK_AND_CALL rbx, calloc, wrt, ..plt
;      call    calloc wrt ..plt
      mov       rdi, QWORD [rbp - 8]
      mov       QWORD [rdi + b_node.object], rax
; if (leaf == false) {
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .epilogue
;   node->child = node->object
      mov       rax, QWORD [rdi + b_node.object]
      mov       QWORD [rdi + b_node.child], rax
;   node->object = &node->child[tree->mindeg * 2]
;   equation is: (node->child + ((tree->mindeg * 2) * sizeof(b_node_t *)))
      mov       rax, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rax + b_tree.mindeg]
      mov       rcx, 2
      mul       rcx
      mov       rcx, QW_SIZE
      mul       rcx
      add       rax, QWORD [rdi + b_node.child]
      mov       QWORD [rdi + b_node.object], rax
; }
.epilogue:
      mov       rbx, QWORD [rbp - 40]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_node_term (b_node_t *node);
;
; param:
;
;   rdi = node
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rbx (callee saved)
;
;-------------------------------------------------------------------------------
;
      static b_node_term
b_node_term:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 16
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rbx
; if (node->leaf == true) free(n->object)
; else free(n->child)
      mov       rcx, QWORD [rdi + b_node.child]
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jz        .non_leaf
      mov       rcx, QWORD [rdi + b_node.object]
.non_leaf:
      mov       rdi, rcx
      ALIGN_STACK_AND_CALL r12, free, wrt, ..plt
; (void) memset(n, 0, sizeof(b_node_t))
      mov       rdi, QWORD [rbp - 8]
      xor       rsi, rsi
      mov       rdx, b_node_size
      ALIGN_STACK_AND_CALL r12, memset, wrt, ..plt
; epilogue
      mov       rbx, QWORD [rbp - 16]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_object_at (b_node_t *node, size_t const i);
;
; param:
;
; rdi = node
; rsi = i
;-------------------------------------------------------------------------------
;
      static b_object_at
b_object_at:
; return node->object[i]
      mov       rax, QWORD [rdi + b_node.tree] 
      mov       rax, QWORD [rax + b_tree.o_size]
      mul       rsi
      add       rax, QWORD [rdi + b_node.object]
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void * b_prev_object (b_node_t *node, size_t const i)
;
; param:
;
;   rdi = node
;   rsi = i
;-------------------------------------------------------------------------------
;
      static b_prev_object
b_prev_object:
; b_node_t *nc = nn->child[i];
      mov       rax, rsi
      mov       rcx, QW_SIZE
      mul       rcx
      add       rax, QWORD [rdi + b_node.child]
      mov       rdi, QWORD [rax]
; while (nc->leaf == false) nc = nc->child[nc->nobj]
.loop:
      movzx     ecx, BYTE [rdi + b_node.leaf]
      test      ecx, ecx
      jnz       .leaf_node
      mov       rax, QWORD [rdi + b_node.nobj]
      mov       rcx, QW_SIZE
      mul       rcx
      add       rax, QWORD [rdi + b_node.child]
      mov       rdi, QWORD [rax]
      jmp       .loop
.leaf_node:
; return &nc->object[nc->nobj - 1]
      mov       rax, QWORD [rdi + b_node.nobj]
      dec       rax
      mov       rcx, QWORD [rdi + b_node.tree]
      mul       QWORD [rcx + b_tree.o_size]
      add       rax, QWORD [rdi + b_node.object]
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   int b_probe (b_node_t *node, void const *key);
;
; param:
;
;   rdi = node
;   rsi = key
;   rdx = buffer
;
; return:
;
;   eax = 0 (success) | -1 (failure)
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (key)
;   QWORD [rbp - 24]  = (size_t i)
;   DWORD [rbp - 32]  = (int cond)
;   QWORD [rbp - 40]  = rbx (callee saved)
;-------------------------------------------------------------------------------
;
      static b_probe
b_probe:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 40
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 40], rbx
; if (node == NULL) return -1;
      mov       eax, -1
      mov       rcx, QWORD [rbp - 8]
      test      rcx, rcx
      jz        .epilogue
; int cond;
; size_t i = b_find_key(node, key, &cond);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      lea       rdx, [rbp - 32]
      call      b_find_key
      mov       QWORD [rbp - 24], rax
; if (i < node->nobj && cond == 0)
      mov       rdi, QWORD [rbp - 8]
      cmp       rax, QWORD [rdi + b_node.nobj]
      jae       .end_if_2
      mov       eax, DWORD [rbp - 32]
      test      eax, eax
      jnz       .end_if_2
;   return 0;
      xor       eax, eax
      jmp       .epilogue
.end_if_2:
; if (node->leaf == true) return -1;
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jz        .not_leaf
      mov       eax, -1
      jmp       .epilogue
.not_leaf:
; return b_probe(node->child[i], key);
      mov       rsi, QWORD [rbp - 24]
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rsi, QWORD [rbp - 16]
      call      b_probe
.epilogue:
      mov       rbx, QWORD [rbp - 40]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_remove (b_tree_t *tree, void const *key);
;
; param:
;
;   rdi = tree
;   rsi = key
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (tree)
;   QWORD [rbp - 16]  = rsi (key)
;   QWORD [rbp - 24]  = (old_root)
;-------------------------------------------------------------------------------
;
      global b_remove:function
b_remove:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 24
      push      r12
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
; if (tree->root == NULL) return;
      xor       rcx, rcx
      mov       rax, QWORD [rdi + b_tree.root]
      cmp       rax, rcx
      je        .epilogue
; b_delete(tree->root, key);
      mov       rdi, rax
      call      b_delete
; if (tree->root->nobj == 0) {
      xor       rax, rax
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rdi + b_tree.root]
      cmp       QWORD [rsi + b_node.nobj], rax
      jne       .epilogue
;   b_node_t *old_root = tree->root;
      mov       QWORD [rbp - 24], rsi
;   if (tree->root->leaf == true)
      movzx     eax, BYTE [rsi + b_node.leaf]
      test      eax, eax
      jz        .else
;     tree->root = NULL;
      xor       rax, rax
      mov       QWORD [rdi + b_tree.root], rax
      jmp       .end_if
;   else
.else:
;     tree->root = tree->root->child[0];
      mov       rax, QWORD [rsi + b_node.child]
      mov       rcx, QWORD [rax]
      mov       QWORD [rdi + b_tree.root], rcx
.end_if:
;   b_node_term(old_root);
      mov       rdi, QWORD [rbp - 24]
      call      b_node_term
;   b_node_free(old_root);
      mov       rdi, QWORD [rbp - 24]
      ALIGN_STACK_AND_CALL r12, free, wrt, ..plt
; }
.epilogue:
      pop     r12
      mov     rsp, rbp
      pop     rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void * b_search (b_node_t *node, void const *key, void *buffer);
;
; param:
;
;   rdi = node
;   rsi = key
;   rdx = buffer
;
; return:
;
;   rax = buffer
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (key)
;   QWORD [rbp - 24]  = rdx (buffer)
;   QWORD [rbp - 32]  = (size_t i)
;   DWORD [rbp - 40]  = (int cond)
;-------------------------------------------------------------------------------
;
      global b_search:function
b_search:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 40
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 24], rdx
; if (node == NULL) return NULL;
      mov       rax, rdi
      test      rax, rax
      jz        .epilogue
; int cond;
; size_t i = b_find_key(node, key, &cond);
      lea       rdx, [rbp - 40]
      call      b_find_key
      mov       QWORD [rbp - 32], rax
; if (i < node->nobj && cond == 0)
      mov       rdi, QWORD [rbp - 8]
      cmp       rax, QWORD [rdi + b_node.nobj]
      jae       .end_if
      mov       eax, DWORD [rbp - 40]
      test      eax, eax
      jnz       .end_if
; (void) memmove64(buffer, &node->object[i], node->tree->o_size);
      mov       rsi, QWORD [rbp - 32]
      call      b_object_at
      mov       rsi, rax
      mov       rax, QWORD [rdi + b_node.tree]
      mov       rdx, QWORD [rax + b_tree.o_size]
      mov       rdi, QWORD [rbp - 24]
      call      memmove64 wrt ..plt
;   return buffer;
      mov       rax, QWORD [rbp - 24]
      jmp       .epilogue
.end_if:
; if (node->leaf == true) return NULL;
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jz        .not_leaf
      xor       rax, rax
      jmp       .epilogue
.not_leaf:
; return b_search(node->child[i], key);
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 32]
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rsi, QWORD [rbp - 16]
      mov       rdx, QWORD [rbp - 24]
      call      b_search
.epilogue:
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_split_child (b_node_t *node, ssize_t const i, b_node_t *node_y);
;
; param:
;
;   rdi = node
;   rsi = i
;   rdx = node_y
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (i)
;   QWORD [rbp - 24]  = rdx (node_y)
;   QWORD [rbp - 32]  = (node_z)
;   QWORD [rbp - 40]  = (size_t o_size)
;   QWORD [rbp - 48]  = (size_t mindeg)
;   QWORD [rbp - 56]  = rbx (callee saved)
;-------------------------------------------------------------------------------
;
      static b_split_child
b_split_child:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 56
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 24], rdx
      mov       QWORD [rbp - 56], rbx
; size_t o_size = node->tree->o_size;
      mov       rsi, QWORD [rdi + b_node.tree]
      mov       rax, QWORD [rsi + b_tree.o_size]
      mov       QWORD [rbp - 40], rax
; size_t mindeg = node->tree->mindeg;
      mov       rax, QWORD [rsi + b_tree.mindeg]
      mov       QWORD [rbp - 48], rax
; b_node_t *node_z = b_node_alloc();
      mov       rdi, 1
      mov       rsi, b_node_size
      ALIGN_STACK_AND_CALL rbx, calloc, wrt, ..plt
      mov       QWORD [rbp - 32], rax
; b_node_init(node_z, node->tree, node_y->leaf);
      mov       rdi, QWORD [rbp - 24]
      movzx     edx, BYTE [rdi + b_node.leaf]
      mov       rsi, QWORD [rdi + b_node.tree]
      mov       rdi, QWORD [rbp - 32]
      call      b_node_init
; node_z->nobj = node->tree->mindeg - 1;
      mov       rax, QWORD [rbp - 48]
      dec       rax
      mov       rdi, QWORD [rbp - 32]
      mov       QWORD [rdi + b_node.nobj], rax
; for (size_t x = 0; x < node->tree->mindeg - 1; ++x) {
      xor       rbx, rbx;
.object_move_loop:
      mov       rax, QWORD [rbp - 48]
      dec       rax
      cmp       rbx, rax
      jae       .object_move_break
;   node_z->object[x] = node_y->object[x + node->tree->mindeg];
      mov       rax, rbx
      add       rax, QWORD [rbp - 48]
      mov       rsi, rax
      mov       rdi, QWORD [rbp - 24]
      call      b_object_at
      push      rax
      mov       rdi, QWORD [rbp - 32]
      mov       rsi, rbx
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
      inc       rbx
      jmp       .object_move_loop
; }
.object_move_break:
; if (node_y->leaf == false) {
      mov       rdi, QWORD [rbp - 24]
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .node_y_is_leaf
;   for (size_t x = 0; x < node->tree->mindeg; ++x) {
      xor       rbx, rbx
.child_move_loop:
      cmp       rbx, [rbp - 48]
      jae       .child_move_break;
;     node_z->child[x] = node_y->child[x + node->tree->mindeg];
      mov       rax, rbx
      add       rax, QWORD [rbp - 48]
      mov       rsi, rax
      mov       rdi, QWORD [rbp - 24]
      call      b_child_at
      push      QWORD [rax]
      mov       rdi, QWORD [rbp - 32]
      mov       rsi, rbx
      call      b_child_at
      pop       QWORD [rax]
      inc       rbx
      jmp       .child_move_loop
;   }
.child_move_break:
; }
.node_y_is_leaf:
; node_y->nobj = node_y->tree->mindeg - 1;
      mov       rax, QWORD [rbp - 48]
      dec       rax
      mov       rdi, QWORD [rbp - 24]
      mov       QWORD [rdi + b_node.nobj], rax
; for (ssize_t x = node->nobj; x >= i + 1; x--) {
      mov       rdi, QWORD [rbp - 8]
      mov       rbx, QWORD [rdi + b_node.nobj]
.child_move_loop_2:
      mov       rax, QWORD [rbp - 16]
      inc       rax
      cmp       rbx, rax
      jl        .child_move_break_2
;   node->child[x + 1] = node->child[x];
      mov       rsi, rbx
      call      b_child_at
      push      QWORD [rax]
      mov       rsi, rbx
      inc       rsi
      call      b_child_at
      pop       QWORD [rax]
      mov       rdi, QWORD [rbp - 8]
      dec       rbx
      jmp       .child_move_loop_2
; }
.child_move_break_2:
; node->child[i + 1] = node_z;
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      inc       rsi
      call      b_child_at
      mov       rbx, QWORD [rbp - 32]
      mov       QWORD [rax], rbx
; for (ssize_t x = node->nobj - 1; x >= i; x--)
      mov       rdi, QWORD [rbp - 8]
      mov       rbx, QWORD [rdi + b_node.nobj]
      dec       rbx
.object_move_loop_2:
      cmp       rbx, QWORD [rbp - 16]
      jl        .object_move_break_2
;   node->object[x + 1] = node->object[x];
      mov       rsi, rbx
      call      b_object_at
      push      rax
      inc       rsi
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
      dec       rbx
      mov       rdi, QWORD [rbp - 8]
      jmp       .object_move_loop_2
.object_move_break_2:
; (void)memmove64(&node->object[i], &node_y->object[node->tree->mindeg - 1],
;     node->tree->o_size);
      mov       rdi, QWORD [rbp - 24]
      mov       rax, QWORD [rbp - 48]
      dec       rax
      mov       rsi, rax
      call      b_object_at
      push      rax
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, QWORD [rbp - 16]
      call      b_object_at
      mov       rdi, rax
      pop       rsi
      mov       rdx, QWORD [rbp - 40]
      call      memmove64 wrt ..plt
; node->nobj += 1;
      mov       rdi, QWORD [rbp - 8]
      mov       rax, QWORD [rdi + b_node.nobj]
      inc       rax
      mov       QWORD [rdi + b_node.nobj], rax
.epilogue:
      mov       rbx, QWORD [rbp - 56]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_terminate (b_node_t *node, b_delete_cb o_del_cb);
;
; param:
;
;   rdi = node
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (b_delete_cb o_del_cb)
;   QWORD [rbp - 24]  = rbx (callee saved)
;   QWORD [rbp - 32]  = r12 (callee saved)
;-------------------------------------------------------------------------------
;
      static b_terminate
b_terminate:
; prologue:
      push      rbp
      mov       rbp, rsp
      sub       rsp, 40
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 24], rbx
      mov       QWORD [rbp - 32], r12
; size_t x;
; for (x = 0; x < node->nobj; x++) {
      xor       rbx, rbx
.loop:
      cmp       rbx, QWORD [rdi + b_node.nobj]
      jae       .break
;   if (node->leaf == false) b_terminate(node->child[x], o_del_cb)
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .leaf_node
      mov       rsi, rbx
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rsi, QWORD [rbp - 16]
      call      b_terminate
.leaf_node:
;   o_del_cb(&node->object)[i])
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, rbx
      call      b_object_at
      mov       rdi, rax
      mov       rcx, QWORD [rbp - 16]
      ALIGN_STACK_AND_CALL r12, rcx
      inc       rbx
      mov       rdi, QWORD [rbp - 8]
      jmp       .loop
; }
.break:
; if (node->leaf == false) b_terminate(node->child[i], o_del_cb);
      mov       rdi, QWORD [rbp - 8]
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .end_if
      mov       rsi, rbx
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rsi, QWORD [rbp - 16]
      call      b_terminate
.end_if:
; b_node_term(node);
      mov       rdi, QWORD [rbp - 8]
      call      b_node_term
; free(node);
      mov       rdi, QWORD [rbp - 8]
      ALIGN_STACK_AND_CALL r12, free, wrt, ..plt
.epilogue:
      mov       rbx, QWORD [rbp - 24]
      mov       r12, QWORD [rbp - 32]
      mov       rsp, rbp
      pop       rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_traverse (b_node_t *node, b_walk_cb walk_cb);
;
; param:
;
;   rdi = node
;   rsi = walk_cb
;
; stack:
;
;   QWORD [rbp - 8]   = rdi (node)
;   QWORD [rbp - 16]  = rsi (walk_cb)
;   QWORD [rbp - 24]  = rbx (callee saved)
;   QWORD [rbp - 32]  = r12 (callee saved)
;-------------------------------------------------------------------------------
;
      static b_traverse
b_traverse:
; prologue
      push      rbp
      mov       rbp, rsp
      sub       rsp, 40
      mov       QWORD [rbp - 8], rdi
      mov       QWORD [rbp - 16], rsi
      mov       QWORD [rbp - 24], rbx
      mov       QWORD [rbp - 32], r12
; for (i = 0; i < node->nobj; i++) {
      xor       rbx, rbx
.loop:
      cmp       rbx, QWORD [rdi + b_node.nobj]
      jae       .break
;   if (node->leaf == false) b_traverse(node->child[i], walk_cb)
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .leaf_node
      mov       rsi, rbx
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rsi, QWORD [rbp - 16]
      call      b_traverse
.leaf_node:
;   walk_cb(&nn->object)[i])
      mov       rdi, QWORD [rbp - 8]
      mov       rsi, rbx
      call      b_object_at
      mov       rdi, rax
      mov       rcx, QWORD [rbp - 16]
      ALIGN_STACK_AND_CALL r12, rcx
      inc       rbx
      mov       rdi, QWORD [rbp - 8]
      jmp       .loop
; }
.break:
; if (node->leaf == false) b_traverse(nn->child[i], walk_cb);
      mov       rdi, QWORD [rbp - 8]
      movzx     eax, BYTE [rdi + b_node.leaf]
      test      eax, eax
      jnz       .epilogue
      mov       rsi, rbx
      call      b_child_at
      mov       rdi, QWORD [rax]
      mov       rsi, QWORD [rbp - 16]
      call      b_traverse
.epilogue:
      mov       rbx, QWORD [rbp - 24]
      mov       r12, QWORD [rbp - 32]
      mov         rsp, rbp
      pop         rbp
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_tree_init (b_tree_t *tree, size_t const mindeg, size_t const o_size,
;                     b_compare_cb o_cmp_cb, b_compare_cb k_cmp_cb,
;                     b_delete_cb o_del_cb, b_get_key_cb k_get_cb);
;
; param:
;
;   rdi = tree
;   rsi = mindeg
;   rdx = o_size
;   rcx = o_cmp_cb
;   r8  = k_cmp_cb
;   r9  = o_del_cb
;   rsp = k_get_cb
;-------------------------------------------------------------------------------
;
      global b_tree_init:function
b_tree_init:
; prologue
      mov       QWORD [rdi + b_tree.mindeg], rsi
      mov       QWORD [rdi + b_tree.o_size], rdx
      mov       QWORD [rdi + b_tree.o_cmp_cb], rcx
      mov       QWORD [rdi + b_tree.k_cmp_cb], r8
      mov       QWORD [rdi + b_tree.o_del_cb], r9
      mov       rax, QWORD [rsp + 8]
      mov       QWORD [rdi + b_tree.k_get_cb], rax
; if (tree->mindeg < 2) tree->mindeg = 2;
      mov       rax, QWORD [rdi + b_tree.mindeg]
      cmp       rax, 2
      jae       .end_if
      mov       rax, 2
      mov       QWORD [rdi + b_tree.mindeg], rax
.end_if:
; align o_size to next 8-byte boundary
; ex: o_size = 8 align to 8
; ex: o_size = 20 align to 24
      mov       rax, QWORD [rdi + b_tree.o_size]
      add       rax, ALIGN_WITH_8
      and       rax, ALIGN_MASK_8
      mov       QWORD [rdi + b_tree.o_size], rax
;epilogue
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_tree_term (b_tree_t *tree);
;
; param:
;
;   rdi = tree
;-------------------------------------------------------------------------------
;
      global b_tree_term:function
b_tree_term:
; if (tree->root == NULL) return;
      mov       rax, QWORD [rdi + b_tree.root]
      test      rax, rax
      jz        .return
; b_terminate(tree->root, tree->o_del_cb);
      mov       rsi, QWORD [rdi + b_tree.o_del_cb]
      mov       rdi, rax
      call      b_terminate
.return:
      ret
;
;-------------------------------------------------------------------------------
; C definition:
;
;   void b_walk (b_tree_t *tree, b_walk_cb walk_cb);
;
; param:
;
;   rdi = tree
;   rsi = walk_cb
;-------------------------------------------------------------------------------
;
      global b_walk:function
b_walk:
; if (tree->root != NULL) b_traverse(tree->root, walk_cb)
      mov       rax, QWORD [rdi + b_tree.root]
      test      rax, rax
      jz        .return
      mov       rdi, rax
      call      b_traverse
.return:
      ret
%endif
