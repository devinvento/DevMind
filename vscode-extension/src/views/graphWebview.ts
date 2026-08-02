import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import * as child_process from 'child_process';

export class DevMindGraphWebview {
    public static currentPanel: vscode.WebviewPanel | undefined;

    public static createOrShow(extensionUri: vscode.Uri, workspaceRoot: string, searchQuery?: string) {
        const column = vscode.window.activeTextEditor ? vscode.window.activeTextEditor.viewColumn : undefined;

        const htmlPath = path.join(workspaceRoot, 'graphify-out', 'graph.html');
        
        // Auto-generate graph.html if missing
        if (!fs.existsSync(htmlPath)) {
            const genScript = path.join(workspaceRoot, 'generate_graph_html.py');
            if (fs.existsSync(genScript)) {
                try {
                    child_process.execSync(`python3 "${genScript}" "${workspaceRoot}"`, { cwd: workspaceRoot });
                } catch (e) {
                    console.error('Failed to generate graph.html:', e);
                }
            }
        }

        if (!fs.existsSync(htmlPath)) {
            vscode.window.showWarningMessage('DevMind: graphify-out/graph.html not found. Please run DevMind Sync first.');
            return;
        }

        if (DevMindGraphWebview.currentPanel) {
            DevMindGraphWebview.currentPanel.reveal(column);
            if (searchQuery) {
                DevMindGraphWebview.currentPanel.webview.postMessage({ type: 'search', query: searchQuery });
            }
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            'devmindGraph',
            'DevMind Code Graph',
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

        // Handle message events from the Webview (like clicking Open File)
        panel.webview.onDidReceiveMessage(
            async (message) => {
                switch (message.command) {
                    case 'openFile':
                        if (message.filePath) {
                            const fullPath = path.isAbsolute(message.filePath)
                                ? message.filePath
                                : path.join(workspaceRoot, message.filePath);
                            
                            if (fs.existsSync(fullPath)) {
                                const doc = await vscode.workspace.openTextDocument(fullPath);
                                await vscode.window.showTextDocument(doc);
                            } else {
                                vscode.window.showWarningMessage(`DevMind: File not found: ${message.filePath}`);
                            }
                        }
                        break;
                }
            },
            undefined,
            undefined
        );

        let htmlContent = fs.readFileSync(htmlPath, 'utf8');

        if (searchQuery) {
            // Auto-trigger search query on load and set viewMode to impact
            const autoSearchScript = `<script>
                window.addEventListener('DOMContentLoaded', () => {
                    setTimeout(() => {
                        if (typeof setViewMode === 'function') {
                            setViewMode('impact');
                        }
                        if (typeof filterGraph === 'function') {
                            filterGraph(${JSON.stringify(searchQuery)});
                        }
                    }, 400);
                });
            </script></body>`;
            htmlContent = htmlContent.replace('</body>', autoSearchScript);
        }

        panel.webview.html = htmlContent;
    }
}
