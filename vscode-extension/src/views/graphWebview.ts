import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export class DevMindGraphWebview {
    public static currentPanel: vscode.WebviewPanel | undefined;

    public static createOrShow(extensionUri: vscode.Uri, workspaceRoot: string) {
        const column = vscode.window.activeTextEditor ? vscode.window.activeTextEditor.viewColumn : undefined;

        if (DevMindGraphWebview.currentPanel) {
            DevMindGraphWebview.currentPanel.reveal(column);
            return;
        }

        const htmlPath = path.join(workspaceRoot, 'graphify-out', 'graph.html');
        if (!fs.existsSync(htmlPath)) {
            vscode.window.showWarningMessage('DevMind: graphify-out/graph.html not found. Please run DevMind Sync first.');
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            'devmindGraph',
            'DevMind Knowledge Graph',
            column || vscode.ViewColumn.One,
            {
                enableScripts: true,
                localResourceRoots: [
                    vscode.Uri.file(path.join(workspaceRoot, 'graphify-out'))
                ]
            }
        );

        DevMindGraphWebview.currentPanel = panel;
        panel.onDidDispose(() => {
            DevMindGraphWebview.currentPanel = undefined;
        }, null);

        let htmlContent = fs.readFileSync(htmlPath, 'utf8');

        // Allow inline scripts & webview loading
        panel.webview.html = htmlContent;
    }
}
