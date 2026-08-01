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
            vscode.window.showInformationMessage('DevMind: Running 8-dimensional Doctor Diagnostics...');
            await runner.executeCommand(['doctor'], true);
            await updateScoreBadge();
        })
    );

    // 2. Sync AI Context
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.sync', async () => {
            vscode.window.showInformationMessage('DevMind: Refreshing Graphify Knowledge Graph & AI Context...');
            await runner.executeCommand(['sync'], true);
            await updateScoreBadge();
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
                vscode.window.showInformationMessage(`DevMind: Generating task plan for "${task}"...`);
                await runner.executeCommand(['plan', task], true);
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

            const relPath = path.relative(runner.getWorkspaceRoot() || '', filePath);
            vscode.window.showInformationMessage(`DevMind: Analyzing impact for file ${relPath}...`);
            await runner.executeCommand(['impact', relPath], true);
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
            await runner.executeCommand(['blame', relPath], true);
        })
    );

    // 6. Security Audit
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.auditSecurity', async () => {
            vscode.window.showInformationMessage('DevMind: Running Security Audit...');
            await runner.executeCommand(['audit', 'security'], true);
        })
    );

    // 7. DB Analyze
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.dbAnalyze', async () => {
            vscode.window.showInformationMessage('DevMind: Analyzing Database Architecture & Schemas...');
            await runner.executeCommand(['db', 'analyze'], true);
        })
    );

    // 8. AI Code Review
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.review', async () => {
            vscode.window.showInformationMessage('DevMind: Running AI Code Review on uncommitted git diff...');
            await runner.executeCommand(['review'], true);
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
                await runner.executeCommand(['adr', 'create', title], true);
                sidebarProvider.refresh();
            }
        })
    );

    // 10. List ADRs
    context.subscriptions.push(
        vscode.commands.registerCommand('devmind.listADRs', async () => {
            await runner.executeCommand(['adr', 'list'], true);
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
