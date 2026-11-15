#!/usr/bin/env node
// brd-to-production browser runner. Uses playwright-core with the system Chrome.
//
//   node brd-ui.mjs <flow file or dir> [--out <evidence dir>] [--filter <text>] [--kind ui|api] [--headed]
//
// A flow file exports default { id, ac, role, title, kind?: 'ui'|'api', ignoreConsole?: [regex], run(ctx) }
// or an array of them. ctx = { page, api, env, login(role), token(role), shot(name), expect(cond, msg), url(path) }.
// kind 'api' flows use ctx.api (Playwright APIRequestContext: api.get/post/put/delete) and never open a page.
// Works for any web stack: login path, field selectors and the "still on login page" pattern come
// from the env file (BRD_LOGIN_PATH, BRD_LOGIN_USER_SELECTOR, BRD_LOGIN_PASS_SELECTOR, BRD_LOGIN_SUBMIT_SELECTOR,
// BRD_LOGIN_FAILED_URL_RE). Chrome is found automatically on Linux, macOS and Windows, or set CHROME_PATH.
// Every flow gets a fresh browser context. A flow FAILS on a thrown error, a failed expect,
// an uncaught page error, a console error, a failed request, or an HTTP status >= 400,
// unless it matches the flow's ignoreConsole list. Credentials come from the env file
// (BRD_ENV_FILE, default .env.brd-test): BRD_BASE_URL, BRD_USER_<ROLE>, BRD_PASS_<ROLE>.
import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const args = process.argv.slice(2);
const opt = (name, def) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : def; };
const target = args.find((a, i) => !a.startsWith('--') && !(i > 0 && args[i - 1].startsWith('--') && args[i - 1] !== '--headed'));
if (!target) { console.error('usage: node brd-ui.mjs <flow file|dir> [--out dir] [--filter text] [--headed]'); process.exit(2); }
const outDir = opt('--out', 'ui-evidence');
const filter = opt('--filter', '');
const kind = opt('--kind', '');
fs.mkdirSync(outDir, { recursive: true });

// env file: KEY=VALUE lines, never printed
const envFile = process.env.BRD_ENV_FILE || '.env.brd-test';
const env = { ...process.env };
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m) env[m[1]] = m[2].replace(/^['"]|['"]$/g, '');
  }
}
// Defaults from the project profile (docs/brd-to-production/PROJECT-PROFILE.md, JSON block), env file wins.
const profilePath = env.BRD_PROFILE || 'docs/brd-to-production/PROJECT-PROFILE.md';
if (fs.existsSync(profilePath)) {
  const m = fs.readFileSync(profilePath, 'utf8').match(/```json\s*\n([\s\S]*?)\n```/);
  if (m) {
    try {
      const p = JSON.parse(m[1]); const ui = p.ui || {};
      const set = (k, v) => { if (v && typeof v === 'string' && !v.startsWith('TODO') && v !== 'none' && env[k] === undefined) env[k] = v; };
      set('BRD_BASE_URL', p.app_url); set('BRD_LOGIN_PATH', ui.login_path); set('BRD_LOGIN_USER_SELECTOR', ui.user_selector);
      set('BRD_LOGIN_PASS_SELECTOR', ui.pass_selector); set('BRD_LOGIN_SUBMIT_SELECTOR', ui.submit_selector); set('BRD_LOGIN_FAILED_URL_RE', ui.failed_url_re);
    } catch (e) { console.error(`WARNING: ${profilePath} JSON block is invalid: ${e.message}`); }
  }
}
const base = (env.BRD_BASE_URL || 'http://localhost:8000').replace(/\/$/, '');
// Safety: only local or private hosts unless explicitly allowed (for a staging server, never production).
const host = new URL(base).hostname;
const local = /^(localhost|127\.|0\.0\.0\.0|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|\[?::1\]?$)/.test(host) || /\.(local|test|localhost|internal|lan)$/.test(host);
if (!local && env.BRD_ALLOW_REMOTE !== '1') {
  console.error(`REFUSED: ${host} is not a local/private host. For a STAGING server set BRD_ALLOW_REMOTE=1 in the env file. Never test production.`);
  process.exit(2);
}
if (/(^|\.)(prod|production|live)(\.|-|$)/i.test(host)) {
  console.error(`REFUSED: ${host} looks like production.`);
  process.exit(2);
}
function findChrome() {
  if (env.CHROME_PATH) return env.CHROME_PATH;
  const c = process.platform === 'darwin'
    ? ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium', '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge']
    : process.platform === 'win32'
      ? [`${process.env['PROGRAMFILES']}\\Google\\Chrome\\Application\\chrome.exe`, `${process.env['PROGRAMFILES(X86)']}\\Google\\Chrome\\Application\\chrome.exe`, `${process.env.LOCALAPPDATA}\\Google\\Chrome\\Application\\chrome.exe`, `${process.env['PROGRAMFILES(X86)']}\\Microsoft\\Edge\\Application\\msedge.exe`]
      : ['/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser', '/snap/bin/chromium', '/usr/bin/microsoft-edge'];
  const f = c.find(p => p && fs.existsSync(p));
  if (!f) { console.error('No Chrome/Chromium/Edge found. Install one or set CHROME_PATH in the env file.'); process.exit(2); }
  return f;
}

const files = fs.statSync(target).isDirectory()
  ? fs.readdirSync(target).filter(f => /\.(m?js)$/.test(f)).sort().map(f => path.join(target, f))
  : [target];
const flows = [];
for (const f of files) {
  const mod = await import(pathToFileURL(path.resolve(f)).href);
  for (const fl of [].concat(mod.default || [])) flows.push({ ...fl, file: f });
}

const browser = await chromium.launch({
  executablePath: findChrome(),
  headless: !args.includes('--headed'),
  args: ['--no-sandbox'],
});
const totals = { PASS: 0, FAIL: 0, BLOCKED: 0 };
console.log(`# brd-ui base=${base} flows=${flows.length} at ${new Date().toISOString()}`);

class Blocked extends Error {}
for (const fl of flows) {
  const label = `${fl.id} [${fl.ac || ''}] ${fl.role || '-'} ${fl.title || ''}`.replace(/\s+/g, ' ').trim();
  if (filter && !label.toLowerCase().includes(filter.toLowerCase())) continue;
  if (kind && (fl.kind || 'ui') !== kind) continue;
  const width = Number(fl.width || 1366);
  const context = await browser.newContext({ viewport: { width, height: Number(fl.height || 900) }, ignoreHTTPSErrors: true });
  const api = context.request;
  const page = fl.kind === 'api' ? null : await context.newPage();
  const problems = [];
  // A missing favicon is browser noise on many stacks, not an app error (set BRD_STRICT_FAVICON=1 to report it).
  const defaults = env.BRD_STRICT_FAVICON === '1' ? [] : [/\/favicon\.ico(\?|$|\s)/];
  const ignore = [...defaults, ...(fl.ignoreConsole || []).map(r => (r instanceof RegExp ? r : new RegExp(r)))];
  const ignored = t => ignore.some(r => r.test(t));
  if (page) {
    page.on('console', m => {
      if (m.type() !== 'error') return;
      const where = m.location() && m.location().url ? ` @ ${m.location().url}` : '';
      const t = `console.error: ${m.text()}${where}`;
      if (!ignored(t)) problems.push(t);
    });
    page.on('pageerror', e => { if (!ignored(String(e))) problems.push(`pageerror: ${e.message}`); });
    page.on('requestfailed', r => { const t = `requestfailed: ${r.method()} ${r.url()} ${r.failure()?.errorText}`; if (!ignored(t)) problems.push(t); });
    page.on('response', r => { if (r.status() >= 400 && !(fl.expectHttpErrors || []).some(x => r.url().includes(x))) { const t = `http ${r.status()}: ${r.request().method()} ${r.url()}`; if (!ignored(t)) problems.push(t); } });
  }
  let n = 0;
  const shots = [];
  const creds = role => {
    const key = String(role).toUpperCase().replace(/[^A-Z0-9]/g, '_');
    return { key, u: env[`BRD_USER_${key}`], p: env[`BRD_PASS_${key}`], t: env[`BRD_TOKEN_${key}`] };
  };
  const ctx = {
    page, api, env,
    url: p => /^https?:/.test(p) ? p : base + (p.startsWith('/') ? p : '/' + p),
    shot: async name => {
      if (!page) return null;
      const f = path.join(outDir, `${fl.id}-${String(++n).padStart(2, '0')}-${name}.png`);
      await page.screenshot({ path: f, fullPage: true }); shots.push(f); return f;
    },
    expect: (cond, msg) => { if (!cond) throw new Error(`expect failed: ${msg}`); },
    token: role => {
      const c = creds(role);
      if (!c.t) throw new Blocked(`no API token for role ${role} (BRD_TOKEN_${c.key} in ${envFile})`);
      return c.t;
    },
    login: async role => {
      const c = creds(role);
      if (!c.u || !c.p) throw new Blocked(`no credentials for role ${role} (BRD_USER_${c.key} / BRD_PASS_${c.key} in ${envFile})`);
      if (!page) throw new Error('login() needs a UI flow; API flows use token(role) or api.post to the login endpoint');
      const userSel = env.BRD_LOGIN_USER_SELECTOR || 'input[name="username"], input[name="email"], input[name="login"], input[type="email"], #login_email';
      const passSel = env.BRD_LOGIN_PASS_SELECTOR || 'input[name="password"], input[type="password"], #login_password';
      await page.goto(ctx.url(env.BRD_LOGIN_PATH || '/login'));
      await page.locator(userSel).first().fill(c.u);
      await page.locator(passSel).first().fill(c.p);
      const submit = env.BRD_LOGIN_SUBMIT_SELECTOR;
      await Promise.all([
        page.waitForLoadState('networkidle').catch(() => {}),
        submit ? page.locator(submit).first().click() : page.locator(passSel).first().press('Enter'),
      ]);
      await page.waitForLoadState('networkidle').catch(() => {});
      await page.waitForTimeout(Number(env.BRD_LOGIN_SETTLE_MS || 500));
      const failed = new RegExp(env.BRD_LOGIN_FAILED_URL_RE || '/(login|signin|sign-in)(/|\\?|#|$)', 'i');
      if (failed.test(new URL(page.url()).pathname + new URL(page.url()).search)) throw new Error(`login as ${role} failed, still on ${page.url()}`);
    },
  };
  let status = 'PASS', detail = '';
  const t0 = Date.now();
  try {
    await fl.run(ctx);
    if (problems.length) { status = 'FAIL'; detail = problems.join(' | '); }
  } catch (e) {
    status = e instanceof Blocked ? 'BLOCKED' : 'FAIL';
    detail = [e.message, ...problems].join(' | ');
  }
  if (status === 'FAIL') await ctx.shot('failure').catch(() => {});
  totals[status]++;
  const log = { id: fl.id, ac: fl.ac, role: fl.role, title: fl.title, kind: fl.kind || 'ui', status, detail, problems, screenshots: shots, url: page ? page.url() : null, ms: Date.now() - t0, at: new Date().toISOString() };
  fs.writeFileSync(path.join(outDir, `${fl.id}.json`), JSON.stringify(log, null, 2));
  console.log(`${status} ${label}${detail ? ' -- ' + detail.slice(0, 600) : ''}${shots.length ? ' shots=' + shots.map(s => path.basename(s)).join(',') : ''}`);
  await context.close();
}
await browser.close();
console.log(`# totals PASS=${totals.PASS} FAIL=${totals.FAIL} BLOCKED=${totals.BLOCKED}`);
process.exit(totals.FAIL ? 1 : 0);
