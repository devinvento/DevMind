import * as vscode from 'vscode';
import * as child_process from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

export class DevMindRunner {
    private outputChannel: vscode.OutputChannel;

    constructor() {
        this.outputChannel = vscode.window.createOutputChannel('DevMind OS');
    }

    public getWorkspaceRoot(): string | undefined {
        const folders = vscode.workspace.workspaceFolders;
        if (folders && folders.length > 0) {
            return folders[0].uri.fsPath;
        }
        return undefined;
    }

    public getCliCommand(workspaceRoot: string): string {
        const config = vscode.workspace.getConfiguration('devmind');
        const customPath = config.get<string>('cliPath');
        if (customPath && customPath !== 'devmind' && fs.existsSync(customPath)) {
            return customPath;
        }

        // Check bin/devmind inside workspace
        const localBin = path.join(workspaceRoot, 'bin', 'devmind');
        if (fs.existsSync(localBin)) {
            return `python3 "${localBin}"`;
        }

        // Check ~/.local/bin/devmind
        const homeBin = path.join(process.env.HOME || '', '.local', 'bin', 'devmind');
        if (fs.existsSync(homeBin)) {
            return `python3 "${homeBin}"`;
        }

        // Fallback to system command
        return 'devmind';
    }

    private stripAnsi(text: string): string {
        // Remove ANSI color escape codes like \033[0;36m or \x1b[0;32m
        return text.replace(/[\u001b\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nxy=><]/g, '')
                   .replace(/\[\d+;\d+m/g, '')
                   .replace(/\[0m/g, '');
    }

    public async executeCommand(args: string[], showOutput: boolean = true): Promise<{ code: number; stdout: string; stderr: string }> {
        const root = this.getWorkspaceRoot();
        if (!root) {
            vscode.window.showErrorMessage('DevMind: No workspace folder open.');
            return { code: 1, stdout: '', stderr: 'No workspace' };
        }

        const cliCmd = this.getCliCommand(root);
        const fullCmd = `${cliCmd} ${args.map(a => `"${a}"`).join(' ')}`;

        if (showOutput) {
            this.outputChannel.show(true);
            this.outputChannel.appendLine(`\n[DevMind CLI] Running: ${fullCmd}`);
            this.outputChannel.appendLine('='.repeat(60));
        }

        return new Promise((resolve) => {
            const execEnv = { ...process.env, NO_COLOR: '1', TERM: 'dumb' };
            child_process.exec(fullCmd, { cwd: root, env: execEnv }, (error, stdout, stderr) => {
                const cleanStdout = this.stripAnsi(stdout || '');
                const cleanStderr = this.stripAnsi(stderr || '');

                if (showOutput) {
                    if (cleanStdout) {
                        this.outputChannel.appendLine(cleanStdout);
                    }
                    if (cleanStderr) {
                        this.outputChannel.appendLine(`[STDERR]\n${cleanStderr}`);
                    }
                }

                const exitCode = error ? (error.code ?? 1) : 0;
                resolve({ code: exitCode, stdout: cleanStdout, stderr: cleanStderr });
            });
        });
    }

    public async getEngineeringScore(): Promise<number> {
        const root = this.getWorkspaceRoot();
        if (!root) {
            return 0;
        }

        const { stdout } = await this.executeCommand(['doctor'], false);
        const match = stdout.match(/Overall DevMind Engineering Score:\s*(\d+)%/);
        if (match && match[1]) {
            return parseInt(match[1], 10);
        }
        return 85;
    }

    public showOutputChannel(): void {
        this.outputChannel.show(true);
    }
}
