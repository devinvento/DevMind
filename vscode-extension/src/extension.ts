import * as vscode from 'vscode';
import { DevMindRunner } from './devmindRunner';
import { DevMindSidebarProvider } from './views/devmindSidebar';
import { registerCommands } from './commands';
import * as fs from 'fs';
import * as path from 'path';
import * as child_process from 'child_process';
import { installBundledSkills } from './skillInstaller';
import { MemorySync } from './memorySync';

let memorySync: MemorySync | undefined;

/**
 * Writes the skills bundled in the VSIX (resources/skills/) into every open workspace folder's
 * .agents/skills/ and .claude/skills/. Runs on activation (right after the VSIX is installed and
 * on every window open), when folders are added, and from the "DevMind: Install AI Skills" command.
 */
function ensureBundledSkills(context: vscode.ExtensionContext, runner: DevMindRunner, notify: boolean): void {
    const bundled = path.join(context.extensionPath, 'resources', 'skills');
    const roots = new Set<string>((vscode.workspace.workspaceFolders || []).map(f => f.uri.fsPath));
    const override = runner.getWorkspaceRoot();
    if (override) { roots.add(override); }

    const changed: string[] = [];
    for (const root of roots) {
        try {
            for (const r of installBundledSkills(bundled, root)) {
                if (r.action === 'created' || r.action === 'updated') {
                    changed.push(`${r.action} ${path.basename(root)}/${r.target}`);
                }
            }
        } catch (err: any) {
            console.error(`DevMind: failed to install skills into ${root}:`, err);
            if (notify) { vscode.window.showErrorMessage(`DevMind: Could not install AI skills in ${root}: ${err.message}`); }
        }
    }
    if (changed.length) {
        console.log(`DevMind skills: ${changed.join(', ')}`);
    }
    if (notify) {
        vscode.window.showInformationMessage(changed.length
            ? `DevMind: AI skills installed (${changed.length}): secret-guard → .agents/skills & .claude/skills`
            : 'DevMind: AI skills already up to date.');
    }
}

export function activate(context: vscode.ExtensionContext) {
    console.log('Activating DevMind Enterprise AI OS VS Code Extension...');

    const runner = new DevMindRunner();
    runner.setContext(context);

    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.installSkills', () => ensureBundledSkills(context, runner, true)),
        vscode.workspace.onDidChangeWorkspaceFolders(() => ensureBundledSkills(context, runner, false))
    );
    const sidebarProvider = new DevMindSidebarProvider(runner);
    memorySync = new MemorySync(context, runner, () => sidebarProvider.refresh());
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
    registerCommands(context, runner, sidebarProvider, statusBarItem);

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
                        } catch (err) {
                            statusBarItem.text = '$(brain) DevMind: Ready';
                        }
                        resolve(true);
                    });
                });
            });
        } else {
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
    } else {
        statusBarItem.text = '$(brain) DevMind: Ready';
    }

    console.log('DevMind Extension Activated Successfully!');
}

export function deactivate() {
    // Upload memory one last time when the window closes (detached process, does not block VS Code).
    memorySync?.pushOnExit();
}
