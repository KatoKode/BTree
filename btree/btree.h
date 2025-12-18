/*------------------------------------------------------------------------------
    BTree Implementation in x86_64 Assembly Language with C Interface
    Copyright (C) 2025  J. McIntosh

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
------------------------------------------------------------------------------*/
#ifndef B_TREE_H
#define B_TREE_H

#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include "../util/util.h"

typedef int (*b_compare_cb) (void const *, void const *);
typedef void (*b_delete_cb) (void const *);
typedef void const * (*b_get_key_cb) (void const *);
typedef void (*b_walk_cb) (void const *);

typedef struct b_tree b_tree_t;

typedef struct b_node b_node_t;

struct b_node {
  size_t        nobj;   // number of objects
  b_tree_t *    tree;   // tree pointer
  b_node_t **   child;  // array of child pointers
  void *        object; // array of objects
  uint8_t       leaf;   // 0 (false) | 1 (true)
};

#define b_node_alloc() (calloc(1, sizeof(b_node_t)))
#define b_node_free(P) (free(P), P = NULL)

struct b_tree {
  size_t        mindeg;   // minimum-degree of the tree
  size_t        o_size;   // ex: o_size = 16 aligned to 16
                          // ex: o_size = 20 aligned to 24
  b_compare_cb  o_cmp_cb; // user supplied function
  b_compare_cb  k_cmp_cb; // user supplied function
  b_delete_cb   o_del_cb; // user supplied function
  b_get_key_cb  k_get_cb; // user supplied function
  b_node_t *    root;
};

#define b_tree_alloc() (calloc(1, sizeof(b_tree_t)))
#define b_tree_free(P) (free(P), P = NULL)

void b_borrow_from_next (b_node_t *, size_t const);
void b_borrow_from_prev (b_node_t *, size_t const);
void b_delete (b_node_t *, void const *);
void b_delete_from_leaf (b_node_t *, size_t const);
void b_delete_from_non_leaf (b_node_t *, size_t const);
void b_fill (b_node_t *, size_t const);
size_t b_find_key (b_node_t *, void const *, int *);
size_t b_hunt_key (b_node_t *, void const *, int *);
int b_insert (b_tree_t *, void const *);
void b_insert_non_full (b_node_t *, void const *);
void b_merge (b_node_t *, size_t const);
void * b_next_object (b_node_t *, size_t const);
void b_node_init (b_node_t *, b_tree_t *, uint8_t const );
void b_node_term (b_node_t *);
void * b_object_at (b_node_t *, size_t const);
void * b_prev_object (b_node_t *, size_t const);
void b_remove (b_tree_t *, void const *);
void * b_search (b_node_t *, void const *);
void b_split_child (b_node_t *, ssize_t const, b_node_t *);
void b_traverse (b_node_t *, b_walk_cb);
void b_tree_init (b_tree_t *, size_t const, size_t const, b_compare_cb,
    b_compare_cb, b_delete_cb, b_get_key_cb);
void b_tree_term (b_tree_t *);
void b_walk (b_tree_t *, b_walk_cb);

#endif
