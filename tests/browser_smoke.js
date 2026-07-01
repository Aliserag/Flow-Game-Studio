// Browser smoke test for the exported web build.
// Starts a static server pointing at dist/web/, opens the HTML5 build in
// headless Chromium, asserts the canvas appears and the engine prints its
// usual boot lines to the console, then exits 0 / 1.
//
// Run with:
//   NODE_PATH=/opt/node22/lib/node_modules node tests/browser_smoke.js
//
// On success prints:
//   [browser-smoke] PASS  <details>
// On failure prints the captured console + page errors and exits non-zero.

const path = require('path');
const fs = require('fs');
const http = require('http');
const { chromium } = require('playwright');

const ROOT = path.join(__dirname, '..', 'dist', 'web');
const PORT = 8000;
const PAGE = `http://127.0.0.1:${PORT}/index.html`;

function startServer() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      // Strip query string and decode.
      const reqPath = decodeURIComponent(req.url.split('?')[0]);
      const filePath = path.join(ROOT, reqPath === '/' ? '/index.html' : reqPath);
      // Path safety.
      if (!filePath.startsWith(ROOT)) {
        res.writeHead(403); res.end('forbidden'); return;
      }
      fs.stat(filePath, (err, st) => {
        if (err || !st.isFile()) { res.writeHead(404); res.end('not found'); return; }
        // Godot HTML5 needs cross-origin isolation for SharedArrayBuffer/threads.
        res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
        res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
        const ext = path.extname(filePath).toLowerCase();
        const mime = {
          '.html': 'text/html',
          '.js':   'application/javascript',
          '.wasm': 'application/wasm',
          '.pck':  'application/octet-stream',
          '.png':  'image/png',
        }[ext] || 'application/octet-stream';
        res.setHeader('Content-Type', mime);
        fs.createReadStream(filePath).pipe(res);
      });
    });
    server.listen(PORT, '127.0.0.1', () => resolve(server));
  });
}

(async () => {
  let server, browser;
  try {
    server = await startServer();
    console.log(`[browser-smoke] serving ${ROOT} on ${PAGE}`);

    browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-dev-shm-usage'],
    });
    const ctx = await browser.newContext();
    const page = await ctx.newPage();

    const consoleLines = [];
    const pageErrors = [];
    page.on('console', m => consoleLines.push(`[${m.type()}] ${m.text()}`));
    page.on('pageerror', e => pageErrors.push(e.message));

    const resp = await page.goto(PAGE, { waitUntil: 'load', timeout: 30000 });
    if (!resp || !resp.ok()) {
      throw new Error(`navigation failed: ${resp && resp.status()}`);
    }

    // Wait for canvas + engine boot — Godot prints `[DataLoader]` once autoloads init.
    await page.waitForSelector('canvas#canvas', { timeout: 20000 });
    let booted = false;
    for (let i = 0; i < 30; i++) {
      await page.waitForTimeout(1000);
      if (consoleLines.some(l => l.includes('[DataLoader]') || l.includes('terrain='))) {
        booted = true; break;
      }
    }

    // Snapshot the menu for evidence.
    const snapDir = path.join(__dirname, '..', '..', 'production', 'e2e', 'screenshots');
    fs.mkdirSync(snapDir, { recursive: true });
    const menuSnap = path.join(snapDir, 'web-menu.png');
    await page.screenshot({ path: menuSnap, fullPage: false });

    // Verify the canvas has rendered something (non-zero size).
    const canvasSize = await page.evaluate(() => {
      const c = document.querySelector('canvas#canvas');
      return c ? { w: c.width, h: c.height } : null;
    });

    // Drive the menu — first dismiss any dropdown by pressing Esc, then click
    // the SOLO SURVIVOR button. The menu panel is centered; based on the
    // captured menu screenshot the button sits around y=470 in canvas-pixel space.
    const consoleSnap = consoleLines.length;
    const canvas = await page.$('canvas#canvas');
    if (canvas) {
      const box = await canvas.boundingBox();
      const scaleX = box.width / 1280;
      const scaleY = box.height / 720;
      // SOLO SURVIVOR button is centered at roughly (640, 470) in canvas-space.
      const tx = box.x + 640 * scaleX;
      const ty = box.y + 470 * scaleY;
      await page.keyboard.press('Escape');
      await page.waitForTimeout(150);
      await page.mouse.move(tx, ty);
      await page.waitForTimeout(150);
      await page.mouse.click(tx, ty);
      await page.waitForTimeout(3500);  // give the scene transition + map gen time
    }
    const gameSnap = path.join(snapDir, 'web-game-attempt.png');
    await page.screenshot({ path: gameSnap, fullPage: false });
    console.log('[browser-smoke] menu screenshot:', menuSnap);
    console.log('[browser-smoke] post-click screenshot:', gameSnap);
    const postClickLines = consoleLines.slice(consoleSnap);
    console.log('[browser-smoke] new lines after click:', postClickLines.length);
    postClickLines.slice(0, 5).forEach(l => console.log('  ' + l));

    // Report.
    if (pageErrors.length > 0) {
      console.error('[browser-smoke] page errors:');
      pageErrors.forEach(e => console.error('  ' + e));
    }
    console.log('[browser-smoke] canvas size:', canvasSize);
    console.log('[browser-smoke] boot detected:', booted);
    console.log('[browser-smoke] console lines captured:', consoleLines.length);
    consoleLines.slice(-15).forEach(l => console.log('  ' + l));

    const ok = !!canvasSize && canvasSize.w > 0 && canvasSize.h > 0 && pageErrors.length === 0;
    console.log(ok ? '[browser-smoke] PASS' : '[browser-smoke] FAIL');
    process.exitCode = ok ? 0 : 1;
  } catch (err) {
    console.error('[browser-smoke] FAIL — ' + err.message);
    process.exitCode = 1;
  } finally {
    try { if (browser) await browser.close(); } catch (e) {}
    try { if (server) server.close(); } catch (e) {}
  }
})();
