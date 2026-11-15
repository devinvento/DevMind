# Testing guide (any stack)

The project profile at `docs/brd-to-production/PROJECT-PROFILE.md` holds the real commands for
this project. This guide holds the rules that apply to every stack.

## 1. Case ids and evidence

Every test carries its case id in its name, so that the gate can match the report to the evidence:

| Stack | Example |
|-------|---------|
| pytest (Python, FastAPI, Django) | `def test_TC_2_01_points_for_1250_sale():` |
| Frappe / Odoo (unittest) | `def test_TC_2_01_points_for_1250_sale(self):` |
| PHPUnit / Laravel / CodeIgniter 4 | `public function test_TC_2_01_points_for_1250_sale(): void` |
| CodeIgniter 3 shipped runner | method docblock `/** @case TC-2-01 @ac AC-002.1 */` |
| Jest / Vitest | `test('TC-2-01 points for 1250 sale', ...)` |
| Browser / API flows | `{ id: 'UI-2-01', ... }` or `{ id: 'API-2-01', kind: 'api', ... }` |

`TC_2_01` and `TC-2-01` are the same id to the gate. `TC-2-010` is a different id.

**Evidence the gate accepts, in order of preference:**
1. **JUnit XML**: `evidence/unit-run-3.xml`. The gate finds the `<testcase>` whose name contains the
   id, and checks its result against the report: pass, failure/error, or skipped. A skipped test
   never counts as PASS.
2. **Runner JSON**: `evidence/ui-run-2/UI-2-01.json`, written by the browser runner. Its `id` and
   `status` must match the report.
3. **A console line**: `evidence/unit-run-3.txt:41`. That line must contain the id and a pass or
   fail word. These styles work:
   - `PASS` or `PASSED`;
   - `FAIL`, `FAILED` or `ERROR`;
   - `ok` or `not ok` (TAP);
   - `✓` or `✕`.

Never overwrite an evidence file. Each run gets a new number, and the report points to the newest one.

## 2. Unit and scenario tests

- **Location:** the profile's `test_dir`, normally `tests/brd/<slug>/`. Some frameworks need
  tests inside an app or addon, and then the profile names that path.
- **Real code:** test through the real code (models, services, controllers, endpoints). Never
  copy logic into the test.
- **What to cover:** cover each AC with these cases:
  - positive;
  - negative: invalid input or a missing field;
  - edge: 0, empty, max, rounding, timezone, duplicate;
  - permission: the allowed role and the forbidden role;
  - data integrity: query the database after the action.
- **Isolation:** follow the profile's `test_data_rule`, which is usually one rolled-back
  transaction per test or a separate test database. Name test data with a `BRDTEST-` prefix or a
  random suffix, because the UI tester runs at the same time.
- **Migrations:** run `migrate_up`, check the schema, run `migrate_down`, check it again, then run
  `migrate_up` once more. Save the output of every step. Stacks without down-migrations, such as
  Frappe and Odoo, use a backup and restore instead, as their profile says.
- **Regression:** run the profile's `unit_all` every round. That covers every earlier phase and the smoke suite.

## 3. Browser and API flows

Flows live in `tests/brd/ui/flows/<slug>-phase<N>.mjs` and run with the shipped runner. It uses
the installed Chrome, Chromium or Edge, so no browser download is needed:

```bash
node tests/brd/ui/brd-ui.mjs tests/brd/ui/flows --out WS/phases/phase-N/evidence/ui-run-K > WS/phases/phase-N/evidence/ui-run-K.txt
node tests/brd/ui/brd-ui.mjs tests/brd/ui/flows/<slug>-phase2.mjs --filter UI-2-03 --out ...   # one flow
node tests/brd/ui/brd-ui.mjs tests/brd/ui/flows --kind api --out ...                          # API flows only
```

```js
export default [
  {
    id: 'UI-2-01', ac: 'AC-002.1', role: 'cashier', title: 'sale with customer shows 12 points',
    async run({ page, login, url, shot, expect }) {
      await login('cashier');                      // uses the profile's login settings
      await page.goto(url('/sales/new'));
      // ... real clicks and typing, like a user ...
      await shot('receipt');
      expect((await page.locator('.points').innerText()).includes('12'), 'receipt shows 12 points');
    },
  },
  {
    id: 'API-2-02', ac: 'AC-005.1', kind: 'api', role: 'cashier', title: 'cashier cannot change the earn rate',
    async run({ api, url, token, expect }) {
      const r = await api.put(url('/api/loyalty/rate'), { data: { rate: 5 }, headers: { Authorization: `Bearer ${token('cashier')}` } });
      expect(r.status() === 403, `expected 403, got ${r.status()}`);
    },
  },
];
```

**When a flow fails.** A UI flow fails on any of these:
- a thrown error or a failed `expect`;
- an uncaught page error or a `console.error`;
- a failed request;
- an HTTP status of 400 or higher on the page's requests.

A missing `/favicon.ico` is ignored by default. Set `BRD_STRICT_FAVICON=1` to report it.

Other known noise can go in `ignoreConsole: [/regex/]`, each entry with a comment saying why. If a
404 or 403 is the expected result, list its URL part in `expectHttpErrors: ['/admin/settings']`.

**Credentials and settings** go in `.env.brd-test`, which must be untracked:

```
BRD_USER_ADMIN=...            BRD_PASS_ADMIN=...           # UI login per role
BRD_USER_CASHIER=...          BRD_PASS_CASHIER=...
BRD_TOKEN_CASHIER=...                                       # API token per role (for kind: 'api')
BRD_BASE_URL=...              # only to override the profile's app_url
BRD_ALLOW_REMOTE=1            # only for a STAGING host that is not local or private
CHROME_PATH=...               # only if Chrome, Chromium or Edge is not found
```

The runner also reads these from the profile's `ui` block, and the env file overrides them:
- the login page: `login_path`;
- the field selectors: `user_selector`, `pass_selector` and `submit_selector`;
- the failed-login URL pattern: `failed_url_re`.

A role without credentials makes its flow **BLOCKED**, never PASS.

**Permission flows.** For each restricted action, test three things:
- the allowed role can do it;
- the forbidden role does not see the control;
- the forbidden role's direct URL or API call is refused.

After a flow whose AC is about data, check the database.

**Layout.** Check each key screen at the default width (1366), and again with `width: 390` if the
screen is used on phones.

## 4. Stack notes

| Stack | Unit runner | Isolation | Browser login (profile `ui`) |
|-------|-------------|-----------|------------------------------|
| Python | pytest `--junitxml` | fixtures, `tmp_path` | none (or the app's own) |
| FastAPI | pytest + TestClient | override the DB dependency | API flows with tokens |
| Django | pytest-django `--junitxml` | `django_db` (test DB, rolled back) | `/admin/login/`, `username` |
| Frappe / ERPNext | `bench run-tests --junit-xml-output` | test site, IntegrationTestCase | `/login`, `#login_email` |
| Odoo | `odoo-bin --test-enable` (or pytest-odoo for JUnit) | TransactionCase | `/web/login`, `login` |
| Laravel | `php artisan test --log-junit` | RefreshDatabase or DatabaseTransactions | `/login`, `email` |
| CodeIgniter 4 | `vendor/bin/phpunit --log-junit` | DatabaseTestTrait, `tests` group | `/login` |
| CodeIgniter 3 | shipped `brd_test_runner` (text) | transaction per test (InnoDB) | `/index.php/login`, `username` |
| Node | Jest or Vitest with a JUnit reporter | test DATABASE_URL | `/login` |
