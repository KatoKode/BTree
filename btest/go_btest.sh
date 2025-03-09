# !/bin/sh
#-------------------------------------------------------------------------------
#   Assembly Language Implementation of a B-Tree
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
# file:   go_btest.sh
# author: J. McIntosh
# brief:  run script for B-Tree demo program
#-------------------------------------------------------------------------------
#
rnd=`shuf -i 10000000-99999999 -n 1`
./btest "${rnd}"


