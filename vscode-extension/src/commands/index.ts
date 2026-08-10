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

    // 3b. AI Debugger (Git Bisect + Graph)
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.debug', async () => {
            const issue = await vscode.window.showInputBox({
                prompt: 'Describe the bug / regression for DevMind AI Debugger',
                placeHolder: 'e.g. Order total is wrong after yesterday calculation update'
            });

            if (issue) {
                await vscode.window.withProgress({
                    location: vscode.ProgressLocation.Notification,
                    title: `DevMind: Running AI Debugger & Git Bisect for "${issue}"...`,
                    cancellable: false
                }, async () => {
                    await runner.executeCommand(['debug', issue], true);
                });
            }
        })
    );

    // 3c. Why This File? (Git + Graph Intelligence)
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.why', async (uri?: vscode.Uri) => {
            let filePath: string | undefined;

            if (uri && uri.fsPath) {
                filePath = uri.fsPath;
            } else if (vscode.window.activeTextEditor) {
                filePath = vscode.window.activeTextEditor.document.uri.fsPath;
            }

            if (!filePath) {
                vscode.window.showWarningMessage('DevMind: Please open or select a file to inspect intelligence.');
                return;
            }

            const relPath = path.relative(runner.getWorkspaceRoot() || '', filePath);
            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: `DevMind: Inspecting File Intelligence for ${relPath}...`,
                cancellable: false
            }, async () => {
                await runner.executeCommand(['why', relPath], true);
            });
        })
    );

    // 3d. Automated Git Bisect Regression Suite
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.regression', async () => {
            const goodCommit = await vscode.window.showInputBox({
                prompt: 'Enter known good commit hash or reference (optional, defaults to HEAD~5)',
                placeHolder: 'e.g. HEAD~5 or a81f2c3'
            });
            const badCommit = await vscode.window.showInputBox({
                prompt: 'Enter bad commit hash or reference (optional, defaults to HEAD)',
                placeHolder: 'e.g. HEAD or b72a901'
            });

            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: 'DevMind: Running Automated Git Bisect Regression Suite...',
                cancellable: false
            }, async () => {
                await runner.executeCommand(['regression', goodCommit || 'HEAD~5', badCommit || 'HEAD'], true);
            });
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

    // 12. Set Target Repository Directory Manually
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.selectDirectory', async () => {
            const options: vscode.OpenDialogOptions = {
                canSelectMany: false,
                openLabel: 'Select Target Repository Directory',
                canSelectFiles: false,
                canSelectFolders: true
            };

            const fileUri = await vscode.window.showOpenDialog(options);
            if (fileUri && fileUri[0]) {
                const selectedDir = fileUri[0].fsPath;
                runner.setManualOverrideDir(selectedDir);
                vscode.window.showInformationMessage(`DevMind: Target directory manually set to: ${selectedDir}`);
                await updateScoreBadge();
            } else {
                runner.setManualOverrideDir(undefined);
                vscode.window.showInformationMessage('DevMind: Reset to automatic directory detection.');
                await updateScoreBadge();
            }
        })
    );
}
