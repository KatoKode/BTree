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
#include "main.h"

int main (int argc, char *argv[]) {

  if (argc < 2) {
    printf ("usage: ./btest [random number]\n");
    return -1;
  }

  // myrand will hold the random number paramenter
  size_t myrand = strtol(argv[1], NULL, 10);
  srand48(myrand);    // initialize the random number generator

  // some constants
  size_t const mindeg = MINIMUM_DEGREE;
  size_t const o_size = sizeof(data_t);

  // allocate and initialize our b-tree
  b_tree_t *tree = b_tree_alloc();
  b_tree_init(tree, mindeg, o_size, o_cmp_cb, k_cmp_cb, o_del_cb, k_get_cb);

  // data_t object used by b_search to hold return value
  data_t db = {0.0, "0.0"};

  for (size_t i = 0L; i < DATA_COUNT; ++i) {
    data_t d;
    size_t x = 0L;

    // get a random double, populate a data_t object, and search the tree for a
    // duplicate
    do {
      // get a random double that is greater-than 0.000001F
      do { d.d = drand48(); } while (d.d < 0.000001F);

      // assign the random double to our data array
      da[i] = d.d;

      // convert the random double to a string and store in our data object
      (void) snprintf(d.s, STR_LEN + 1, "%8.6f", d.d);

      // yield the CPU when dealing with duplicates
      if ((x++ % 2L) == 0L) sched_yield();

      // search tree for duplicate data_t object
    } while ((b_search(tree->root, (void const *)&da[i], &db)) != NULL);

    // got a unique data_t object to add to the tree
    b_insert(tree, &d);
  }

  // walk the tree outputing data_t objects
  walk_tree(tree);

  // delete some data_t objects from the tree
  for (size_t n = 0L; n < DELETE_COUNT; ++n) {
    puts("\n---| begin delete |---\n");

    // search for a matching data_t object and delete it from the tree
    b_remove(tree, (void const *)&da[n]);

    // yield the CPU when dealing with duplicates
    sched_yield();

    puts("\n---| begin search after delete |---\n");

    // search for deleted data_t object to test deletion
    if ((b_search(tree->root, (void const *)&da[n], &db)) != NULL) {
      print_data("\n---| DELETION ERROR! |---\n", &db);
    }

    // yield the CPU
    if ((n % 2L) == 0L) sched_yield();
  }

  // try to delete a data_t object that is not in the tree
  puts("\n---| begin delete of key not in tree |---\n");
  double b = drand48();
  b_remove(tree, (void const *)&b);

  // walk the tree outputing data_t objects - again
  walk_tree(tree);

  // release memory held by all the data_t objects (if any), as well as, all
  // the memory held by the tree
  term_tree(tree);

  return 0;
}
//
// callback to compare objects
//
int o_cmp_cb (void const *vp1, void const *vp2) {
  data_t const *d1 = vp1;
  data_t const *d2 = vp2;
/*
  printf("%s:  d1: %8.6f s: %8s (lt eq gt) d2: %8.6f s: %8s\n",
      __func__, d1->d, d1->s, d2->d, d2->s);
*/
  // do comparsions
  if (d1->d > d2->d) return 1;
  else if (d1->d < d2->d) return -1;
  return 0;
}
//
// callback to compare key with object
//
int k_cmp_cb (void const * vp1, void const * vp2) {
  double const d = *(double const *)vp1;
  data_t const *d2 = vp2;
/*
  printf("%s:  d: %8.6f (lt eq gt) d: %8.6f  s:%8s\n",
      __func__, d, d2->d, d2->s);
*/
  // do comparsions
  if (d > d2->d) return 1;
  else if (d < d2->d) return -1;
  return 0;
}
//
// callback to get object key
//
void const * k_get_cb (void const *vp) {
  data_t const *dp = vp;

  printf("%s: d:\t%8.6f\n", __func__, dp->d);
  // return object key
  return &dp->d;
}
//
// callback to process object before deletion from tree
//
void o_del_cb (void const *vp) {
  data_t const *d = vp;
  print_data(__func__, d);
}
//
// output data object
//
void print_data (char const *s, data_t const *d) {
  printf("%s:  d: %8.6f s: %8s\n", s, d->d, d->s);
}
//
// terminate tree
//
void term_tree (b_tree_t *tree) {
  puts("\n---| term tree |---\n");
  b_tree_term(tree);
  b_tree_free(tree);
}

//
// callback for tree walking
//
void walk_cb (void const *vp) {
  data_t const *d = vp;

  printf("%6lu:  d: %8.6lf  s: %8s\n", ndx++, d->d, d->s);

  fflush(stdout);

  if ((ndx % 8) == 0) sched_yield();
}
//
// begin tree walking
//
void walk_tree (b_tree_t *tree) {
  puts("\n---| walk tree |---\n");

  // initialize index used by tree walking callback
  ndx = 0L;

  b_walk(tree, walk_cb);
}

