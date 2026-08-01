# Security Guidelines & Guardrails

Generated: Sat Aug  1 09:55:11 PM +06 2026

## Critical Security Rules for AI Agents

> [!CAUTION]
> **NEVER** expose sensitive credentials, `.env` files, API keys, private keys, or database passwords.

### 1. Secret Protection
- Never commit secrets or hardcode sensitive tokens in code.
- Check `.gitignore` to ensure secret files are excluded.

### 2. Injection Prevention
- Always sanitize user input. Use prepared statements or ORM parameters for SQL queries.
- Escape HTML/JSX outputs to prevent XSS (Cross-Site Scripting).

### 3. Authentication & Authorization
- Validate permissions explicitly on all protected endpoints.
- Do not bypass authentication checks in production routes.
