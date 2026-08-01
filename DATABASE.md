# Database Architecture & Schema Context

Generated: Sun Aug  2 12:01:55 AM +06 2026
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
- /var/www/html/DevMind/.agents/skills/database-migrations
