#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# DevMind Enterprise AI Project Operating System & CLI Suite
# Version: 3.0.0
#
# Features:
#   - DevMind CLI installation (devmind doctor, sync, plan, impact, blame, audit, db, review, adr, infra)
#   - System dependency verification (git, curl, python3, node, uv, graphify)
#   - Everything Claude Code (ECC) integration (system-wide single checkout)
#   - Intelligent Stack Detection (Laravel, CodeIgniter, Frappe, Django, FastApi, Node, React, etc.)
#   - Automated Database & Architecture Intelligence (DATABASE.md, ARCHITECTURE.md, SECURITY.md)
#   - Project Memory System (.devmind/memory/) & ADR Manager (docs/adr/)
#   - Specialized AI Agent Personas (.agents/agents/)
#   - Standard Operating Workflows (.agents/workflows/)
#   - Project-Specific Domain Rules (.agents/rules/)
#   - Powerful AI Operating Manual (.agents/AGENTS.md)
#   - Graphify Code Graph & Antigravity MCP Server Integration
#   - Multi-Dimensional Engineering Score & Diagnostic Suite (0-100%)
#
# Usage:
#   ./setup-ai-project.sh [--update|-u] [/path/to/project]
#
###############################################################################

SCRIPT_VERSION="3.0.0"
SCRIPT_SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

UPDATE_ECC="false"
PROJECT_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --update|-u)
            UPDATE_ECC="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--update|-u] [/path/to/project]"
            echo
            echo "Options:"
            echo "  --update, -u    Force git fetch/pull for Everything Claude Code repository"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            if [[ -z "$PROJECT_ARG" ]]; then
                PROJECT_ARG="$1"
            else
                echo -e "\033[0;31m[ERROR]\033[0m Unknown argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

PROJECT_DIR="${PROJECT_ARG:-$(pwd)}"

ECC_REPO_URL="${ECC_REPO_URL:-https://github.com/affaan-m/everything-claude-code.git}"
ECC_DIR="${ECC_DIR:-$HOME/.local/share/everything-claude-code}"

ANTIGRAVITY_MCP_CONFIG="${HOME}/.gemini/antigravity/mcp_config.json"

AGENTS_DIR="${PROJECT_DIR}/.agents"
SKILLS_DIR="${AGENTS_DIR}/skills"
RULES_DIR="${AGENTS_DIR}/rules"
WORKFLOWS_DIR="${AGENTS_DIR}/workflows"
AGENTS_AGENTS_DIR="${AGENTS_DIR}/agents"
DEVMIND_MEMORY_DIR="${PROJECT_DIR}/.devmind/memory"
ADR_DIR="${PROJECT_DIR}/docs/adr"

GRAPHIFY_OUTPUT_DIR="${PROJECT_DIR}/graphify-out"

# State Variables
PROJECT_TYPE="Generic / Unspecified"
TECH_STACK=""
TEST_FRAMEWORK="None detected"
DB_ENGINE="None detected"

###############################################################################
# Colors
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

trap 'error "Setup failed at line $LINENO. Command: $BASH_COMMAND"' ERR

###############################################################################
# 1. Project Validation & Environment Setup
###############################################################################

validate_project() {
    if [[ ! -d "$PROJECT_DIR" ]]; then
        die "Project directory does not exist: $PROJECT_DIR"
    fi

    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
    log "Target Project Path: ${CYAN}$PROJECT_DIR${NC}"

    if [[ ! -d "$PROJECT_DIR/.git" ]]; then
        warn "This directory is not a Git repository."
    fi
}

###############################################################################
# 2. System Dependency Manager
###############################################################################

check_command() {
    command -v "$1" >/dev/null 2>&1
}

install_system_package() {
    local pkgs=("$@")

    if check_command apt-get; then
        if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
            apt-get update -qq && apt-get install -y "${pkgs[@]}"
        elif check_command sudo; then
            sudo apt-get update -qq && sudo apt-get install -y "${pkgs[@]}"
        else
            die "Root/sudo access required to install ${pkgs[*]} via apt-get"
        fi
    elif check_command dnf; then
        if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
            dnf install -y "${pkgs[@]}"
        elif check_command sudo; then
            sudo dnf install -y "${pkgs[@]}"
        fi
    elif check_command pacman; then
        if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
            pacman -Sy --noconfirm "${pkgs[@]}"
        elif check_command sudo; then
            sudo pacman -Sy --noconfirm "${pkgs[@]}"
        fi
    elif check_command brew; then
        brew install "${pkgs[@]}"
    else
        die "No supported package manager found to install: ${pkgs[*]}"
    fi
}

install_curl() {
    if check_command curl; then
        success "curl is installed: $(curl --version | head -n1)"
        return
    fi
    log "Installing curl..."
    install_system_package curl
}

install_git() {
    if check_command git; then
        success "git is installed: $(git --version)"
        return
    fi
    log "Installing git..."
    install_system_package git
}

install_python() {
    if check_command python3; then
        success "python3 is installed: $(python3 --version)"
        return
    fi
    log "Installing python3..."
    install_system_package python3
}

install_node() {
    if check_command node && check_command npm; then
        success "Node.js is installed: $(node --version) (npm $(npm --version))"
        return
    fi

    log "Node.js not found. Installing..."
    if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
        export NVM_DIR="$HOME/.nvm"
        # shellcheck disable=SC1090,SC1091
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install --lts || true
    else
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash || true
        export NVM_DIR="$HOME/.nvm"
        if [[ -s "$NVM_DIR/nvm.sh" ]]; then
            # shellcheck disable=SC1090,SC1091
            \. "$NVM_DIR/nvm.sh"
            nvm install --lts
        fi
    fi

    if check_command node; then
        success "Node.js installed: $(node --version)"
        return
    fi

    install_system_package nodejs npm || die "Node.js installation failed."
}

install_uv() {
    if check_command uv; then
        success "uv is installed: $(uv --version)"
        return
    fi
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    check_command uv || die "uv installation failed"
    success "uv installed successfully"
}

install_graphify() {
    if check_command graphify; then
        success "Graphify is installed: $(graphify --version 2>/dev/null || echo 'available')"
        return
    fi
    log "Installing Graphify CLI with full backends..."
    uv tool install "graphifyy[gemini]" --force
    uv tool update-shell >/dev/null 2>&1 || true
    export PATH="$HOME/.local/bin:$PATH"
    check_command graphify || die "Graphify installation failed"
    success "Graphify installed successfully"
}

install_devmind_cli() {
    log "Installing DevMind CLI tool..."

    if [[ "$PROJECT_DIR" != "$SCRIPT_SOURCE_DIR" ]]; then
        log "Copying DevMind CLI and helper assets to target project..."
        mkdir -p "$PROJECT_DIR/bin"
        if [[ -f "$SCRIPT_SOURCE_DIR/bin/devmind" ]]; then
            cp "$SCRIPT_SOURCE_DIR/bin/devmind" "$PROJECT_DIR/bin/devmind"
        fi
        if [[ -f "$SCRIPT_SOURCE_DIR/generate_graph_html.py" ]]; then
            cp "$SCRIPT_SOURCE_DIR/generate_graph_html.py" "$PROJECT_DIR/generate_graph_html.py"
        fi
        if [[ -f "$SCRIPT_SOURCE_DIR/setup-ai-project.sh" ]]; then
            cp "$SCRIPT_SOURCE_DIR/setup-ai-project.sh" "$PROJECT_DIR/setup-ai-project.sh"
            chmod +x "$PROJECT_DIR/setup-ai-project.sh"
        fi
    fi

    local bin_path="$PROJECT_DIR/bin/devmind"
    if [[ -f "$bin_path" ]]; then
        chmod +x "$bin_path"
        mkdir -p "$HOME/.local/bin"
        ln -sf "$bin_path" "$HOME/.local/bin/devmind"
        success "DevMind CLI installed to $HOME/.local/bin/devmind"
    else
        warn "devmind script not found at bin/devmind"
    fi
}

install_ecc_repository() {
    if [[ -d "$ECC_DIR/.git" ]]; then
        if [[ "$UPDATE_ECC" == "true" ]]; then
            log "Updating ECC repository ($ECC_DIR)..."
            git -C "$ECC_DIR" fetch --quiet
            git -C "$ECC_DIR" pull --ff-only --quiet || warn "Could not fast-forward ECC repository."
            success "ECC repository updated"
        else
            success "ECC repository ready: $ECC_DIR"
        fi
    else
        log "Cloning Everything Claude Code repository..."
        mkdir -p "$(dirname "$ECC_DIR")"
        git clone "$ECC_REPO_URL" "$ECC_DIR"
        success "ECC repository cloned"
    fi

    [[ -d "$ECC_DIR/skills" ]] || die "ECC skills directory not found at $ECC_DIR/skills"
    [[ -d "$ECC_DIR/rules" ]] || die "ECC rules directory not found at $ECC_DIR/rules"

    # Auto-integrate Frappe skills repository
    local frappe_skills_url="https://github.com/frappe/skills.git"
    local frappe_skills_temp_dir="$HOME/.local/share/frappe-skills"
    if [[ -d "$frappe_skills_temp_dir/.git" ]]; then
        if [[ "$UPDATE_ECC" == "true" ]]; then
            log "Updating Frappe skills repository..."
            git -C "$frappe_skills_temp_dir" fetch --quiet
            git -C "$frappe_skills_temp_dir" pull --ff-only --quiet || warn "Could not fast-forward Frappe skills repository."
        fi
    else
        log "Cloning Frappe skills repository..."
        mkdir -p "$(dirname "$frappe_skills_temp_dir")"
        git clone "$frappe_skills_url" "$frappe_skills_temp_dir" --quiet
    fi

    if [[ -d "$frappe_skills_temp_dir/skills" ]]; then
        cp -r "$frappe_skills_temp_dir/skills"/* "$ECC_DIR/skills/"
    fi
}

###############################################################################
# 3. Intelligent Stack & Ecosystem Detection
###############################################################################

detect_project_stack() {
    log "Detecting project stack & technology ecosystem..."

    local stacks=()

    # PHP ecosystems
    if [[ -f "$PROJECT_DIR/artisan" ]]; then
        PROJECT_TYPE="PHP / Laravel"
        stacks+=("PHP" "Laravel")
    elif [[ -f "$PROJECT_DIR/spark" ]] || [[ -f "$PROJECT_DIR/application/config/config.php" ]] || [[ -f "$PROJECT_DIR/system/core/CodeIgniter.php" ]] || grep -qi "codeigniter" "$PROJECT_DIR/composer.json" 2>/dev/null; then
        PROJECT_TYPE="PHP / CodeIgniter"
        stacks+=("PHP" "CodeIgniter")
    elif [[ -f "$PROJECT_DIR/composer.json" ]]; then
        PROJECT_TYPE="PHP Application"
        stacks+=("PHP" "Composer")
    fi

    # Python & Frappe ecosystems
    if [[ -f "$PROJECT_DIR/apps.txt" ]] || [[ -d "$PROJECT_DIR/sites" ]]; then
        PROJECT_TYPE="Python / Frappe Framework"
        stacks+=("Python" "Frappe" "ERPNext")
    elif [[ -f "$PROJECT_DIR/manage.py" ]]; then
        PROJECT_TYPE="Python / Django"
        stacks+=("Python" "Django")
    elif grep -qi "fastapi" "$PROJECT_DIR/requirements.txt" 2>/dev/null || grep -qi "fastapi" "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
        PROJECT_TYPE="Python / FastAPI"
        stacks+=("Python" "FastAPI")
    elif [[ -f "$PROJECT_DIR/requirements.txt" ]] || [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
        PROJECT_TYPE="Python Application"
        stacks+=("Python")
    fi

    # Node & Frontend ecosystems
    if [[ -f "$PROJECT_DIR/next.config.js" ]] || [[ -f "$PROJECT_DIR/next.config.mjs" ]] || [[ -f "$PROJECT_DIR/next.config.ts" ]]; then
        PROJECT_TYPE="${PROJECT_TYPE:+$PROJECT_TYPE + }Node / Next.js"
        stacks+=("Node.js" "Next.js" "React")
    elif [[ -f "$PROJECT_DIR/vite.config.js" ]] || [[ -f "$PROJECT_DIR/vite.config.ts" ]]; then
        PROJECT_TYPE="${PROJECT_TYPE:+$PROJECT_TYPE + }Node / Vite"
        stacks+=("Node.js" "Vite")
    elif [[ -f "$PROJECT_DIR/package.json" ]]; then
        if grep -qi "react" "$PROJECT_DIR/package.json" 2>/dev/null; then
            stacks+=("Node.js" "React")
        elif grep -qi "vue" "$PROJECT_DIR/package.json" 2>/dev/null; then
            stacks+=("Node.js" "Vue")
        else
            stacks+=("Node.js")
        fi
        [[ "$PROJECT_TYPE" == "Generic / Unspecified" ]] && PROJECT_TYPE="Node.js Application"
    fi

    TECH_STACK="${stacks[*]:-General Software Project}"

    success "Detected Stack: ${CYAN}$PROJECT_TYPE${NC}"
}

detect_testing_framework() {
    log "Detecting test suites..."

    local tests=()

    if [[ -f "$PROJECT_DIR/phpunit.xml" ]] || [[ -f "$PROJECT_DIR/phpunit.xml.dist" ]]; then
        tests+=("PHPUnit")
    fi

    if [[ -f "$PROJECT_DIR/pytest.ini" ]] || [[ -d "$PROJECT_DIR/tests" && -f "$PROJECT_DIR/conftest.py" ]]; then
        tests+=("PyTest")
    fi

    if grep -qi "jest" "$PROJECT_DIR/package.json" 2>/dev/null; then
        tests+=("Jest")
    fi

    if grep -qi "vitest" "$PROJECT_DIR/package.json" 2>/dev/null; then
        tests+=("Vitest")
    fi

    if [[ -f "$PROJECT_DIR/cypress.config.js" ]] || [[ -f "$PROJECT_DIR/cypress.config.ts" ]]; then
        tests+=("Cypress")
    fi

    if [[ ${#tests[@]} -gt 0 ]]; then
        TEST_FRAMEWORK="${tests[*]}"
        success "Detected Testing Frameworks: ${CYAN}$TEST_FRAMEWORK${NC}"
    else
        TEST_FRAMEWORK="None detected"
        warn "No automated test configuration detected."
    fi
}

detect_database() {
    log "Detecting database architecture..."

    local dbs=()

    # 1. Environment files (.env)
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        if grep -qi "DB_CONNECTION=mysql" "$PROJECT_DIR/.env" 2>/dev/null || grep -qi "mysql" "$PROJECT_DIR/.env" 2>/dev/null; then
            dbs+=("MySQL / MariaDB")
        fi
        if grep -qi "DB_CONNECTION=pgsql" "$PROJECT_DIR/.env" 2>/dev/null || grep -qi "postgres" "$PROJECT_DIR/.env" 2>/dev/null; then
            dbs+=("PostgreSQL")
        fi
        if grep -qi "DB_CONNECTION=sqlite" "$PROJECT_DIR/.env" 2>/dev/null || grep -qi "sqlite" "$PROJECT_DIR/.env" 2>/dev/null; then
            dbs+=("SQLite")
        fi
    fi

    # 2. SQLite file checks
    if find "$PROJECT_DIR" -maxdepth 3 -name "*.sqlite" -o -name "*.sqlite3" -o -name "*.db" 2>/dev/null | grep -q .; then
        dbs+=("SQLite")
    fi

    # 3. PHP / Laravel database configuration
    if [[ -f "$PROJECT_DIR/config/database.php" ]]; then
        local laravel_driver
        laravel_driver=$(grep -oE "'default'\s*=>\s*env\(\s*['\"]DB_CONNECTION['\"]\s*,\s*['\"][^'\"]+['\"]" "$PROJECT_DIR/config/database.php" 2>/dev/null | head -n 1 | sed -E "s/.*,\s*['\"]([^'\"]+)['\"].*/\1/" || true)
        if [[ -n "$laravel_driver" ]]; then
            if [[ "$laravel_driver" == *"mysql"* ]]; then
                dbs+=("MySQL / MariaDB")
            elif [[ "$laravel_driver" == *"postgres"* || "$laravel_driver" == *"pgsql"* ]]; then
                dbs+=("PostgreSQL")
            elif [[ "$laravel_driver" == *"sqlite"* ]]; then
                dbs+=("SQLite")
            fi
        else
            dbs+=("PHP Database Abstraction")
        fi
    fi

    # 4. CodeIgniter 3 database configuration
    if [[ -f "$PROJECT_DIR/application/config/database.php" ]]; then
        local ci_driver
        ci_driver=$(grep -oE "'dbdriver'\s*\]\s*=\s*['\"][^'\"]+['\"]" "$PROJECT_DIR/application/config/database.php" 2>/dev/null | head -n 1 | sed -E "s/.*=\s*['\"]([^'\"]+)['\"].*/\1/" || true)
        if [[ -n "$ci_driver" ]]; then
            if [[ "$ci_driver" == *"mysql"* ]]; then
                dbs+=("MySQL / MariaDB")
            elif [[ "$ci_driver" == *"postgre"* || "$ci_driver" == *"pgsql"* ]]; then
                dbs+=("PostgreSQL")
            elif [[ "$ci_driver" == *"sqlite"* ]]; then
                dbs+=("SQLite")
            else
                dbs+=("CodeIgniter DB ($ci_driver)")
            fi
        else
            dbs+=("PHP Database Abstraction")
        fi
    fi

    # 5. Python / Django database configuration
    local django_settings
    django_settings=$(find "$PROJECT_DIR" -maxdepth 4 -name "settings.py" 2>/dev/null | head -n 1 || true)
    if [[ -n "$django_settings" ]]; then
        if grep -q "django.db.backends.postgresql" "$django_settings" 2>/dev/null; then
            dbs+=("PostgreSQL")
        fi
        if grep -q "django.db.backends.mysql" "$django_settings" 2>/dev/null; then
            dbs+=("MySQL / MariaDB")
        fi
        if grep -q "django.db.backends.sqlite3" "$django_settings" 2>/dev/null; then
            dbs+=("SQLite")
        fi
    fi

    # 6. Java / Spring Boot configurations
    local spring_configs
    spring_configs=$(find "$PROJECT_DIR" -maxdepth 4 -name "application.properties" -o -name "application.yml" -o -name "application.yaml" 2>/dev/null || true)
    if [[ -n "$spring_configs" ]]; then
        if echo "$spring_configs" | xargs grep -qi "mysql" 2>/dev/null; then
            dbs+=("MySQL / MariaDB")
        fi
        if echo "$spring_configs" | xargs grep -qi "postgresql" 2>/dev/null; then
            dbs+=("PostgreSQL")
        fi
        if echo "$spring_configs" | xargs grep -qi "jdbc:h2" 2>/dev/null; then
            dbs+=("H2 Database")
        fi
        if echo "$spring_configs" | xargs grep -qi "sqlite" 2>/dev/null; then
            dbs+=("SQLite")
        fi
    fi

    # 7. Node.js dependencies
    if [[ -f "$PROJECT_DIR/package.json" ]]; then
        if grep -qE '"(mysql|mysql2)"\s*:' "$PROJECT_DIR/package.json" 2>/dev/null; then
            dbs+=("MySQL / MariaDB")
        fi
        if grep -qE '"(pg|pg-promise)"\s*:' "$PROJECT_DIR/package.json" 2>/dev/null; then
            dbs+=("PostgreSQL")
        fi
        if grep -qE '"(sqlite3|better-sqlite3)"\s*:' "$PROJECT_DIR/package.json" 2>/dev/null; then
            dbs+=("SQLite")
        fi
        if grep -qE '"(mongodb|mongoose)"\s*:' "$PROJECT_DIR/package.json" 2>/dev/null; then
            dbs+=("MongoDB")
        fi
        if grep -qE '"(redis|ioredis)"\s*:' "$PROJECT_DIR/package.json" 2>/dev/null; then
            dbs+=("Redis")
        fi
    fi

    # 8. Python dependencies (requirements.txt / pyproject.toml)
    local py_deps=""
    if [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
        py_deps+=$(cat "$PROJECT_DIR/requirements.txt" 2>/dev/null)
    fi
    if [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
        py_deps+=$(cat "$PROJECT_DIR/pyproject.toml" 2>/dev/null)
    fi
    if [[ -n "$py_deps" ]]; then
        if echo "$py_deps" | grep -qiE "psycopg|asyncpg" 2>/dev/null; then
            dbs+=("PostgreSQL")
        fi
        if echo "$py_deps" | grep -qiE "mysqlclient|pymysql" 2>/dev/null; then
            dbs+=("MySQL / MariaDB")
        fi
        if echo "$py_deps" | grep -qiE "pymongo|motor" 2>/dev/null; then
            dbs+=("MongoDB")
        fi
        if echo "$py_deps" | grep -qiE "redis" 2>/dev/null; then
            dbs+=("Redis")
        fi
    fi

    # 9. Frappe / ERPNext sites config
    if [[ -f "$PROJECT_DIR/sites/common_site_config.json" ]]; then
        if grep -qi "db_type.*postgres" "$PROJECT_DIR/sites/common_site_config.json" 2>/dev/null; then
            dbs+=("PostgreSQL")
        else
            dbs+=("MySQL / MariaDB")
        fi
    fi

    if [[ ${#dbs[@]} -gt 0 ]]; then
        DB_ENGINE=$(printf "%s\n" "${dbs[@]}" | sort -u | tr '\n' ' ' | xargs || true)
        success "Detected Database: ${CYAN}$DB_ENGINE${NC}"
    else
        DB_ENGINE="None explicitly configured"
        warn "No database driver explicitly detected."
    fi
}

###############################################################################
# 4. Intelligence Document & Memory Setup
###############################################################################

generate_database_docs() {
    local doc="$PROJECT_DIR/DATABASE.md"
    log "Generating Database Intelligence Document ($doc)..."

    local schema_hints
    schema_hints=$(find "$PROJECT_DIR" -maxdepth 4 -not -path '*/system/*' -not -path '*/vendor/*' -not -path '*/.git/*' -not -path '*/node_modules/*' \( -name "*migration*" -o -name "*schema*" -o -name "*doctype*" -o -name "*.sql" \) 2>/dev/null || true)
    if [[ -n "$schema_hints" ]]; then
        schema_hints=$(echo "$schema_hints" | head -n 15 | sed 's/^/- /')
    else
        schema_hints="- None detected"
    fi

    cat > "$doc" <<EOF
# Database Architecture & Schema Context

Generated: $(date)
Target Project: $PROJECT_DIR

## Database Overview
- **Detected Engine**: $DB_ENGINE
- **Project Stack**: $PROJECT_TYPE

## Key Database Guidelines for AI Agents
1. **Schema Modifications**:
   - Always write migrations or structured DDL scripts. Never execute direct destructive schema changes in production.
   - Ensure foreign key constraints, indexes, and unique constraints are defined.
2. **Query Performance**:
   - Avoid \`SELECT *\` queries in performance-critical API paths.
   - Ensure indexed columns are used in \`WHERE\` and \`JOIN\` clauses.
3. **Data Integrity**:
   - Wrap multi-table mutation operations in database transactions.
   - Use parameterized queries or ORM bindings to prevent SQL Injection.

## Schema Hints & Tables
$schema_hints
EOF
    success "Generated DATABASE.md"
}

generate_architecture_docs() {
    local doc="$PROJECT_DIR/ARCHITECTURE.md"
    log "Generating Architecture Intelligence Document ($doc)..."

    cat > "$doc" <<EOF
# Project Architecture Overview

Generated: $(date)

## Overview
- **Primary Stack**: $PROJECT_TYPE
- **Technologies**: $TECH_STACK
- **Testing Suite**: $TEST_FRAMEWORK
- **Database Engine**: $DB_ENGINE

## Architectural Principles
1. **Modular Design**: Keep core domain business logic decoupled from transport/presentation layers.
2. **Service Layer**: Move complex logic from controllers or routing handlers into dedicated service or domain modules.
3. **Immutability & Safety**: Minimize unexpected side effects. Validate inputs strictly at system boundaries.
4. **Graphify Alignment**: Consult \`graphify-out/graph.json\` before modifying core shared components.
EOF
    success "Generated ARCHITECTURE.md"
}

generate_security_docs() {
    local doc="$PROJECT_DIR/SECURITY.md"
    log "Generating Security Guidelines Document ($doc)..."

    cat > "$doc" <<EOF
# Security Guidelines & Guardrails

Generated: $(date)

## Critical Security Rules for AI Agents

> [!CAUTION]
> **NEVER** expose sensitive credentials, \`.env\` files, API keys, private keys, or database passwords.

### 1. Secret Protection
- Never commit secrets or hardcode sensitive tokens in code.
- Check \`.gitignore\` to ensure secret files are excluded.

### 2. Injection Prevention
- Always sanitize user input. Use prepared statements or ORM parameters for SQL queries.
- Escape HTML/JSX outputs to prevent XSS (Cross-Site Scripting).

### 3. Authentication & Authorization
- Validate permissions explicitly on all protected endpoints.
- Do not bypass authentication checks in production routes.
EOF
    success "Generated SECURITY.md"
}

generate_testing_scaffold() {
    log "Setting up automated test suite scaffolding based on stack ($PROJECT_TYPE)..."

    mkdir -p "$PROJECT_DIR/tests"

    if [[ "$PROJECT_TYPE" == *"PHP"* ]]; then
        if [[ ! -f "$PROJECT_DIR/phpunit.xml" && ! -f "$PROJECT_DIR/phpunit.xml.dist" ]]; then
            cat > "$PROJECT_DIR/phpunit.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<phpunit bootstrap="vendor/autoload.php" colors="true">
    <testsuites>
        <testsuite name="Project Test Suite">
            <directory>tests</directory>
        </testsuite>
    </testsuites>
</phpunit>
EOF
            success "Created default phpunit.xml for PHP stack"
        fi
        if [[ ! -f "$PROJECT_DIR/tests/ExampleTest.php" ]]; then
            cat > "$PROJECT_DIR/tests/ExampleTest.php" <<'EOF'
<?php

use PHPUnit\Framework\TestCase;

class ExampleTest extends TestCase
{
    public function test_basic_example()
    {
        $this->assertTrue(true);
    }
}
EOF
            success "Created tests/ExampleTest.php"
        fi
        TEST_FRAMEWORK="PHPUnit (Auto-scaffolded)"

    elif [[ "$PROJECT_TYPE" == *"Python"* ]]; then
        if [[ ! -f "$PROJECT_DIR/pytest.ini" ]]; then
            cat > "$PROJECT_DIR/pytest.ini" <<'EOF'
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
EOF
            success "Created default pytest.ini for Python stack"
        fi
        if [[ ! -f "$PROJECT_DIR/tests/test_example.py" ]]; then
            cat > "$PROJECT_DIR/tests/test_example.py" <<'EOF'
def test_basic_example():
    assert True
EOF
            success "Created tests/test_example.py"
        fi
        TEST_FRAMEWORK="PyTest (Auto-scaffolded)"

    elif [[ "$PROJECT_TYPE" == *"Node"* ]] || [[ "$PROJECT_TYPE" == *"React"* ]]; then
        if [[ ! -f "$PROJECT_DIR/jest.config.js" ]]; then
            cat > "$PROJECT_DIR/jest.config.js" <<'EOF'
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.js'],
};
EOF
            success "Created default jest.config.js for Node.js stack"
        fi
        if [[ ! -f "$PROJECT_DIR/tests/example.test.js" ]]; then
            cat > "$PROJECT_DIR/tests/example.test.js" <<'EOF'
test('basic example test', () => {
  expect(true).toBe(true);
});
EOF
            success "Created tests/example.test.js"
        fi
        TEST_FRAMEWORK="Jest (Auto-scaffolded)"

    else
        if [[ ! -f "$PROJECT_DIR/tests/README.md" ]]; then
            cat > "$PROJECT_DIR/tests/README.md" <<'EOF'
# Project Automated Tests
This directory contains automated unit and integration tests for the project.
EOF
            success "Created tests/ directory and README.md"
        fi
        TEST_FRAMEWORK="General Test Suite (Auto-scaffolded)"
    fi
}

setup_project_memory_and_adr() {
    log "Configuring Project Memory Layer (.devmind/memory/) & ADR Manager (docs/adr/)..."
    mkdir -p "$DEVMIND_MEMORY_DIR"
    mkdir -p "$ADR_DIR"

    [[ -f "$DEVMIND_MEMORY_DIR/decisions.md" ]] || touch "$DEVMIND_MEMORY_DIR/decisions.md"
    [[ -f "$DEVMIND_MEMORY_DIR/known-issues.md" ]] || touch "$DEVMIND_MEMORY_DIR/known-issues.md"
    [[ -f "$DEVMIND_MEMORY_DIR/failed-attempts.md" ]] || touch "$DEVMIND_MEMORY_DIR/failed-attempts.md"
    [[ -f "$DEVMIND_MEMORY_DIR/project-history.md" ]] || touch "$DEVMIND_MEMORY_DIR/project-history.md"

    success "Configured Project Memory Layer (.devmind/memory/) & ADR Manager (docs/adr/)"
}

###############################################################################
# 5. Specialized AI Agents Generator (.agents/agents/)
###############################################################################

generate_specialized_agents() {
    log "Generating Specialized AI Agent Personas in .agents/agents/..."

    mkdir -p "$AGENTS_AGENTS_DIR"

    # Architect
    cat > "$AGENTS_AGENTS_DIR/architect.md" <<'EOF'
# Role: System Architect Agent
**Objective**: High-level system design, dependency analysis, and refactoring planning.

## Guidelines:
1. Always analyze `graphify-out/graph.json` before proposing major architectural changes.
2. Ensure changes maintain modular decoupling and scalability.
3. Output concrete implementation plans before modifying code.
EOF

    # Backend Developer
    cat > "$AGENTS_AGENTS_DIR/backend-developer.md" <<'EOF'
# Role: Backend Developer Agent
**Objective**: Build robust API endpoints, business services, and backend logic.

## Guidelines:
1. Follow MVC or Service-Repository patterns strictly.
2. Keep controllers thin; place complex business rules in service classes.
3. Write clean, readable code with comprehensive error handling.
EOF

    # Frontend Developer
    cat > "$AGENTS_AGENTS_DIR/frontend-developer.md" <<'EOF'
# Role: Frontend Developer Agent
**Objective**: Build modern, accessible, and responsive user interfaces.

## Guidelines:
1. Ensure visual excellence, smooth micro-interactions, and dark mode support.
2. Keep state local where possible; use standard component patterns.
3. Maintain accessible semantic HTML structure.
EOF

    # Database Expert
    cat > "$AGENTS_AGENTS_DIR/database-expert.md" <<'EOF'
# Role: Database Expert Agent
**Objective**: Schema design, query optimization, and migration safety.

## Guidelines:
1. Review `DATABASE.md` and ensure parameterized queries.
2. Add necessary indexes for slow queries.
3. Never issue destructive raw drop statements without verification.
EOF

    # Security Reviewer
    cat > "$AGENTS_AGENTS_DIR/security-reviewer.md" <<'EOF'
# Role: Security Reviewer Agent
**Objective**: Identify vulnerabilities, secret leaks, and security flaws.

## Guidelines:
1. Review code against OWASP Top 10 vulnerabilities.
2. Ensure no API keys, tokens, or credentials are hardcoded.
3. Verify authentication and authorization checks.
EOF

    # Code Reviewer
    cat > "$AGENTS_AGENTS_DIR/code-reviewer.md" <<'EOF'
# Role: Code Reviewer Agent
**Objective**: Code quality audit, pattern enforcement, and clean code validation.

## Guidelines:
1. Check adherence to project rules in `.agents/rules/`.
2. Ensure no unnecessary code bloat or unused imports.
3. Verify edge cases are handled gracefully.
EOF

    # Test Engineer
    cat > "$AGENTS_AGENTS_DIR/test-engineer.md" <<'EOF'
# Role: Test Engineer Agent
**Objective**: Write unit, integration, and regression test cases.

## Guidelines:
1. Follow Test-Driven Development (TDD) principles.
2. Ensure test coverage for critical business logic paths.
3. Verify tests pass cleanly before completing tasks.
EOF

    success "Created 7 specialized AI Agent personas in .agents/agents/"
}

###############################################################################
# 6. Operational Workflows Generator (.agents/workflows/)
###############################################################################

generate_workflows() {
    log "Generating Operational Workflows in .agents/workflows/..."

    mkdir -p "$WORKFLOWS_DIR"

    # New Feature Workflow
    cat > "$WORKFLOWS_DIR/new-feature.md" <<'EOF'
# Workflow: New Feature Implementation

```mermaid
flowchart TD
    Req["Understand Requirement"] --> Graph["Graphify Analysis"]
    Graph --> Plan["Create Implementation Plan"]
    Plan --> Approve{"User Approval"}
    Approve -- Yes --> TDD["Write Tests (TDD)"]
    TDD --> Code["Implement Feature"]
    Code --> Test["Run Tests & Verification"]
    Test --> Review["Code Review"]
    Review --> GraphRebuild["Rebuild Graphify Graph"]
```

## Execution Steps:
1. Understand the goal & search for existing implementations.
2. Inspect codebase dependencies with Graphify.
3. Present an implementation plan to the user.
4. Implement using small, safe changes.
5. Verify test pass and perform code review.
EOF

    # Bug Fix Workflow
    cat > "$WORKFLOWS_DIR/bug-fix.md" <<'EOF'
# Workflow: Bug Investigation & Fix

```mermaid
flowchart TD
    Logs["Inspect Error Logs & Stack Traces"] --> Reproduce["Reproduce Issue"]
    Reproduce --> Plan["Plan Root Cause Fix"]
    Plan --> Fix["Apply Minimal Safe Edit"]
    Fix --> Verify["Verify Fix with Tests"]
```

## Execution Steps:
1. Read full error logs and stack traces first.
2. Trace the root cause without masking symptoms.
3. Implement the minimal safe fix.
4. Verify with automated tests.
EOF

    # Refactor Workflow
    cat > "$WORKFLOWS_DIR/refactor.md" <<'EOF'
# Workflow: Code Refactoring

```mermaid
flowchart TD
    Graph["Graphify Coupling Check"] --> Plan["Draft Refactoring Plan"]
    Plan --> Baseline["Ensure Baseline Tests Pass"]
    Baseline --> Refactor["Refactor Incremental Chunks"]
    Refactor --> Verify["Run Regression Tests"]
```
EOF

    # Security Audit Workflow
    cat > "$WORKFLOWS_DIR/security-audit.md" <<'EOF'
# Workflow: Security Audit
1. Audit `.env` and secret inclusions in git.
2. Inspect input sanitization and SQL queries.
3. Verify authorization guards on API endpoints.
EOF

    # Performance Audit Workflow
    cat > "$WORKFLOWS_DIR/performance-audit.md" <<'EOF'
# Workflow: Performance Audit
1. Profile slow database queries and missing indexes.
2. Identify N+1 query patterns.
3. Audit frontend payload size and dynamic rendering bottlenecks.
EOF

    # Code Review Workflow
    cat > "$WORKFLOWS_DIR/code-review.md" <<'EOF'
# Workflow: Code Review
1. Inspect `git diff`.
2. Check formatting, security, and rule compliance.
3. Verify test coverage and pass status.
EOF

    success "Created 6 Operational Workflows in .agents/workflows/"
}

###############################################################################
# 7. Project Rules Generator (.agents/rules/)
###############################################################################

generate_rules() {
    log "Generating Project Domain Rules in .agents/rules/..."

    mkdir -p "$RULES_DIR"

    cat > "$RULES_DIR/architecture.md" <<'EOF'
# Rule: System Architecture
- Use modular design pattern.
- Decouple controllers from business logic; use Service layers.
- Do not modify core framework files directly.
EOF

    cat > "$RULES_DIR/database.md" <<'EOF'
# Rule: Database Management
- Always use parameterized queries or ORM models.
- Ensure foreign keys and indexes exist for related tables.
- Wrap multi-table writes in database transactions.
EOF

    cat > "$RULES_DIR/security.md" <<'EOF'
# Rule: Security & Secret Safety
- Never hardcode secrets, tokens, or credentials.
- Sanitize user inputs and escape dynamic HTML outputs.
- Enforce permission authorization checks on all endpoints.
EOF

    cat > "$RULES_DIR/api.md" <<'EOF'
# Rule: API Design
- Return consistent JSON response structures.
- Use standard HTTP status codes (200, 201, 400, 401, 403, 404, 500).
- Validate all incoming API payloads.
EOF

    cat > "$RULES_DIR/testing.md" <<'EOF'
# Rule: Testing Requirements
- Write unit or integration tests for new business logic.
- Run tests before declaring task completion.
- Never comment out failing tests to force green status.
EOF

    cat > "$RULES_DIR/project-specific.md" <<EOF
# Rule: Project-Specific Guidelines
- **Project Stack**: $PROJECT_TYPE
- **Testing Framework**: $TEST_FRAMEWORK
- **Database Engine**: $DB_ENGINE
EOF

    success "Created 6 Domain Rule files in .agents/rules/"
}

###############################################################################
# 8. Symlink ECC Skills, Rules & Agents
###############################################################################

map_ecc_skills() {
    mkdir -p "$SKILLS_DIR"
    log "Mapping ECC skills from system repository..."

    find "$ECC_DIR/skills" -mindepth 1 -maxdepth 1 -type d | while read -r skill_dir; do
        skill_name="$(basename "$skill_dir")"
        target="$SKILLS_DIR/$skill_name"
        [[ -e "$target" || -L "$target" ]] && rm -rf "$target"
        ln -s "$skill_dir" "$target"
    done

    success "Mapped ECC Skills"
}

map_ecc_rules() {
    mkdir -p "$RULES_DIR"
    log "Mapping ECC rules from system repository..."

    find "$ECC_DIR/rules" -maxdepth 1 -type f -name '*.md' | while read -r rule_file; do
        rule_name="$(basename "$rule_file")"
        target="$RULES_DIR/ecc-$rule_name"
        [[ -e "$target" || -L "$target" ]] && rm -f "$target"
        ln -s "$rule_file" "$target"
    done

    success "Mapped ECC Rules"
}

map_ecc_agents() {
    mkdir -p "$AGENTS_AGENTS_DIR"
    if [[ ! -d "$ECC_DIR/agents" ]]; then
        return
    fi
    log "Mapping ECC agents from system repository..."

    find "$ECC_DIR/agents" -maxdepth 1 -type f -name '*.md' | while read -r agent_file; do
        agent_name="$(basename "$agent_file")"
        target="$AGENTS_AGENTS_DIR/ecc-$agent_name"
        [[ -e "$target" || -L "$target" ]] && rm -f "$target"
        ln -s "$agent_file" "$target"
    done

    success "Mapped ECC Agents"
}

###############################################################################
# 9. Create Master AGENTS.md Operating Manual
###############################################################################

create_agents_manifest() {
    local manifest="$AGENTS_DIR/AGENTS.md"
    log "Generating Master AI Operating Manual ($manifest)..."

    cat > "$manifest" <<EOF
# AI Project Operating Manual & Guidelines

Welcome AI Agent. This document defines the operating rules, tech stack, and execution guidelines for **$PROJECT_DIR**.

---

## 📌 Project Context
- **Project Type**: $PROJECT_TYPE
- **Technologies**: $TECH_STACK
- **Testing Framework**: $TEST_FRAMEWORK
- **Database Engine**: $DB_ENGINE
- **System Source**: $ECC_DIR

---

## 🛡️ Forbidden Actions (Strict Enforcement)
- **NEVER** commit hardcoded secrets, passwords, or \`.env\` credentials.
- **NEVER** force-push or delete production git branches.
- **NEVER** perform large refactors without Graphify dependency analysis.
- **NEVER** comment out failing tests to fake pass status.
- **NEVER** modify core framework files directly.

---

## 📋 Mandatory Steps Before Changing Code
1. **Search & Understand**: Search codebase for existing patterns and utilities.
2. **Graphify Dependency Check**: Inspect \`graphify-out/graph.json\` for module coupling.
3. **Implementation Plan**: Present a clear plan for complex changes.
4. **Check Tests**: Identify existing tests related to the target file.

---

## 📋 Mandatory Steps After Changing Code
1. **Run Verification Commands**: Execute test suites or build commands.
2. **Inspect Diff**: Review \`git diff\` to ensure no unintended edits occurred.
3. **Update Graphify Graph**: Run \`graphify .\` after structural changes.

---

## 📁 AI Environment Structure
- Personas: \`.agents/agents/\`
- Workflows: \`.agents/workflows/\`
- Rules: \`.agents/rules/\`
- Skills: \`.agents/skills/\`
- Architecture Docs: \`ARCHITECTURE.md\`, \`DATABASE.md\`, \`SECURITY.md\`
EOF

    success "Created .agents/AGENTS.md"
}

###############################################################################
# 10. Graphify & Antigravity MCP Integration
###############################################################################

build_graphify_graph() {
    cd "$PROJECT_DIR"
    log "Building Graphify code graph..."

    if [[ -f "$GRAPHIFY_OUTPUT_DIR/graph.json" ]]; then
        warn "Existing Graphify graph detected."
        if [[ -t 0 ]]; then
            read -r -p "Rebuild Graphify graph for this project? [Y/n]: " answer
            answer="${answer:-Y}"
        else
            answer="Y"
        fi
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            warn "Skipping Graphify graph rebuild."
            return
        fi
    fi

    if command -v graphify >/dev/null 2>&1; then
        if graphify .; then
            success "Project Graphify code graph generated"
        else
            warn "Full Graphify extraction failed (likely no API key). Falling back to offline AST code-only update..."
            if graphify update .; then
                success "Project Graphify code-only graph generated successfully"
            else
                warn "Graphify CLI returned an error. Run manually: graphify update ."
            fi
        fi
        log "Generating interactive HTML graph visualizer (graphify-out/graph.html)..."
        if python3 "$PROJECT_DIR/generate_graph_html.py" "$PROJECT_DIR" >/dev/null 2>&1; then
            success "Generated HTML visualizer: graphify-out/graph.html"
        fi
    else
        warn "Graphify CLI unavailable."
    fi
}

configure_graphify_mcp() {
    log "Configuring Graphify MCP server..."
    mkdir -p "$(dirname "$ANTIGRAVITY_MCP_CONFIG")"

    if [[ ! -f "$ANTIGRAVITY_MCP_CONFIG" ]]; then
        cat > "$ANTIGRAVITY_MCP_CONFIG" <<'EOF'
{
  "mcpServers": {}
}
EOF
    fi

    if ! python3 - "$ANTIGRAVITY_MCP_CONFIG" "$PROJECT_DIR" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
project_dir = sys.argv[2]

with config_path.open("r", encoding="utf-8") as f:
    config = json.load(f)

if "mcpServers" not in config:
    config["mcpServers"] = {}

config["mcpServers"]["graphify"] = {
    "command": "uv",
    "args": [
        "run",
        "--with",
        "graphifyy",
        "--with",
        "mcp",
        "-m",
        "graphify.serve",
        "${workspace.path}/graphify-out/graph.json"
    ]
}

with config_path.open("w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print("Graphify MCP configured.")
PY
    then
        die "Failed to configure Graphify MCP"
    fi

    success "Graphify MCP configured"
}

create_setup_report() {
    local report="$PROJECT_DIR/AI_SETUP.md"

    cat > "$report" <<EOF
# AI Development Setup Summary

Generated: $(date)

## Project Context
- **Stack**: $PROJECT_TYPE
- **Technologies**: $TECH_STACK
- **Test Framework**: $TEST_FRAMEWORK
- **Database**: $DB_ENGINE

## Configured Components
- **DevMind CLI**: devmind (installed at $HOME/.local/bin/devmind)
- **ECC Source**: $ECC_DIR
- **Graphify Graph**: graphify-out/graph.json
- **Antigravity MCP**: $ANTIGRAVITY_MCP_CONFIG

## AI Assets
- Mapped Skills: $(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
- Mapped Rules: $(find "$RULES_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
- Mapped Agents: $(find "$AGENTS_AGENTS_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
- Mapped Workflows: $(find "$WORKFLOWS_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
EOF

    success "Created AI_SETUP.md"
}

update_gitignore() {
    local gitignore="$PROJECT_DIR/.gitignore"
    log "Updating .gitignore to exclude DevMind and AI setup files..."

    # Ensure .gitignore exists
    touch "$gitignore"

    # Entries to add
    local entries=(
        ".agents/"
        ".devmind/"
        "graphify-out/"
        "AI_SETUP.md"
        "ARCHITECTURE.md"
        "DATABASE.md"
        "SECURITY.md"
        "generate_graph_html.py"
        "bin/devmind"
        "pytest.ini"
        "tests/test_example.py"
        "phpunit.xml"
        "tests/ExampleTest.php"
        "jest.config.js"
        "tests/example.test.js"
    )

    local header="# DevMind AI Project Operating System"
    local header_added=false
    local added=0

    for entry in "${entries[@]}"; do
        if ! grep -Fqx "$entry" "$gitignore"; then
            # Add header first if not already present and we are about to add entries
            if ! grep -Fqx "$header" "$gitignore" && [ "$header_added" = false ]; then
                # If the file doesn't end with a newline, add one first
                if [[ -s "$gitignore" && "$(tail -c 1 "$gitignore" | wc -l)" -eq 0 ]]; then
                    echo "" >> "$gitignore"
                fi
                echo "" >> "$gitignore"
                echo "$header" >> "$gitignore"
                header_added=true
            fi
            
            # If the file doesn't end with a newline, add one first
            if [[ -s "$gitignore" && "$(tail -c 1 "$gitignore" | wc -l)" -eq 0 ]]; then
                echo "" >> "$gitignore"
            fi
            echo "$entry" >> "$gitignore"
            added=$((added + 1))
        fi
    done

    if [[ $added -gt 0 ]]; then
        success "Added $added entries to .gitignore"
    else
        success ".gitignore is already up to date"
    fi
}

###############################################################################
# 11. Run DevMind Doctor Diagnostics
###############################################################################

run_devmind_doctor() {
    if check_command devmind; then
        devmind doctor
    else
        python3 "$PROJECT_DIR/bin/devmind" doctor
    fi
}

###############################################################################
# Main Execution Pipeline
###############################################################################

main() {
    echo
    echo -e "${BOLD}${CYAN}====================================================${NC}"
    echo -e "${BOLD}${CYAN}   DevMind AI Project Operating System (v$SCRIPT_VERSION)  ${NC}"
    echo -e "${BOLD}${CYAN}   Unified CLI + Context Engine + Agent Framework   ${NC}"
    echo -e "${BOLD}${CYAN}====================================================${NC}"
    echo

    # 1. Validation
    validate_project

    # 2. System level tools check & DevMind CLI
    install_curl
    install_git
    install_python
    install_node
    install_uv
    install_graphify
    install_devmind_cli
    install_ecc_repository

    # 3. Stack & Ecosystem Inspection
    detect_project_stack
    detect_testing_framework
    detect_database

    # 4. Intelligence Documents, Testing Scaffold & Memory Setup
    generate_database_docs
    generate_architecture_docs
    generate_security_docs
    generate_testing_scaffold
    setup_project_memory_and_adr
    update_gitignore

    # 5. Agent Personas & Workflows Generator
    generate_specialized_agents
    generate_workflows
    generate_rules

    # 6. Symlink ECC System Assets
    map_ecc_skills
    map_ecc_rules
    map_ecc_agents

    # 7. Operating Manual & Integration
    create_agents_manifest
    build_graphify_graph
    configure_graphify_mcp
    create_setup_report

    # 8. Diagnostics & Engineering Score
    run_devmind_doctor

    echo
    echo "Next steps:"
    echo "1. Run 'devmind doctor' or 'devmind sync' anytime."
    echo "2. Open: $PROJECT_DIR"
    echo "3. Read: $PROJECT_DIR/AI_SETUP.md and .agents/AGENTS.md"
    echo
}

main "$@"
