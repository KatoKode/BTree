/*------------------------------------------------------------------------------
    BTree (BTREE) Implementation in x86_64 Assembly Language with C Interface
    Copyright (C) 2025  J. McIntosh

    BTREE is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    BTREE is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with BTREE; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
------------------------------------------------------------------------------*/
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <math.h>
#include <pthread.h>
#include "../btree/btree.h"
#include "../util/util.h"

// defines you can modify
#define DATA_COUNT      (8 * 1024)
#define DELETE_COUNT    (DATA_COUNT * 0.75)
#define MINIMUM_DEGREE  2
#define INS_MOD_BY      64
#define DEL_MOD_BY      64

// defines you should not modify
#define STR_LEN   15

// index for tree walking
size_t ndx;
size_t o_del_count;

// data object
typedef struct data data_t;

struct data {
//  double    d;
  long      lng;
  char      str[STR_LEN + 1];
};

// array of doubles
//double da [DATA_COUNT];
long la [DATA_COUNT];

// callback definitions
int o_cmp_cb (void const *, void const *);
int k_cmp_cb (void const *, void const *);
void const * k_get_cb (void const *);
void o_del_cb (void const *);
void walk_cb (void const *);
// output data_t object
void print_data (char const *, data_t const *);
// begin termination of tree
void term_tree (b_tree_t *);
// begin walking the tree
void walk_tree (b_tree_t *);
