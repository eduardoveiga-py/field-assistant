const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const rootDir = path.resolve('build/web');
const CDP_PORT = 9333;

const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.wasm': 'application/wasm',
  '.json': 'application/json',
  '.png': 'image/png',
  '.css': 'text/css',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
};

async function runMode({ port, sqliteMime, label }) {
  return new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      let reqPath = req.url.split('?')[0];
      if (reqPath === '/') reqPath = '/index.html';
      const filePath = path.join(rootDir, reqPath);

      fs.stat(filePath, (err, stats) => {
        if (err || !stats.isFile()) {
          res.writeHead(404, { 'Content-Type': 'text/html' });
          res.end('<h1>404 Not Found</h1>');
          return;
        }
        const ext = path.extname(filePath).toLowerCase();
        let contentType = MIME_TYPES[ext] || 'application/octet-stream';
        if (reqPath.endsWith('sqlite3.wasm')) {
          contentType = sqliteMime;
        }
        res.writeHead(200, {
          'Content-Type': contentType,
          'Cross-Origin-Opener-Policy': 'same-origin',
          'Cross-Origin-Embedder-Policy': 'require-corp',
        });
        fs.createReadStream(filePath).pipe(res);
      });
    });

    server.listen(port, () => {
      console.log(`[${label}] Test server running at http://localhost:${port} (sqlite3.wasm MIME: ${sqliteMime})`);

      const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
      const userDataDir = path.join(process.env.TEMP || '.', `chrome-test-profile-${label}-${Date.now()}`);
      const cdpPort = CDP_PORT + (port % 10);

      const chrome = spawn(chromePath, [
        '--headless=new',
        `--remote-debugging-port=${cdpPort}`,
        `--user-data-dir=${userDataDir}`,
        '--no-first-run',
        '--no-default-browser-check',
        `http://localhost:${port}`,
      ]);

      const cleanup = () => {
        try { chrome.kill(); } catch (_) {}
        try { server.close(); } catch (_) {}
        try { fs.rmSync(userDataDir, { recursive: true, force: true }); } catch (_) {}
      };

      chrome.on('error', (err) => {
        cleanup();
        reject(new Error(`[${label}] Failed to spawn Chrome: ${err}`));
      });

      setTimeout(async () => {
        try {
          const httpGet = (url) => new Promise((resGet, rejGet) => {
            http.get(url, (res) => {
              let data = '';
              res.on('data', (chunk) => { data += chunk; });
              res.on('end', () => resGet(JSON.parse(data)));
            }).on('error', rejGet);
          });

          const targets = await httpGet(`http://localhost:${cdpPort}/json`);
          const pageTarget = targets.find((t) => t.type === 'page');
          if (!pageTarget) {
            cleanup();
            reject(new Error(`[${label}] No page target found`));
            return;
          }

          const ws = new WebSocket(pageTarget.webSocketDebuggerUrl);
          let msgId = 1;
          const send = (method, params = {}) => new Promise((resSend) => {
            const id = msgId++;
            const timer = setTimeout(() => {
              ws.removeEventListener('message', handler);
              console.warn(`[${label}] send timeout for ${method}`);
              resSend({});
            }, 15000);
            const handler = (event) => {
              const parsed = JSON.parse(event.data);
              if (parsed.id === id) {
                clearTimeout(timer);
                ws.removeEventListener('message', handler);
                resSend(parsed.result || {});
              }
            };
            ws.addEventListener('message', handler);
            ws.send(JSON.stringify({ id, method, params }));
          });

          ws.addEventListener('open', async () => {
            let hasCspViolation = false;
            let hasRuntimeException = false;

            ws.addEventListener('message', (event) => {
              const parsed = JSON.parse(event.data);
              if (parsed.method === 'Log.entryAdded') {
                const entry = parsed.params.entry || {};
                console.log(`[${label} LOG ${entry.level}/${entry.source}]`, entry.text);
                if (entry.source === 'security' || (entry.text || '').includes('Content Security Policy')) {
                  hasCspViolation = true;
                }
              }
              if (parsed.method === 'Runtime.consoleAPICalled') {
                const args = (parsed.params.args || []).map((a) => a.value || a.description || '').join(' ');
                if (args.includes('ERRO CRÍTICO [DriftWeb]')) {
                  hasRuntimeException = true;
                }
              }
              if (parsed.method === 'Runtime.exceptionThrown') {
                hasRuntimeException = true;
                console.error(`[${label} EXCEPTION]`, JSON.stringify(parsed.params.exceptionDetails));
              }
            });

            await send('Runtime.enable');
            await send('Log.enable');

            let finalState = {
              elementsCount: 0,
              hasPersistenceStorage: false,
              reachedAuthOrHome: false,
              hasFatalScreen: false,
              hasTileCspAllowed: false,
              semanticsSample: [],
            };

            // Poll up to 24s for Flutter boot, Drift Wasm/IndexedDB/OPFS open, and splash transition
            for (let i = 0; i < 12; i++) {
              await new Promise((r) => setTimeout(r, 2000));
              const evalRes = await send('Runtime.evaluate', {
                awaitPromise: true,
                expression: `(async () => {
                  const placeholder = document.querySelector('flt-semantics-placeholder');
                  if (placeholder) placeholder.click();
                  await new Promise(r => setTimeout(r, 300));
                  const elementsCount = document.querySelectorAll('flt-glass-pane, flutter-view, flt-scene, canvas').length;
                  const dbs = indexedDB.databases ? await indexedDB.databases() : [];
                  let opfs = [];
                  try {
                    const root = await navigator.storage.getDirectory();
                    for await (const [name] of root.entries()) opfs.push(name);
                  } catch (_) {}
                  const semantics = Array.from(document.querySelectorAll('flt-semantics'))
                    .map(e => e.getAttribute('aria-label') || e.textContent || '')
                    .filter(Boolean);
                  const cspMeta = document.querySelector('meta[http-equiv="Content-Security-Policy"]')?.getAttribute('content') || '';
                  const hasTileCspAllowed = [
                    'https://tile.openstreetmap.org',
                    'https://*.openstreetmap.fr',
                    'https://server.arcgisonline.com',
                    'https://tile.opentopomap.org',
                    'https://*.basemaps.cartocdn.com',
                  ].every(d => cspMeta.includes(d));
                  return JSON.stringify({
                    elementsCount,
                    dbs: dbs.map(d => d.name),
                    opfs,
                    semantics,
                    hasTileCspAllowed,
                  });
                })()`,
              });
              const data = JSON.parse(evalRes?.result?.value || '{}');
              const texts = data.semantics || [];
              const hasPersistence = (data.opfs || []).length > 0 || (data.dbs || []).some((n) => String(n).includes('ministerio_pessoal'));
              const reached = texts.some((t) =>
                t.includes('Entrar na Conta') || t.includes('Hoje no Ministério')
              );
              const fatal = texts.some((t) =>
                t.includes('Armazenamento Local Indisponível') || t.includes('Erro ao carregar')
              );

              finalState = {
                elementsCount: data.elementsCount || 0,
                hasPersistenceStorage: hasPersistence,
                reachedAuthOrHome: reached,
                hasFatalScreen: fatal,
                hasTileCspAllowed: Boolean(data.hasTileCspAllowed),
                semanticsSample: texts.slice(0, 8),
                dbs: data.dbs || [],
                opfs: data.opfs || [],
              };

              if (fatal || (hasPersistence && reached)) {
                break;
              }
            }

            console.log(`[${label}] STATE:`, JSON.stringify(finalState));
            const failed =
              finalState.elementsCount === 0 ||
              !finalState.hasPersistenceStorage ||
              !finalState.reachedAuthOrHome ||
              finalState.hasFatalScreen ||
              !finalState.hasTileCspAllowed ||
              hasCspViolation ||
              hasRuntimeException;

            ws.close();
            cleanup();
            if (failed) {
              reject(new Error(`[${label}] Web/Drift check failed: ${JSON.stringify({ ...finalState, hasCspViolation, hasRuntimeException })}`));
            } else {
              resolve();
            }
          });
        } catch (e) {
          cleanup();
          reject(e);
        }
      }, 2000);
    });
  });
}

(async () => {
  try {
    await runMode({
      port: 55789,
      sqliteMime: 'application/wasm',
      label: 'WASM-WORKER',
    });
    await runMode({
      port: 55790,
      sqliteMime: 'application/octet-stream',
      label: 'OCTET-FALLBACK',
    });
    console.log('ALL WEB DRIFT + CSP CHECKS PASSED');
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
})();
