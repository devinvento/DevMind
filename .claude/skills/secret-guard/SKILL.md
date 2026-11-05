---
name: secret-guard
description: Use BEFORE every `git push` (and before committing config, .env, credentials, DB dumps or AI memory files). Runs the DevMind Secret Guard scan, blocks the push if API keys, passwords, tokens, private keys, .env files, database dumps or AI chat history would leave the machine, and guides the fix. Also use when the user asks to "check for secrets", "scan for sensitive data" or "is it safe to push".
metadata:
  origin: DevMind
  version: 1
---

<!-- Managed by the DevMind VS Code extension: auto-updated when a newer version ships.
     To customise this skill and stop auto-updates, change `origin: DevMind` above to `origin: custom`. -->

# Secret Guard

Code goes to **git**. Secrets go to **nowhere**. AI memory and chat history go to **Google Drive** (DevMind memory sync), never to git.

The real enforcement is the git `pre-push` hook installed by `setup-ai-project.sh`. It runs `devmind scan --pre-push` and rejects the push when it finds anything. This skill makes sure you, the agent, check *before* you push and fix problems properly instead of fighting the hook.

## When to activate

- Right before running `git push` (any remote, any branch)
- Before committing files such as `config/*.php`, `database.php`, `docker-compose.yml`, `.env*`, `*.pem`, `*.sql`, or anything under `.devmind/memory/`
- When the user asks whether something is safe to push or to scan for secrets

## Hard rules

1. **Never** run `git push --no-verify`, never set `DEVMIND_SKIP_SECRET_SCAN=1`, and never delete, edit or `chmod -x` `.git/hooks/pre-push` to get a push through. Only the user may bypass, and only after they have looked at the findings themselves.
2. **Never** print a full secret value in chat, commit messages, ADRs, memory files or PR descriptions. Refer to it by file and line, masked (e.g. `shpat_db76***`).
3. Never add a real secret to `.secretscanignore` or mark it with `devmind:allow-secret`. The allowlist is only for **verified false positives**, such as fake keys in fixtures or placeholder values, and you must tell the user every time you add an entry.
4. Chat history (`.devmind/memory/sessions/`, `.devmind/memory/chat-history.md`, raw `*.jsonl` transcripts) must never be committed. It syncs to Google Drive.

## Workflow

### 1. Scan before pushing

```bash
devmind scan --range @{u}..HEAD           # commits not yet on the upstream branch
devmind scan --range HEAD --not --remotes # new branch with no upstream yet
devmind scan --staged                     # before committing: staged changes only
```

If `devmind` is not on PATH, use `python3 ./bin/devmind scan ...`.

Exit code `0` means clean, so push normally. Exit code `1` means findings, so **do not push**. Continue with step 2.

### 2. Triage each finding

| Finding | What to do |
|---|---|
| `sensitive-file` `.env` | `git rm --cached .env`, add it to `.gitignore`, commit a `.env.example` with empty values instead |
| `sensitive-file` key/cert/credentials JSON | `git rm --cached <file>`, add it to `.gitignore`, and load it from a path outside the repo or from an env var |
| `sensitive-file` DB dump (`*.sql` > 1 MB, `*.dump`, `*.bak`) | Remove it from the commit. Dumps from POS projects contain customer data, so they must never be pushed |
| `sensitive-file` AI chat history | Remove it from the commit. It belongs in Google Drive memory sync |
| `hardcoded-credential` / API key / token | Move the value to `.env` and read it with `getenv()` / `env()` / `os.environ`. For CodeIgniter use `getenv('DB_PASSWORD')` in `application/config/database.php` |
| `db-url-password` | Build the URL from env vars (`${DB_PASSWORD}` in docker-compose, env interpolation elsewhere) |
| False positive (fake fixture, placeholder) | Append ` // devmind:allow-secret` (use the language's comment syntax) on that line, or add a path glob / `regex:` line to `.secretscanignore`. Tell the user you did this |

### 3. Clean the unpushed commits

The secret is still in the local commits, so fixing the working tree is not enough.

- If the last commit is the only one affected, fix the files, `git add`, then `git commit --amend --no-edit`.
- If several unpushed commits are affected, `git reset --soft @{u}` (or `git reset --soft <last-pushed-sha>`), fix the files, then recommit.
- **Ask the user first** before any history rewrite that touches commits which are **already pushed** (`git filter-repo`, BFG). Rewriting shared history affects every collaborator.

### 4. Rotate if it ever left the machine

If the scan or the user shows that a real key was **already pushed** at some point (it is in `origin` history), tell the user plainly that the key must be **rotated** at the provider (Shopify, Stripe, Braintree, Infobip, AWS, DB user password…). Removing it from git does not undo the exposure, because clones, forks and caches keep it.

### 5. Re-scan, then push

Run the scan again. Push only when it exits `0`. If the pre-push hook still blocks the push, read its output. Do not retry with flags.

## Full-repo audit

Use `devmind scan --all` to check every tracked file, not just the new commits. Run it when onboarding a project or when the user asks for an audit. Report the findings grouped by file, with values masked, and recommend rotation for anything real that is already in history.

## What the scanner detects

- **Patterns:** private keys, AWS keys, GitHub tokens, Anthropic/OpenAI keys, Stripe live keys, Braintree production tokens, Slack tokens/webhooks, Google API keys and OAuth secrets, Shopify tokens, JWTs, DB URLs with passwords, and hard-coded `password`/`secret`/`api_key`/`token` assignments. Placeholders, `env()`/`getenv()` calls and Laravel validation rules are ignored.
- **Files:** `.env*` (except `.example/.sample/.template/.dist`), `*.pem/*.key/*.p12/*.pfx/*.jks/*.ppk`, SSH private keys, `credentials.json`, service-account JSON, `.htpasswd`, DB dumps, `.devmind/memory/sessions/`, `.devmind/memory/chat-history.md`, raw AI transcripts.
- **Not scanned by the generic password rule:** `vendor/`, `node_modules/`, `tests/`, `fixtures/`, and `lang/`/`language/`/`locale/`. High-confidence token patterns still apply in those paths.
