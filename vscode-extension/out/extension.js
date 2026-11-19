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
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const devmindRunner_1 = require("./devmindRunner");
const devmindSidebar_1 = require("./views/devmindSidebar");
const commands_1 = require("./commands");
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const child_process = __importStar(require("child_process"));
const skillInstaller_1 = require("./skillInstaller");
const memorySync_1 = require("./memorySync");
const mcpSetup_1 = require("./mcpSetup");
let memorySync;
/**
 * Older DevMind setups wrote `@ARCHITECTURE.md`, `@DATABASE.md` and `@SECURITY.md` into CLAUDE.md.
 * Claude Code inlines `@` imports into every session, so a large DATABASE.md burned hundreds of
 * thousands of tokens per message. Remove those import lines (the files themselves are left alone).
 */
function stripDocImports(root) {
    const file = path.join(root, 'CLAUDE.md');
    if (!fs.existsSync(file)) {
        return false;
    }
    const text = fs.readFileSync(file, 'utf8');
    const cleaned = text.replace(/^[ \t]*-[ \t]*(?:Architecture|Database|Security):[ \t]*@(?:ARCHITECTURE|DATABASE|SECURITY)\.md[ \t]*\r?\n/gm, '');
    if (cleaned === text) {
        return false;
    }
    fs.writeFileSync(file, cleaned, 'utf8');
    console.log(`DevMind: removed token-heavy @DATABASE/@ARCHITECTURE/@SECURITY imports from ${file}`);
    return true;
}
/**
 * Writes the skills and agents bundled in the VSIX (resources/manifest.json) into every open workspace
 * folder's .agents/ and .claude/. Runs on activation (right after the VSIX is installed and on every
 * window open), when folders are added, and from the "DevMind: Install AI Skills & Agents" command.
 */
function ensureBundledSkills(context, runner, notify) {
    const resources = path.join(context.extensionPath, 'resources');
    const roots = new Set((vscode.workspace.workspaceFolders || []).map(f => f.uri.fsPath));
    const override = runner.getWorkspaceRoot();
    if (override) {
        roots.add(override);
    }
    const changed = [];
    const kept = [];
    for (const root of roots) {
        try {
            stripDocImports(root);
            for (const r of (0, skillInstaller_1.installBundledAssets)(resources, root)) {
                if (r.action === 'created' || r.action === 'updated') {
                    changed.push(`${r.action} ${path.basename(root)}/${r.target}`);
                }
                else if (r.action === 'kept-custom') {
                    kept.push(`${path.basename(root)}/${r.target}`);
                }
            }
            if (!notify) {
                (0, mcpSetup_1.suggestSundoraDbMcp)(context, root);
            }
        }
        catch (err) {
            console.error(`DevMind: failed to install skills into ${root}:`, err);
            if (notify) {
                vscode.window.showErrorMessage(`DevMind: Could not install AI skills in ${root}: ${err.message}`);
            }
        }
    }
    if (changed.length) {
        console.log(`DevMind skills/agents: ${changed.join(', ')}`);
    }
    if (notify) {
        const skills = new Set(changed.filter(c => c.includes('/skills/')).map(c => c.split('/').pop()));
        const agents = new Set(changed.filter(c => c.includes('/agents/')).map(c => c.split('/').pop()));
        vscode.window.showInformationMessage(changed.length
            ? `DevMind: installed/updated ${skills.size} skill(s) and ${agents.size} agent(s) into .agents/ & .claude/` +
                (kept.length ? ` (${kept.length} customised copies kept)` : '')
            : `DevMind: AI skills & agents already up to date${kept.length ? ` (${kept.length} customised copies kept)` : ''}.`);
    }
}
function activate(context) {
    console.log('Activating DevMind Enterprise AI OS VS Code Extension...');
    const runner = new devmindRunner_1.DevMindRunner();
    runner.setContext(context);
    context.subscriptions.push(vscode.commands.registerCommand('devmind.installSkills', () => ensureBundledSkills(context, runner, true)), (0, mcpSetup_1.registerSundoraDbMcp)(context, runner), vscode.workspace.onDidChangeWorkspaceFolders(() => ensureBundledSkills(context, runner, false)));
    const sidebarProvider = new devmindSidebar_1.DevMindSidebarProvider(runner);
    memorySync = new memorySync_1.MemorySync(context, runner, () => sidebarProvider.refresh());
    const startMemorySync = () => { memorySync?.start().catch(err => console.error('DevMind memory sync:', err)); };
    // Register Sidebar Tree View
    const treeView = vscode.window.createTreeView('devmind.sidebarView', {
        treeDataProvider: sidebarProvider,
        showCollapseAll: true
    });
    context.subscriptions.push(treeView);
    // Create Status Bar Item
    const statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.command = 'devmind.doctor';
    statusBarItem.text = '$(brain) DevMind: Loading...';
    statusBarItem.tooltip = 'DevMind Engineering Score\nClick to run Doctor diagnostics.';
    statusBarItem.show();
    context.subscriptions.push(statusBarItem);
    // Register All Extension Commands
    (0, commands_1.registerCommands)(context, runner, sidebarProvider, statusBarItem);
    // Auto-Bootstrap dependencies if missing
    const root = runner.getWorkspaceRoot();
    if (root) {
        const setupScript = path.join(root, 'setup-ai-project.sh');
        const agentsDir = path.join(root, '.agents');
        if (fs.existsSync(setupScript) && !fs.existsSync(agentsDir)) {
            const isDevMindRepo = fs.existsSync(path.join(root, 'vscode-extension')) &&
                fs.existsSync(path.join(root, 'rebuild-and-install.sh'));
            if (isDevMindRepo) {
                statusBarItem.text = '$(brain) DevMind: Ready (DevMode)';
                statusBarItem.tooltip = 'DevMind Development Mode active';
                ensureBundledSkills(context, runner, false);
                startMemorySync();
                return;
            }
            vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: "DevMind: Auto-installing CLI dependencies & context engine...",
                cancellable: false
            }, async (progress) => {
                progress.report({ message: "Running project setup..." });
                return new Promise((resolve) => {
                    const execEnv = { ...process.env, NO_COLOR: '1', TERM: 'dumb' };
                    child_process.exec(`echo "Y" | "${setupScript}"`, { cwd: root, env: execEnv }, async (error) => {
                        // Install skills only AFTER setup: creating .agents/ earlier would stop
                        // this auto-setup from ever running (it is triggered by .agents/ missing).
                        ensureBundledSkills(context, runner, false);
                        startMemorySync();
                        if (error) {
                            vscode.window.showErrorMessage(`DevMind Auto-Install Failed: ${error.message}`);
                            resolve(false);
                            return;
                        }
                        vscode.window.showInformationMessage("DevMind: Dependencies and AI context successfully installed!");
                        sidebarProvider.refresh();
                        try {
                            const score = await runner.getEngineeringScore();
                            statusBarItem.text = `$(brain) DevMind: ${score}%`;
                            statusBarItem.tooltip = `DevMind Engineering Score: ${score}%\nClick to run Doctor diagnostics.`;
                        }
                        catch (err) {
                            statusBarItem.text = '$(brain) DevMind: Ready';
                        }
                        resolve(true);
                    });
                });
            });
        }
        else {
            ensureBundledSkills(context, runner, false);
            startMemorySync();
            // Fetch initial score asynchronously without blocking activation
            runner.getEngineeringScore().then(score => {
                statusBarItem.text = `$(brain) DevMind: ${score}%`;
                statusBarItem.tooltip = `DevMind Engineering Score: ${score}%\nClick to run Doctor diagnostics.`;
            }).catch(err => {
                console.error('Failed to get initial DevMind score:', err);
                statusBarItem.text = '$(brain) DevMind: Ready';
            });
        }
    }
    else {
        statusBarItem.text = '$(brain) DevMind: Ready';
    }
    console.log('DevMind Extension Activated Successfully!');
}
function deactivate() {
    // Upload memory one last time when the window closes (detached process, does not block VS Code).
    memorySync?.pushOnExit();
}
//# sourceMappingURL=extension.js.map