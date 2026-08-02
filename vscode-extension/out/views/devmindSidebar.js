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
exports.DevMindSidebarProvider = exports.DevMindTreeItem = void 0;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
class DevMindTreeItem extends vscode.TreeItem {
    label;
    collapsibleState;
    contextValue;
    command;
    iconName;
    descriptionText;
    constructor(label, collapsibleState, contextValue, command, iconName, descriptionText) {
        super(label, collapsibleState);
        this.label = label;
        this.collapsibleState = collapsibleState;
        this.contextValue = contextValue;
        this.command = command;
        this.iconName = iconName;
        this.descriptionText = descriptionText;
        this.contextValue = contextValue;
        this.description = descriptionText;
        if (iconName) {
            this.iconPath = new vscode.ThemeIcon(iconName);
        }
    }
}
exports.DevMindTreeItem = DevMindTreeItem;
class DevMindSidebarProvider {
    runner;
    _onDidChangeTreeData = new vscode.EventEmitter();
    onDidChangeTreeData = this._onDidChangeTreeData.event;
    constructor(runner) {
        this.runner = runner;
    }
    refresh() {
        this._onDidChangeTreeData.fire();
    }
    getTreeItem(element) {
        return element;
    }
    async getChildren(element) {
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
                new DevMindTreeItem('📊 Code Graph & Code Intelligence', vscode.TreeItemCollapsibleState.Collapsed, 'category_graph', undefined, 'graph'),
                new DevMindTreeItem('📜 Architecture Decisions (ADRs)', vscode.TreeItemCollapsibleState.Collapsed, 'category_adr', undefined, 'law'),
                new DevMindTreeItem('🧠 Project Memory', vscode.TreeItemCollapsibleState.Collapsed, 'category_memory', undefined, 'circuit-board')
            ];
        }
        if (element.contextValue === 'category_health') {
            const score = await this.runner.getEngineeringScore();
            return [
                new DevMindTreeItem(`Engineering Score: ${score}%`, vscode.TreeItemCollapsibleState.None, 'doctor_score', { command: 'devmind.doctor', title: 'Run Doctor Diagnostics' }, 'pass-filled', score >= 80 ? 'Optimal' : 'Needs Sync'),
                new DevMindTreeItem('Run Full Doctor Diagnostics', vscode.TreeItemCollapsibleState.None, 'action_doctor', { command: 'devmind.doctor', title: 'Run Doctor' }, 'pulse'),
                new DevMindTreeItem('Sync AI Context & Code Graph', vscode.TreeItemCollapsibleState.None, 'action_sync', { command: 'devmind.sync', title: 'Sync AI Context' }, 'sync'),
                new DevMindTreeItem('Audit Security Vulnerabilities', vscode.TreeItemCollapsibleState.None, 'action_security', { command: 'devmind.auditSecurity', title: 'Audit Security' }, 'shield'),
                new DevMindTreeItem('Analyze Database Architecture', vscode.TreeItemCollapsibleState.None, 'action_db', { command: 'devmind.dbAnalyze', title: 'Analyze DB Schema' }, 'database')
            ];
        }
        if (element.contextValue === 'category_ai_tasks') {
            return [
                new DevMindTreeItem('Plan AI Task / Goal...', vscode.TreeItemCollapsibleState.None, 'action_plan', { command: 'devmind.plan', title: 'Plan AI Task' }, 'list-ordered'),
                new DevMindTreeItem('Run AI Code Review on Git Diff', vscode.TreeItemCollapsibleState.None, 'action_review', { command: 'devmind.review', title: 'AI Code Review' }, 'eye')
            ];
        }
        if (element.contextValue === 'category_graph') {
            const graphFile = path.join(root, 'graphify-out', 'graph.json');
            const hasGraph = fs.existsSync(graphFile);
            return [
                new DevMindTreeItem(hasGraph ? 'Graphify Index: Active' : 'Graphify Index: Missing', vscode.TreeItemCollapsibleState.None, 'graph_status', undefined, hasGraph ? 'check' : 'warning', hasGraph ? 'graphify-out/graph.json' : 'Run devmind sync'),
                new DevMindTreeItem('Open Interactive Code Graph', vscode.TreeItemCollapsibleState.None, 'action_open_graph', { command: 'devmind.openGraph', title: 'Open Graph' }, 'eye'),
                new DevMindTreeItem('Analyze File Impact...', vscode.TreeItemCollapsibleState.None, 'action_impact', { command: 'devmind.impact', title: 'File Impact Analysis' }, 'search'),
                new DevMindTreeItem('Inspect Git Blame Intelligence...', vscode.TreeItemCollapsibleState.None, 'action_blame', { command: 'devmind.blame', title: 'Git Blame Intelligence' }, 'git-commit')
            ];
        }
        if (element.contextValue === 'category_adr') {
            const adrDir = path.join(root, 'docs', 'adr');
            const adrItems = [
                new DevMindTreeItem('+ Create New ADR', vscode.TreeItemCollapsibleState.None, 'action_create_adr', { command: 'devmind.createADR', title: 'Create ADR' }, 'add')
            ];
            if (fs.existsSync(adrDir)) {
                const files = fs.readdirSync(adrDir).filter(f => f.endsWith('.md')).sort();
                files.forEach(file => {
                    const filePath = path.join(adrDir, file);
                    adrItems.push(new DevMindTreeItem(file, vscode.TreeItemCollapsibleState.None, 'adr_file', { command: 'vscode.open', title: 'Open ADR File', arguments: [vscode.Uri.file(filePath)] }, 'book'));
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
                return new DevMindTreeItem(file, vscode.TreeItemCollapsibleState.None, 'memory_file', { command: 'vscode.open', title: 'Open Memory File', arguments: [vscode.Uri.file(filePath)] }, 'file-text');
            });
        }
        return [];
    }
}
exports.DevMindSidebarProvider = DevMindSidebarProvider;
//# sourceMappingURL=devmindSidebar.js.map