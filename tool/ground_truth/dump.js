/**
 * Ground-truth harness — roda o runtime OFICIAL do DragonBones (TypeScript
 * compilado para JS) no node, SEM engine gráfico, e despeja o estado da
 * armature quadro a quadro em JSON. Serve de gabarito numérico para validar
 * o port Dart deste repositório.
 *
 * Uso: node dump.js <ske.json> <tex.json> <anim> <out.json>
 */
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const RUNTIME = process.env.DRAGONBONES_JS ||
  path.join(__dirname, 'vendor', 'dragonBones.js');

function loadRuntime() {
  const code = fs.readFileSync(RUNTIME, 'utf8');
  const ctx = vm.createContext({ console });
  vm.runInContext(code, ctx, { filename: 'dragonBones.js' });
  return ctx.dragonBones;
}

const db = loadRuntime();

// `BinaryOffset` is a TypeScript `const enum`, so the compiler inlines it and
// it does NOT exist at runtime (`db.BinaryOffset` is undefined). Mirror the
// values from .ref/dragonBones-ts/core/DragonBones.ts instead.
const BO = {
  WeigthFloatOffset: 1,
  WeigthBoneIndices: 2,
  GeometryVertexCount: 0,
  GeometryTriangleCount: 1,
  GeometryFloatOffset: 2,
  GeometryVertexIndices: 4,
};

// ---------------------------------------------------------------- headless

// Proxy: cada engine implementa IArmatureProxy. Aqui é um no-op que só precisa
// existir para o runtime não estourar.
class HeadlessArmatureDisplay {
  static toString() { return '[class HeadlessArmatureDisplay]'; }
  constructor() { this._armature = null; }
  get armature() { return this._armature; }
  get animation() { return this._armature ? this._armature.animation : null; }
  dbInit(armature) { this._armature = armature; }
  dbUpdate() { }
  dbClear() { this._armature = null; }
  dispose(_disposeProxy) { }
  hasDBEventListener(_type) { return false; }
  addDBEventListener(_type, _listener) { }
  removeDBEventListener(_type, _listener) { }
  dispatchDBEvent(_type, _eventObject) { }
}

// Slot: todos os métodos abstratos de render viram no-op, EXCETO os de malha.
// O que interessa aqui é a matemática (transforms dos ossos e vértices de
// malha), não o desenho.
//
// `_updateMesh` é transcrito VERBATIM de `.ref/egret-binding/EgretSlot.ts` — que
// é onde a deformação de malha realmente vive. O runtime oficial NÃO a
// implementa: `Slot._updateMesh` é abstrato e cada engine o escreve. Então o
// gabarito para malha é o binding oficial do Egret, não o core.
class HeadlessSlot extends db.Slot {
  static toString() { return '[class HeadlessSlot]'; }
  _updateVisible() { }
  _initDisplay(_value, _isRetain) { }
  _disposeDisplay(_value, _isRelease) { }
  _onUpdateDisplay() { }
  _addDisplay() { }
  _replaceDisplay(_value) { }
  _removeDisplay() { }
  _updateZOrder() { }
  _updateBlendMode() { }
  _updateColor() { }
  _updateTransform() { }
  _identityTransform() { }

  // Estático por display: UVs e índices de triângulo. Espelha o que
  // EgretSlot._updateFrame escreve uma vez no MeshNode.
  _updateFrame() {
    if (this._geometryData === null) { return; }
    const geometryData = this._geometryData;
    const data = geometryData.data;
    const intArray = data.intArray;
    const floatArray = data.floatArray;
    const vertexCount = intArray[geometryData.offset + BO.GeometryVertexCount];
    const triangleCount = intArray[geometryData.offset + BO.GeometryTriangleCount];
    let vertexOffset = intArray[geometryData.offset + BO.GeometryFloatOffset];
    if (vertexOffset < 0) { vertexOffset += 65536; }
    const uvOffset = vertexOffset + vertexCount * 2;

    this._meshUvs = [];
    for (let i = 0, l = vertexCount * 2; i < l; ++i) {
      this._meshUvs[i] = floatArray[uvOffset + i];
    }
    this._meshIndices = [];
    for (let i = 0, l = triangleCount * 3; i < l; ++i) {
      this._meshIndices[i] = intArray[geometryData.offset + BO.GeometryVertexIndices + i];
    }
  }

  // VERBATIM de EgretSlot._updateMesh (só a escrita no MeshNode foi trocada por
  // um array local).
  _updateMesh() {
    const scale = this._armature._armatureData.scale;
    const deformVertices = this._displayFrame.deformVertices;
    const bones = this._geometryBones;
    const geometryData = this._geometryData;
    const weightData = geometryData.weight;

    const hasDeform = deformVertices.length > 0 && geometryData.inheritDeform;
    const vertices = [];

    if (weightData !== null) {
      const data = geometryData.data;
      const intArray = data.intArray;
      const floatArray = data.floatArray;
      const vertexCount = intArray[geometryData.offset + BO.GeometryVertexCount];
      let weightFloatOffset = intArray[weightData.offset + BO.WeigthFloatOffset];
      if (weightFloatOffset < 0) { weightFloatOffset += 65536; }

      for (
        let i = 0, iD = 0, iB = weightData.offset + BO.WeigthBoneIndices + bones.length, iV = weightFloatOffset, iF = 0;
        i < vertexCount;
        ++i
      ) {
        const boneCount = intArray[iB++];
        let xG = 0.0, yG = 0.0;

        for (let j = 0; j < boneCount; ++j) {
          const boneIndex = intArray[iB++];
          const bone = bones[boneIndex];

          if (bone !== null) {
            const matrix = bone.globalTransformMatrix;
            const weight = floatArray[iV++];
            let xL = floatArray[iV++] * scale;
            let yL = floatArray[iV++] * scale;

            if (hasDeform) {
              xL += deformVertices[iF++];
              yL += deformVertices[iF++];
            }

            xG += (matrix.a * xL + matrix.c * yL + matrix.tx) * weight;
            yG += (matrix.b * xL + matrix.d * yL + matrix.ty) * weight;
          }
        }

        vertices[iD++] = xG;
        vertices[iD++] = yG;
      }
    } else {
      const data = geometryData.data;
      const intArray = data.intArray;
      const floatArray = data.floatArray;
      const vertexCount = intArray[geometryData.offset + BO.GeometryVertexCount];
      let vertexOffset = intArray[geometryData.offset + BO.GeometryFloatOffset];
      if (vertexOffset < 0) { vertexOffset += 65536; }

      for (let i = 0, l = vertexCount * 2; i < l; i += 2) {
        let x = floatArray[vertexOffset + i] * scale;
        let y = floatArray[vertexOffset + i + 1] * scale;

        if (hasDeform) {
          x += deformVertices[i];
          y += deformVertices[i + 1];
        }

        vertices[i] = x;
        vertices[i + 1] = y;
      }
    }

    this._meshVertices = vertices;
  }
}

class HeadlessTextureData extends db.TextureData {
  static toString() { return '[class HeadlessTextureData]'; }
  _onClear() { super._onClear(); }
}

class HeadlessTextureAtlasData extends db.TextureAtlasData {
  static toString() { return '[class HeadlessTextureAtlasData]'; }
  createTexture() { return db.BaseObject.borrowObject(HeadlessTextureData); }
  _onClear() { super._onClear(); }
}

class HeadlessFactory extends db.BaseFactory {
  static toString() { return '[class HeadlessFactory]'; }
  constructor() {
    super();
    this._dragonBones = new db.DragonBones(new HeadlessArmatureDisplay());
  }
  _isSupportMesh() { return true; }
  _buildTextureAtlasData(textureAtlasData, _textureAtlas) {
    return textureAtlasData || db.BaseObject.borrowObject(HeadlessTextureAtlasData);
  }
  _buildArmature(dataPackage) {
    const armature = db.BaseObject.borrowObject(db.Armature);
    const display = new HeadlessArmatureDisplay();
    armature.init(dataPackage.armature, display, display, this._dragonBones);
    return armature;
  }
  _buildSlot(_dataPackage, slotData, armature) {
    const slot = db.BaseObject.borrowObject(HeadlessSlot);
    slot.init(slotData, armature, {}, {});
    return slot;
  }
}

// ---------------------------------------------------------------- dump

function r(v) { return Math.round(v * 1e6) / 1e6; }

function dumpState(armature) {
  const bones = armature.getBones().map((b) => ({
    name: b.name,
    // matrix global: [a, b, c, d, tx, ty]
    matrix: [r(b.globalTransformMatrix.a), r(b.globalTransformMatrix.b),
             r(b.globalTransformMatrix.c), r(b.globalTransformMatrix.d),
             r(b.globalTransformMatrix.tx), r(b.globalTransformMatrix.ty)],
  }));
  const slots = armature.getSlots().map((s) => {
    // Everything a renderer needs to place a sprite: the slot's world matrix,
    // the pivot that anchors it, and the atlas region to sample. This mirrors
    // what EgretSlot._updateFrame / _identityTransform compute.
    const td = s._textureData || null;
    const region = td ? td.region : null;
    const atlasScale = td && td.parent ? td.parent.scale : 1.0;
    const armatureScale = armature.armatureData.scale;
    const scale = atlasScale * armatureScale;
    const rotated = td ? !!td.rotated : false;
    const regionW = region ? region.width : 0;
    const regionH = region ? region.height : 0;

    // Mesh slots carry a posed triangle list instead of a quad. Vertices come
    // from the transcribed Egret `_updateMesh`; uvs/indices from `_updateFrame`.
    let mesh = null;
    if (s._geometryData) {
      const geometryData = s._geometryData;
      const intArray = geometryData.data.intArray;
      mesh = {
        vertexCount: intArray[geometryData.offset + BO.GeometryVertexCount],
        triangleCount: intArray[geometryData.offset + BO.GeometryTriangleCount],
        weighted: geometryData.weight !== null,
        vertices: (s._meshVertices || []).map(r),
        uvs: (s._meshUvs || []).map(r),
        indices: (s._meshIndices || []).slice(),
      };
    }

    return {
      name: s.name,
      displayIndex: s.displayIndex,
      color: [r(s._colorTransform.alphaMultiplier), r(s._colorTransform.redMultiplier),
              r(s._colorTransform.greenMultiplier), r(s._colorTransform.blueMultiplier),
              r(s._colorTransform.alphaOffset), r(s._colorTransform.redOffset),
              r(s._colorTransform.greenOffset), r(s._colorTransform.blueOffset)],
      matrix: [r(s.globalTransformMatrix.a), r(s.globalTransformMatrix.b),
               r(s.globalTransformMatrix.c), r(s.globalTransformMatrix.d),
               r(s.globalTransformMatrix.tx), r(s.globalTransformMatrix.ty)],
      pivot: [r(s._pivotX), r(s._pivotY)],
      region: region ? [r(region.x), r(region.y), r(regionW), r(regionH)] : null,
      textureName: td ? td.name : null,
      rotated,
      // drawn quad size = region size, swapped when the atlas entry is rotated
      quadSize: [r((rotated ? regionH : regionW) * scale), r((rotated ? regionW : regionH) * scale)],
      visible: !!s._visible,
      zOrder: s._zOrder === undefined ? 0 : s._zOrder,
      blendMode: s._blendMode === undefined ? 0 : s._blendMode,
      displayType: s._geometryData ? 'mesh' : (td ? 'image' : null),
      mesh,
      // A slot holding a nested armature draws nothing itself; the child's own
      // slots are reported so the port's flattening can be checked.
      childArmatureName: s._childArmature ? s._childArmature.armatureData.name : null,
      childSlots: s._childArmature ? dumpSlotList(s._childArmature) : null,
    };
  });
  return { bones, slots };
}

function dumpSlotList(armature) {
  return armature.getSlots().map((s) => ({
    name: s.name,
    matrix: [r(s.globalTransformMatrix.a), r(s.globalTransformMatrix.b),
             r(s.globalTransformMatrix.c), r(s.globalTransformMatrix.d),
             r(s.globalTransformMatrix.tx), r(s.globalTransformMatrix.ty)],
    zOrder: s._zOrder === undefined ? 0 : s._zOrder,
    visible: !!s._visible,
    blendMode: s._blendMode === undefined ? 0 : s._blendMode,
    pivot: [r(s._pivotX), r(s._pivotY)],
    textureName: s._textureData ? s._textureData.name : null,
    mesh: s._geometryData ? {
      vertexCount: s._geometryData.data.intArray[s._geometryData.offset + BO.GeometryVertexCount],
      vertices: (s._meshVertices || []).map(r),
      uvs: (s._meshUvs || []).map(r),
      indices: (s._meshIndices || []).slice(),
    } : null,
  }));
}

function main() {
  const args = process.argv.slice(2);
  const skePath = args[0];
  const texPath = args[1] && args[1] !== '-' ? args[1] : null;
  const animName = args[2] && args[2] !== '-' ? args[2] : null;
  const outPath = args[3] || null;

  const factory = new HeadlessFactory();

  const skeRaw = JSON.parse(fs.readFileSync(skePath, 'utf8'));
  const ske = factory.parseDragonBonesData(skeRaw);
  if (!ske) throw new Error('parseDragonBonesData falhou');
  if (texPath && fs.existsSync(texPath)) {
    const texRaw = JSON.parse(fs.readFileSync(texPath, 'utf8'));
    const tex = factory.parseTextureAtlasData(texRaw, {}, 1.0);
    if (tex) factory.addTextureAtlasData(tex, ske.name);
  }

  const armatureName = ske.armatureNames[0];
  const armature = factory.buildArmature(armatureName, ske.name);
  if (!armature) throw new Error('buildArmature falhou');

  const anim = armature.animation;
  const animationNames = armature.armatureData.animationNames;
  if (animName) anim.play(animName);

  const state0 = anim.lastAnimationState;
  const duration = state0 ? state0.totalTime : 0;
  const frameRate = armature.armatureData.frameRate;

  const frames = [];
  const totalFrames = Math.max(1, Math.round(duration * frameRate));
  for (let f = 0; f <= totalFrames; f++) {
    if (f > 0) armature.advanceTime(1.0 / frameRate);
    frames.push({ frame: f, time: r(f / frameRate), state: dumpState(armature) });
  }

  const out = {
    source: path.basename(skePath),
    runtimeVersion: db.DragonBones.VERSION,
    formatVersion: skeRaw.version,
    frameRate,
    armatureName,
    animationNames,
    animation: animName,
    duration: r(duration),
    totalFrames,
    boneCount: armature.getBones().length,
    slotCount: armature.getSlots().length,
    frames,
  };

  const json = JSON.stringify(out);
  if (outPath) {
    fs.writeFileSync(outPath, json);
    console.log(`ok -> ${path.basename(outPath)} (${frames.length} quadros, ${out.boneCount} ossos, ${out.slotCount} slots)`);
  } else {
    console.log(json.slice(0, 1500));
  }
}

main();
