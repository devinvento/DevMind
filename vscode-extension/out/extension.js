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
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const devmindRunner_1 = require("./devmindRunner");
const devmindSidebar_1 = require("./views/devmindSidebar");
const commands_1 = require("./commands");
function activate(context) {
    console.log('Activating DevMind Enterprise AI OS VS Code Extension...');
    const runner = new devmindRunner_1.DevMindRunner();
    const sidebarProvider = new devmindSidebar_1.DevMindSidebarProvider(runner);
    // Register Sidebar Tree View
    const treeView = vscode.window.createTreeView('devmind.sidebarView', {
        treeDataProvider: sidebarProvider,
        showCollapseAll: true
    });
    context.subscriptions.push(treeView);
    // Create Status Bar Item
    const statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.command = 'devmind.doctor';
    statusBarItem.text = '$(brain) DevMind: Loading...';
    statusBarItem.tooltip = 'DevMind Engineering Score\nClick to run Doctor diagnostics.';
    statusBarItem.show();
    context.subscriptions.push(statusBarItem);
    // Register All Extension Commands
    (0, commands_1.registerCommands)(context, runner, sidebarProvider, statusBarItem);
    // Fetch initial score asynchronously without blocking activation
    runner.getEngineeringScore().then(score => {
        statusBarItem.text = `$(brain) DevMind: ${score}%`;
        statusBarItem.tooltip = `DevMind Engineering Score: ${score}%\nClick to run Doctor diagnostics.`;
    }).catch(err => {
        console.error('Failed to get initial DevMind score:', err);
        statusBarItem.text = '$(brain) DevMind: Ready';
    });
    // Auto Sync on Save Listener
    context.subscriptions.push(vscode.workspace.onDidSaveTextDocument(async (document) => {
        const config = vscode.workspace.getConfiguration('devmind');
        const autoSync = config.get('autoSyncOnSave');
        if (autoSync) {
            const fileName = document.fileName;
            if (fileName.endsWith('ARCHITECTURE.md') || fileName.endsWith('DATABASE.md') || fileName.includes('.devmind')) {
                vscode.window.showInformationMessage('DevMind: Auto-syncing AI context...');
                await runner.executeCommand(['sync'], false);
                sidebarProvider.refresh();
            }
        }
    }));
    console.log('DevMind Extension Activated Successfully!');
}
function deactivate() { }
//# sourceMappingURL=extension.js.map