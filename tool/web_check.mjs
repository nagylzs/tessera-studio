// A minimal Chrome DevTools Protocol client for checking the web build in a
// Chrome under Xvfb (CLAUDE.md, "The web build"). Node 22+ (global WebSocket).
// CDP_PORT selects the Chrome; never one this session did not start.
// node tool/web_check.mjs shot <file.png>
// node tool/web_check.mjs click <x> <y>
// node tool/web_check.mjs type <text>
// node tool/web_check.mjs key <Escape|Enter|Tab>
// node tool/web_check.mjs open <x> <y> <file>   click, and answer the file chooser
// node tool/web_check.mjs winsize <width> <height>   the window, so it stays
// node tool/web_check.mjs eval <expression>
import { writeFileSync } from 'node:fs';

const port = process.env.CDP_PORT ?? '9471';
const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const page = targets.find((t) => t.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));

let id = 0;
const pending = new Map();
const listeners = [];
ws.addEventListener('message', (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
  } else if (msg.method) {
    for (const l of listeners) l(msg);
  }
});
const send = (method, params = {}) =>
  new Promise((resolve, reject) => {
    pending.set(++id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function click(x, y) {
  for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', {
      type, x, y, button: type === 'mouseMoved' ? 'none' : 'left', clickCount: 1,
    });
    await sleep(40);
  }
}

const [cmd, ...args] = process.argv.slice(2);
try {
  if (cmd === 'shot') {
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(args[0], Buffer.from(data, 'base64'));
  } else if (cmd === 'click') {
    await click(+args[0], +args[1]);
  } else if (cmd === 'type') {
    await send('Input.insertText', { text: args.join(' ') });
  } else if (cmd === 'key') {
    const key = args[0];
    const codes = { Escape: 27, Enter: 13, Tab: 9 };
    for (const type of ['keyDown', 'keyUp']) {
      await send('Input.dispatchKeyEvent', {
        type, key, code: key, windowsVirtualKeyCode: codes[key] ?? 0,
      });
    }
  } else if (cmd === 'open') {
    await send('Page.enable');
    await send('DOM.enable');
    await send('Page.setInterceptFileChooserDialog', { enabled: true });
    const opened = new Promise((resolve) =>
      listeners.push((m) => m.method === 'Page.fileChooserOpened' && resolve(m.params)),
    );
    await click(+args[0], +args[1]);
    const chooser = await Promise.race([opened, sleep(8000).then(() => null)]);
    if (!chooser) throw new Error('no file chooser opened');
    await send('DOM.setFileInputFiles', {
      files: [args[2]], backendNodeId: chooser.backendNodeId,
    });
    await send('Page.setInterceptFileChooserDialog', { enabled: false });
  } else if (cmd === 'winsize') {
    const { windowId } = await send('Browser.getWindowForTarget');
    await send('Browser.setWindowBounds', {
      windowId, bounds: { width: +args[0], height: +args[1] },
    });
  } else if (cmd === 'eval') {
    const r = await send('Runtime.evaluate', { expression: args.join(' '), returnByValue: true });
    console.log(JSON.stringify(r.result.value));
  } else {
    throw new Error(`unknown command ${cmd}`);
  }
} finally {
  ws.close();
}
