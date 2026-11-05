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
exports.MemorySync = void 0;
const vscode = __importStar(require("vscode"));
const child_process = __importStar(require("child_process"));
const path = __importStar(require("path"));
function timeAgo(iso) {
    if (!iso) {
        return 'never';
    }
    const mins = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
    if (mins < 1) {
        return 'just now';
    }
    if (mins < 60) {
        return `${mins} min ago`;
    }
    const h = Math.round(mins / 60);
    return h < 24 ? `${h} h ago` : `${Math.round(h / 24)} d ago`;
}
class MemorySync {
    context;
    runner;
    onChanged;
    statusItem;
    timer;
    busy = false;
    lastStatus;
    constructor(context, runner, onChanged) {
        this.context = context;
        this.runner = runner;
        this.onChanged = onChanged;
        this.statusItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 99);
        this.statusItem.command = 'devmind.memoryMenu';
        this.statusItem.text = '$(cloud) Memory';
        this.statusItem.show();
        context.subscriptions.push(this.statusItem, this, vscode.commands.registerCommand('devmind.memoryPush', () => this.run('push', 'Pushing AI memory to Google Drive…')), vscode.commands.registerCommand('devmind.memoryPull', () => this.run('pull', 'Pulling AI memory from Google Drive…')), vscode.commands.registerCommand('devmind.memorySyncAll', () => this.run('sync-all', 'Syncing AI memory for all projects…')), vscode.commands.registerCommand('devmind.memorySetup', () => this.setup()), vscode.commands.registerCommand('devmind.memoryConnectDrive', () => this.connectDrive()), vscode.commands.registerCommand('devmind.memoryDisconnectDrive', () => this.disconnectDrive()), vscode.commands.registerCommand('devmind.memoryOpenHistory', () => this.openHistory()), vscode.commands.registerCommand('devmind.memoryMenu', () => this.menu()), vscode.workspace.onDidChangeConfiguration(e => {
            if (e.affectsConfiguration('devmind.memory')) {
                this.scheduleAutoPush();
            }
        }));
    }
    /** Called once on activation: refresh the badge, auto-pull, start the auto-push timer. */
    async start() {
        const st = await this.refreshStatus();
        const cfg = vscode.workspace.getConfiguration('devmind.memory');
        if (st && st.configured && st.backend_ready && cfg.get('autoPullOnStartup', true)) {
            await this.run('pull', undefined, true);
        }
        this.scheduleAutoPush();
    }
    scheduleAutoPush() {
        if (this.timer) {
            clearInterval(this.timer);
            this.timer = undefined;
        }
        const minutes = vscode.workspace.getConfiguration('devmind.memory').get('autoPushMinutes', 30);
        if (minutes > 0) {
            this.timer = setInterval(() => {
                if (this.lastStatus?.configured && this.lastStatus.backend_ready) {
                    this.run('push', undefined, true);
                }
            }, minutes * 60 * 1000);
        }
    }
    async refreshStatus() {
        const { code, stdout } = await this.runner.executeCommand(['memory', 'status', '--json'], false);
        let st;
        try {
            st = code === 0 ? JSON.parse(stdout.trim().split('\n').pop() || '') : undefined;
        }
        catch {
            st = undefined;
        }
        this.lastStatus = st;
        this.render(st);
        return st;
    }
    render(st) {
        this.statusItem.backgroundColor = undefined;
        this.statusItem.command = 'devmind.memoryMenu';
        if (!st) {
            this.statusItem.text = '$(cloud) Memory: n/a';
            this.statusItem.tooltip = 'DevMind CLI not found or not a git project.';
            return;
        }
        if (!st.configured || !st.backend_ready) {
            this.statusItem.text = '$(cloud) Connect Google Drive';
            this.statusItem.tooltip = 'AI memory sync is not connected yet. Click to log in to Google Drive (one click).';
            this.statusItem.command = 'devmind.memoryConnectDrive';
            this.statusItem.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
            return;
        }
        if (st.last_error) {
            this.statusItem.text = '$(error) Memory: sync failed';
            this.statusItem.tooltip = `Last error: ${st.last_error}\nClick for options.`;
            this.statusItem.backgroundColor = new vscode.ThemeColor('statusBarItem.errorBackground');
            return;
        }
        const last = [st.last_push, st.last_pull].filter(Boolean).sort().pop() || null;
        this.statusItem.text = `$(cloud) Synced ${timeAgo(last)}`;
        this.statusItem.tooltip = new vscode.MarkdownString(`**DevMind AI Memory** (Google Drive)\n\n` +
            `- Remote: \`${st.remote}/${st.project_key}\`\n- Machine: \`${st.machine}\`\n` +
            `- Sessions: ${st.sessions}\n- Last push: ${timeAgo(st.last_push)}\n- Last pull: ${timeAgo(st.last_pull)}\n\n` +
            `Click for Push / Pull / Sync all.`);
    }
    async run(sub, progressTitle, silent = false) {
        if (this.busy) {
            return false;
        }
        if (!this.lastStatus?.configured || !this.lastStatus.backend_ready) {
            if (!silent) {
                const pick = await vscode.window.showWarningMessage('DevMind AI memory is not connected to Google Drive yet.', 'Connect Google Drive', 'Use a folder');
                if (pick === 'Connect Google Drive') {
                    await this.connectDrive();
                }
                else if (pick === 'Use a folder') {
                    await this.setup('folder');
                }
            }
            return false;
        }
        this.busy = true;
        this.statusItem.text = '$(sync~spin) Memory: syncing…';
        try {
            const args = ['memory', sub, ...(silent ? ['--quiet'] : [])];
            const exec = () => this.runner.executeCommand(args, !silent);
            const res = progressTitle
                ? await vscode.window.withProgress({ location: vscode.ProgressLocation.Notification, title: `DevMind: ${progressTitle}` }, exec)
                : await exec();
            if (!silent) {
                if (res.code === 0) {
                    vscode.window.showInformationMessage(`DevMind: Memory ${sub} complete.`);
                }
                else {
                    vscode.window.showErrorMessage(`DevMind: Memory ${sub} failed. See the "DevMind OS" output for details.`);
                }
            }
            return res.code === 0;
        }
        finally {
            this.busy = false;
            await this.refreshStatus();
            this.onChanged();
        }
    }
    async menu() {
        const connected = !!(this.lastStatus?.configured && this.lastStatus.backend_ready);
        const items = [
            { label: '$(cloud-upload) Push Memory', description: 'Capture new sessions, redact, upload', cmd: 'devmind.memoryPush' },
            { label: '$(cloud-download) Pull Memory', description: 'Download & rebuild chat-history.md', cmd: 'devmind.memoryPull' },
            { label: '$(sync) Sync All Projects', description: 'Pull + push every project on this machine', cmd: 'devmind.memorySyncAll' },
            { label: '$(history) Open Chat History', description: '.devmind/memory/chat-history.md', cmd: 'devmind.memoryOpenHistory' },
            connected
                ? { label: '$(debug-disconnect) Disconnect Google Drive', description: this.lastStatus?.remote || '', cmd: 'devmind.memoryDisconnectDrive' }
                : { label: '$(plug) Connect Google Drive', description: 'One-click Google login', cmd: 'devmind.memoryConnectDrive' },
            { label: '$(gear) Use a Different Folder / Remote', description: 'Mounted folder or custom rclone remote', cmd: 'devmind.memorySetup' },
        ];
        const pick = await vscode.window.showQuickPick(items, { placeHolder: 'DevMind AI Memory (Google Drive)' });
        if (pick) {
            vscode.commands.executeCommand(pick.cmd);
        }
    }
    async openHistory() {
        const root = this.runner.getWorkspaceRoot();
        if (!root) {
            return;
        }
        await this.runner.executeCommand(['memory', 'index'], false);
        const file = path.join(root, '.devmind', 'memory', 'chat-history.md');
        vscode.commands.executeCommand('markdown.showPreview', vscode.Uri.file(file));
    }
    async askMachineName() {
        return vscode.window.showInputBox({
            title: 'DevMind: name this computer',
            prompt: 'Used in session file names so two PCs never overwrite each other (e.g. office-pc, home-pc)',
            value: this.lastStatus?.machine || '',
            validateInput: v => /^[A-Za-z0-9-]*$/.test(v) ? undefined : 'Use letters, numbers and dashes only'
        });
    }
    /**
     * One-click Google Drive connection. The CLI (`devmind memory connect --no-browser`) installs rclone
     * if needed, starts the Google OAuth flow and prints `DEVMIND_AUTH_URL: …`, which we open here
     * (via asExternalUri so it also works in Remote-SSH/WSL), then saves the token and verifies access.
     */
    async connectDrive() {
        const root = this.runner.getWorkspaceRoot();
        if (!root) {
            vscode.window.showErrorMessage('DevMind: open a project folder first.');
            return;
        }
        const machine = await this.askMachineName();
        if (machine === undefined) {
            return;
        }
        const cli = this.runner.getCliCommand(root);
        const args = `memory connect --no-browser${machine ? ` --machine "${machine}"` : ''}`;
        this.runner.showOutputChannel();
        this.runner.log(`\n[DevMind] Connecting Google Drive: ${cli} ${args}`);
        const result = await vscode.window.withProgress({
            location: vscode.ProgressLocation.Notification,
            title: 'DevMind: Connecting Google Drive',
            cancellable: true
        }, (progress, token) => new Promise(resolve => {
            const child = child_process.spawn(`${cli} ${args}`, {
                cwd: root, shell: true, detached: process.platform !== 'win32',
                env: { ...process.env, NO_COLOR: '1', TERM: 'dumb', PYTHONUNBUFFERED: '1' }
            });
            let lastError = '';
            let opened = false;
            const onLine = async (line) => {
                if (!line.trim()) {
                    return;
                }
                this.runner.log(line.replace(/state=[\w-]+/, 'state=…'));
                const step = line.match(/^DEVMIND_STEP:\s*(.+)$/);
                if (step) {
                    progress.report({ message: step[1] });
                }
                const url = line.match(/^DEVMIND_AUTH_URL:\s*(\S+)/);
                if (url && !opened) {
                    opened = true;
                    const external = await vscode.env.asExternalUri(vscode.Uri.parse(url[1]));
                    await vscode.env.openExternal(external);
                    progress.report({ message: 'Sign in to Google in your browser and click "Allow"…' });
                    vscode.window.showInformationMessage('DevMind: Sign in to Google in the browser tab that just opened and click "Allow".', 'Open login page again').then(again => { if (again) {
                        vscode.env.openExternal(external);
                    } });
                }
                if (/\[ERROR\]/.test(line)) {
                    lastError = line.replace(/^.*\[ERROR\]\s*/, '');
                }
            };
            let buf = '';
            const feed = (chunk) => {
                buf += chunk.toString();
                const lines = buf.split(/\r?\n/);
                buf = lines.pop() || '';
                lines.forEach(onLine);
            };
            child.stdout?.on('data', feed);
            child.stderr?.on('data', feed);
            token.onCancellationRequested(() => {
                try {
                    if (child.pid && process.platform !== 'win32') {
                        process.kill(-child.pid, 'SIGTERM');
                    }
                    else {
                        child.kill();
                    }
                }
                catch { /* already gone */ }
            });
            child.on('close', code => {
                if (buf) {
                    onLine(buf);
                }
                resolve(code === 0 ? { ok: true } : { ok: false, error: token.isCancellationRequested ? 'Cancelled.' : lastError });
            });
            child.on('error', err => resolve({ ok: false, error: err.message }));
        }));
        const st = await this.refreshStatus();
        this.onChanged();
        if (result.ok && st?.backend_ready) {
            const go = await vscode.window.showInformationMessage(`✅ Google Drive connected (${st.remote}). Pull existing AI memory for this project now?`, 'Pull now', 'Later');
            if (go === 'Pull now') {
                await this.run('pull', 'Pulling AI memory from Google Drive…');
            }
            this.scheduleAutoPush();
        }
        else if (result.error !== 'Cancelled.') {
            const act = await vscode.window.showErrorMessage(`DevMind: Google Drive connection failed${result.error ? `: ${result.error}` : ''}`, 'Show log', 'Try again');
            if (act === 'Show log') {
                this.runner.showOutputChannel();
            }
            if (act === 'Try again') {
                await this.connectDrive();
            }
        }
    }
    async disconnectDrive() {
        const sure = await vscode.window.showWarningMessage('Disconnect Google Drive on this computer? Your memory files on Drive are kept.', { modal: true }, 'Disconnect');
        if (sure !== 'Disconnect') {
            return;
        }
        await this.runner.executeCommand(['memory', 'disconnect'], true);
        await this.refreshStatus();
        this.onChanged();
    }
    async setup(preset) {
        const choice = preset ? { id: preset } : await vscode.window.showQuickPick([
            { label: '$(plug) Google Drive (one-click login)', description: 'Recommended', id: 'drive' },
            { label: '$(folder) A local / mounted folder', description: 'e.g. a folder synced by another tool', id: 'folder' },
            { label: '$(terminal) Custom rclone remote', description: 'Advanced: e.g. myremote:Path', id: 'rclone' },
        ], { placeHolder: 'Where should DevMind store AI memory?' });
        if (!choice) {
            return;
        }
        if (choice.id === 'drive') {
            return this.connectDrive();
        }
        let remote;
        if (choice.id === 'rclone') {
            remote = await vscode.window.showInputBox({
                prompt: 'Existing rclone remote and folder (configured with "rclone config")',
                value: this.lastStatus?.backend === 'rclone' ? this.lastStatus.remote : 'myremote:DevMind-Memory'
            });
        }
        else {
            const picked = await vscode.window.showOpenDialog({
                canSelectFolders: true, canSelectFiles: false, openLabel: 'Use this folder for AI memory'
            });
            remote = picked?.[0]?.fsPath;
        }
        if (!remote) {
            return;
        }
        const machine = await this.askMachineName();
        if (machine === undefined) {
            return;
        }
        const args = ['memory', 'setup', '--remote', remote, ...(machine ? ['--machine', machine] : [])];
        const res = await this.runner.executeCommand(args, true);
        const st = await this.refreshStatus();
        if (res.code === 0 && st?.backend_ready) {
            const go = await vscode.window.showInformationMessage(`DevMind memory sync ready: ${remote}. Pull existing memory now?`, 'Pull now', 'Later');
            if (go === 'Pull now') {
                await this.run('pull', 'Pulling AI memory from Google Drive…');
            }
        }
    }
    /** Best-effort push when VS Code closes: a detached process that outlives the window. */
    pushOnExit() {
        const cfg = vscode.workspace.getConfiguration('devmind.memory');
        const root = this.runner.getWorkspaceRoot();
        if (!root || !cfg.get('pushOnClose', true)) {
            return;
        }
        if (!this.lastStatus?.configured || !this.lastStatus.backend_ready) {
            return;
        }
        try {
            const cli = this.runner.getCliCommand(root);
            const child = child_process.spawn(`${cli} memory push --quiet`, {
                cwd: root, shell: true, detached: true, stdio: 'ignore'
            });
            child.unref();
        }
        catch (err) {
            console.error('DevMind: push on exit failed', err);
        }
    }
    dispose() {
        if (this.timer) {
            clearInterval(this.timer);
        }
    }
}
exports.MemorySync = MemorySync;
//# sourceMappingURL=memorySync.js.map