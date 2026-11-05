"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.SKILL_TARGET_DIRS = void 0;
exports.installBundledSkills = installBundledSkills;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
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
exports.SKILL_TARGET_DIRS = ['.agents/skills', '.claude/skills'];
function readFrontmatterField(content, field) {
    const fm = content.match(/^---\n([\s\S]*?)\n---/);
    if (!fm) {
        return undefined;
    }
    const m = fm[1].match(new RegExp(`^\\s*${field}:\\s*(.+?)\\s*$`, 'm'));
    return m ? m[1].replace(/^['"]|['"]$/g, '') : undefined;
}
function versionOf(content) {
    const v = parseInt(readFrontmatterField(content, 'version') || '0', 10);
    return Number.isFinite(v) ? v : 0;
}
function copyDir(src, dest) {
    fs.mkdirSync(dest, { recursive: true });
    for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
        const s = path.join(src, entry.name);
        const d = path.join(dest, entry.name);
        if (entry.isDirectory()) {
            copyDir(s, d);
        }
        else if (entry.isFile()) {
            fs.copyFileSync(s, d);
        }
    }
}
function installBundledSkills(bundledSkillsDir, projectRoot) {
    const results = [];
    if (!fs.existsSync(bundledSkillsDir)) {
        return results;
    }
    for (const entry of fs.readdirSync(bundledSkillsDir, { withFileTypes: true })) {
        if (!entry.isDirectory()) {
            continue;
        }
        const srcDir = path.join(bundledSkillsDir, entry.name);
        const srcSkill = path.join(srcDir, 'SKILL.md');
        if (!fs.existsSync(srcSkill)) {
            continue;
        }
        const bundledContent = fs.readFileSync(srcSkill, 'utf8');
        const bundledVersion = versionOf(bundledContent);
        for (const rel of exports.SKILL_TARGET_DIRS) {
            const destDir = path.join(projectRoot, rel, entry.name);
            const target = path.join(rel, entry.name);
            let action;
            let lst;
            try {
                lst = fs.lstatSync(destDir);
            }
            catch {
                lst = undefined;
            }
            if (!lst) {
                copyDir(srcDir, destDir);
                action = 'created';
            }
            else if (lst.isSymbolicLink()) {
                action = 'kept-symlink';
            }
            else {
                const destSkill = path.join(destDir, 'SKILL.md');
                const existing = fs.existsSync(destSkill) ? fs.readFileSync(destSkill, 'utf8') : '';
                if (!existing) {
                    copyDir(srcDir, destDir);
                    action = 'created';
                }
                else if (readFrontmatterField(existing, 'origin') !== 'DevMind') {
                    action = 'kept-custom';
                }
                else if (versionOf(existing) < bundledVersion) {
                    copyDir(srcDir, destDir);
                    action = 'updated';
                }
                else {
                    action = 'unchanged';
                }
            }
            results.push({ skill: entry.name, target, action });
        }
    }
    return results;
}
//# sourceMappingURL=skillInstaller.js.map