// brd-to-production phase 0 smoke flows. Set BRD_BASE_URL and BRD_LOGIN_PATH in .env.brd-test.
// UI-0-01 needs no login. UI-0-02 needs BRD_USER_ADMIN / BRD_PASS_ADMIN (BLOCKED until present).
// API-0-01 checks BRD_SMOKE_API_PATH (default "/"): any status below 500 passes.
export default [
  {
    id: 'UI-0-01', ac: 'AC-P0.2', role: 'anonymous', title: 'login page renders without JS or HTTP errors',
    async run({ page, url, env, shot, expect }) {
      await page.goto(url(env.BRD_LOGIN_PATH || '/login'));
      expect(await page.locator('input[type="password"]').count() >= 1, 'a password field is present');
      await shot('login');
    },
  },
  {
    id: 'UI-0-02', ac: 'AC-P0.3', role: 'admin', title: 'admin can log in',
    async run({ login, shot }) {
      await login('admin');
      await shot('after-login');
    },
  },
  {
    id: 'API-0-01', ac: 'AC-P0.2', kind: 'api', role: 'anonymous', title: 'server answers HTTP',
    async run({ api, url, env, expect }) {
      const r = await api.get(url(env.BRD_SMOKE_API_PATH || '/'));
      expect(r.status() < 500, `status ${r.status()} < 500`);
    },
  },
];
