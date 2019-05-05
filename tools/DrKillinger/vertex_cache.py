"""Algorithms to reorder triangle list order and vertex order aiming to
minimize vertex cache misses.

This is effectively an implementation of
'Linear-Speed Vertex Cache Optimisation' by Tom Forsyth, 28th September 2006
http://home.comcast.net/~tom_forsyth/papers/fast_vert_cache_opt.html
"""

# ***** BEGIN LICENSE BLOCK *****
#
# Copyright (c) 2007-2009, Python File Format Interface
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#
#    * Redistributions in binary form must reproduce the above
#      copyright notice, this list of conditions and the following
#      disclaimer in the documentation and/or other materials provided
#      with the distribution.
#
#    * Neither the name of the Python File Format Interface
#      project nor the names of its contributors may be used to endorse
#      or promote products derived from this software without specific
#      prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# ***** END LICENSE BLOCK *****

import collections

class VertexInfo:
    """Stores information about a vertex."""

    # constants used for scoring algorithm
    CACHE_SIZE = 32 # higher values yield virtually no improvement
    """The size of the modeled cache."""

    CACHE_DECAY_POWER = 1.5
    LAST_TRI_SCORE = 0.75
    VALENCE_BOOST_SCALE = 2.0
    VALENCE_BOOST_POWER = 0.5

    def __init__(self, cache_position=-1, score=-1,
                 triangle_indices=None):
        self.cache_position = cache_position
        self.score = score
        self.triangle_indices = ([] if triangle_indices is None
                             else triangle_indices)

    def update_score(self):
        if not self.triangle_indices:
            # no triangle needs this vertex
            self.score = -1
            return

        if self.cache_position < 0:
            # not in cache
            self.score = 0
        elif self.cache_position >= 0 and self.cache_position < 3:
            # used in last triangle
            self.score = self.LAST_TRI_SCORE
        else:
            self.score = (
                (1.0 - (self.cache_position - 3) / (self.CACHE_SIZE - 3))
                ** self.CACHE_DECAY_POWER)

        # bonus points for having low number of triangles still in use
        self.score += self.VALENCE_BOOST_SCALE * (
            len(self.triangle_indices) ** (-self.VALENCE_BOOST_POWER))

class TriangleInfo:
    def __init__(self, added=False, score=0.0, vertex_indices=None):
        self.added = False
        self.score = 0.0
        self.vertex_indices = ([] if vertex_indices is None
                               else vertex_indices)

class Mesh:
    """Simple mesh implementation which keeps track of which triangles
    are used by which vertex, and vertex cache positions.
    """

    def __init__(self, triangles):
        """Initialize mesh from given set of triangles.

        Empty mesh
        ----------

        >>> Mesh([]).triangle_infos
        []

        Single triangle mesh (with degenerate)
        --------------------------------------

        >>> m = Mesh([(0,1,2), (1,2,0)])
        >>> [vertex_info.triangle_indices for vertex_info in m.vertex_infos]
        [[0], [0], [0]]
        >>> [triangle_info.vertex_indices for triangle_info in m.triangle_infos]
        [(0, 1, 2)]

        Double triangle mesh
        --------------------

        >>> m = Mesh([(0,1,2), (2,1,3)])
        >>> [vertex_info.triangle_indices for vertex_info in m.vertex_infos]
        [[0], [0, 1], [0, 1], [1]]
        >>> [triangle_info.vertex_indices for triangle_info in m.triangle_infos]
        [(0, 1, 2), (1, 3, 2)]
        """
        # initialize vertex and triangle information, and vertex cache
        self.vertex_infos = []
        self.triangle_infos = []
        # add all vertices
        if triangles:
            num_vertices = max(max(verts) for verts in triangles) + 1
        else:
            num_vertices = 0
        self.vertex_infos = [VertexInfo() for i in range(num_vertices)]
        # add all triangles
        _added_triangles = set([])
        triangle_index = 0
        for v0, v1, v2 in triangles:
            if v0 == v1 or v1 == v2 or v2 == v0:
                # skip degenerate triangles
                continue
            if v0 < v1 and v0 < v2:
                verts = (v0, v1, v2)
            elif v1 < v0 and v1 < v2:
                verts = (v1, v2, v0)
            elif v2 < v0 and v2 < v1:
                verts = (v2, v0, v1)
            if verts not in _added_triangles:
                self.triangle_infos.append(TriangleInfo(vertex_indices=verts))
                for vertex in verts:
                    self.vertex_infos[vertex].triangle_indices.append(
                        triangle_index)
                triangle_index += 1
                _added_triangles.add(verts)
        # calculate score of all vertices
        for vertex_info in self.vertex_infos:
            vertex_info.update_score()
        # calculate score of all triangles
        for triangle_info in self.triangle_infos:
            triangle_info.score = sum(
                self.vertex_infos[vertex].score
                for vertex in triangle_info.vertex_indices)

    def get_cache_optimized_triangles(self):
        """Reorder triangles in a cache efficient way.

        >>> m = Mesh([(0,1,2), (7,8,9),(2,3,4)])
        >>> m.get_cache_optimized_triangles()
        [(7, 8, 9), (0, 1, 2), (2, 3, 4)]
        """
        triangles = []
        cache = collections.deque()
        while any(not triangle_info.added for triangle_info in self.triangle_infos):
            # pick triangle with highest score
            best_triangle_index, best_triangle_info = max(
                (triangle
                 for triangle in enumerate(self.triangle_infos)
                 if not triangle[1].added),
                key=lambda triangle: triangle[1].score)
            # mark as added
            best_triangle_info.added = True
            # append to ordered list of triangles
            triangles.append(best_triangle_info.vertex_indices)
            # keep list of vertices and triangles whose score we will need
            # to update
            updated_vertices = set([])
            updated_triangles = set([])
            # for each vertex in the just added triangle
            for vertex in best_triangle_info.vertex_indices:
                vertex_info = self.vertex_infos[vertex]
                # update triangle indices
                vertex_info.triangle_indices.remove(best_triangle_index)
                # must update its score
                updated_vertices.add(vertex)
                updated_triangles.update(vertex_info.triangle_indices)
                # add vertices to cache (score is updated later)
                if vertex not in cache:
                    cache.appendleft(vertex)
                    if len(cache) > VertexInfo.CACHE_SIZE:
                        # cache overflow!
                        # remove vertex from cache
                        removed_vertex = cache.pop()
                        removed_vertex_info = self.vertex_infos[removed_vertex]
                        # update its cache position
                        removed_vertex_info.cache_position = -1
                        # must update its score
                        updated_vertices.add(removed_vertex)
                        updated_triangles.update(removed_vertex_info.triangle_indices)
            # for each vertex in the cache (this includes those from the
            # just added triangle)
            for i, vertex in enumerate(cache):
                vertex_info = self.vertex_infos[vertex]
                # update cache positions
                vertex_info.cache_position = i
                # must update its score
                updated_vertices.add(vertex)
                updated_triangles.update(vertex_info.triangle_indices)
            # update scores
            for vertex in updated_vertices:
                self.vertex_infos[vertex].update_score()
            for triangle in updated_triangles:
                triangle_info = self.triangle_infos[triangle]
                triangle_info.score = sum(
                    self.vertex_infos[vertex].score
                    for vertex in triangle_info.vertex_indices)
        # return result
        return triangles

def get_cache_optimized_triangles(triangles):
    mesh = Mesh(triangles)
    return mesh.get_cache_optimized_triangles()

def get_cache_optimized_vertex_map(triangles):
    """Map vertices so triangles have consequetive indices.

    >>> get_cache_optimized_vertex_map([(5,2,1),(0,2,3)])
    [3, 2, 1, 4, None, 0]
    """
    num_vertices = max(max(triangle) for triangle in triangles) + 1
    vertex_map = [None for i in range(num_vertices)]
    new_vertex = 0
    for triangle in triangles:
        for old_vertex in triangle:
            if vertex_map[old_vertex] is None:
                vertex_map[old_vertex] = new_vertex
                new_vertex += 1
    return vertex_map

def average_transform_to_vertex_ratio(triangles, cache_size=32):
    """Calculate number of transforms per vertex for a given cache size
    and ordering of triangles. See
    http://castano.ludicon.com/blog/2009/01/29/acmr/
    """
    cache = collections.deque(maxlen=cache_size)
    # get number of vertices
    vertices = set(triangles)

    # get number of cache misses (each miss needs a transform)
    num_misses = 0
    for triangle in triangles:
        for vertex in triangle:
            if vertex not in cache:
                cache.appendleft(vertex)
                num_misses += 1
    # return result
    return float(num_misses) / float(len(vertices))

if __name__=='__main__':
    import doctest
    doctest.testmod()
