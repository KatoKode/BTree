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
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <pthread.h>
#include "../btree/btree.h"
#include "../util/util.h"

// defines you can modify
#define DATA_COUNT    128
#define DELETE_COUNT  0

// defines you should not modify
#define STR_LEN   15
#define MINIMUM_DEGREE  15

// index for tree walking
size_t ndx;

// data object
typedef struct data data_t;

struct data {
  double    d;
  char      s[STR_LEN + 1];
};

// array of doubles
double da [DATA_COUNT];

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
