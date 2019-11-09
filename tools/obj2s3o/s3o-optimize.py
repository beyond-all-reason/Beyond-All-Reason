#!/usr/bin/env python

from s3o import S3O
from optparse import OptionParser
from glob import glob
import vertex_cache


def recursively_optimize_pieces(piece):
    optimize_piece(piece)
    for child in piece.children:
        recursively_optimize_pieces(child)


def chunks(l, n):
    """ Yield successive n-sized chunks from l.
    """
    for i in range(0, len(l), n):
        yield tuple(l[i:i + n])


def optimize_piece(piece):
    remap = {}
    new_indices = []

    for index in piece.indices:
        vertex = piece.vertices[index]
        if vertex not in remap:
            remap[vertex] = len(remap)
        new_indices.append(remap[vertex])

    new_vertices = [(index, vertex) for vertex, index in remap.items()]
    new_vertices.sort()
    new_vertices = [vertex for index, vertex in new_vertices]

    if piece.primitive_type == "triangles" and len(new_indices) > 0:
        tris = list(chunks(new_indices, 3))
        acmr = vertex_cache.average_transform_to_vertex_ratio(tris)

        tmp = vertex_cache.get_cache_optimized_triangles(tris)
        acmr_new = vertex_cache.average_transform_to_vertex_ratio(tmp)
        if acmr_new < acmr:
            new_indices = []
            for tri in tmp:
                new_indices.extend(tri)

    vertex_map = []
    remapped_indices = []
    for index in new_indices:
        try:
            new_index = vertex_map.index(index)
        except ValueError:
            new_index = len(vertex_map)
            vertex_map.append(index)

        remapped_indices.append(new_index)

    new_vertices = [new_vertices[index] for index in vertex_map]
    new_indices = remapped_indices

    piece.indices = new_indices
    piece.vertices = new_vertices


def sizeof_fmt(num):
    for x in ['bytes', 'KB', 'MB', 'GB']:
        if abs(num) < 1024.0:
            return "%3.1f %s" % (num, x)
        num /= 1024.0
    return "%3.1f%s" % (num, 'TB')

if __name__ == '__main__':
    parser = OptionParser(usage="%prog [options] FILES", version="%prog 0.1",
                          description="Optimize a Spring S3O file by "
                                      "removing redundant data.")
    parser.add_option("-d", "--dry-run", action="store_true",
                      default=False, dest="is_dry",
                      help="show output summary without committing changes")
    parser.add_option("-q", "--quiet", action="store_true",
                      default=False, dest="silence_output",
                      help="silence detailed optimization output")

    options, args = parser.parse_args()
    if len(args) < 1:
        parser.error("insufficient arguments")

    dry = options.is_dry
    silence_output = options.silence_output

    if len(args) == 1:
        filenames = glob(args[0])
    else:
        filenames = args

    delta_total = 0

    for filename in filenames:
        with open(filename, 'rb+') as input_file:
            data = input_file.read()
            model = S3O(data)
            recursively_optimize_pieces(model.root_piece)
            optimized_data = model.serialize()

            delta_size = len(optimized_data) - len(data)

            if delta_size <= 0:
                delta_total += delta_size
                if not silence_output:
                    print("modified %s: "
                          "size change: %d bytes" % (filename, delta_size))

                if not dry:
                    input_file.seek(0)
                    input_file.truncate()
                    input_file.write(optimized_data)
            else:
                if not silence_output:
                    print("not modified %s: "
                          "size change: %d bytes" % (filename, delta_size))

    print("total size difference: %s" % sizeof_fmt(delta_total))
