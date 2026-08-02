import * as vscode from 'vscode';
import { DevMindRunner } from './devmindRunner';
import { DevMindSidebarProvider } from './views/devmindSidebar';
import { registerCommands } from './commands';
import * as fs from 'fs';
import * as path from 'path';
import * as child_process from 'child_process';

export function activate(context: vscode.ExtensionContext) {
    console.log('Activating DevMind Enterprise AI OS VS Code Extension...');

    const runner = new DevMindRunner();
    const sidebarProvider = new DevMindSidebarProvider(runner);

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
            vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: "DevMind: Auto-installing CLI dependencies & context engine...",
                cancellable: false
            }, async (progress) => {
                progress.report({ message: "Running project setup..." });
                return new Promise((resolve) => {
                    const execEnv = { ...process.env, NO_COLOR: '1', TERM: 'dumb' };
                    child_process.exec(`echo "Y" | "${setupScript}"`, { cwd: root, env: execEnv }, async (error) => {
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

    // Auto Sync on Save Listener
    context.subscriptions.push(
        vscode.workspace.onDidSaveTextDocument(async (document) => {
            const config = vscode.workspace.getConfiguration('devmind');
            const autoSync = config.get<boolean>('autoSyncOnSave');
            if (autoSync) {
                const fileName = document.fileName;
                if (fileName.endsWith('ARCHITECTURE.md') || fileName.endsWith('DATABASE.md') || fileName.includes('.devmind')) {
                    vscode.window.showInformationMessage('DevMind: Auto-syncing AI context...');
                    await runner.executeCommand(['sync'], false);
                    sidebarProvider.refresh();
                }
            }
        })
    );

    console.log('DevMind Extension Activated Successfully!');
}

export function deactivate() {}
