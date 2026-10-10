/**
 * Ground-truth harness for *animation events* — the official DragonBones
 * runtime (TypeScript compiled to JS) driven headlessly in node, with every
 * event it emits captured in order.
 *
 * Deliberately standalone rather than an extra mode of `dump.js`: that script
 * produces the 9 MB of committed pose dumps, and nothing here may perturb them.
 *
 * Uso: node dump_events.js <ske.json> <tex.json> <out.json> [fixtureId]
 *
 * Por que o clock: eventos são bufferizados durante o update e despachados no
 * fim de `DragonBones.advanceTime` — nunca pelo `Armature.advanceTime`. Então
 * aqui a armature é registrada no clock do hub e o hub é quem avança, que é
 * exatamente o que o binding oficial do Egret faz (EgretFactory.advanceTime /
 * `_dragonBones.clock.add(armature)`). Um harness que chamasse
 * `armature.advanceTime` direto não veria evento nenhum.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const RUNTIME = process.env.DRAGONBONES_JS ||
  path.join(__dirname, 'vendor', 'dragonBones.js');

let runtimeContext = null;

function loadRuntime() {
  const code = fs.readFileSync(RUNTIME, 'utf8');
  const ctx = vm.createContext({ console });
  vm.runInContext(code, ctx, { filename: 'dragonBones.js' });
  runtimeContext = ctx;
  return ctx.dragonBones;
}

// Arrays handed to the runtime MUST be created inside the runtime's own vm
// context.
//
// The official parser tests `rawData instanceof Array` (ObjectDataParser.ts:1897,
// inside `_parseActionData`) and nothing else in the JSON path. An array produced
// by this file's `JSON.parse` belongs to a *different* realm, so that test is
// false, and every animation action — frame events, sounds, `gotoAndPlay` — is
// silently dropped. Everything else in the parser iterates with `for...of`,
// which is realm-agnostic, so actions were the only casualty and the pose dumps
// looked perfectly healthy without them.
function parseInRuntime(text) {
  runtimeContext.__text = text;
  try {
    return vm.runInContext('JSON.parse(__text)', runtimeContext);
  } finally {
    delete runtimeContext.__text;
  }
}

const db = loadRuntime();

// Optional tracing (DBE_TRACE=1). Monkey-patching the reference runtime is the
// only way to see *why* an event did or did not fire: the compiled JS exposes
// no hooks, and "the event is missing" is indistinguishable from "the timeline
// state was never created" from the outside.
if (process.env.DBE_TRACE) {
  const cross = db.ActionTimelineState.prototype._onCrossFrame;
  db.ActionTimelineState.prototype._onCrossFrame = function (frameIndex) {
    // Mirror upstream's own frame lookup so the action list can be inspected
    // (`BinaryOffset.TimelineFrameOffset` is a const enum, inlined away).
    const tld = this._timelineData;
    const frameOffset = this._animationData.frameOffset +
      this._timelineArray[tld.offset + 5 + frameIndex];
    const actionCount = this._frameArray[frameOffset + 1];
    const actions = this._animationData.parent.actions;
    const listed = [];
    for (let i = 0; i < actionCount; ++i) {
      const ai = this._frameArray[frameOffset + 2 + i];
      const a = actions[ai];
      listed.push(`${ai}:${a ? a.type + '/' + a.name : 'NULL'}`);
    }
    console.error(`  _onCrossFrame(f=${frameIndex}) anim=${this._animationData.name}` +
      ` actionEnabled=${this._animationState.actionEnabled}` +
      ` frameCount=${this._frameCount} frameIndex=${this._frameIndex}` +
      ` offset=${this._frameOffset} count=${actionCount} [${listed.join(',')}]`);
    return cross.call(this, frameIndex);
  };

  const parseActionInFrame = db.ObjectDataParser.prototype._parseActionDataInFrame;
  db.ObjectDataParser.prototype._parseActionDataInFrame = function (rawData, frameStart) {
    console.error(`  _parseActionDataInFrame(keys=${Object.keys(rawData)}) frameStart=${frameStart}` +
      ` armature=${this._armature ? this._armature.name : 'null'}`);
    return parseActionInFrame.apply(this, arguments);
  };

  const addAction = db.ArmatureData.prototype.addAction;
  db.ArmatureData.prototype.addAction = function (value, isDefault) {
    console.error(`  addAction(armature=${this.name} type=${value.type} name=${value.name} isDefault=${isDefault})`);
    return addAction.call(this, value, isDefault);
  };

  const fadeIn = db.Animation.prototype.fadeIn;
  db.Animation.prototype.fadeIn = function (name) {
    console.error(`  fadeIn(armature=${this._armature.armatureData.name} name=${JSON.stringify(name)})`);
    if (process.env.DBE_STACK) {
      console.error(new Error('fadeIn').stack.split('\n').slice(1, 9).join('\n'));
    }
    return fadeIn.apply(this, arguments);
  };

  const play = db.Animation.prototype.play;
  db.Animation.prototype.play = function (name) {
    console.error(`  play(armature=${this._armature.armatureData.name} name=${JSON.stringify(name)})`);
    return play.apply(this, arguments);
  };

  const bufferAction = db.Armature.prototype._bufferAction;
  db.Armature.prototype._bufferAction = function (action, append) {
    const ad = action.actionData;
    console.error(`  _bufferAction(armature=${this._armatureData.name} type=${ad ? ad.type : '?'}` +
      ` name=${ad ? ad.name : '?'} append=${append} slot=${action.slot ? action.slot.name : '-'})`);
    return bufferAction.call(this, action, append);
  };

  const parseAction = db.ObjectDataParser.prototype._parseActionData;
  db.ObjectDataParser.prototype._parseActionData = function (rawData, type) {
    const result = parseAction.apply(this, arguments);
    console.error(`  _parseActionData(type=${type}) -> ${result.length}` +
      ` raw=${JSON.stringify(rawData).slice(0, 90)}`);
    return result;
  };

  const init = db.TimelineState.prototype.init;
  db.TimelineState.prototype.init = function (armature, animationState, timelineData) {
    init.call(this, armature, animationState, timelineData);
    if (this instanceof db.ActionTimelineState) {
      const ad = animationState._animationData.parent;
      console.error(`  ActionTimelineState.init: armature=${ad.name}` +
        ` timelineData=${timelineData !== null}` +
        ` actions=${ad.actions.length}` +
        ` kinds=${ad.actions.map((a) => a.type + ':' + a.name).join(',')}`);
    }
  };
}

// ---------------------------------------------------------------- collector

// Every event the run produces, in dispatch order. Shared by all proxies (each
// armature — including nested children — has its own) and by the hub's global
// event manager, so nothing is missed.
let events = [];
let currentFrame = 0;

function r(v) { return Math.round(v * 1e6) / 1e6; }

const VERBOSE = !!process.env.DBE_VERBOSE;

function record(type, eventObject) {
  if (VERBOSE) {
    const state = eventObject.animationState;
    console.error(`    [f${currentFrame}] ${type} name=${eventObject.name || '-'}` +
      ` slot=${eventObject.slot ? eventObject.slot.name : '-'}` +
      ` state=${state ? state.name : '-'}` +
      ` time=${state ? r(state.currentTime) : '-'}/${state ? r(state.totalTime) : '-'}` +
      ` play=${state ? state.currentPlayTimes : '-'}` +
      ` frameCnt=${state ? state._actionTimeline : '-'}`);
  }
  events.push({
    frame: currentFrame,
    type,
    name: eventObject.name || '',
    time: r(eventObject.time || 0),
    armature: eventObject.armature ? eventObject.armature.armatureData.name : null,
    animationState: eventObject.animationState ? eventObject.animationState.name : null,
    bone: eventObject.bone ? eventObject.bone.name : null,
    slot: eventObject.slot ? eventObject.slot.name : null,
    data: eventObject.data ? {
      ints: eventObject.data.ints.slice(),
      floats: eventObject.data.floats.slice(),
      strings: eventObject.data.strings.slice(),
    } : null,
  });
}

// Proxy that listens to everything. `hasDBEventListener` returning true is what
// makes the official runtime allocate the frame events at all — with `false` it
// silently skips them (only sounds are unconditional).
class CollectingDisplay {
  static toString() { return '[class CollectingDisplay]'; }
  constructor() { this._armature = null; }
  get armature() { return this._armature; }
  get animation() { return this._armature ? this._armature.animation : null; }
  dbInit(armature) { this._armature = armature; }
  dbUpdate() { }
  dbClear() { this._armature = null; }
  dispose(_disposeProxy) { }
  hasDBEventListener(_type) { return true; }
  addDBEventListener(_type, _listener) { }
  removeDBEventListener(_type, _listener) { }
  dispatchDBEvent(type, eventObject) { record(type, eventObject); }
}

// Slots: pose math is irrelevant here, so every render hook is a no-op. Unlike
// dump.js there is no mesh transcription — events do not depend on geometry.
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
    this._dragonBones = new db.DragonBones(new CollectingDisplay());
  }
  _isSupportMesh() { return true; }
  _buildTextureAtlasData(textureAtlasData, _textureAtlas) {
    return textureAtlasData || db.BaseObject.borrowObject(HeadlessTextureAtlasData);
  }
  _buildArmature(dataPackage) {
    const armature = db.BaseObject.borrowObject(db.Armature);
    const display = new CollectingDisplay();
    armature.init(dataPackage.armature, display, display, this._dragonBones);
    // The binding registers the armature on the hub's clock; the hub then both
    // advances and dispatches. Same as EgretFactory._buildArmature.
    this._dragonBones.clock.add(armature);
    return armature;
  }
  _buildSlot(_dataPackage, slotData, armature) {
    const slot = db.BaseObject.borrowObject(HeadlessSlot);
    slot.init(slotData, armature, {}, {});
    return slot;
  }
}

// ---------------------------------------------------------------- scenarios

/**
 * Plays one animation and returns the events it produced.
 *
 * A *fresh factory per scenario*, not a fresh armature: every armature built —
 * including the nested child armatures, which are built during the first update —
 * registers itself on the hub's clock, and `armature.clock = null` only detaches
 * the root. Reusing a hub therefore lets the children of previous scenarios keep
 * advancing and firing events into the current recording. Re-parsing costs a few
 * milliseconds and buys exact isolation.
 */
function runScenario(skeText, texText, armatureName, animationName, playTimes) {
  events = [];

  const factory = new HeadlessFactory();
  const ske = factory.parseDragonBonesData(parseInRuntime(skeText));
  if (!ske) {
    return { error: 'parseDragonBonesData falhou' };
  }
  if (texText !== null) {
    const tex = factory.parseTextureAtlasData(parseInRuntime(texText), {}, 1.0);
    if (tex) factory.addTextureAtlasData(tex, ske.name);
  }

  const fps = ske.getArmature(armatureName).frameRate;
  const armature = factory.buildArmature(armatureName, ske.name);
  if (armature === null) {
    return { error: 'buildArmature falhou' };
  }

  const animation = armature.animation;
  animation.play(animationName, playTimes);

  const state = animation.lastAnimationState;
  if (state === null) {
    return { error: 'play() produced no state' };
  }

  const duration = state.totalTime;
  // playTimes loops, plus slack so `complete` lands (it fires on the crossing
  // that ends the last loop).
  const loops = playTimes > 0 ? playTimes : 1;
  const totalFrames = Math.ceil(duration * fps * loops) + 4;

  for (let f = 0; f <= totalFrames; f++) {
    currentFrame = f;
    factory._dragonBones.advanceTime(1.0 / fps);
  }

  return {
    record: {
      animation: animationName,
      playTimes,
      duration: r(duration),
      totalFrames,
      events: events.slice(),
    },
  };
}

function main() {
  const args = process.argv.slice(2);
  const skePath = args[0];
  const texPath = args[1] && args[1] !== '-' ? args[1] : null;
  const outPath = args[2] || null;
  const fixtureId = args[3] || path.basename(skePath);

  const skeText = fs.readFileSync(skePath, 'utf8');
  const texText = texPath && fs.existsSync(texPath) ? fs.readFileSync(texPath, 'utf8') : null;

  // A throwaway factory just to read the armature/animation metadata.
  const probeFactory = new HeadlessFactory();
  const probeData = probeFactory.parseDragonBonesData(parseInRuntime(skeText));
  if (!probeData) throw new Error('parseDragonBonesData falhou');
  const armatureName = probeData.armatureNames[0];
  const probeArmature = probeFactory.buildArmature(armatureName, probeData.name);
  if (!probeArmature) throw new Error('buildArmature falhou');
  const animationNames = probeArmature.armatureData.animationNames;
  const fps = probeArmature.armatureData.frameRate;
  const formatVersion = probeData.version;

  const scenarios = [];
  for (const animationName of animationNames) {
    // playTimes 1 → start / frame events / complete
    // playTimes 2 → the same, plus loopComplete at the end of the first loop
    for (const playTimes of [1, 2]) {
      const result = runScenario(skeText, texText, armatureName, animationName, playTimes);
      if (result.error) {
        scenarios.push({ animation: animationName, playTimes, error: result.error, events: [] });
      } else {
        scenarios.push(result.record);
      }
    }
  }

  const out = {
    source: path.basename(skePath),
    runtimeVersion: db.DragonBones.VERSION,
    formatVersion,
    frameRate: fps,
    armatureName,
    animationNames,
    fixture: fixtureId,
    scenarios,
  };

  const json = JSON.stringify(out);
  if (outPath) {
    fs.writeFileSync(outPath, json);
    const total = scenarios.reduce((n, s) => n + (s.events ? s.events.length : 0), 0);
    console.log(`ok -> ${path.basename(outPath)} (${scenarios.length} cenários, ${total} eventos)`);
  } else {
    console.log(json.slice(0, 3000));
  }
}

main();
