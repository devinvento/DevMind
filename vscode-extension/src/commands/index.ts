import * as vscode from 'vscode';
import * as path from 'path';
import { DevMindRunner } from '../devmindRunner';
import { DevMindSidebarProvider } from '../views/devmindSidebar';
import { DevMindGraphWebview } from '../views/graphWebview';

export function registerCommands(
    context: vscode.ExtensionContext,
    runner: DevMindRunner,
    sidebarProvider: DevMindSidebarProvider,
    statusBarItem: vscode.StatusBarItem
): void {

    const updateScoreBadge = async () => {
        const score = await runner.getEngineeringScore();
        statusBarItem.text = `$(brain) DevMind: ${score}%`;
        statusBarItem.tooltip = `DevMind Engineering Score: ${score}%\nClick to run Doctor diagnostics.`;
        statusBarItem.show();
        sidebarProvider.refresh();
    };

    // 1. Doctor Diagnostics
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.doctor', async () => {
            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: "DevMind: Running 8-dimensional Doctor Diagnostics...",
                cancellable: false
            }, async () => {
                await runner.executeCommand(['doctor'], true);
                await updateScoreBadge();
            });
        })
    );

    // 2. Sync AI Context
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.sync', async () => {
            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: "DevMind: Refreshing Graphify Knowledge Graph & AI Context...",
                cancellable: false
            }, async () => {
                await runner.executeCommand(['sync'], true);
                await updateScoreBadge();
            });
            vscode.window.showInformationMessage('DevMind: AI Context Sync Complete!');
        })
    );

    // 3. Plan AI Task
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.plan', async () => {
            const task = await vscode.window.showInputBox({
                prompt: 'Enter the task specification or goal for DevMind AI Task Planner',
                placeHolder: 'e.g. Add OTP verification to login endpoint'
            });

            if (task) {
                await vscode.window.withProgress({
                    location: vscode.ProgressLocation.Notification,
                    title: `DevMind: Generating task plan for "${task}"...`,
                    cancellable: false
                }, async () => {
                    await runner.executeCommand(['plan', task], true);
                });
            }
        })
    );

    // 4. File Impact Analysis
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.impact', async (uri?: vscode.Uri) => {
            let filePath: string | undefined;

            if (uri && uri.fsPath) {
                filePath = uri.fsPath;
            } else if (vscode.window.activeTextEditor) {
                filePath = vscode.window.activeTextEditor.document.uri.fsPath;
            }

            if (!filePath) {
                vscode.window.showWarningMessage('DevMind: Please open or select a file to run impact analysis.');
                return;
            }

            const root = runner.getWorkspaceRoot();
            const relPath = root ? path.relative(root, filePath) : filePath;
            const targetSearch = path.basename(filePath);

            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: `DevMind: Analyzing impact for ${relPath}...`,
                cancellable: false
            }, async () => {
                // Execute CLI impact analysis output
                await runner.executeCommand(['impact', relPath], true);
            });

            // Launch interactive HTML Knowledge Graph webview focused on target file
            if (root) {
                DevMindGraphWebview.createOrShow(context.extensionUri, root, targetSearch);
            }
        })
    );

    // 5. Git Blame Intelligence
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.blame', async (uri?: vscode.Uri) => {
            let filePath: string | undefined;

            if (uri && uri.fsPath) {
                filePath = uri.fsPath;
            } else if (vscode.window.activeTextEditor) {
                filePath = vscode.window.activeTextEditor.document.uri.fsPath;
            }

            if (!filePath) {
                vscode.window.showWarningMessage('DevMind: Please open or select a file to inspect git intelligence.');
                return;
            }

            const relPath = path.relative(runner.getWorkspaceRoot() || '', filePath);
            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: `DevMind: Inspecting Git Blame Intelligence for ${relPath}...`,
                cancellable: false
            }, async () => {
                await runner.executeCommand(['blame', relPath], true);
            });
        })
    );

    // 6. Security Audit
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.auditSecurity', async () => {
            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: "DevMind: Running Security Audit...",
                cancellable: false
            }, async () => {
                await runner.executeCommand(['audit', 'security'], true);
            });
        })
    );

    // 7. DB Analyze
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.dbAnalyze', async () => {
            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: "DevMind: Analyzing Database Architecture & Schemas...",
                cancellable: false
            }, async () => {
                await runner.executeCommand(['db', 'analyze'], true);
            });
        })
    );

    // 8. AI Code Review
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.review', async () => {
            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: "DevMind: Running AI Code Review on uncommitted git diff...",
                cancellable: false
            }, async () => {
                await runner.executeCommand(['review'], true);
            });
        })
    );

    // 9. Create ADR
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.createADR', async () => {
            const title = await vscode.window.showInputBox({
                prompt: 'Enter title for the Architecture Decision Record (ADR)',
                placeHolder: 'e.g. Migrate to Redis caching layer'
            });

            if (title) {
                await vscode.window.withProgress({
                    location: vscode.ProgressLocation.Notification,
                    title: `DevMind: Creating ADR "${title}"...`,
                    cancellable: false
                }, async () => {
                    await runner.executeCommand(['adr', 'create', title], true);
                    sidebarProvider.refresh();
                });
            }
        })
    );

    // 10. List ADRs
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.listADRs', async () => {
            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: "DevMind: Listing Architecture Decision Records (ADRs)...",
                cancellable: false
            }, async () => {
                await runner.executeCommand(['adr', 'list'], true);
            });
        })
    );

    // 11. Open Knowledge Graph Webview
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.openGraph', async () => {
            const root = runner.getWorkspaceRoot();
            if (root) {
                DevMindGraphWebview.createOrShow(context.extensionUri, root);
            }
        })
    );
}
