'use strict';
window.__rendererProbe = { ran: true, clicked: false, remoteCodeExecuted: false, attempts: {} };
document.getElementById('content').textContent = 'Verified local Mini DOM from probe.js';
document.getElementById('action').addEventListener('click', function () {
  window.__rendererProbe.clicked = true;
  document.getElementById('result').textContent = 'Local interaction completed';
});
window.runNetworkProbe = async function (port) {
  const probe = window.__rendererProbe;
  const base = 'http://127.0.0.1:' + port + '/';
  const jobs = [];
  function resource(name, element, url) {
    jobs.push(new Promise(function (resolve) {
      let ended = false;
      function end(value) { if (ended) return; ended = true; probe.attempts[name] = value; element.remove(); resolve(); }
      element.onload = function () { end('load'); };
      element.onerror = function () { end('error'); };
      probe.attempts[name] = 'attempted';
      element.src = url;
      document.body.appendChild(element);
      setTimeout(function () { end('timeout'); }, 1200);
    }));
  }
  resource('image', new Image(), base + 'image');
  resource('remoteScript', document.createElement('script'), base + 'script');
  resource('iframe', document.createElement('iframe'), base + 'frame');
  resource('file', new Image(), 'file:///etc/passwd');
  resource('content', new Image(), 'content://stmini.invalid/private');
  resource('dataScript', document.createElement('script'), 'data:text/javascript,window.__rendererProbe.remoteCodeExecuted=true');
  const blob = URL.createObjectURL(new Blob(['window.__rendererProbe.remoteCodeExecuted=true'], { type: 'application/javascript' }));
  resource('blobScript', document.createElement('script'), blob);
  probe.attempts.fetch = 'attempted';
  jobs.push(fetch(base + 'fetch').then(function () { probe.attempts.fetch = 'resolved'; }, function () { probe.attempts.fetch = 'rejected'; }));
  jobs.push(new Promise(function (resolve) {
    const xhr = new XMLHttpRequest(); probe.attempts.xhr = 'attempted';
    xhr.onload = function () { probe.attempts.xhr = 'load'; resolve(); };
    xhr.onerror = function () { probe.attempts.xhr = 'error'; resolve(); };
    xhr.ontimeout = function () { probe.attempts.xhr = 'timeout'; resolve(); };
    try { xhr.open('GET', base + 'xhr'); xhr.timeout = 1200; xhr.send(); }
    catch (_) { probe.attempts.xhr = 'rejected'; resolve(); }
  }));
  jobs.push(new Promise(function (resolve) {
    probe.attempts.websocket = 'attempted'; let socket;
    try {
      socket = new WebSocket('ws://127.0.0.1:' + port + '/socket');
      socket.onerror = function () { probe.attempts.websocket = 'error'; resolve(); };
      socket.onopen = function () { probe.attempts.websocket = 'open'; socket.close(); resolve(); };
      setTimeout(function () { if (probe.attempts.websocket === 'attempted') { probe.attempts.websocket = 'timeout'; socket.close(); resolve(); } }, 1200);
    } catch (_) { probe.attempts.websocket = 'rejected'; resolve(); }
  }));
  probe.attempts.popup = window.open(base + 'popup', '_blank') === null ? 'rejected' : 'opened';
  const form = document.createElement('form'); form.action = base + 'form'; form.method = 'POST';
  probe.attempts.form = 'attempted'; document.body.appendChild(form); form.submit(); form.remove();
  jobs.push(new Promise(function (resolve) { setTimeout(function () { probe.attempts.form = 'settled_without_navigation'; resolve(); }, 1200); }));
  await Promise.all(jobs); URL.revokeObjectURL(blob); probe.done = true;
  return probe;
};

// Enabled only in the externally installed Engine fixture, never product assets.
const engineAutoNavigation = false;
if (engineAutoNavigation) { setTimeout(function () { document.getElementById('second').click(); }, 5000); }
