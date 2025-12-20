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

  for (size_t i = 0; i < DATA_COUNT; ++i) {
    data_t d;

    // get a random double, populate a data_t object, and search the tree for a
    // duplicate
    do {
      // get a random double that is greater-than 0.000001F
      d.lng = lrand48();

      // assign the random double to our data array
      la[i] = d.lng;

      // convert the random double to a string and store in our data object
      (void) snprintf(d.str, STR_LEN + 1, "%ld", d.lng);

      // search tree for duplicate data_t object
    } while (b_insert(tree, &d) < 0);
  }
#ifdef WALK_TREE
  // walk the tree outputing data_t objects
  walk_tree(tree);
#endif
  size_t delete_count = (size_t)floor(DELETE_COUNT);

  // delete some data_t objects from the tree
  for (size_t n = 0; n < delete_count; ++n) {
#ifdef DEMO_DEBUG
    puts("\n---| begin delete |---\n");
#endif
    // search for a matching data_t object and delete it from the tree
    b_remove(tree, (void const *)&la[n]);
#ifdef DEMO_DEBUG
    puts("\n---| begin search after delete |---\n");

    // search for deleted data_t object to test deletion
    void *dp;
    if ((dp = b_search(tree->root, (void const *)&la[n])) != NULL) {
      print_data("\n---| DELETION ERROR! |---\n", dp);
    }
#endif
  }


  // try to delete a data_t object that is not in the tree
  puts("\n---| begin delete of key not in tree |---\n");
  long lng = lrand48();
  b_remove(tree, (void const *)&lng);
#ifdef WALK_TREE
  // walk the tree outputing data_t objects - again
  walk_tree(tree);
#endif
  // release memory held by all the data_t objects (if any), as well as, all
  // the memory held by the tree
  term_tree(tree);

  return 0;
}
//------------------------------------------------------------------------------
//
// O_CMP_CB
//
//------------------------------------------------------------------------------
int o_cmp_cb (void const *vp1, void const *vp2) {
  data_t const *d1 = vp1;
  data_t const *d2 = vp2;
#ifdef DEMO_DEBUG
  printf("%s:  d1:{ lng: %ld  str: %s } <=> d2: { lng: %ld  str:%s}\n",
      __func__, d1->lng, d1->str, d2->lng, d2->str);
#endif
  // do comparsions
  if (d1->lng > d2->lng) return 1;
  else if (d1->lng < d2->lng) return -1;
  return 0;
}
//------------------------------------------------------------------------------
//
// K_CMP_CB
//
//------------------------------------------------------------------------------
int k_cmp_cb (void const * vp1, void const * vp2) {
  long const lng = *(long const *)vp1;
  data_t const *d2 = vp2;
#ifdef DEMO_DEBUG
  printf("%s:  lng: %ld (lt eq gt) d->lng: %ld  d->str:%s\n",
      __func__, lng, d2->lng, d2->str);
#endif
  // do comparsions
  if (lng > d2->lng) return 1;
  else if (lng < d2->lng) return -1;
  return 0;
}
//------------------------------------------------------------------------------
//
// K_GET_CB
//
//------------------------------------------------------------------------------
void const * k_get_cb (void const *vp) {
  data_t const *dp = vp;
#ifdef DEMO_DEBUG
  printf("%s: lng: %ld  str: %s\n", __func__, dp->lng, dp->str);
#endif
  // return object key
  return &dp->lng;
}
//------------------------------------------------------------------------------
//
// O_DEL_CB
//
//------------------------------------------------------------------------------
void o_del_cb (void const *vp) {
#ifdef DEMO_DEBUG
  data_t const *d = vp;
  print_data(__func__, d);
#endif
}
#ifdef DEMO_DEBUG
//------------------------------------------------------------------------------
//
// PRINT_DATA
//
//------------------------------------------------------------------------------
void print_data (char const *s, data_t const *d) {
  printf("%s:  lng: %ld str: %s\n", s, d->lng, d->str);
}
#endif
//------------------------------------------------------------------------------
//
// TERM_TREE
//
//------------------------------------------------------------------------------
void term_tree (b_tree_t *tree) {
#ifdef DEMO_DEBUG
  puts("\n---| term tree |---\n");
#endif
  b_tree_term(tree);
  b_tree_free(tree);
}
//------------------------------------------------------------------------------
//
// WALK_CB
//
//------------------------------------------------------------------------------
void walk_cb (void const *vp) {
  data_t const *d = vp;

  printf("%6lu:  lng: %ld  str: %s\n", ndx++, d->lng, d->str);

  fflush(stdout);
}
//------------------------------------------------------------------------------
//
// WALK_TREE
//
//------------------------------------------------------------------------------
void walk_tree (b_tree_t *tree) {
  puts("\n---| walk tree |---\n");

  // initialize index used by tree walking callback
  ndx = 0L;

  b_walk(tree, walk_cb);
}

