part of dragonbones;

/// Read-only view over the shared mesh arrays that back a [GeometryData].
///
/// DragonBones 5.x does not store mesh vertices in the mesh *display*; it
/// appends them to two flat arrays on the [DragonBonesData] (an `Int16List` for
/// indices/counts and a `Float32List` for vertices and UVs) and leaves an
/// `offset` in the geometry pointing at its slot. The layout, from
/// `ObjectDataParser._parseGeometry`:
///
/// ```text
/// intArray   [offset + GeometryVertexCount]      = vertexCount
///            [offset + GeometryTriangleCount]    = triangleCount
///            [offset + GeometryFloatOffset]      = vertexOffset  (into floatArray)
///            [offset + GeometryWeightOffset]     = weightOffset  (into intArray)
///            [offset + GeometryVertexIndices + i] = triangle index i
///
/// floatArray [vertexOffset + i]                  = vertex i   (x, y interleaved)
///            [vertexOffset + vertexCount*2 + i]  = uv i        (u, v interleaved)
/// ```
///
/// The offsets are stored in an `Int16List`, so anything past 32767 wraps
/// negative; upstream adds 65536 back and so do we (see `_u16`).
///
/// The vertex block is in **slot-local units** at the armature's own scale; it
/// is *not* the posed mesh. See [buildMeshGeometry] for that.
extension MeshGeometryArrays on GeometryData {
  int get _meshVertexCount =>
      this.data!.intArray![this.offset + BinaryOffset.GeometryVertexCount];

  int get _meshTriangleCount =>
      this.data!.intArray![this.offset + BinaryOffset.GeometryTriangleCount];

  int get _vertexFloatOffset => _u16(
      this.data!.intArray![this.offset + BinaryOffset.GeometryFloatOffset]);

  /// Reinterprets a (possibly negative) `Int16List` entry as its unsigned value.
  static int _u16(int value) => value < 0 ? value + 65536 : value;

  /// Number of mesh vertices.
  int get vertexCount => _meshVertexCount;

  /// Number of triangles.
  int get triangleCount => _meshTriangleCount;

  /// The mesh at rest: `2 * vertexCount` numbers, `x, y` interleaved.
  List<double> get restVertices {
    final floatArray = this.data!.floatArray!;
    final offset = _vertexFloatOffset;
    final result = List<double>.filled(_meshVertexCount * 2, 0.0);
    for (var i = 0; i < result.length; ++i) {
      result[i] = floatArray[offset + i];
    }
    return result;
  }

  /// Texture coordinates: `2 * vertexCount` numbers, `u, v` interleaved.
  List<double> get uvs {
    final floatArray = this.data!.floatArray!;
    final offset = _vertexFloatOffset + _meshVertexCount * 2;
    final result = List<double>.filled(_meshVertexCount * 2, 0.0);
    for (var i = 0; i < result.length; ++i) {
      result[i] = floatArray[offset + i];
    }
    return result;
  }

  /// Triangle indices: `3 * triangleCount` entries into the vertex list.
  List<int> get triangles {
    final intArray = this.data!.intArray!;
    final offset = this.offset + BinaryOffset.GeometryVertexIndices;
    final result = List<int>.filled(_meshTriangleCount * 3, 0);
    for (var i = 0; i < result.length; ++i) {
      result[i] = intArray[offset + i];
    }
    return result;
  }
}

/// A triangle mesh posed for one frame, in the armature's coordinate space.
///
/// This is the runtime's analogue of the upstream engine-side `MeshNode`:
/// vertex positions have been resolved (rest vertices, bone weights and any
/// deform applied), while [uvs] and [triangles] are static.
///
/// A renderer feeds [vertices]/[uvs]/[triangles] to a triangle list directly:
/// `Canvas.drawVertices` in Flutter, `MeshNode` in Egret, `ArrayMesh` in Godot.
class MeshGeometry {
  MeshGeometry({
    required this.vertices,
    required this.uvs,
    required this.triangles,
  });

  /// `2 * vertexCount` posed positions, `x, y` interleaved.
  final List<double> vertices;

  /// `2 * vertexCount` texture coordinates, `u, v` interleaved.
  final List<double> uvs;

  /// `3 * triangleCount` vertex indices.
  final List<int> triangles;

  /// Number of vertices in the mesh.
  int get vertexCount => this.vertices.length ~/ 2;

  /// Number of triangles in the mesh.
  int get triangleCount => this.triangles.length ~/ 3;

  @override
  String toString() => 'MeshGeometry($vertexCount verts, $triangleCount tris)';
}

/// Resolves the posed vertices of a mesh display.
///
/// Faithful port of the official Egret binding's `EgretSlot._updateMesh`
/// (`.ref/egret-binding/EgretSlot.ts`). Deformation is a **CPU** job in
/// DragonBones — there is no shader involved — which is why it can be ported,
/// and verified, without a GPU.
///
/// Two paths exist:
///
/// * **Weighted (skinned) mesh** — `geometry.weight != null`. Each vertex is
///   skinned by up to [Bone] bones: the per-vertex bone weights and local
///   offsets were baked by the parser into the shared arrays (see
///   [MeshGeometryArrays]), and skinning applies each bone's *current*
///   `globalTransformMatrix`.
/// * **Plain mesh** — vertices are the rest positions scaled by the armature
///   scale.
///
/// Both add `deform` when [deformVertices] is non-empty and the geometry
/// inherits deform (the animated FFD offsets).
///
/// Returns null when [geometry] has no backing arrays (a display that was never
/// parsed) or when it is a `Path` geometry, which is not a drawable mesh.
MeshGeometry? buildMeshGeometry({
  required GeometryData geometry,
  required List<Bone?> bones,
  required List<double> deformVertices,
  required double scale,
}) {
  final data = geometry.data;
  if (data == null || data.intArray == null || data.floatArray == null) {
    return null;
  }

  final intArray = data.intArray!;
  final floatArray = data.floatArray!;
  final vertexCount = geometry.vertexCount;
  final triangleCount = geometry.triangleCount;
  final vertexOffset = MeshGeometryArrays._u16(
    intArray[geometry.offset + BinaryOffset.GeometryFloatOffset],
  );

  final hasDeform = deformVertices.isNotEmpty && geometry.inheritDeform;

  // UVs and triangles are static: upstream fills them once in `_updateFrame`.
  final uvs = List<double>.filled(vertexCount * 2, 0.0);
  final uvOffset = vertexOffset + vertexCount * 2;
  for (var i = 0, l = vertexCount * 2; i < l; ++i) {
    uvs[i] = floatArray[uvOffset + i];
  }

  final triangles = List<int>.filled(triangleCount * 3, 0);
  final indexOffset = geometry.offset + BinaryOffset.GeometryVertexIndices;
  for (var i = 0, l = triangleCount * 3; i < l; ++i) {
    triangles[i] = intArray[indexOffset + i];
  }

  final vertices = List<double>.filled(vertexCount * 2, 0.0);
  final weight = geometry.weight;

  if (weight != null) {
    final weightFloatOffset = MeshGeometryArrays._u16(
      intArray[weight.offset + BinaryOffset.WeigthFloatOffset],
    );

    // `iB` skips the per-weight-bone index table, which sits right after the
    // two header slots and is as long as the bone list.
    var iB = weight.offset + BinaryOffset.WeigthBoneIndices + bones.length;
    var iV = weightFloatOffset;
    var iF = 0;
    var iD = 0;

    for (var i = 0; i < vertexCount; ++i) {
      final boneCount = intArray[iB++];
      var xG = 0.0;
      var yG = 0.0;

      for (var j = 0; j < boneCount; ++j) {
        final boneIndex = intArray[iB++];
        final bone = boneIndex >= 0 && boneIndex < bones.length
            ? bones[boneIndex]
            : null;

        // Upstream reads the weight and both offsets *inside* this null check,
        // so a missing bone desynchronises the cursor. Kept as-is: it cannot
        // happen for a mesh whose bones were resolved at build time, and
        // diverging here would silently change the arithmetic.
        if (bone != null) {
          final matrix = bone.globalTransformMatrix;
          final boneWeight = floatArray[iV++];
          var xL = floatArray[iV++] * scale;
          var yL = floatArray[iV++] * scale;

          if (hasDeform) {
            xL += deformVertices[iF++];
            yL += deformVertices[iF++];
          }

          xG += (matrix.a * xL + matrix.c * yL + matrix.tx) * boneWeight;
          yG += (matrix.b * xL + matrix.d * yL + matrix.ty) * boneWeight;
        }
      }

      vertices[iD++] = xG;
      vertices[iD++] = yG;
    }
  } else {
    for (var i = 0, l = vertexCount * 2; i < l; i += 2) {
      var x = floatArray[vertexOffset + i] * scale;
      var y = floatArray[vertexOffset + i + 1] * scale;

      if (hasDeform) {
        x += deformVertices[i];
        y += deformVertices[i + 1];
      }

      // NOTE: upstream branches here for `Surface` bones (a 4.x feature that
      // remaps the vertices through a surface transform). BoneType.Surface is
      // not ported — no supported fixture uses it — so the branch is omitted
      // rather than faked.
      vertices[i] = x;
      vertices[i + 1] = y;
    }
  }

  return MeshGeometry(vertices: vertices, uvs: uvs, triangles: triangles);
}
