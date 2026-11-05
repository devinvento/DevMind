import * as fs from 'fs';
import * as path from 'path';

/**
 * Installs the skills bundled inside the VSIX (resources/skills/<name>/) into a project's
 * `.agents/skills/<name>/` and `.claude/skills/<name>/` folders.
 *
 * Kept free of any `vscode` import so it can be unit-tested with plain Node.
 *
 * Overwrite policy for an existing target:
 *   - symlink (created by setup-ai-project.sh)          -> left alone
 *   - SKILL.md with `origin: DevMind` and older version -> updated
 *   - anything else (user-customised, `origin: custom`) -> left alone
 */

export const SKILL_TARGET_DIRS = ['.agents/skills', '.claude/skills'];

export type SkillInstallAction = 'created' | 'updated' | 'unchanged' | 'kept-custom' | 'kept-symlink';

export interface SkillInstallResult {
    skill: string;
    target: string;
    action: SkillInstallAction;
}

function readFrontmatterField(content: string, field: string): string | undefined {
    const fm = content.match(/^---\n([\s\S]*?)\n---/);
    if (!fm) { return undefined; }
    const m = fm[1].match(new RegExp(`^\\s*${field}:\\s*(.+?)\\s*$`, 'm'));
    return m ? m[1].replace(/^['"]|['"]$/g, '') : undefined;
}

function versionOf(content: string): number {
    const v = parseInt(readFrontmatterField(content, 'version') || '0', 10);
    return Number.isFinite(v) ? v : 0;
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

export function installBundledSkills(bundledSkillsDir: string, projectRoot: string): SkillInstallResult[] {
    const results: SkillInstallResult[] = [];
    if (!fs.existsSync(bundledSkillsDir)) { return results; }

    for (const entry of fs.readdirSync(bundledSkillsDir, { withFileTypes: true })) {
        if (!entry.isDirectory()) { continue; }
        const srcDir = path.join(bundledSkillsDir, entry.name);
        const srcSkill = path.join(srcDir, 'SKILL.md');
        if (!fs.existsSync(srcSkill)) { continue; }
        const bundledContent = fs.readFileSync(srcSkill, 'utf8');
        const bundledVersion = versionOf(bundledContent);

        for (const rel of SKILL_TARGET_DIRS) {
            const destDir = path.join(projectRoot, rel, entry.name);
            const target = path.join(rel, entry.name);
            let action: SkillInstallAction;

            let lst: fs.Stats | undefined;
            try { lst = fs.lstatSync(destDir); } catch { lst = undefined; }

            if (!lst) {
                copyDir(srcDir, destDir);
                action = 'created';
            } else if (lst.isSymbolicLink()) {
                action = 'kept-symlink';
            } else {
                const destSkill = path.join(destDir, 'SKILL.md');
                const existing = fs.existsSync(destSkill) ? fs.readFileSync(destSkill, 'utf8') : '';
                if (!existing) {
                    copyDir(srcDir, destDir);
                    action = 'created';
                } else if (readFrontmatterField(existing, 'origin') !== 'DevMind') {
                    action = 'kept-custom';
                } else if (versionOf(existing) < bundledVersion) {
                    copyDir(srcDir, destDir);
                    action = 'updated';
                } else {
                    action = 'unchanged';
                }
            }
            results.push({ skill: entry.name, target, action });
        }
    }
    return results;
}
