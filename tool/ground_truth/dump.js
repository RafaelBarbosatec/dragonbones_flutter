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

// Slot: todos os métodos abstratos de render viram no-op. O que interessa aqui
// é a matemática (transforms dos ossos), não o desenho.
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
  _updateFrame() { }
  _updateMesh() { }
  _updateTransform() { }
  _identityTransform() { }
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
  const slots = armature.getSlots().map((s) => ({
    name: s.name,
    displayIndex: s.displayIndex,
    color: [r(s._colorTransform.aM), r(s._colorTransform.rM), r(s._colorTransform.gM), r(s._colorTransform.bM),
            r(s._colorTransform.aO), r(s._colorTransform.rO), r(s._colorTransform.gO), r(s._colorTransform.bO)],
  }));
  return { bones, slots };
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
