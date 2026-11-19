import * as fs from 'fs';
import * as path from 'path';

/**
 * Installs the skills and agents bundled inside the VSIX (resources/skills/<name>/, resources/agents/<name>.md)
 * into a project, as listed in resources/manifest.json:
 *   skills -> .agents/skills/<name>/  and  .claude/skills/<name>/
 *   agents -> .agents/agents/<name>.md and .claude/agents/<name>.md
 * Each entry has a `when` condition: always | frappe | codeigniter-phppos.
 *
 * Kept free of any `vscode` import so it can be unit-tested with plain Node.
 *
 * Overwrite policy for an existing target:
 *   - symlink (created by setup-ai-project.sh)              -> left alone
 *   - managed copy (origin DevMind) with an older version   -> updated
 *   - anything else (user-customised, origin custom, ...)   -> left alone
 */

export const SKILL_TARGET_DIRS = ['.agents/skills', '.claude/skills'];
export const AGENT_TARGET_DIRS = ['.agents/agents', '.claude/agents'];

export type SkillInstallAction = 'created' | 'updated' | 'unchanged' | 'kept-custom' | 'kept-symlink';
export type InstallCondition = 'always' | 'frappe' | 'codeigniter-phppos';

export interface SkillInstallResult {
    kind: 'skill' | 'agent';
    skill: string;
    target: string;
    action: SkillInstallAction;
}

interface Manifest {
    skills?: Record<string, { when?: InstallCondition }>;
    agents?: Record<string, { when?: InstallCondition }>;
}

// ---------------------------------------------------------------------------
// Project detection
// ---------------------------------------------------------------------------

const SCAN_SKIP = new Set(['node_modules', '.git', 'env', 'venv', '.venv', 'sites', 'logs', '__pycache__',
    'dist', 'build', 'assets', 'vendor', '.agents', '.claude', '.devmind', 'graphify-out']);

/** A Frappe app package has hooks.py next to modules.txt (same rule as `devmind` has_frappe_app). */
export function isFrappeProject(root: string, maxDepth = 4, maxDirs = 4000): boolean {
    let visited = 0;
    const walk = (dir: string, depth: number): boolean => {
        if (++visited > maxDirs) { return false; }
        let entries: fs.Dirent[];
        try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return false; }
        const names = new Set(entries.filter(e => e.isFile()).map(e => e.name));
        if (names.has('hooks.py') && names.has('modules.txt')) { return true; }
        if (depth >= maxDepth) { return false; }
        for (const e of entries) {
            if (e.isDirectory() && !SCAN_SKIP.has(e.name) && !e.name.endsWith('-env') && !e.name.startsWith('.')) {
                if (walk(path.join(dir, e.name), depth + 1)) { return true; }
            }
        }
        return false;
    };
    return walk(root, 0);
}

/** CodeIgniter POS (Sundora / pos/* clients): application/config/database.php with the phppos_ prefix. */
export function isCodeIgniterPhpposProject(root: string): boolean {
    const cfg = path.join(root, 'application', 'config', 'database.php');
    try {
        return /\[['"]dbprefix['"]\]\s*=\s*['"]phppos_['"]/.test(fs.readFileSync(cfg, 'utf8'));
    } catch {
        return false;
    }
}

export function conditionMet(when: InstallCondition | undefined, root: string, cache: Map<string, boolean>): boolean {
    const w = when || 'always';
    if (w === 'always') { return true; }
    if (!cache.has(w)) {
        cache.set(w, w === 'frappe' ? isFrappeProject(root) : w === 'codeigniter-phppos' ? isCodeIgniterPhpposProject(root) : false);
    }
    return cache.get(w)!;
}

// ---------------------------------------------------------------------------
// Version / origin markers
// ---------------------------------------------------------------------------

function readFrontmatterField(content: string, field: string): string | undefined {
    const fm = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
    if (!fm) { return undefined; }
    const m = fm[1].match(new RegExp(`^\\s*${field}:\\s*(.+?)\\s*$`, 'm'));
    return m ? m[1].replace(/^['"]|['"]$/g, '') : undefined;
}

/** Skills: `metadata: origin/version` in the frontmatter. Agents: `<!-- devmind-managed: origin=X version=N -->`. */
function managedInfo(content: string, kind: 'skill' | 'agent'): { origin?: string; version: number } {
    if (kind === 'agent') {
        const m = content.match(/<!--\s*devmind-managed:\s*origin=(\S+)\s+version=(\d+)/);
        return m ? { origin: m[1], version: parseInt(m[2], 10) } : { version: 0 };
    }
    const v = parseInt(readFrontmatterField(content, 'version') || '0', 10);
    return { origin: readFrontmatterField(content, 'origin'), version: Number.isFinite(v) ? v : 0 };
}

function copyDir(src: string, dest: string): void {
    fs.mkdirSync(dest, { recursive: true });
    for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
        const s = path.join(src, entry.name);
        const d = path.join(dest, entry.name);
        if (entry.isDirectory()) {
            copyDir(s, d);
        } else if (entry.isFile()) {
            fs.copyFileSync(s, d);
        }
    }
}

function decide(kind: 'skill' | 'agent', bundledContent: string, targetPath: string, markerFile: string): SkillInstallAction | 'write' {
    let lst: fs.Stats | undefined;
    try { lst = fs.lstatSync(targetPath); } catch { lst = undefined; }
    if (!lst) { return 'write'; }
    if (lst.isSymbolicLink()) { return 'kept-symlink'; }
    const existing = fs.existsSync(markerFile) ? fs.readFileSync(markerFile, 'utf8') : '';
    if (!existing) { return 'write'; }
    const have = managedInfo(existing, kind);
    if (have.origin !== 'DevMind') { return 'kept-custom'; }
    return have.version < managedInfo(bundledContent, kind).version ? 'write' : 'unchanged';
}

// ---------------------------------------------------------------------------
// Installer
// ---------------------------------------------------------------------------

/**
 * @param resourcesDir the extension's resources/ folder (contains manifest.json, skills/, agents/)
 */
export function installBundledAssets(resourcesDir: string, projectRoot: string): SkillInstallResult[] {
    const results: SkillInstallResult[] = [];
    const skillsDir = path.join(resourcesDir, 'skills');
    const agentsDir = path.join(resourcesDir, 'agents');
    let manifest: Manifest = {};
    try {
        manifest = JSON.parse(fs.readFileSync(path.join(resourcesDir, 'manifest.json'), 'utf8'));
    } catch {
        // No manifest (older layout): install every bundled skill, always.
        const names = fs.existsSync(skillsDir) ? fs.readdirSync(skillsDir) : [];
        manifest = { skills: Object.fromEntries(names.map(n => [n, { when: 'always' as InstallCondition }])) };
    }
    const cache = new Map<string, boolean>();

    for (const [name, spec] of Object.entries(manifest.skills || {})) {
        const srcDir = path.join(skillsDir, name);
        const srcSkill = path.join(srcDir, 'SKILL.md');
        if (!fs.existsSync(srcSkill) || !conditionMet(spec.when, projectRoot, cache)) { continue; }
        const bundled = fs.readFileSync(srcSkill, 'utf8');
        for (const rel of SKILL_TARGET_DIRS) {
            const destDir = path.join(projectRoot, rel, name);
            const d = decide('skill', bundled, destDir, path.join(destDir, 'SKILL.md'));
            let action: SkillInstallAction;
            if (d === 'write') {
                const existed = fs.existsSync(path.join(destDir, 'SKILL.md'));
                copyDir(srcDir, destDir);
                action = existed ? 'updated' : 'created';
            } else {
                action = d;
            }
            results.push({ kind: 'skill', skill: name, target: path.join(rel, name), action });
        }
    }

    for (const [name, spec] of Object.entries(manifest.agents || {})) {
        const src = path.join(agentsDir, `${name}.md`);
        if (!fs.existsSync(src) || !conditionMet(spec.when, projectRoot, cache)) { continue; }
        const bundled = fs.readFileSync(src, 'utf8');
        for (const rel of AGENT_TARGET_DIRS) {
            const dest = path.join(projectRoot, rel, `${name}.md`);
            const d = decide('agent', bundled, dest, dest);
            let action: SkillInstallAction;
            if (d === 'write') {
                const existed = fs.existsSync(dest);
                fs.mkdirSync(path.dirname(dest), { recursive: true });
                fs.copyFileSync(src, dest);
                action = existed ? 'updated' : 'created';
            } else {
                action = d;
            }
            results.push({ kind: 'agent', skill: name, target: path.join(rel, `${name}.md`), action });
        }
    }
    return results;
}

/** Backwards-compatible wrapper (older callers passed resources/skills). */
export function installBundledSkills(bundledSkillsDir: string, projectRoot: string): SkillInstallResult[] {
    return installBundledAssets(path.dirname(bundledSkillsDir), projectRoot);
}
