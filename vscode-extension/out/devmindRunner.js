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
exports.DevMindRunner = void 0;
const vscode = __importStar(require("vscode"));
const child_process = __importStar(require("child_process"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
class DevMindRunner {
    outputChannel;
    manualOverrideDir;
    context;
    constructor() {
        this.outputChannel = vscode.window.createOutputChannel('DevMind OS');
    }
    setContext(context) {
        this.context = context;
    }
    setManualOverrideDir(dir) {
        this.manualOverrideDir = dir;
    }
    getManualOverrideDir() {
        return this.manualOverrideDir;
    }
    getWorkspaceRoot() {
        if (this.manualOverrideDir && fs.existsSync(this.manualOverrideDir)) {
            return this.manualOverrideDir;
        }
        const folders = vscode.workspace.workspaceFolders;
        if (folders && folders.length > 0) {
            return folders[0].uri.fsPath;
        }
        return undefined;
    }
    getCliCommand(workspaceRoot) {
        const config = vscode.workspace.getConfiguration('devmind');
        const customPath = config.get('cliPath');
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
    stripAnsi(text) {
        // Remove ANSI color escape codes like \033[0;36m or \x1b[0;32m
        return text.replace(/[\u001b\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nxy=><]/g, '')
            .replace(/\[\d+;\d+m/g, '')
            .replace(/\[0m/g, '');
    }
    async executeCommand(args, showOutput = true) {
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
        const execEnv = { ...process.env, NO_COLOR: '1', TERM: 'dumb' };
        if (this.context) {
            const geminiKey = await this.context.secrets.get('GEMINI_API_KEY');
            if (geminiKey)
                execEnv['GEMINI_API_KEY'] = geminiKey;
            const openaiKey = await this.context.secrets.get('OPENAI_API_KEY');
            if (openaiKey)
                execEnv['OPENAI_API_KEY'] = openaiKey;
            const deepseekKey = await this.context.secrets.get('DEEPSEEK_API_KEY');
            if (deepseekKey)
                execEnv['DEEPSEEK_API_KEY'] = deepseekKey;
            const anthropicKey = await this.context.secrets.get('ANTHROPIC_API_KEY') || await this.context.secrets.get('CLAUDE_API_KEY');
            if (anthropicKey) {
                execEnv['ANTHROPIC_API_KEY'] = anthropicKey;
                execEnv['CLAUDE_API_KEY'] = anthropicKey;
            }
        }
        return new Promise((resolve) => {
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
    async getEngineeringScore() {
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
    showOutputChannel() {
        this.outputChannel.show(true);
    }
}
exports.DevMindRunner = DevMindRunner;
//# sourceMappingURL=devmindRunner.js.map