const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const rootDir = path.resolve('build/web');
const PORT = 55789;
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
      contentType = 'application/octet-stream'; // Test Drift resilience to non-wasm MIME on sqlite3
    }
    res.writeHead(200, {
      'Content-Type': contentType,
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
    fs.createReadStream(filePath).pipe(res);
  });
});

server.listen(PORT, async () => {
  console.log(`Test server running at http://localhost:${PORT}`);
  
  // Launch Chrome headless with remote debugging port
  const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
  const userDataDir = path.join(process.env.TEMP || '.', 'chrome-test-profile-' + Date.now());
  
  const chrome = spawn(chromePath, [
    '--headless=new',
    `--remote-debugging-port=${CDP_PORT}`,
    `--user-data-dir=${userDataDir}`,
    '--no-first-run',
    '--no-default-browser-check',
    `http://localhost:${PORT}`
  ]);

  chrome.on('error', (err) => {
    console.error('Failed to spawn Chrome:', err);
    server.close();
    process.exit(1);
  });

  // Wait 3 seconds for Chrome to start, then connect via CDP
  setTimeout(async () => {
    try {
      const httpGet = (url) => new Promise((resolve, reject) => {
        http.get(url, (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => resolve(JSON.parse(data)));
        }).on('error', reject);
      });

      const targets = await httpGet(`http://localhost:${CDP_PORT}/json`);
      const pageTarget = targets.find(t => t.type === 'page');
      if (!pageTarget) {
        console.error('No page target found');
        cleanup();
        return;
      }

      console.log('Target found:', pageTarget.title, pageTarget.url);

      const ws = new WebSocket(pageTarget.webSocketDebuggerUrl);

      let msgId = 1;
      const send = (method, params = {}) => {
        return new Promise((resolve, reject) => {
          const id = msgId++;
          const timer = setTimeout(() => {
            ws.removeEventListener('message', handler);
            console.warn('send timeout for ' + method);
            resolve({});
          }, 15000);
          const handler = (event) => {
            const parsed = JSON.parse(event.data);
            if (parsed.id === id) {
              clearTimeout(timer);
              ws.removeEventListener('message', handler);
              if (parsed.error) {
                console.error('CDP error for ' + method + ':', parsed.error);
              }
              resolve(parsed.result || {});
            }
          };
          ws.addEventListener('message', handler);
          ws.send(JSON.stringify({ id, method, params }));
        });
      };

      ws.addEventListener('open', async () => {
        console.log('Connected to CDP');

        ws.addEventListener('message', (event) => {
          const parsed = JSON.parse(event.data);
          if (parsed.method === 'Console.messageAdded') {
            console.log(`[CONSOLE ${parsed.params.message.level}]`, parsed.params.message.text);
          }
          if (parsed.method === 'Runtime.consoleAPICalled') {
            const args = (parsed.params.args || []).map(a => a.value || a.description || JSON.stringify(a)).join(' ');
            console.log(`[BROWSER CONSOLE ${parsed.params.type}]`, args);
          }
          if (parsed.method === 'Runtime.exceptionThrown') {
            console.error('[BROWSER EXCEPTION]', JSON.stringify(parsed.params.exceptionDetails));
          }
        });

        await send('Runtime.enable');
        await send('Log.enable');

        // Wait 15 seconds for Flutter app to download 4MB main.dart.js, boot, and run queries
        setTimeout(async () => {
          // Check if Flutter canvas rendered
          const canvasRes = await send('Runtime.evaluate', {
            expression: `document.querySelectorAll('flt-glass-pane, flt-scene, canvas').length`
          });
          console.log('[FLUTTER ELEMENTS COUNT]:', canvasRes?.result?.value);

          const bodyText = await send('Runtime.evaluate', {
            expression: `document.body.innerText`
          });
          console.log('[BODY TEXT]:', (bodyText?.result?.value || '').substring(0, 200));

          const hasError = (bodyText?.result?.value || '').includes('Erro ao carregar');
          console.log('[HAS ERROR "Erro ao carregar"]:', hasError);

          ws.close();
          cleanup();
          process.exit(hasError ? 1 : 0);
        }, 8000);
      });

      function cleanup() {
        chrome.kill();
        server.close();
        try { fs.rmSync(userDataDir, { recursive: true, force: true }); } catch (_) {}
      }
    } catch (e) {
      console.error('Error during CDP interaction:', e);
      chrome.kill();
      server.close();
      process.exit(1);
    }
  }, 2000);
});
