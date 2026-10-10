const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const base = 'qgc-dehaze/qgc4-overlay/';
const read = p => fs.readFileSync(base + p, 'utf8');
function fn(source, name) {
  const start = source.indexOf('function ' + name + '(');
  assert.notEqual(start, -1, name + ' must exist');
  const open = source.indexOf('{', start);
  let depth = 1, end = open + 1;
  for (; depth && end < source.length; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  return source.slice(start, end);
}
test('telemetry uses stock palette and QGC labels, not 13px custom text', () => {
  const s = read('src/FlightDisplay/TelemetryValuesBar.qml');
  assert.match(s, /color:\s*qgcPal.window/);
  assert.match(s, /QGCLabel\s*\{/);
  assert.match(s, /ScreenTools.smallFontPointSize/);
  assert.match(s, /ScreenTools.defaultFontPointSize/);
  assert.doesNotMatch(s, /font.pixelSize:\s*13|#DDDDDD|#C0191D22/);
});
test('telemetry keeps three columns and uses native Fact names', () => {
  const s = read('src/FlightDisplay/TelemetryValuesBar.qml');
  assert.equal((s.match(/model:\s*3/g) || []).length, 2);
  assert.match(s, /shortDescription/);
  assert.match(s, /Distance to Home/);
  assert.match(s, /Engine Load/);
});
test('formatter uses stock enum/value string and never fabricates missing data', () => {
  const format = vm.runInNewContext('(' + fn(read('src/FlightDisplay/TelemetryValuesBar.qml'), 'format') + ')');
  assert.equal(format(null), '—');
  assert.equal(format({valueString:'nan'}), '—');
  assert.equal(format({valueString:'22.18',enumOrValueString:'22.18',units:'V'}), '22.18 V');
  assert.equal(format({valueString:'1',enumOrValueString:'Ready',units:''}), 'Ready');
});
test('RC indicator keeps RC icon, replaces signal bars with text', () => {
  const s = read('src/ui/toolbar/RCRSSIIndicator.qml');
  assert.match(s, /RC.svg/);
  assert.doesNotMatch(s, /SignalStrength\s*\{/);
  assert.match(s, /RSSI/);
  assert.match(s, /dBm/);
});
test('signal text uses independent native readings and handles disconnected state', () => {
  const s = read('src/ui/toolbar/RCRSSIIndicator.qml');
  const context = {_activeVehicle:null};
  vm.createContext(context);
  vm.runInContext(fn(s, 'signalText'), context);
  assert.equal(context.signalText(), 'RSSI —% · — dBm');
  context._activeVehicle = {rcRSSI:0,telemetryLRSSI:-75};
  assert.equal(context.signalText(), 'RSSI 0% · -75 dBm');
  context._activeVehicle = {rcRSSI:255,telemetryLRSSI:0};
  assert.equal(context.signalText(), 'RSSI —% · — dBm');
  context._activeVehicle = {rcRSSI:64,telemetryLRSSI:-128};
  assert.equal(context.signalText(), 'RSSI 64% · -128 dBm');
  context._activeVehicle.vehicleLinkManager = {communicationLost:true};
  assert.equal(context.signalText(), 'RSSI —% · — dBm');
  context._activeVehicle = {rcRSSI:null,telemetryLRSSI:null};
  assert.equal(context.signalText(), 'RSSI —% · — dBm');
});
test('RSSI and DEHAZING remain present when no vehicle is connected', () => {
  const s = read('src/ui/toolbar/MainToolBarIndicators.qml');
  assert.match(s, /Row\s*\{\s*visible:\s*!indicatorRow.hasRcRssiIndicator\(\)/);
  assert.match(s, /RCRSSIIndicator\s*\{/);
});
test('marked left tool strip is hidden with zero insets', () => {
  const s = read('src/FlightDisplay/FlyViewWidgetLayer.qml');
  const block = s.slice(s.indexOf('FlyViewToolStrip {'), s.indexOf('GripperMenu {'));
  assert.match(block, /visible:\s*false/);
  assert.match(block, /leftEdgeTopInset: visible \?/);
});
test('status is anchored in upper toolbar rather than video picture', () => {
  const s = read('src/ui/toolbar/MainToolBar.qml');
  assert.match(s, /id:\s*dehazeStatus/);
  assert.match(s, /anchors.right:\s*parent.right/);
  assert.match(s, /dehazeStatus.left/);
  assert.match(s, /dehazeAlgorithm/);
  assert.match(s, /затримка — ms/);
  assert.doesNotMatch(read('src/FlightDisplay/FlightDisplayViewVideo.qml'), /id:\s*dehazeStatus|id:\s*dbm/);
});
test('camera label is enlarged while retaining native pitch source', () => {
  const s = read('src/FlightDisplay/FlightDisplayViewVideo.qml');
  assert.match(s, /font.pixelSize:\s*19 \* 2.5/);
  assert.match(s, /root.pitchFact.rawValue/);
  assert.match(s, /CAM —°/);
});
test('build replaces variant token in new upper toolbar', () => {
  assert.match(fs.readFileSync('.github/workflows/build-qgc44-dehaze.yml','utf8'), /sed -i[^\n]*DEHAZE_BUILD_VARIANT[^\n]*src\/ui\/toolbar\/MainToolBar.qml/);
});
