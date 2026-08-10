# Database Architecture & Schema Context

Generated: 2026-08-10 16:06:47
Target Project: /var/www/html/DevMind

## Database Overview
- **Primary Database**: None explicitly configured
- **Secondary Database(s)**: None detected
- **Cache / Queue Store**: None detected
- **Project Stack**: Generic / Unspecified
- **Package Manager**: None

## Database Architecture Intelligence
### Primary DB Details
- **Engine**: None explicitly configured
- **Version**: Unknown
- **Migration Count**: 0 files detected

### Database Schema
#### ├── Tables
- None detected

#### ├── Columns
- None detected

#### ├── Foreign Keys
- None detected

#### ├── Indexes
- None detected

#### ├── Relationships
- None detected

#### └── Potential Issues
- None detected. Schema appears structurally sound.

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
