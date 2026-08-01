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
exports.DevMindGraphWebview = void 0;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
class DevMindGraphWebview {
    static currentPanel;
    static createOrShow(extensionUri, workspaceRoot) {
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
        const panel = vscode.window.createWebviewPanel('devmindGraph', 'DevMind Knowledge Graph', column || vscode.ViewColumn.One, {
            enableScripts: true,
            localResourceRoots: [
                vscode.Uri.file(path.join(workspaceRoot, 'graphify-out'))
            ]
        });
        DevMindGraphWebview.currentPanel = panel;
        panel.onDidDispose(() => {
            DevMindGraphWebview.currentPanel = undefined;
        }, null);
        let htmlContent = fs.readFileSync(htmlPath, 'utf8');
        // Allow inline scripts & webview loading
        panel.webview.html = htmlContent;
    }
}
exports.DevMindGraphWebview = DevMindGraphWebview;
//# sourceMappingURL=graphWebview.js.map