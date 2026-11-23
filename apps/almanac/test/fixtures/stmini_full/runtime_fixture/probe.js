'use strict';
let sequence = 0;
const pending = new Map();
function send(message) {
  if (window.webkit && window.webkit.messageHandlers.CMSScriptMessageChannel) window.webkit.messageHandlers.CMSScriptMessageChannel.postMessage(message);
  else window.CMSScriptMessageChannel.postMessage(JSON.stringify(message));
}
window.CMSJsCallBack = function (response) {
  const finish = pending.get(response.methodId);
  if (finish) { pending.delete(response.methodId); finish(response); }
};
function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const methodId = 'fixture-' + (++sequence);
    pending.set(methodId, resolve);
    setTimeout(() => { if (pending.delete(methodId)) reject(new Error('bridge_timeout:' + method)); }, 6000);
    send({method, params: {...params, methodId}});
  });
}
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
let running = false;
async function probe() {
  if (running) return;
  running = true;
  const checks = {};
  try {
    const id = document.body.dataset.mini;
    checks.javascript = true;
    checks.css = getComputedStyle(document.body).color === 'rgb(13, 47, 83)';
    checks.image = document.getElementById('pixel').naturalWidth === 1;
    checks.packageName = (await call('getPackageName')).data.packageName === 'com.almanac.lite';
    const info = await call('mini_getMiniPackageInfo');
    checks.packageInfo = info.code === '1' && info.data.miniId === id && info.data.version === '1.0';
    checks.storageSet = (await call('setStorage', {key: 'roundtrip', data: JSON.stringify({synthetic: id})})).code === '1';
    const value = await call('getStorage', {key: 'roundtrip'});
    checks.storageRead = value.code === '1' && value.data.synthetic === id;
    checks.storageRemove = (await call('removeStorage', {key: 'roundtrip'})).code === '1';
    checks.removed = (await call('getStorage', {key: 'roundtrip'})).code === '0';
    await pause(300);
    checks.iframeAttempted = window.__iframeAttempted === true;
    const iframeTransport = window.__iframeTransport;
    const iframeDefense = iframeTransport && !iframeTransport.rawObjectPresent ? 'document_isolation' :
      iframeTransport && iframeTransport.rawPostReturned && !iframeTransport.threw ? 'native_gate' : 'transport_exception';
    checks.iframeTransportObserved = !!iframeTransport &&
      typeof iframeTransport.rawObjectPresent === 'boolean' &&
      typeof iframeTransport.rawPostReturned === 'boolean' &&
      typeof iframeTransport.threw === 'boolean' && iframeDefense !== 'transport_exception';
    checks.iframeRejected = (await call('getStorage', {key: 'iframe_probe'})).code === '0';
    send({method: 'setStorage', params: {methodId: 123, key: 'malformed_probe', data: '"forbidden"'}});
    checks.malformedRejected = (await call('getStorage', {key: 'malformed_probe'})).code === '0';
    checks.unknownMethodRejected = (await call('fixture_business_provider_not_installed')).code === '0';
    checks.providerFailClosed = (await call('getQuantSession')).code === '0';
    const updateCheck = await call('mini_checkMiniProgramUpdate');
    const updateInstall = await call('mini_downloadMiniProgramUpdate', {downloadUrl: 'http://fixture.invalid/rejected.zip', isforce: true});
    checks.updateCheckUnsupported = updateCheck.code === '0' && updateCheck.data.supported === false;
    checks.insecureUpdateInstallRejected = updateInstall.code === '0' && typeof updateInstall.data.msg === 'string' && updateInstall.data.msg.length > 0;
    document.getElementById('action').onclick = () => { document.getElementById('result').textContent = 'Synthetic interaction complete'; };
    document.getElementById('action').click();
    checks.interaction = document.getElementById('result').textContent === 'Synthetic interaction complete';
    const result = {passed: Object.values(checks).every(Boolean), miniId: id, version: info.data.version, checks, iframeTransport, iframeDefense, providerSemantics: window.webkit ? 'recognized_iOS_quant_provider_missing' : 'Android_source_unsupported_provider'};
    document.getElementById('result').textContent = result.passed ? 'Complete native Bridge checks passed' : 'Bridge checks failed';
    await call('applog', {msg: 'FULL_RUNTIME_FIXTURE_RESULT ' + JSON.stringify(result)});
    if (id === 'batch6_network_fixture' && !window.__snapshotInterval) {
      const version = info.data.version;
      window.__snapshotInterval = setInterval(async () => {
        try {
          const manifest = await (await fetch('mini-manifest.json?probe=' + Date.now())).json();
          const running = await call('mini_getMiniPackageInfo');
          await call('applog', {msg: 'FULL_RUNTIME_SNAPSHOT_RESULT ' + JSON.stringify({miniId: id, version, time: Date.now(), passed: manifest.version === version && running.code === '1' && running.data.version === version})});
        } catch (_) {}
      }, 1000);
    }

  } catch (error) {
    const result = {passed: false, miniId: document.body.dataset.mini, checks, error: String(error)};
    document.getElementById('result').textContent = 'Controlled fixture failed';
    try { send({method: 'applog', params: {methodId: 'fixture-error', msg: 'FULL_RUNTIME_FIXTURE_RESULT ' + JSON.stringify(result)}}); } catch (_) {}
  } finally { running = false; }
}
window.CMSCallJsMessage = function (message) {
  if (message.method === 'appHide' || message.method === 'appShow') {
    send({method: 'applog', params: {methodId: 'life-' + (++sequence), msg: 'FULL_RUNTIME_LIFECYCLE ' + JSON.stringify({miniId: document.body.dataset.mini, method: message.method})}});
  }
  if (message.method === 'pageWillAppear') setTimeout(probe, 300);
};
setTimeout(probe, 500);
