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
#   - Graphify Knowledge Graph & Antigravity MCP Server Integration
#   - Multi-Dimensional Engineering Score & Diagnostic Suite (0-100%)
#
# Usage:
#   ./setup-ai-project.sh [--update|-u] [/path/to/project]
#
###############################################################################

SCRIPT_VERSION="3.0.0"
SCRIPT_SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

INIT_TESTS="false"
UPDATE_ECC="false"
PROJECT_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --update|-u)
            UPDATE_ECC="true"
            shift
            ;;
        --init-tests)
            INIT_TESTS="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--update|-u] [--init-tests] [/path/to/project]"
            echo
            echo "Options:"
            echo "  --update, -u    Force git fetch/pull for Everything Claude Code repository"
            echo "  --init-tests    Scaffold configuration/scaffold test files if not detected"
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
# Absolutize now: every path below is derived from PROJECT_DIR, and later steps cd around
if [[ -d "$PROJECT_DIR" ]]; then
    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
fi

ECC_REPO_URL="${ECC_REPO_URL:-https://github.com/affaan-m/everything-claude-code.git}"
ECC_DIR="${ECC_DIR:-$HOME/.local/share/everything-claude-code}"

FRAPPE_SKILLS_DIR="${FRAPPE_SKILLS_DIR:-$HOME/.local/share/frappe-skills}"
# Skill lookup order: ECC first, then the Frappe skills checkout
SKILL_SOURCE_DIRS=("$ECC_DIR/skills" "$FRAPPE_SKILLS_DIR/skills")

ANTIGRAVITY_MCP_CONFIG="${HOME}/.gemini/config/mcp_config.json"

AGENTS_DIR="${PROJECT_DIR}/.agents"
SKILLS_DIR="${AGENTS_DIR}/skills"
RULES_DIR="${AGENTS_DIR}/rules"
WORKFLOWS_DIR="${AGENTS_DIR}/workflows"
AGENTS_AGENTS_DIR="${AGENTS_DIR}/agents"
CLAUDE_DIR="${PROJECT_DIR}/.claude"
DEVMIND_MEMORY_DIR="${PROJECT_DIR}/.devmind/memory"
ADR_DIR="${PROJECT_DIR}/docs/adr"

GRAPHIFY_OUTPUT_DIR="${PROJECT_DIR}/graphify-out"

# State Variables
PROJECT_TYPE="Generic / Unspecified"
PROFILE_NAME="generic"
TECH_STACK=""
TEST_FRAMEWORK="None detected"
DB_ENGINE="None detected"
PACKAGE_MANAGER="None detected"
PRIMARY_DB="None detected"
SECONDARY_DB="None detected"
CACHE_QUEUE="None detected"

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

detect_node_version() {
    if [[ -f "$PROJECT_DIR/.nvmrc" ]]; then
        cat "$PROJECT_DIR/.nvmrc" | tr -d '[:space:]'
    elif [[ -f "$PROJECT_DIR/package.json" ]]; then
        python3 -c "
import json, sys
try:
    with open('$PROJECT_DIR/package.json') as f:
        data = json.load(f)
        node_engine = data.get('engines', {}).get('node', '')
        import re
        node_version = re.sub(r'[>=^~<\s]', '', node_engine)
        if node_version:
            parts = re.findall(r'\d+(?:\.\d+)*', node_version)
            if parts:
                print(parts[0])
except Exception:
    pass
" 2>/dev/null
    fi
}

install_node() {
    if check_command node && check_command npm; then
        success "Node.js is installed: $(node --version) (npm $(npm --version))"
        return
    fi

    log "Node.js not found. Installing..."
    local preferred_ver
    preferred_ver=$(detect_node_version)
    if [[ -z "$preferred_ver" ]]; then
        preferred_ver="--lts"
        log "No preferred Node.js version detected. Defaulting to --lts"
    else
        log "Detected preferred Node.js version from project configurations: $preferred_ver"
    fi

    if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
        export NVM_DIR="$HOME/.nvm"
        # shellcheck disable=SC1090,SC1091
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install "$preferred_ver"
    else
        log "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash || true
        export NVM_DIR="$HOME/.nvm"
        if [[ -s "$NVM_DIR/nvm.sh" ]]; then
            # shellcheck disable=SC1090,SC1091
            \. "$NVM_DIR/nvm.sh"
            nvm install "$preferred_ver"
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
            sed -i "s|@@DEVMIND_SOURCE_DIR@@|$SCRIPT_SOURCE_DIR|g" "$PROJECT_DIR/bin/devmind"
        fi
        if [[ -f "$SCRIPT_SOURCE_DIR/generate_graph_html.py" ]]; then
            cp "$SCRIPT_SOURCE_DIR/generate_graph_html.py" "$PROJECT_DIR/generate_graph_html.py"
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
        git clone --depth 1 "$ECC_REPO_URL" "$ECC_DIR"
        success "ECC repository cloned"
    fi

    [[ -d "$ECC_DIR/skills" ]] || die "ECC skills directory not found at $ECC_DIR/skills"
    [[ -d "$ECC_DIR/rules" ]] || die "ECC rules directory not found at $ECC_DIR/rules"

    # Auto-integrate Frappe skills repository
    local frappe_skills_url="${FRAPPE_SKILLS_URL:-https://github.com/frappe/skills.git}"
    local frappe_skills_temp_dir="$FRAPPE_SKILLS_DIR"
    if [[ -d "$frappe_skills_temp_dir/.git" ]]; then
        if [[ "$UPDATE_ECC" == "true" ]]; then
            log "Updating Frappe skills repository..."
            git -C "$frappe_skills_temp_dir" fetch --quiet
            git -C "$frappe_skills_temp_dir" pull --ff-only --quiet || warn "Could not fast-forward Frappe skills repository."
        fi
    else
        log "Cloning Frappe skills repository..."
        mkdir -p "$(dirname "$frappe_skills_temp_dir")"
        git clone --depth 1 "$frappe_skills_url" "$frappe_skills_temp_dir" --quiet
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
    if [[ -f "$PROJECT_DIR/apps.txt" ]] || [[ -d "$PROJECT_DIR/sites" ]] || find "$PROJECT_DIR" -maxdepth 4 \( -name node_modules -o -name .git -o -name venv -o -name .venv -o -name site-packages \) -prune -o -name hooks.py -execdir test -f modules.txt \; -print -quit | grep -q .; then
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
    
    PACKAGE_MANAGER=$(detect_package_manager)
    success "Detected Package Manager: ${CYAN}$PACKAGE_MANAGER${NC}"

    # Select Profile based on stack
    if [[ "$PROJECT_TYPE" == *"Frappe"* ]]; then
        PROFILE_NAME="frappe"
    elif [[ "$PROJECT_TYPE" == *"Laravel"* ]]; then
        PROFILE_NAME="laravel"
    elif [[ "$PROJECT_TYPE" == *"Django"* ]]; then
        PROFILE_NAME="django"
    elif [[ "$PROJECT_TYPE" == *"FastAPI"* ]]; then
        PROFILE_NAME="fastapi"
    elif [[ "$PROJECT_TYPE" == *"Next.js"* ]]; then
        PROFILE_NAME="nextjs"
    elif [[ "$PROJECT_TYPE" == *"React"* ]] || [[ "$PROJECT_TYPE" == *"Vite"* ]]; then
        PROFILE_NAME="react"
    elif [[ "$PROJECT_TYPE" == *"Node.js"* ]]; then
        PROFILE_NAME="node"
    else
        PROFILE_NAME="generic"
    fi
    success "Selected Profile: ${CYAN}$PROFILE_NAME${NC}"
}

detect_package_manager() {
    if [[ -f "$PROJECT_DIR/pnpm-lock.yaml" ]]; then
        echo "pnpm"
    elif [[ -f "$PROJECT_DIR/yarn.lock" ]]; then
        echo "yarn"
    elif [[ -f "$PROJECT_DIR/bun.lockb" ]] || [[ -f "$PROJECT_DIR/bun.lock" ]]; then
        echo "bun"
    elif [[ -f "$PROJECT_DIR/package-lock.json" ]]; then
        echo "npm"
    elif [[ -f "$PROJECT_DIR/package.json" ]]; then
        echo "npm"
    else
        echo "None"
    fi
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
    log "Detecting database & cache/queue architecture with confidence scores..."

    local db_results
    db_results=$(PROJECT_DIR="$PROJECT_DIR" python3 -c "
import os
import re
import json

project_dir = os.environ.get('PROJECT_DIR', '.')
db_candidates = {}
cache_candidates = {}

def add_db(name, confidence, source):
    if name not in db_candidates:
        db_candidates[name] = []
    db_candidates[name].append((confidence, source))

def add_cache(name, confidence, source):
    if name not in cache_candidates:
        cache_candidates[name] = []
    cache_candidates[name].append((confidence, source))

env_path = os.path.join(project_dir, '.env')
if os.path.exists(env_path):
    try:
        with open(env_path, 'r', errors='ignore') as f:
            env_content = f.read()
            conn_match = re.search(r'DB_CONNECTION\s*=\s*(\w+)', env_content, re.I)
            if conn_match:
                conn = conn_match.group(1).lower()
                if 'mysql' in conn:
                    add_db('MySQL / MariaDB', 95, '.env DB_CONNECTION')
                elif 'postgres' in conn or 'pgsql' in conn:
                    add_db('PostgreSQL', 95, '.env DB_CONNECTION')
                elif 'sqlite' in conn:
                    add_db('SQLite', 95, '.env DB_CONNECTION')
            else:
                if re.search(r'mysql', env_content, re.I):
                    add_db('MySQL / MariaDB', 70, '.env keyword')
                if re.search(r'postgres|pgsql', env_content, re.I):
                    add_db('PostgreSQL', 70, '.env keyword')
                if re.search(r'sqlite', env_content, re.I):
                    add_db('SQLite', 70, '.env keyword')
            if re.search(r'redis', env_content, re.I):
                add_cache('Redis', 90, '.env keyword')
            if re.search(r'memcached', env_content, re.I):
                add_cache('Memcached', 90, '.env keyword')
    except Exception:
        pass

frappe_config = os.path.join(project_dir, 'sites', 'common_site_config.json')
if os.path.exists(frappe_config):
    try:
        with open(frappe_config, 'r') as f:
            data = json.load(f)
            db_type = data.get('db_type', '').lower()
            if 'postgres' in db_type:
                add_db('PostgreSQL', 95, 'common_site_config db_type')
            else:
                add_db('MySQL / MariaDB', 95, 'common_site_config db_type (default)')
            if 'redis_cache' in data or 'redis_queue' in data:
                add_cache('Redis', 95, 'common_site_config redis')
    except Exception:
        pass

laravel_config = os.path.join(project_dir, 'config', 'database.php')
if os.path.exists(laravel_config):
    try:
        with open(laravel_config, 'r', errors='ignore') as f:
            content = f.read()
            match = re.search(r\"'default'\s*=>\s*env\(\s*['\\\" ]DB_CONNECTION['\\\" ]\s*,\s*['\\\"]([^'\\\"]+)['\\\"]\", content)
            if match:
                conn = match.group(1).lower()
                if 'mysql' in conn:
                    add_db('MySQL / MariaDB', 95, 'Laravel config default')
                elif 'postgres' in conn or 'pgsql' in conn:
                    add_db('PostgreSQL', 95, 'Laravel config default')
                elif 'sqlite' in conn:
                    add_db('SQLite', 95, 'Laravel config default')
    except Exception:
        pass

for root, dirs, files in os.walk(project_dir):
    if 'settings.py' in files:
        settings_path = os.path.join(root, 'settings.py')
        try:
            with open(settings_path, 'r', errors='ignore') as f:
                content = f.read()
                if 'django.db.backends.postgresql' in content:
                    add_db('PostgreSQL', 95, 'Django settings')
                if 'django.db.backends.mysql' in content:
                    add_db('MySQL / MariaDB', 95, 'Django settings')
                if 'django.db.backends.sqlite3' in content:
                    add_db('SQLite', 95, 'Django settings')
        except Exception:
            pass
        break

pkg_path = os.path.join(project_dir, 'package.json')
if os.path.exists(pkg_path):
    try:
        with open(pkg_path, 'r') as f:
            data = json.load(f)
            deps = {**data.get('dependencies', {}), **data.get('devDependencies', {})}
            if any(k in deps for k in ['mysql', 'mysql2', 'sequelize', 'typeorm']):
                add_db('MySQL / MariaDB', 80, 'Node package.json dependencies')
            if any(k in deps for k in ['pg', 'pg-promise']):
                add_db('PostgreSQL', 80, 'Node package.json dependencies')
            if any(k in deps for k in ['sqlite3', 'better-sqlite3']):
                add_db('SQLite', 80, 'Node package.json dependencies')
            if any(k in deps for k in ['mongodb', 'mongoose']):
                add_db('MongoDB', 85, 'Node package.json dependencies')
            if any(k in deps for k in ['redis', 'ioredis']):
                add_cache('Redis', 85, 'Node package.json dependencies')
    except Exception:
        pass

for dep_file in ['requirements.txt', 'pyproject.toml']:
    dep_path = os.path.join(project_dir, dep_file)
    if os.path.exists(dep_path):
        try:
            with open(dep_path, 'r', errors='ignore') as f:
                content = f.read().lower()
                if 'psycopg' in content or 'asyncpg' in content:
                    add_db('PostgreSQL', 80, f'Python {dep_file}')
                if 'mysqlclient' in content or 'pymysql' in content:
                    add_db('MySQL / MariaDB', 80, f'Python {dep_file}')
                if 'pymongo' in content or 'motor' in content:
                    add_db('MongoDB', 85, f'Python {dep_file}')
                if 'redis' in content:
                    add_cache('Redis', 80, f'Python {dep_file}')
        except Exception:
            pass

sqlite_found = False
for root, dirs, files in os.walk(project_dir):
    depth = root[len(project_dir):].count(os.path.sep)
    if depth > 2:
        continue
    for file in files:
        if file.endswith(('.sqlite', '.sqlite3', '.db')) and not file.startswith('.'):
            sqlite_found = True
            break
    if sqlite_found:
        break
if sqlite_found:
    add_db('SQLite', 60, 'Local SQLite file')

final_dbs = {}
for db_name, list_vals in db_candidates.items():
    max_val = max(list_vals, key=lambda x: x[0])
    final_dbs[db_name] = max_val

final_caches = {}
for cache_name, list_vals in cache_candidates.items():
    max_val = max(list_vals, key=lambda x: x[0])
    final_caches[cache_name] = max_val

sorted_dbs = sorted(final_dbs.items(), key=lambda x: x[1][0], reverse=True)
sorted_caches = sorted(final_caches.items(), key=lambda x: x[1][0], reverse=True)

primary = 'None detected'
secondaries = []
cache = 'None detected'

if sorted_dbs:
    primary = f\"{sorted_dbs[0][0]} ({sorted_dbs[0][1][0]}% confidence via {sorted_dbs[0][1][1]})\"
    for item in sorted_dbs[1:]:
        secondaries.append(f\"{item[0]} ({item[1][0]}% confidence via {item[1][1]})\")

if sorted_caches:
    cache = ', '.join(f\"{item[0]} ({item[1][0]}% confidence via {item[1][1]})\" for item in sorted_caches)

print('PRIMARY_DB=' + primary)
print('SECONDARY_DB=' + (', '.join(secondaries) if secondaries else 'None detected'))
print('CACHE_QUEUE=' + cache)
" 2>/dev/null)

    if [[ -n "$db_results" ]]; then
        PRIMARY_DB=$(echo "$db_results" | grep "^PRIMARY_DB=" | cut -d= -f2- || echo "None detected")
        SECONDARY_DB=$(echo "$db_results" | grep "^SECONDARY_DB=" | cut -d= -f2- || echo "None detected")
        CACHE_QUEUE=$(echo "$db_results" | grep "^CACHE_QUEUE=" | cut -d= -f2- || echo "None detected")
        DB_ENGINE="$PRIMARY_DB"
    fi

    if [[ "$PRIMARY_DB" != "None detected" ]]; then
        success "Primary Database: ${CYAN}$PRIMARY_DB${NC}"
        if [[ "$SECONDARY_DB" != "None detected" ]]; then
            success "Secondary Database(s): ${CYAN}$SECONDARY_DB${NC}"
        fi
        if [[ "$CACHE_QUEUE" != "None detected" ]]; then
            success "Cache / Queue Store: ${CYAN}$CACHE_QUEUE${NC}"
        fi
    else
        PRIMARY_DB="None explicitly configured"
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

    PROJECT_DIR="$PROJECT_DIR" \
    PRIMARY_DB="$PRIMARY_DB" \
    SECONDARY_DB="$SECONDARY_DB" \
    CACHE_QUEUE="$CACHE_QUEUE" \
    PROJECT_TYPE="$PROJECT_TYPE" \
    PACKAGE_MANAGER="$PACKAGE_MANAGER" \
    DB_ENGINE="$DB_ENGINE" \
    DOC_PATH="$doc" \
    python3 << 'EOF'
import os
import re
import glob
import subprocess
from datetime import datetime

project_dir = os.environ.get('PROJECT_DIR', '.')
doc_path = os.environ.get('DOC_PATH', 'DATABASE.md')
primary_db = os.environ.get('PRIMARY_DB', 'None')
secondary_db = os.environ.get('SECONDARY_DB', 'None')
cache_queue = os.environ.get('CACHE_QUEUE', 'None')
project_stack = os.environ.get('PROJECT_TYPE', 'Generic')
package_manager = os.environ.get('PACKAGE_MANAGER', 'None')
db_engine = os.environ.get('DB_ENGINE', 'None')

current_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

db_version = "Unknown"
if "postgres" in db_engine.lower() or "postgresql" in db_engine.lower():
    try:
        db_version = subprocess.check_output(["psql", "--version"], stderr=subprocess.DEVNULL).decode().strip()
    except:
        pass
elif "mysql" in db_engine.lower() or "mariadb" in db_engine.lower():
    try:
        db_version = subprocess.check_output(["mysql", "--version"], stderr=subprocess.DEVNULL).decode().strip()
    except:
        pass
elif "sqlite" in db_engine.lower():
    try:
        db_version = subprocess.check_output(["sqlite3", "--version"], stderr=subprocess.DEVNULL).decode().strip()
    except:
        pass

tables = {}
foreign_keys = []
indexes = []
relationships = []
migration_files = []
potential_issues = []

# Scan for migration files
migration_patterns = [
    '**/migrations/*.py',
    '**/migrations/*.js',
    '**/migrations/*.ts',
    '**/database/migrations/*.php',
    '**/db/migrate/*.rb',
    '**/migrations/*.sql'
]
for pattern in migration_patterns:
    for path in glob.glob(os.path.join(project_dir, pattern), recursive=True):
        if any(p in path for p in ['/vendor/', '/node_modules/', '/.git/', '/system/', '/.venv/', '/venv/']):
            continue
        migration_files.append(path)
migration_count = len(migration_files)

# Excluded folders list
excluded_dirs = ['/vendor/', '/node_modules/', '/.git/', '/system/', '/.venv/', '/venv/', '/graphify-out/', '/.agents/', '/.devmind/']

# Parse Frappe DocTypes
for root, dirs, files in os.walk(project_dir):
    if any(p in root for p in excluded_dirs):
        continue
    if 'doctype' in root.lower():
        for file in files:
            if file.endswith('.json'):
                path = os.path.join(root, file)
                try:
                    import json
                    with open(path, 'r', errors='ignore') as f:
                        data = json.load(f)
                    if isinstance(data, dict) and data.get('doctype') == 'DocType':
                        doc_name = data.get('name')
                        if doc_name:
                            tables[doc_name] = {
                                'engine': 'Frappe DocType',
                                'columns': [],
                                'primary_key': 'name'
                            }
                            for field in data.get('fields', []):
                                fname = field.get('fieldname')
                                ftype = field.get('fieldtype')
                                if fname and ftype:
                                    tables[doc_name]['columns'].append((fname, ftype))
                                    if ftype == 'Link' and field.get('options'):
                                        foreign_keys.append((doc_name, fname, field.get('options')))
                                        relationships.append(f"{doc_name}.{fname} -> {field.get('options')}.name")
                except Exception:
                    pass

# Parse Prisma Schema
for root, dirs, files in os.walk(project_dir):
    if any(p in root for p in excluded_dirs):
        continue
    for file in files:
        if file == 'schema.prisma':
            path = os.path.join(root, file)
            try:
                with open(path, 'r', errors='ignore') as f:
                    prisma_content = f.read()
                models = re.findall(r'model\s+(\w+)\s*\{(.*?)\}', prisma_content, re.DOTALL)
                for model_name, model_body in models:
                    tables[model_name] = {
                        'engine': 'Prisma Model',
                        'columns': [],
                        'primary_key': 'id'
                    }
                    for line in model_body.splitlines():
                        line = line.strip()
                        if not line or line.startswith('//'):
                            continue
                        parts = line.split()
                        if len(parts) >= 2:
                            field_name = parts[0]
                            field_type = parts[1]
                            if '@id' in line:
                                tables[model_name]['primary_key'] = field_name
                            tables[model_name]['columns'].append((field_name, field_type))
                            if '@relation' in line:
                                rel_match = re.search(r'fields:\s*\[(.*?)\]', line)
                                ref_match = re.search(r'references:\s*\[(.*?)\]', line)
                                if rel_match and ref_match:
                                    rel_field = rel_match.group(1).strip()
                                    ref_field = ref_match.group(1).strip()
                                    foreign_keys.append((model_name, rel_field, field_type))
                                    relationships.append(f"{model_name}.{rel_field} -> {field_type}.{ref_field}")
            except Exception:
                pass

# Parse SQL DDL files
sql_files = []
for root, dirs, files in os.walk(project_dir):
    if any(p in root for p in excluded_dirs):
        continue
    for file in files:
        if file.endswith('.sql'):
            sql_files.append(os.path.join(root, file))

for path in sql_files:
    try:
        with open(path, 'r', errors='ignore') as f:
            sql_content = f.read()
        sql_content = re.sub(r'--.*', '', sql_content)
        sql_content = re.sub(r'/\*.*?\*/', '', sql_content, flags=re.DOTALL)
        creates = re.finditer(r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)\s*\((.*?)\);', sql_content, re.DOTALL | re.IGNORECASE)
        for match in creates:
            table_name = match.group(1)
            table_body = match.group(2)
            tables[table_name] = {
                'engine': 'SQL DDL',
                'columns': [],
                'primary_key': 'None'
            }
            lines = table_body.split(',')
            for line in lines:
                line = line.strip()
                if not line:
                    continue
                parts = line.split()
                if len(parts) >= 2:
                    first_word = parts[0].upper()
                    if first_word in ['PRIMARY', 'FOREIGN', 'CONSTRAINT', 'INDEX', 'KEY', 'UNIQUE']:
                        if 'PRIMARY KEY' in line.upper():
                            pk_match = re.search(r'PRIMARY\s+KEY\s*\((.*?)\)', line, re.IGNORECASE)
                            if pk_match:
                                tables[table_name]['primary_key'] = pk_match.group(1).replace('`','').replace('"','').strip()
                        if 'FOREIGN KEY' in line.upper():
                            fk_match = re.search(r'FOREIGN\s+KEY\s*\((.*?)\)\s+REFERENCES\s+(\w+)\s*\((.*?)\)', line, re.IGNORECASE)
                            if fk_match:
                                fk_col = fk_match.group(1).replace('`','').replace('"','').strip()
                                ref_tbl = fk_match.group(2).strip()
                                ref_col = fk_match.group(3).replace('`','').replace('"','').strip()
                                foreign_keys.append((table_name, fk_col, ref_tbl))
                                relationships.append(f"{table_name}.{fk_col} -> {ref_tbl}.{ref_col}")
                        continue
                    col_name = parts[0].replace('`','').replace('"','').strip()
                    col_type = parts[1]
                    if 'PRIMARY KEY' in line.upper():
                        tables[table_name]['primary_key'] = col_name
                    tables[table_name]['columns'].append((col_name, col_type))
    except Exception:
        pass

# Parse Django models.py
for root, dirs, files in os.walk(project_dir):
    if any(p in root for p in excluded_dirs):
        continue
    for file in files:
        if file == 'models.py':
            path = os.path.join(root, file)
            try:
                with open(path, 'r', errors='ignore') as f:
                    django_content = f.read()
                classes = re.finditer(r'class\s+(\w+)\s*\(\s*models\.Model\s*\)\s*:(.*?)(?=\nclass|\Z)', django_content, re.DOTALL)
                for match in classes:
                    class_name = match.group(1)
                    class_body = match.group(2)
                    tables[class_name] = {
                        'engine': 'Django Model',
                        'columns': [],
                        'primary_key': 'id'
                    }
                    for line in class_body.splitlines():
                        line = line.strip()
                        if '=' in line and not line.startswith('#'):
                            col_parts = line.split('=', 1)
                            col_name = col_parts[0].strip()
                            field_call = col_parts[1].strip()
                            ftype_match = re.match(r'models\.(\w+Field)', field_call)
                            if ftype_match:
                                ftype = ftype_match.group(1)
                                tables[class_name]['columns'].append((col_name, ftype))
                                if 'ForeignKey' in field_call or 'OneToOneField' in field_call:
                                    target_match = re.search(r'(?:ForeignKey|OneToOneField)\(\s*[\'"]?(\w+)[\'"]?', field_call)
                                    if target_match:
                                        target_model = target_match.group(1)
                                        foreign_keys.append((class_name, col_name, target_model))
                                        relationships.append(f"{class_name}.{col_name} -> {target_model}.id")
            except Exception:
                pass

# Parse potential issues
for table_name, tinfo in tables.items():
    if tinfo['primary_key'] == 'None' or not tinfo['primary_key']:
        potential_issues.append(f"Table '{table_name}' has no primary key defined.")
for fk_tbl, fk_col, ref_tbl in foreign_keys:
    tbl_names_lower = [t.lower() for t in tables.keys()]
    if ref_tbl.lower() not in tbl_names_lower:
        potential_issues.append(f"Foreign key '{fk_tbl}.{fk_col}' references missing table '{ref_tbl}'.")

# Build Markdown
markdown_out = []
markdown_out.append("# Database Architecture & Schema Context\n")
markdown_out.append(f"Generated: {current_date}")
markdown_out.append(f"Target Project: {project_dir}\n")

markdown_out.append("## Database Overview")
markdown_out.append(f"- **Primary Database**: {primary_db}")
markdown_out.append(f"- **Secondary Database(s)**: {secondary_db}")
markdown_out.append(f"- **Cache / Queue Store**: {cache_queue}")
markdown_out.append(f"- **Project Stack**: {project_stack}")
markdown_out.append(f"- **Package Manager**: {package_manager}\n")

markdown_out.append("## Database Architecture Intelligence")
markdown_out.append("### Primary DB Details")
markdown_out.append(f"- **Engine**: {db_engine}")
markdown_out.append(f"- **Version**: {db_version}")
markdown_out.append(f"- **Migration Count**: {migration_count} files detected\n")

markdown_out.append("### Database Schema")

# Tables
markdown_out.append("#### ├── Tables")
if tables:
    for tname, tinfo in tables.items():
        markdown_out.append(f"- **{tname}** (Engine: {tinfo['engine']})")
else:
    markdown_out.append("- None detected")
markdown_out.append("")

# Columns
markdown_out.append("#### ├── Columns")
if tables:
    for tname, tinfo in tables.items():
        markdown_out.append(f"- **{tname}** (PK: `{tinfo['primary_key']}`):")
        for cname, ctype in tinfo['columns']:
            markdown_out.append(f"  - `{cname}` ({ctype})")
else:
    markdown_out.append("- None detected")
markdown_out.append("")

# Foreign Keys
markdown_out.append("#### ├── Foreign Keys")
if foreign_keys:
    for fk_tbl, fk_col, ref_tbl in foreign_keys:
        markdown_out.append(f"- `{fk_tbl}.{fk_col}` -> `{ref_tbl}`")
else:
    markdown_out.append("- None detected")
markdown_out.append("")

# Indexes
markdown_out.append("#### ├── Indexes")
sql_indexes = []
for path in sql_files:
    try:
        with open(path, 'r', errors='ignore') as f:
            sql_content = f.read()
        idx_matches = re.finditer(r'CREATE\s+(?:UNIQUE\s+)?INDEX\s+(\w+)\s+ON\s+(\w+)\s*\((.*?)\);', sql_content, re.IGNORECASE)
        for match in idx_matches:
            sql_indexes.append(f"Index `{match.group(1)}` on `{match.group(2)}({match.group(3)})`")
    except Exception:
        pass

if sql_indexes:
    for idx in sql_indexes:
        markdown_out.append(f"- {idx}")
else:
    if tables:
        markdown_out.append("- Primary and Foreign Key indexes detected (auto-managed by framework models/migrations)")
    else:
        markdown_out.append("- None detected")
markdown_out.append("")

# Relationships
markdown_out.append("#### ├── Relationships")
if relationships:
    for rel in relationships:
        markdown_out.append(f"- {rel}")
else:
    markdown_out.append("- None detected")
markdown_out.append("")

# Potential Issues
markdown_out.append("#### └── Potential Issues")
if potential_issues:
    for issue in potential_issues:
        markdown_out.append(f"- **[Warning]**: {issue}")
else:
    markdown_out.append("- None detected. Schema appears structurally sound.")

markdown_out.append("\n## Key Database Guidelines for AI Agents")
markdown_out.append("1. **Schema Modifications**:")
markdown_out.append("   - Always write migrations or structured DDL scripts. Never execute direct destructive schema changes in production.")
markdown_out.append("   - Ensure foreign key constraints, indexes, and unique constraints are defined.")
markdown_out.append("2. **Query Performance**:")
markdown_out.append("   - Avoid `SELECT *` queries in performance-critical API paths.")
markdown_out.append("   - Ensure indexed columns are used in `WHERE` and `JOIN` clauses.")
markdown_out.append("3. **Data Integrity**:")
markdown_out.append("   - Wrap multi-table mutation operations in database transactions.")
markdown_out.append("   - Use parameterized queries or ORM bindings to prevent SQL Injection.")

with open(doc_path, 'w') as f:
    f.write("\n".join(markdown_out) + "\n")
EOF
    success "Generated DATABASE.md"
}

generate_architecture_docs() {
    local doc="$PROJECT_DIR/ARCHITECTURE.md"
    log "Generating Architecture Intelligence Document ($doc)..."

    python3 - <<EOF
import os
import json
import datetime
from pathlib import Path

project_dir = Path("$PROJECT_DIR")
doc_path = Path("$doc")

# Load graph data
nodes = []
links = []
graph_json_path = project_dir / 'graphify-out' / 'graph.json'
if graph_json_path.exists():
    try:
        with open(graph_json_path, 'r') as f:
            graph_data = json.load(f)
            nodes = graph_data.get('nodes', [])
            links = graph_data.get('links', [])
    except Exception:
        pass

# Collect codebase files
code_files = []
for r, d, f_list in os.walk(project_dir):
    # Skip ignored directories
    if any(p in r for p in ['.git', 'node_modules', '.agents', '.devmind', 'graphify-out', 'venv', '.venv']):
        continue
    for f in f_list:
        file_path = Path(r) / f
        try:
            rel_path = file_path.relative_to(project_dir)
            code_files.append(rel_path)
        except Exception:
            pass

# Categorize components
api_controllers_routes = []
business_logic_models = []
databases_found = []
queues_found = []
caches_found = []
external_apis_found = []
auth_found = []

# Scan files content & paths
for rf in code_files:
    rf_str = str(rf).lower()
    
    # 1. API / Controllers / Routes
    if any(w in rf_str for w in ['route', 'controller', 'views.py', 'handlers', 'endpoints', 'api/', 'routes/']):
        api_controllers_routes.append(rf)
        
    # 2. Business Logic / Services / Models
    elif any(w in rf_str for w in ['service', 'models.py', 'models/', 'domain', 'entities', 'doctype']):
        business_logic_models.append(rf)
        
    # Read files to scan for specific patterns (Database, Cache, Queue, External APIs, Authentication)
    abs_path = project_dir / rf
    if abs_path.is_file() and abs_path.suffix in ['.py', '.js', '.ts', '.go', '.rb', '.php', '.java', '.json', '.html', '.txt']:
        try:
            content = abs_path.read_text(errors='ignore')
            
            # Database
            if 'postgresql' in content.lower() or 'psycopg' in content.lower():
                if 'PostgreSQL' not in databases_found: databases_found.append('PostgreSQL')
            if 'mysql' in content.lower() or 'pymysql' in content.lower() or 'mariadb' in content.lower():
                if 'MySQL / MariaDB' not in databases_found: databases_found.append('MySQL / MariaDB')
            if 'sqlite' in content.lower():
                if 'SQLite' not in databases_found: databases_found.append('SQLite')
            if 'frappe.db' in content.lower():
                if 'Frappe DB API' not in databases_found: databases_found.append('Frappe DB API')
                
            # Queue
            if 'celery' in content.lower() or 'pika' in content.lower() or 'rabbitmq' in content.lower():
                if 'Celery/RabbitMQ' not in queues_found: queues_found.append('Celery/RabbitMQ')
            if 'kafka' in content.lower():
                if 'Kafka' not in queues_found: queues_found.append('Kafka')
            if 'rq' in content.lower() or 'frappe.enqueue' in content.lower():
                if 'Python RQ (Redis Queue)' not in queues_found: queues_found.append('Python RQ (Redis Queue)')
                
            # Cache
            if 'redis' in content.lower() or 'frappe.cache' in content.lower():
                if 'Redis' not in caches_found: caches_found.append('Redis')
            if 'memcached' in content.lower():
                if 'Memcached' not in caches_found: caches_found.append('Memcached')
                
            # External APIs
            if 'shopify' in content.lower():
                if 'Shopify API' not in external_apis_found: external_apis_found.append('Shopify API')
            if 'stripe' in content.lower():
                if 'Stripe API' not in external_apis_found: external_apis_found.append('Stripe API')
            if 'slack' in content.lower():
                if 'Slack API' not in external_apis_found: external_apis_found.append('Slack API')
                
            # Authentication
            if 'jwt' in content.lower() or 'jsonwebtoken' in content.lower():
                if 'JWT (JSON Web Tokens)' not in auth_found: auth_found.append('JWT (JSON Web Tokens)')
            if 'oauth' in content.lower():
                if 'OAuth 2.0' not in auth_found: auth_found.append('OAuth 2.0')
            if 'session' in content.lower() or 'cookie' in content.lower():
                if 'Session-based Auth' not in auth_found: auth_found.append('Session-based Auth')
        except Exception:
            pass

# Fallbacks if scans are empty
if not databases_found and "$DB_ENGINE" != "None detected":
    databases_found.append("$DB_ENGINE")

# Format paths helpers
def format_paths(paths):
    if not paths:
        return "  └── None detected"
    dirs = sorted(list(set([str(p.parent) for p in paths if p.parent != Path('.')])))
    files = sorted([str(p) for p in paths])
    
    lines = []
    if dirs:
        lines.append("  ├── **Directories**: " + ", ".join(dirs[:5]))
    if files:
        lines.append("  └── **Files**: " + ", ".join([os.path.basename(f) for f in files[:10]]))
    return "\n".join(lines)

def format_simple_list(lst, default="None explicitly configured"):
    if not lst:
        return f"  └── {default}"
    return "\n".join([f"  └── {item}" if idx == len(lst)-1 else f"  ├── {item}" for idx, item in enumerate(lst)])

# Graphify community or node info if available
graphify_summary = ""
if nodes:
    communities = {}
    for n in nodes:
        comm = n.get('community', 'Unassigned')
        label = n.get('label', '')
        if comm != 'Unassigned':
            if comm not in communities:
                communities[comm] = []
            if len(communities[comm]) < 5:
                communities[comm].append(label)
                
    graphify_summary = "\n## Graphify Knowledge Graph Insights\n"
    graphify_summary += f"- **Total Concept Nodes**: {len(nodes)}\n"
    graphify_summary += f"- **Relations (Edges)**: {len(links)}\n"
    graphify_summary += "- **Key Code Communities / Micro-systems**:\n"
    for comm_id, members in sorted(communities.items())[:5]:
        graphify_summary += f"  - **Community #{comm_id}**: {', '.join(members)}\n"

# Construct final markdown
markdown = f"""# Project Architecture Overview

Generated: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Target Project: {project_dir.resolve()}

## Project Architecture Map

Project
│
├── API / Controllers / Routes
{format_paths(api_controllers_routes)}
│
├── Business Logic / Services / Models
{format_paths(business_logic_models)}
│
├── Database
{format_simple_list(databases_found)}
│
├── Queue
{format_simple_list(queues_found)}
│
├── Cache
{format_simple_list(caches_found)}
│
├── External APIs
{format_simple_list(external_apis_found)}
│
└── Authentication
{format_simple_list(auth_found)}

{graphify_summary}
## Architectural Principles
1. **Modular Design**: Keep core domain business logic decoupled from transport/presentation layers.
2. **Service Layer**: Move complex logic from controllers or routing handlers into dedicated service or domain modules.
3. **Immutability & Safety**: Minimize unexpected side effects. Validate inputs strictly at system boundaries.
4. **Graphify Alignment**: Consult \`graphify-out/graph.json\` before modifying core shared components.
"""

doc_path.write_text(markdown)
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
    if [[ "$TEST_FRAMEWORK" != "None detected" ]]; then
        success "Existing testing framework ($TEST_FRAMEWORK) is already configured. Skipping scaffolding."
        return
    fi

    if [[ "$INIT_TESTS" != "true" ]]; then
        warn "No test suite is configured for this stack ($PROJECT_TYPE). To scaffold a default test suite, run the installer with --init-tests."
        return
    fi

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

    if [[ ! -s "$DEVMIND_MEMORY_DIR/decisions.md" ]]; then
        cat > "$DEVMIND_MEMORY_DIR/decisions.md" <<'EOF'
# Architecture & Design Decisions

This document records the major architectural choices made in the project.

## Decision Log

### 1. Unified DevMind CLI & Operating Framework
- **Date**: 2026-08-01
- **Decision**: Implemented `devmind` CLI v3.0.0 for environment diagnostics, context refresh (`devmind sync`), task planning, impact analysis, security auditing, and ADR tracking.
- **Reason**: Standardizes AI context retrieval and enforces engineering safety guardrails.
- **Status**: Accepted
EOF
    fi

    [[ -f "$DEVMIND_MEMORY_DIR/known-issues.md" ]] || touch "$DEVMIND_MEMORY_DIR/known-issues.md"
    [[ -f "$DEVMIND_MEMORY_DIR/failed-attempts.md" ]] || touch "$DEVMIND_MEMORY_DIR/failed-attempts.md"

    if [[ ! -s "$DEVMIND_MEMORY_DIR/project-history.md" ]]; then
        cat > "$DEVMIND_MEMORY_DIR/project-history.md" <<'EOF'
# Project Evolution History

This document records the chronological history of feature additions, refactoring, and major system changes.

## Evolution Log
EOF
    fi

    success "Configured Project Memory Layer (.devmind/memory/) & ADR Manager (docs/adr/)"
}

setup_git_hooks() {
    log "Configuring automated Git post-commit hooks..."
    local git_dir="$PROJECT_DIR/.git"
    if [[ -d "$git_dir" ]]; then
        local hook_file="$git_dir/hooks/post-commit"
        mkdir -p "$git_dir/hooks"
        
        local hook_result
        hook_result=$(HOOK_FILE="$hook_file" python3 << 'EOF'
import os
import re

hook_file = os.environ.get('HOOK_FILE')
hook_code = '''# >>> DEVMIND HOOK START >>>
# DevMind Git Post-Commit Hook
if [[ -z "$DEVMIND_COMMITTING" ]]; then
    export DEVMIND_COMMITTING=1
    COMMIT_MSG=$(git log -1 --pretty=%B)
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    DEVMIND_CMD="devmind"
    if ! command -v devmind &>/dev/null; then
        if [[ -f "./bin/devmind" ]]; then
            DEVMIND_CMD="python3 ./bin/devmind"
        elif [[ -f "$HOME/.local/bin/devmind" ]]; then
            DEVMIND_CMD="$HOME/.local/bin/devmind"
        else
            DEVMIND_CMD=""
        fi
    fi
    
    if [[ -n "$DEVMIND_CMD" ]]; then
        if [[ "$COMMIT_MSG" =~ ^[Rr]evert ]]; then
            $DEVMIND_CMD queue "REVERT [$COMMIT_HASH]: $COMMIT_MSG" >/dev/null 2>&1
        elif [[ "$COMMIT_MSG" =~ ^(feat|feature) ]]; then
            $DEVMIND_CMD queue "FEATURE [$COMMIT_HASH]: $COMMIT_MSG" >/dev/null 2>&1
        elif [[ "$COMMIT_MSG" =~ ^refactor ]]; then
            $DEVMIND_CMD queue "REFACTOR [$COMMIT_HASH]: $COMMIT_MSG" >/dev/null 2>&1
        elif [[ "$COMMIT_MSG" =~ ^fix ]]; then
            $DEVMIND_CMD queue "FIX [$COMMIT_HASH]: $COMMIT_MSG" >/dev/null 2>&1
        else
            $DEVMIND_CMD queue "CHORE [$COMMIT_HASH]: $COMMIT_MSG" >/dev/null 2>&1
        fi
        
        # Automatically process queue in the background
        $DEVMIND_CMD sync >/dev/null 2>&1 &
        
        echo -e "\\033[1;36m[DevMind INFO]\\033[0m Commit queued and AI memory sync started in background."
    fi
fi
# <<< DEVMIND HOOK END <<<'''

if not os.path.exists(hook_file):
    with open(hook_file, 'w') as f:
        f.write('#!/usr/bin/env bash\n' + hook_code + '\n')
    print('CREATED')
else:
    with open(hook_file, 'r') as f:
        content = f.read()
    
    start_marker = '# >>> DEVMIND HOOK START >>>'
    end_marker = '# <<< DEVMIND HOOK END <<<'
    if start_marker in content and end_marker in content:
        pattern = re.compile(rf'{re.escape(start_marker)}.*?{re.escape(end_marker)}', re.DOTALL)
        new_content = pattern.sub(hook_code, content)
        with open(hook_file, 'w') as f:
            f.write(new_content)
        print('UPDATED_MARKERS')
    elif 'devmind plan' in content:
        has_other_stuff = False
        lines = content.splitlines()
        for line in lines:
            line_strip = line.strip()
            if line_strip and not line_strip.startswith('#') and 'devmind' not in line_strip and 'DEVMIND' not in line_strip and 'git add' not in line_strip and 'git commit' not in line_strip and 'git diff' not in line_strip and 'git check-ignore' not in line_strip and line_strip != 'fi' and line_strip != 'then' and not line_strip.startswith('if'):
                has_other_stuff = True
                break
        if not has_other_stuff:
            with open(hook_file, 'w') as f:
                f.write('#!/usr/bin/env bash\n' + hook_code + '\n')
            print('OVERWRITTEN')
        else:
            content_cleaned = re.sub(r'if \[\[ -z "\$DEVMIND_COMMITTING" \]\]; then.*?fi', '', content, flags=re.DOTALL)
            content_cleaned = re.sub(r'# DevMind.*?\n', '', content_cleaned)
            content_cleaned = content_cleaned.strip() + '\n\n' + hook_code + '\n'
            with open(hook_file, 'w') as f:
                f.write(content_cleaned)
            print('REPLACED_OLD')
    else:
        new_content = content.strip() + '\n\n' + hook_code + '\n'
        with open(hook_file, 'w') as f:
            f.write(new_content)
        print('APPENDED')
EOF
)

        chmod +x "$hook_file"

        if [[ "$hook_result" == "CREATED" ]]; then
            success "Created new DevMind post-commit hook: $hook_file"
        elif [[ "$hook_result" == "UPDATED_MARKERS" ]]; then
            success "Updated DevMind hook markers in: $hook_file"
        elif [[ "$hook_result" == "OVERWRITTEN" ]]; then
            success "Overwrote old DevMind post-commit hook: $hook_file"
        elif [[ "$hook_result" == "REPLACED_OLD" ]]; then
            success "Replaced old inline DevMind hook and appended new markers to: $hook_file"
        else
            success "Appended DevMind hook to existing post-commit hook: $hook_file"
        fi
    else
        warn "No .git directory found at target path. Skipping Git hook configuration."
    fi
}

# Installs the DevMind Secret Guard as a git pre-push hook. It runs `devmind scan --pre-push`
# and blocks the push (non-zero exit) when secrets, .env files, DB dumps or AI chat history
# are found in the commits being pushed. Works for humans and AI agents alike.
setup_pre_push_hook() {
    log "Configuring DevMind Secret Guard (git pre-push hook)..."
    local git_dir="$PROJECT_DIR/.git"
    if [[ ! -d "$git_dir" ]]; then
        warn "No .git directory found at target path. Skipping Secret Guard hook."
        return 0
    fi
    mkdir -p "$git_dir/hooks"
    local hook_file="$git_dir/hooks/pre-push"

    local hook_result
    hook_result=$(HOOK_FILE="$hook_file" python3 << 'EOF'
import os, re

hook_file = os.environ['HOOK_FILE']
hook_code = r'''# >>> DEVMIND SECRET GUARD START >>>
# DevMind Secret Guard: blocks pushes that contain secrets / .env / DB dumps / AI chat history.
# Bypass for a single push (humans only, after checking): DEVMIND_SKIP_SECRET_SCAN=1 git push
# (POSIX sh on purpose: this block may be inserted into an existing #!/bin/sh hook.)
DEVMIND_PUSH_REFS="$(cat)"
DEVMIND_SCAN_CMD=""
if [ -f "./bin/devmind" ]; then
    DEVMIND_SCAN_CMD="python3 ./bin/devmind"
elif command -v devmind >/dev/null 2>&1; then
    DEVMIND_SCAN_CMD="devmind"
elif [ -f "$HOME/.local/bin/devmind" ]; then
    DEVMIND_SCAN_CMD="python3 $HOME/.local/bin/devmind"
fi
if [ -n "$DEVMIND_SCAN_CMD" ]; then
    if ! printf '%s\n' "$DEVMIND_PUSH_REFS" | $DEVMIND_SCAN_CMD scan --pre-push; then
        printf '\033[1;31m[DevMind Secret Guard]\033[0m Push blocked. Fix the items above and push again.\n' >&2
        exit 1
    fi
else
    printf '\033[1;33m[DevMind Secret Guard]\033[0m devmind CLI not found, secret scan SKIPPED. Run setup-ai-project.sh to install it.\n' >&2
fi
# Restore stdin for any hook code that follows this block.
exec 0<<DEVMIND_REFS_EOF
$DEVMIND_PUSH_REFS
DEVMIND_REFS_EOF
# <<< DEVMIND SECRET GUARD END <<<'''

start, end = '# >>> DEVMIND SECRET GUARD START >>>', '# <<< DEVMIND SECRET GUARD END <<<'
if not os.path.exists(hook_file):
    with open(hook_file, 'w') as f:
        f.write('#!/usr/bin/env bash\n' + hook_code + '\n')
    print('CREATED')
else:
    content = open(hook_file).read()
    if start in content and end in content:
        content = re.sub(rf'{re.escape(start)}.*?{re.escape(end)}', lambda _: hook_code, content, flags=re.DOTALL)
        print('UPDATED')
    else:
        # Insert right after the shebang so our block reads the ref list from stdin first.
        lines = content.splitlines(keepends=True)
        if lines and lines[0].startswith('#!'):
            content = lines[0] + hook_code + '\n' + ''.join(lines[1:])
        else:
            content = '#!/usr/bin/env bash\n' + hook_code + '\n' + content
        print('PREPENDED')
    with open(hook_file, 'w') as f:
        f.write(content)
EOF
)
    chmod +x "$hook_file"
    case "$hook_result" in
        CREATED)   success "Created DevMind Secret Guard pre-push hook: $hook_file" ;;
        UPDATED)   success "Updated DevMind Secret Guard pre-push hook: $hook_file" ;;
        *)         success "Added DevMind Secret Guard to existing pre-push hook: $hook_file" ;;
    esac
}

# Links DevMind's own first-party skills (skills/ in the DevMind source repo) into the project.
map_devmind_skills() {
    local src_dir="$SCRIPT_SOURCE_DIR/skills"
    [[ -d "$src_dir" ]] || return 0
    mkdir -p "$SKILLS_DIR"
    local skill_dir name target mapped=0
    for skill_dir in "$src_dir"/*/; do
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        name="$(basename "$skill_dir")"
        target="$SKILLS_DIR/$name"
        if [[ -L "$target" ]]; then
            rm -f "$target"
        elif [[ -e "$target" ]]; then
            warn "Local custom skill '$name' already exists. Preserving it."
            continue
        fi
        ln -s "${skill_dir%/}" "$target"
        mapped=$((mapped + 1))
    done
    success "Mapped $mapped DevMind skills (secret-guard, ...)"
}

###############################################################################
# 5. Specialized AI Agents Generator (.agents/agents/)
###############################################################################

generate_specialized_agents() {
    log "Generating Specialized AI Agent Personas in .agents/agents/..."

    mkdir -p "$AGENTS_AGENTS_DIR"
    
    # Clear any old agent files to avoid residues
    rm -f "$AGENTS_AGENTS_DIR"/*.md

    local is_frappe=false
    if [[ "$PROJECT_TYPE" == *"Frappe"* ]] || [[ "$TECH_STACK" == *"Frappe"* ]]; then
        is_frappe=true
    fi

    if [[ "$is_frappe" == "true" ]]; then
        # Architect (Frappe Specialist)
        cat > "$AGENTS_AGENTS_DIR/architect.md" <<'EOF'
# Role: System Architect Agent (Frappe Specialist)
**Objective**: High-level system design, dependency analysis, and refactoring planning for Frappe applications.

## Guidelines:
1. Always align designs with the Frappe Framework architecture (sites, apps, DocTypes, hooks, and background workers).
2. Ensure custom modules use Frappe's native extension mechanisms (e.g. `fixtures`, `custom fields`, and `property setters`) instead of altering core Frappe/ERPNext code.
3. Validate integrations against standard DocType schema conventions.
EOF

        # Frappe Developer
        cat > "$AGENTS_AGENTS_DIR/frappe-developer.md" <<'EOF'
# Role: Frappe Developer Agent
**Objective**: Build robust Frappe backend APIs, Whitelisted functions, and server-side controller scripts.

## Guidelines:
1. Use `frappe.whitelist()` for client-accessible functions, enforcing correct authorization (e.g. `allow_guest=False` unless explicitly public).
2. Implement hooks (`doc_events`, `override_doctype_class`, etc.) in `hooks.py` for decoupled event-driven logic.
3. Use Frappe's ORM helper functions (`frappe.get_doc`, `frappe.get_all`, `frappe.db.set_value`) instead of raw SQL queries where possible.
EOF

        # ERPNext Developer
        cat > "$AGENTS_AGENTS_DIR/erpnext-developer.md" <<'EOF'
# Role: ERPNext Developer Agent
**Objective**: Build and extend business processes, accounting workflows, stock operations, and CRM cycles in the ERPNext ecosystem.

## Guidelines:
1. Adhere to ERPNext standards for naming, accounting principles, inventory entries, and document states.
2. Utilize standard patterns for invoice processing, stock reconciliation, and customer relationship management.
3. Always verify changes against standard tax rules and multi-currency formats.
EOF

        # DocType Expert
        cat > "$AGENTS_AGENTS_DIR/doctype-expert.md" <<'EOF'
# Role: DocType Expert Agent
**Objective**: DocType schema design, JSON configuration updates, and metadata integrity.

## Guidelines:
1. Define custom fields, permissions (User Permissions, Role Permissions), and naming series via the DocType UI or fixtures.
2. Ensure JSON configuration files under doctype folders match database schema requirements.
3. Handle schema migrations safely using Bench migration tools.
EOF

        # Bench Expert
        cat > "$AGENTS_AGENTS_DIR/bench-expert.md" <<'EOF'
# Role: Bench CLI & Migration Expert Agent
**Objective**: Site setup, multi-tenant configs, Bench operations, and deployment automation.

## Guidelines:
1. Always run `bench migrate` to update schema definitions, custom fields, and fixtures.
2. Monitor Redis cache/socketio states and Celery background workers.
3. Use Bench utilities (`bench clear-cache`, `bench restart`) for zero-downtime hot-reloads.
EOF

        # Security Reviewer (Frappe Specialist)
        cat > "$AGENTS_AGENTS_DIR/security-reviewer.md" <<'EOF'
# Role: Security Reviewer Agent (Frappe Specialist)
**Objective**: Identify vulnerabilities, credential leaks, and permission bypasses in Frappe apps.

## Guidelines:
1. Ensure all whitelisted endpoints verify user permissions (`frappe.has_permission`).
2. Review custom SQL statements for SQL injection risks (always use placeholder params in `frappe.db.sql`).
3. Verify CSRF token validation and XSS prevention in Jinja/HTML templates.
EOF

        # Code Reviewer (Frappe Specialist)
        cat > "$AGENTS_AGENTS_DIR/code-reviewer.md" <<'EOF'
# Role: Code Reviewer Agent (Frappe Specialist)
**Objective**: Enforce clean code, Frappe standards, and framework-level best practices.

## Guidelines:
1. Ensure files follow PEP 8 standards and Frappe's file structural patterns.
2. Discourage direct database mutations; enforce using the DocType controller lifecycle methods (`before_insert`, `on_update`, etc.).
3. Promote efficient queries using `frappe.get_all` with minimal fields instead of `frappe.get_list` or raw SQL.
EOF

        # Test Engineer (Frappe Specialist)
        cat > "$AGENTS_AGENTS_DIR/test-engineer.md" <<'EOF'
# Role: Test Engineer Agent (Frappe Specialist)
**Objective**: Write Unit and Integration tests using the Frappe test framework.

## Guidelines:
1. Run tests using `bench run-tests --app <app_name>`.
2. Mock external HTTP requests or third-party connections using standard unittest mocking.
3. Use Frappe's test runner to seed mock DocType instances and clean up transactions after each test run.
EOF

        success "Created 8 specialized Frappe AI Agent personas in .agents/agents/"
    else
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
**Objective**: Write Unit and Integration test cases.

## Guidelines:
1. Follow Test-Driven Development (TDD) principles.
2. Ensure test coverage for critical business logic paths.
3. Verify tests pass cleanly before completing tasks.
EOF

        success "Created 7 specialized AI Agent personas in .agents/agents/"
    fi
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
    Plan --> ADR["Create ADR Record"]
    ADR --> Approve{"User Approval"}
    Approve -- Yes --> TDD["Write Tests (TDD)"]
    TDD --> Code["Implement Feature"]
    Code --> Test["Run Tests & Verification"]
    Test --> Review["Code Review"]
    Review --> GraphRebuild["Rebuild Graphify Graph"]
```

## Execution Steps:
1. Understand the goal & search for existing implementations.
2. Inspect codebase dependencies with Graphify.
3. Automatically create a new Architecture Decision Record (ADR) under `docs/adr/` (e.g. by running `devmind adr create "<title>"` or via VS Code sidebar) to document the decision context.
4. Present an implementation plan to the user.
5. Implement using small, safe changes.
6. Verify test pass and perform code review.
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
- Automatically create an Architecture Decision Record (ADR) under docs/adr/ when implementing new features or planning major changes.
- If you see the comment <!-- DEVMIND_PENDING_ADR_AI_POPULATION --> in a newly created ADR file under docs/adr/, you MUST automatically read the recent git commits/diffs, generate the Context, Decision, and Consequences, overwrite the placeholder sections in the ADR with the generated contents, and remove the comment.
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

get_profile_items() {
    local key="$1"
    local profile_file=""
    local candidate
    # A project-local profiles/<name>.yaml overrides the one shipped with DevMind
    for candidate in \
        "${PROJECT_DIR}/profiles/${PROFILE_NAME}.yaml" \
        "${SCRIPT_SOURCE_DIR}/profiles/${PROFILE_NAME}.yaml" \
        "${SCRIPT_SOURCE_DIR}/profiles/generic.yaml"; do
        if [[ -f "$candidate" ]]; then
            profile_file="$candidate"
            break
        fi
    done
    if [[ -z "$profile_file" ]]; then
        warn "No profile file found for '$PROFILE_NAME' (looked in $PROJECT_DIR/profiles and $SCRIPT_SOURCE_DIR/profiles)"
        return 0
    fi

    python3 - "$profile_file" "$key" <<'PY'
import sys
profile_file, wanted = sys.argv[1], sys.argv[2]
profile = {'skills': [], 'agents': [], 'rules': []}
current_key = None
with open(profile_file, 'r', encoding='utf-8') as f:
    for line in f:
        line = line.split('#', 1)[0].strip()
        if not line:
            continue
        if line.startswith('-'):
            val = line[1:].strip().strip('"').strip("'")
            if current_key and val:
                profile[current_key].append(val)
        elif ':' in line:
            k = line.split(':', 1)[0].strip()
            current_key = k if k in profile else None
for item in profile[wanted]:
    print(item)
PY
}

# Remove symlinks in $1 that point into the ECC / Frappe skill checkouts, so assets
# from a previous profile (or an older DevMind that linked everything) don't linger.
# Links pointing anywhere else are user-owned and preserved.
prune_managed_links() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    local link link_target
    while IFS= read -r -d '' link; do
        link_target="$(readlink "$link")"
        if [[ "$link_target" == "$ECC_DIR/"* || "$link_target" == "$FRAPPE_SKILLS_DIR/"* ]]; then
            rm -f "$link"
        fi
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type l -print0)
}

resolve_skill_dir() {
    local skill_name="$1" src
    for src in "${SKILL_SOURCE_DIRS[@]}"; do
        if [[ -d "$src/$skill_name" ]]; then
            echo "$src/$skill_name"
            return 0
        fi
    done
    return 1
}

map_ecc_skills() {
    mkdir -p "$SKILLS_DIR"
    log "Mapping ECC skills for profile '$PROFILE_NAME'..."
    prune_managed_links "$SKILLS_DIR"

    local skill_name skill_dir target mapped=0
    while read -r skill_name; do
        [[ -z "$skill_name" ]] && continue
        if ! skill_dir="$(resolve_skill_dir "$skill_name")"; then
            warn "Profile '$PROFILE_NAME' skill '$skill_name' not found in ECC or Frappe skills. Skipping."
            continue
        fi
        target="$SKILLS_DIR/$skill_name"
        if [[ -e "$target" || -L "$target" ]]; then
            warn "Local custom skill '$skill_name' already exists. Preserving it."
            continue
        fi
        ln -s "$skill_dir" "$target"
        mapped=$((mapped + 1))
    done < <(get_profile_items skills)

    success "Mapped $mapped ECC skills for profile '$PROFILE_NAME'"
}

# Profile rule entries may be:
#   common/testing  -> $ECC_DIR/rules/common/testing.md
#   php             -> every .md in $ECC_DIR/rules/php/
#   some-rule       -> $ECC_DIR/rules/some-rule.md (flat layout)
map_ecc_rules() {
    mkdir -p "$RULES_DIR"
    log "Mapping ECC rules for profile '$PROFILE_NAME'..."
    prune_managed_links "$RULES_DIR"

    local rule_name rule_file target mapped=0
    local -a rule_files
    while read -r rule_name; do
        [[ -z "$rule_name" ]] && continue
        rule_files=()
        if [[ -d "$ECC_DIR/rules/$rule_name" ]]; then
            while IFS= read -r -d '' rule_file; do
                rule_files+=("$rule_file")
            done < <(find "$ECC_DIR/rules/$rule_name" -maxdepth 1 -type f -name '*.md' -print0 | sort -z)
        elif [[ -f "$ECC_DIR/rules/$rule_name.md" ]]; then
            rule_files+=("$ECC_DIR/rules/$rule_name.md")
        else
            warn "Profile '$PROFILE_NAME' rule '$rule_name' not found in $ECC_DIR/rules. Skipping."
            continue
        fi
        for rule_file in "${rule_files[@]}"; do
            # common/testing.md -> ecc-common-testing.md (avoids common/php name clashes)
            target="$RULES_DIR/ecc-$(echo "${rule_file#"$ECC_DIR/rules/"}" | tr '/' '-')"
            [[ -e "$target" || -L "$target" ]] && rm -f "$target"
            ln -s "$rule_file" "$target"
            mapped=$((mapped + 1))
        done
    done < <(get_profile_items rules)

    success "Mapped $mapped ECC rules for profile '$PROFILE_NAME'"
}

map_ecc_agents() {
    mkdir -p "$AGENTS_AGENTS_DIR"
    if [[ ! -d "$ECC_DIR/agents" ]]; then
        return
    fi
    log "Mapping ECC agents for profile '$PROFILE_NAME'..."
    prune_managed_links "$AGENTS_AGENTS_DIR"

    local agent_name agent_file target mapped=0
    while read -r agent_name; do
        [[ -z "$agent_name" ]] && continue
        agent_file="$ECC_DIR/agents/$agent_name.md"
        if [[ ! -f "$agent_file" ]]; then
            warn "Profile '$PROFILE_NAME' agent '$agent_name' not found in $ECC_DIR/agents. Skipping."
            continue
        fi
        target="$AGENTS_AGENTS_DIR/ecc-$agent_name.md"
        [[ -e "$target" || -L "$target" ]] && rm -f "$target"
        ln -s "$agent_file" "$target"
        mapped=$((mapped + 1))
    done < <(get_profile_items agents)

    success "Mapped $mapped ECC agents for profile '$PROFILE_NAME'"
}

###############################################################################
# 8b. Claude Code Integration (CLAUDE.md, .claude/skills|agents|rules, .mcp.json)
#
# Claude Code does not read .agents/. It discovers:
#   - project memory from CLAUDE.md (and .claude/rules/*.md)
#   - skills from .claude/skills/<name>/SKILL.md
#   - subagents from .claude/agents/*.md (YAML frontmatter with name + description)
#   - project MCP servers from .mcp.json
###############################################################################

CLAUDE_MD_BEGIN="<!-- devmind:begin -->"
CLAUDE_MD_END="<!-- devmind:end -->"

# Mirror every entry of $1 into $2 as a symlink to the same place, after pruning
# links in $2 that DevMind manages (into ECC/Frappe, or back into .agents/).
mirror_into_claude() {
    local src_dir="$1" dest_dir="$2"
    mkdir -p "$dest_dir"
    prune_managed_links "$dest_dir"
    local link
    while IFS= read -r -d '' link; do
        [[ "$(readlink "$link")" == "$AGENTS_DIR/"* ]] && rm -f "$link"
    done < <(find "$dest_dir" -mindepth 1 -maxdepth 1 -type l -print0)

    [[ -d "$src_dir" ]] || return 0
    local entry name target resolved
    while IFS= read -r -d '' entry; do
        name="$(basename "$entry")"
        target="$dest_dir/$name"
        if [[ -e "$target" && ! -L "$target" ]]; then
            continue  # user-owned file/dir in .claude/ wins
        fi
        resolved="$entry"
        [[ -L "$entry" ]] && resolved="$(readlink "$entry")"
        rm -f "$target"
        ln -s "$resolved" "$target"
    done < <(find "$src_dir" -mindepth 1 -maxdepth 1 -print0)
}

# DevMind-generated personas are plain markdown; Claude Code subagents need
# frontmatter. Write a Claude-format copy for each generated persona, then link
# ECC agents whose name is not already taken by a project persona.
sync_claude_agents() {
    local dest="$CLAUDE_DIR/agents"
    mkdir -p "$dest"
    prune_managed_links "$dest"

    python3 - "$AGENTS_AGENTS_DIR" "$dest" <<'PY'
import re, sys
from pathlib import Path

src, dest = Path(sys.argv[1]), Path(sys.argv[2])
MARK = "<!-- generated by devmind -->"

# Drop previously generated copies so removed personas don't linger
for f in dest.glob("*.md"):
    if f.is_file() and not f.is_symlink() and MARK in f.read_text(encoding="utf-8", errors="ignore"):
        f.unlink()

if src.is_dir():
    for f in sorted(src.glob("*.md")):
        if f.is_symlink():
            continue  # ECC agents are linked separately below
        text = f.read_text(encoding="utf-8", errors="ignore")
        out = dest / f.name
        if out.exists() or out.is_symlink():
            continue  # user-owned agent wins
        if text.startswith("---"):
            out.write_text(text, encoding="utf-8")
            continue
        title = re.search(r"^#\s*Role:\s*(.+)$", text, re.M)
        objective = re.search(r"\*\*Objective\*\*:\s*(.+)$", text, re.M)
        desc = (objective.group(1) if objective else (title.group(1) if title else f.stem)).strip()
        desc = desc.replace('"', "'")
        out.write_text(
            f'---\nname: {f.stem}\ndescription: "{desc}"\n---\n{MARK}\n\n{text}',
            encoding="utf-8",
        )
PY

    local link agent_file name
    while IFS= read -r -d '' link; do
        agent_file="$(readlink "$link")"
        name="$(basename "$agent_file")"
        [[ -e "$dest/$name" || -L "$dest/$name" ]] && continue
        ln -s "$agent_file" "$dest/$name"
    done < <(find "$AGENTS_AGENTS_DIR" -mindepth 1 -maxdepth 1 -type l -name 'ecc-*.md' -print0 2>/dev/null)
}

write_claude_md() {
    local claude_md="$PROJECT_DIR/CLAUDE.md"
    local block
    block="$(cat <<EOF
$CLAUDE_MD_BEGIN
## DevMind Project Context (auto-generated — edit outside this block)

@.agents/AGENTS.md

- Stack profile: \`$PROFILE_NAME\` ($PROJECT_TYPE)
- Architecture: @ARCHITECTURE.md
- Database: @DATABASE.md
- Security: @SECURITY.md
- Project memory: \`.devmind/memory/\` · ADRs: \`docs/adr/\`
- Knowledge graph: \`graphify-out/graph.json\` (report: \`graphify-out/GRAPH_REPORT.md\`). Prefer the \`graphify\` MCP tools for dependency questions; run \`graphify update .\` after structural changes.
$CLAUDE_MD_END
EOF
)"

    CLAUDE_MD="$claude_md" BLOCK="$block" BEGIN="$CLAUDE_MD_BEGIN" END="$CLAUDE_MD_END" python3 - <<'PY'
import os, re
path, block = os.environ["CLAUDE_MD"], os.environ["BLOCK"]
begin, end = os.environ["BEGIN"], os.environ["END"]
text = open(path, encoding="utf-8").read() if os.path.exists(path) else "# CLAUDE.md\n"
pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.S)
if pattern.search(text):
    text = pattern.sub(lambda _: block, text)
else:
    text = text.rstrip("\n") + "\n\n" + block + "\n"
open(path, "w", encoding="utf-8").write(text)
PY
}

configure_claude_code() {
    log "Configuring Claude Code integration (CLAUDE.md, .claude/, .mcp.json)..."

    mirror_into_claude "$SKILLS_DIR" "$CLAUDE_DIR/skills"
    mirror_into_claude "$RULES_DIR" "$CLAUDE_DIR/rules"
    sync_claude_agents
    write_claude_md

    success "Claude Code: $(find "$CLAUDE_DIR/skills" -mindepth 1 -maxdepth 1 | wc -l) skills, $(find "$CLAUDE_DIR/agents" -mindepth 1 -maxdepth 1 | wc -l) agents, $(find "$CLAUDE_DIR/rules" -mindepth 1 -maxdepth 1 | wc -l) rules linked; CLAUDE.md updated"
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
    if [[ "${DEVMIND_SKIP_GRAPH:-}" == "1" ]]; then
        log "Skipping Graphify rebuild (DEVMIND_SKIP_GRAPH=1, graph managed by devmind sync)"
        return
    fi
    log "Building Graphify knowledge graph..."

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
            success "Project Graphify knowledge graph generated"
        else
            warn "Full Graphify extraction failed (likely no API key). Falling back to offline AST code-only update..."
            if graphify update .; then
                success "Project Graphify knowledge-only graph generated successfully"
            else
                warn "Graphify CLI returned an error. Run manually: graphify update ."
            fi
        fi
        # GRAPH_REPORT.md is what Claude's graphify skill reads first; cluster-only builds it without an LLM
        if [[ -f "$GRAPHIFY_OUTPUT_DIR/graph.json" && ! -f "$GRAPHIFY_OUTPUT_DIR/GRAPH_REPORT.md" ]]; then
            graphify cluster-only . --no-label --no-viz >/dev/null 2>&1 \
                && success "Generated graphify-out/GRAPH_REPORT.md" \
                || warn "Could not generate GRAPH_REPORT.md. Run manually: graphify cluster-only ."
        fi
        log "Generating interactive HTML graph visualizer (graphify-out/graph.html)..."
        local html_out
        if html_out=$(python3 "$PROJECT_DIR/generate_graph_html.py" "$PROJECT_DIR" 2>&1); then
            success "Generated HTML visualizer: graphify-out/graph.html"
        else
            warn "HTML visualizer failed: $(echo "$html_out" | tail -n 1)"
        fi
    else
        warn "Graphify CLI unavailable."
    fi
}

initialize_context_manifest() {
    mkdir -p "${PROJECT_DIR}/.devmind"
    local manifest="${PROJECT_DIR}/.devmind/context.json"
    log "Initializing DevMind Context Manifest ($manifest)..."

    local current_commit="unknown"
    if command -v git >/dev/null 2>&1 && [[ -d "${PROJECT_DIR}/.git" ]]; then
        current_commit=$(git -C "${PROJECT_DIR}" rev-parse HEAD 2>/dev/null || echo "unknown")
    fi

    local arch_hash=""
    local db_hash=""
    if command -v sha256sum >/dev/null 2>&1; then
        [[ -f "${PROJECT_DIR}/ARCHITECTURE.md" ]] && arch_hash=$(sha256sum "${PROJECT_DIR}/ARCHITECTURE.md" | awk '{print $1}')
        [[ -f "${PROJECT_DIR}/DATABASE.md" ]] && db_hash=$(sha256sum "${PROJECT_DIR}/DATABASE.md" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        [[ -f "${PROJECT_DIR}/ARCHITECTURE.md" ]] && arch_hash=$(shasum -a 256 "${PROJECT_DIR}/ARCHITECTURE.md" | awk '{print $1}')
        [[ -f "${PROJECT_DIR}/DATABASE.md" ]] && db_hash=$(shasum -a 256 "${PROJECT_DIR}/DATABASE.md" | awk '{print $1}')
    fi

    local stack_json="[]"
    if [[ "$PROJECT_TYPE" == *"Frappe"* ]]; then
        stack_json='["Python", "Frappe Framework", "ERPNext"]'
    elif [[ "$PROJECT_TYPE" == *"Laravel"* ]]; then
        stack_json='["PHP", "Laravel"]'
    elif [[ "$PROJECT_TYPE" == *"Django"* ]]; then
        stack_json='["Python", "Django"]'
    elif [[ "$PROJECT_TYPE" == *"FastAPI"* ]]; then
        stack_json='["Python", "FastAPI"]'
    elif [[ "$PROJECT_TYPE" == *"Next.js"* ]]; then
        stack_json='["Node.js", "Next.js", "React"]'
    elif [[ "$PROJECT_TYPE" == *"React"* ]]; then
        stack_json='["Node.js", "React"]'
    elif [[ "$PROJECT_TYPE" == *"Node.js"* ]]; then
        stack_json='["Node.js"]'
    else
        stack_json='["Generic"]'
    fi

    cat > "$manifest" <<EOF
{
  "stack": $stack_json,
  "last_sync_commit": "$current_commit",
  "graph_generated_at": "$(date '+%Y-%m-%d %H:%M:%S')",
  "architecture_hash": "$arch_hash",
  "database_hash": "$db_hash"
}
EOF
    success "Initialized Context Manifest"
}

detect_active_editor() {
    if [[ -n "${ANTIGRAVITY_AGENT:-}" || -n "${ANTIGRAVITY_EDITOR_APP_ROOT:-}" || "${CHROME_DESKTOP:-}" == *"antigravity"* || "${GIO_LAUNCHED_DESKTOP_FILE:-}" == *"antigravity"* ]]; then
        echo "antigravity"
    elif [[ -n "${CURSOR_AGENT:-}" || -n "${CURSOR_APP_ROOT:-}" || "${TERM_PROGRAM:-}" == "cursor" || -n "${CURSOR_TRACE_ID:-}" ]]; then
        echo "cursor"
    elif [[ -n "${VSCODE_PID:-}" || "${TERM_PROGRAM:-}" == "vscode" ]]; then
        echo "vscode"
    else
        echo "cli"
    fi
}

configure_graphify_mcp() {
    local active_editor
    active_editor="$(detect_active_editor)"
    log "Configuring Graphify MCP servers for detected editor: ${active_editor}..."

    # 1. Antigravity/Gemini configs (workspace-relative paths)
    local relative_configs=(
        "${HOME}/.gemini/config/mcp_config.json"
        "${HOME}/.gemini/antigravity/mcp_config.json"
        "${HOME}/.gemini/antigravity-ide/mcp_config.json"
    )

    # 2. Other IDEs / Clients (absolute paths)
    local absolute_configs=()

    # Cursor MCP config: ONLY if running under Cursor OR if .cursor directory was explicitly created in the project
    if [[ "$active_editor" == "cursor" ]]; then
        absolute_configs+=("${PROJECT_DIR}/.cursor/mcp.json")
        if [[ -d "${HOME}/.cursor" ]]; then
            absolute_configs+=("${HOME}/.cursor/mcp.json")
        fi
    elif [[ -d "${PROJECT_DIR}/.cursor" && "$active_editor" != "antigravity" ]]; then
        absolute_configs+=("${PROJECT_DIR}/.cursor/mcp.json")
    fi

    # VS Code MCP config: ONLY if running under VS Code OR if .vscode directory exists in the project
    if [[ "$active_editor" == "vscode" ]]; then
        absolute_configs+=("${PROJECT_DIR}/.vscode/mcp.json")
    elif [[ -d "${PROJECT_DIR}/.vscode" && "$active_editor" != "antigravity" ]]; then
        absolute_configs+=("${PROJECT_DIR}/.vscode/mcp.json")
    fi

    # OS-specific paths for Claude Desktop, Cline, and Roo Code (only if installed and not running under Antigravity/Cursor)
    if [[ "$active_editor" == "cli" || "$active_editor" == "vscode" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            absolute_configs+=(
                "${HOME}/Library/Application Support/Claude/claude_desktop_config.json"
                "${HOME}/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
                "${HOME}/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json"
            )
        else
            absolute_configs+=(
                "${HOME}/.config/Claude/claude_desktop_config.json"
                "${HOME}/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
                "${HOME}/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json"
            )
        fi
    fi

    # Claude Code (CLI + VS Code extension): project-scoped servers live in .mcp.json
    absolute_configs+=("${PROJECT_DIR}/.mcp.json")

    local configured_any=false

    # Helper function to inject Graphify configuration into an MCP settings file
    write_mcp_config() {
        local path="$1"
        local is_rel="$2"
        local parent_dir
        parent_dir="$(dirname "$path")"

        # Only create/write if:
        # - It is a relative config (always created for Antigravity)
        # - The parent directory already exists on the user's system (global/local config for an installed app)
        if [[ "$is_rel" = "true" || -d "$parent_dir" ]]; then
            mkdir -p "$parent_dir"

            if [[ ! -f "$path" || ! -s "$path" ]]; then
                cat > "$path" <<'EOF'
{
  "mcpServers": {}
}
EOF
            fi

            if python3 - "$path" "$PROJECT_DIR" "$is_rel" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
project_dir = sys.argv[2]
is_relative = sys.argv[3].lower() == "true"

try:
    with config_path.open("r", encoding="utf-8") as f:
        config = json.load(f)
except Exception:
    config = {}

if not isinstance(config, dict):
    config = {}

if "mcpServers" not in config:
    config["mcpServers"] = {}

graph_path = "${workspace.path}/graphify-out/graph.json" if is_relative else str(Path(project_dir) / "graphify-out" / "graph.json")

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
        graph_path
    ]
}

with config_path.open("w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print("Success")
PY
            then
                success "Graphify MCP configured at $path"
                configured_any=true
            else
                warn "Failed to configure Graphify MCP at $path"
            fi
        fi
    }

    # Process relative configs
    for path in "${relative_configs[@]}"; do
        write_mcp_config "$path" "true"
    done

    # Process absolute configs
    for path in "${absolute_configs[@]}"; do
        write_mcp_config "$path" "false"
    done

    if [[ "$configured_any" = true ]]; then
        success "Graphify MCP configured successfully across available environments"
    else
        die "Failed to configure Graphify MCP in any configuration path"
    fi
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

## Claude Code
- Profile: $PROFILE_NAME
- CLAUDE.md imports .agents/AGENTS.md
- Skills: $(find "$CLAUDE_DIR/skills" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l) · Agents: $(find "$CLAUDE_DIR/agents" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l) · Rules: $(find "$CLAUDE_DIR/rules" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
- Graphify MCP: .mcp.json (approve the server when Claude Code first asks)
EOF

    success "Created AI_SETUP.md"
}

update_gitignore() {
    local gitignore="$PROJECT_DIR/.gitignore"
    log "Updating .gitignore to exclude DevMind metadata and assets..."

    # Ensure .gitignore exists
    touch "$gitignore"

    local gitignore_result
    gitignore_result=$(GITIGNORE_PATH="$gitignore" python3 -c "
import os

gitignore_path = os.environ.get('GITIGNORE_PATH')
if os.path.exists(gitignore_path):
    with open(gitignore_path, 'r', errors='ignore') as f:
        content = f.read()
    
    required_ignores = [
        '.agents/',
        '.devmind/',
        'AI_SETUP.md',
        'ARCHITECTURE.md',
        'DATABASE.md',
        'SECURITY.md',
        'generate_graph_html.py',
        'bin/devmind',
        'pytest.ini',
        'tests/test_example.py',
        'phpunit.xml',
        'tests/ExampleTest.php',
        'jest.config.js',
        'tests/example.test.js',
        'graphify-out/',
        '.mcp.json',
        '.claude/skills/',
        '.claude/agents/',
        '.claude/rules/'
    ]
    
    lines = content.splitlines()
    existing_ignores = {line.strip() for line in lines if line.strip() and not line.strip().startswith('#')}
    
    missing_ignores = [pattern for pattern in required_ignores if pattern not in existing_ignores]
    
    if missing_ignores:
        new_content = content
        if new_content and not new_content.endswith('\n'):
            new_content += '\n'
        new_content += '\n# DevMind AI Project Operating System & Generated Context\n'
        for pattern in missing_ignores:
            new_content += f'{pattern}\n'
        with open(gitignore_path, 'w') as f:
            f.write(new_content)
        print('ADDED_IGNORES')
    else:
        print('UP_TO_DATE')
" 2>/dev/null)

    if [[ "$gitignore_result" == *"ADDED_IGNORES"* ]]; then
        success "Added missing ignore patterns to .gitignore"
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
    setup_git_hooks
    setup_pre_push_hook
    update_gitignore

    # 5. Agent Personas & Workflows Generator
    generate_specialized_agents
    generate_workflows
    generate_rules

    # 6. Symlink ECC System Assets
    map_ecc_skills
    map_devmind_skills
    map_ecc_rules
    map_ecc_agents

    # 7. Operating Manual & Integration
    create_agents_manifest
    configure_claude_code
    build_graphify_graph
    initialize_context_manifest
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
