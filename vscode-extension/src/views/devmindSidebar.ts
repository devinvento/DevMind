import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { DevMindRunner } from '../devmindRunner';

export class DevMindTreeItem extends vscode.TreeItem {
    constructor(
        public readonly label: string,
        public readonly collapsibleState: vscode.TreeItemCollapsibleState,
        public readonly contextValue: string,
        public readonly command?: vscode.Command,
        public readonly iconName?: string,
        public readonly descriptionText?: string
    ) {
        super(label, collapsibleState);
        this.contextValue = contextValue;
        this.description = descriptionText;

        if (iconName) {
            this.iconPath = new vscode.ThemeIcon(iconName);
        }
    }
}

export class DevMindSidebarProvider implements vscode.TreeDataProvider<DevMindTreeItem> {
    private _onDidChangeTreeData: vscode.EventEmitter<DevMindTreeItem | undefined | null | void> = new vscode.EventEmitter<DevMindTreeItem | undefined | null | void>();
    readonly onDidChangeTreeData: vscode.Event<DevMindTreeItem | undefined | null | void> = this._onDidChangeTreeData.event;

    constructor(private runner: DevMindRunner) {}

    public refresh(): void {
        this._onDidChangeTreeData.fire();
    }

    public getTreeItem(element: DevMindTreeItem): vscode.TreeItem {
        return element;
    }

    public async getChildren(element?: DevMindTreeItem): Promise<DevMindTreeItem[]> {
        const root = this.runner.getWorkspaceRoot();
        if (!root) {
            return [
                new DevMindTreeItem('No Workspace Open', vscode.TreeItemCollapsibleState.None, 'info', undefined, 'warning')
            ];
        }

        if (!element) {
            // Root categories
            return [
                new DevMindTreeItem('🩺 System Health & Audits', vscode.TreeItemCollapsibleState.Expanded, 'category_health', undefined, 'pulse'),
                new DevMindTreeItem('🤖 AI Task Planner & Review', vscode.TreeItemCollapsibleState.Expanded, 'category_ai_tasks', undefined, 'robot'),
                new DevMindTreeItem('📊 Knowledge Graph & Code Intelligence', vscode.TreeItemCollapsibleState.Collapsed, 'category_graph', undefined, 'graph'),
                new DevMindTreeItem('📜 Architecture Decisions (ADRs)', vscode.TreeItemCollapsibleState.Collapsed, 'category_adr', undefined, 'law'),
                new DevMindTreeItem('🧠 Project Memory', vscode.TreeItemCollapsibleState.Collapsed, 'category_memory', undefined, 'circuit-board')
            ];
        }

        if (element.contextValue === 'category_health') {
            const score = await this.runner.getEngineeringScore();
            return [
                new DevMindTreeItem(
                    `Engineering Score: ${score}%`,
                    vscode.TreeItemCollapsibleState.None,
                    'doctor_score',
                    { command: 'devmind.doctor', title: 'Run Doctor Diagnostics' },
                    'pass-filled',
                    score >= 80 ? 'Optimal' : 'Needs Sync'
                ),
                new DevMindTreeItem(
                    'Run Full Doctor Diagnostics',
                    vscode.TreeItemCollapsibleState.None,
                    'action_doctor',
                    { command: 'devmind.doctor', title: 'Run Doctor' },
                    'pulse'
                ),
                new DevMindTreeItem(
                    'Sync AI Context & Knowledge Graph',
                    vscode.TreeItemCollapsibleState.None,
                    'action_sync',
                    { command: 'devmind.sync', title: 'Sync AI Context' },
                    'sync'
                ),
                new DevMindTreeItem(
                    'Audit Security Vulnerabilities',
                    vscode.TreeItemCollapsibleState.None,
                    'action_security',
                    { command: 'devmind.auditSecurity', title: 'Audit Security' },
                    'shield'
                ),
                new DevMindTreeItem(
                    'Analyze Database Architecture',
                    vscode.TreeItemCollapsibleState.None,
                    'action_db',
                    { command: 'devmind.dbAnalyze', title: 'Analyze DB Schema' },
                    'database'
                )
            ];
        }

        if (element.contextValue === 'category_ai_tasks') {
            return [
                new DevMindTreeItem(
                    'Plan AI Task / Goal...',
                    vscode.TreeItemCollapsibleState.None,
                    'action_plan',
                    { command: 'devmind.plan', title: 'Plan AI Task' },
                    'list-ordered'
                ),
                new DevMindTreeItem(
                    'Run AI Code Review on Git Diff',
                    vscode.TreeItemCollapsibleState.None,
                    'action_review',
                    { command: 'devmind.review', title: 'AI Code Review' },
                    'eye'
                )
            ];
        }

        if (element.contextValue === 'category_graph') {
            const graphFile = path.join(root, 'graphify-out', 'graph.json');
            const hasGraph = fs.existsSync(graphFile);

            return [
                new DevMindTreeItem(
                    hasGraph ? 'Graphify Index: Active' : 'Graphify Index: Missing',
                    vscode.TreeItemCollapsibleState.None,
                    'graph_status',
                    undefined,
                    hasGraph ? 'check' : 'warning',
                    hasGraph ? 'graphify-out/graph.json' : 'Run devmind sync'
                ),
                new DevMindTreeItem(
                    'Open Interactive Knowledge Graph',
                    vscode.TreeItemCollapsibleState.None,
                    'action_open_graph',
                    { command: 'devmind.openGraph', title: 'Open Graph' },
                    'eye'
                ),
                new DevMindTreeItem(
                    'Analyze File Impact...',
                    vscode.TreeItemCollapsibleState.None,
                    'action_impact',
                    { command: 'devmind.impact', title: 'File Impact Analysis' },
                    'search'
                ),
                new DevMindTreeItem(
                    'Inspect Git Blame Intelligence...',
                    vscode.TreeItemCollapsibleState.None,
                    'action_blame',
                    { command: 'devmind.blame', title: 'Git Blame Intelligence' },
                    'git-commit'
                )
            ];
        }

        if (element.contextValue === 'category_adr') {
            const adrDir = path.join(root, 'docs', 'adr');
            const adrItems: DevMindTreeItem[] = [
                new DevMindTreeItem(
                    '+ Create New ADR',
                    vscode.TreeItemCollapsibleState.None,
                    'action_create_adr',
                    { command: 'devmind.createADR', title: 'Create ADR' },
                    'add'
                )
            ];

            if (fs.existsSync(adrDir)) {
                const files = fs.readdirSync(adrDir).filter(f => f.endsWith('.md')).sort();
                files.forEach(file => {
                    const filePath = path.join(adrDir, file);
                    adrItems.push(
                        new DevMindTreeItem(
                            file,
                            vscode.TreeItemCollapsibleState.None,
                            'adr_file',
                            { command: 'vscode.open', title: 'Open ADR File', arguments: [vscode.Uri.file(filePath)] },
                            'book'
                        )
                    );
                });
            }

            return adrItems;
        }

        if (element.contextValue === 'category_memory') {
            const memoryDir = path.join(root, '.devmind', 'memory');
            if (!fs.existsSync(memoryDir)) {
                return [new DevMindTreeItem('Memory Directory Not Found', vscode.TreeItemCollapsibleState.None, 'info', undefined, 'info')];
            }

            const files = fs.readdirSync(memoryDir).filter(f => f.endsWith('.md'));
            return files.map(file => {
                const filePath = path.join(memoryDir, file);
                return new DevMindTreeItem(
                    file,
                    vscode.TreeItemCollapsibleState.None,
                    'memory_file',
                    { command: 'vscode.open', title: 'Open Memory File', arguments: [vscode.Uri.file(filePath)] },
                    'file-text'
                );
            });
        }

        return [];
    }
}
