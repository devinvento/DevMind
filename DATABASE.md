# Database Architecture & Schema Context

Generated: সোমবার 10 আগস্ট 2026 12:34:16 অপরাহ্ণ +06
Target Project: /var/www/html/DevMind

## Database Overview
- **Detected Engine**: None explicitly configured
- **Project Stack**: Generic / Unspecified

## Key Database Guidelines for AI Agents
1. **Schema Modifications**:
   - Always write migrations or structured DDL scripts. Never execute direct destructive schema changes in production.
   - Ensure foreign key constraints, indexes, and unique constraints are defined.
2. **Query Performance**:
   - Avoid `SELECT *` queries in performance-critical API paths.
   - Ensure indexed columns are used in `WHERE` and `JOIN` clauses.
3. **Data Integrity**:
   - Wrap multi-table mutation operations in database transactions.
   - Use parameterized queries or ORM bindings to prevent SQL Injection.

## Schema Hints & Tables
- None detected
