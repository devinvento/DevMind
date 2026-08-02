#!/usr/bin/env python3
import json
import sys
from pathlib import Path

def generate_html_graph(json_path: Path, html_path: Path):
    if not json_path.exists():
        print(f"Error: {json_path} does not exist.")
        return

    with json_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    nodes = data.get("nodes", [])
    links = data.get("links", [])

    # Process nodes for Vis.js
    vis_nodes = []
    color_palette = [
        "#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6",
        "#EC4899", "#06B6D4", "#F97316", "#14B8A6", "#6366F1"
    ]

    for node in nodes:
        node_id = node.get("id")
        label = node.get("label", node_id)
        community = node.get("community", 0)
        file_type = node.get("file_type", "code")
        source_file = node.get("source_file", "")
        source_loc = node.get("source_location", "")

        color = color_palette[community % len(color_palette)]
        shape = "ellipse" if file_type == "code" else "box"

        title_html = f"<b>{label}</b><br/>File: {source_file}<br/>Location: {source_loc}<br/>Community: {community}"

        vis_nodes.append({
            "id": node_id,
            "label": label,
            "title": title_html,
            "source_file": source_file,
            "source_location": source_loc,
            "community": community,
            "shape": shape,
            "color": {
                "background": color,
                "border": "#1E293B",
                "highlight": {"background": "#F43F5E", "border": "#FFFFFF"}
            },
            "font": {"color": "#F8FAFC", "face": "Outfit, sans-serif", "size": 14},
            "margin": 10
        })

    # Process edges
    vis_edges = []
    for link in links:
        source = link.get("source")
        target = link.get("target")
        relation = link.get("relation", "")

        vis_edges.append({
            "from": source,
            "to": target,
            "label": relation,
            "color": {"color": "#475569", "highlight": "#38BDF8"},
            "font": {"color": "#94A3B8", "size": 10, "align": "middle"},
            "arrows": "to"
        })

    html_template = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevMind Knowledge Graph Visualizer</title>
    <script type="text/javascript" src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js"></script>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Outfit', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
        body { background-color: #0B0F19; color: #F8FAFC; overflow: hidden; height: 100vh; display: flex; flex-direction: column; }
        
        /* Header styling */
        header { 
            background: rgba(30, 41, 59, 0.7); 
            backdrop-filter: blur(12px);
            padding: 14px 24px; 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
            border-bottom: 1px solid rgba(51, 65, 85, 0.5); 
            z-index: 100;
        }
        h1 { 
            font-size: 20px; 
            font-weight: 700; 
            color: #38BDF8; 
            display: flex; 
            align-items: center; 
            gap: 10px; 
            letter-spacing: -0.5px;
        }
        .badge { 
            background: linear-gradient(135deg, #38BDF8 0%, #0369A1 100%); 
            color: white; 
            padding: 3px 10px; 
            border-radius: 20px; 
            font-size: 11px; 
            font-weight: 600;
            box-shadow: 0 0 10px rgba(56, 189, 248, 0.3);
        }
        .header-center {
            display: flex;
            align-items: center;
            gap: 20px;
        }
        .stats { 
            font-size: 13px; 
            color: #94A3B8; 
            display: flex; 
            gap: 16px; 
            background: rgba(15, 23, 42, 0.4);
            padding: 6px 16px;
            border-radius: 30px;
            border: 1px solid rgba(51, 65, 85, 0.3);
        }
        .stats b { color: #38BDF8; }
        
        .controls { display: flex; gap: 16px; align-items: center; }
        
        /* Search Box */
        .search-container {
            position: relative;
        }
        .search-container input[type="text"] { 
            background: rgba(15, 23, 42, 0.6); 
            border: 1px solid rgba(51, 65, 85, 0.6); 
            color: #F8FAFC; 
            padding: 8px 16px 8px 36px; 
            border-radius: 8px; 
            outline: none; 
            font-size: 14px; 
            width: 260px; 
            transition: all 0.3s;
        }
        .search-container input[type="text"]:focus { 
            border-color: #38BDF8; 
            box-shadow: 0 0 15px rgba(56, 189, 248, 0.25);
            background: rgba(15, 23, 42, 0.8);
        }
        .search-icon {
            position: absolute;
            left: 12px;
            top: 50%;
            transform: translateY(-50%);
            color: #64748B;
            pointer-events: none;
            display: flex;
            align-items: center;
        }

        /* View Mode Segmented Control */
        .segmented-control {
            display: flex;
            background: rgba(15, 23, 42, 0.6);
            border: 1px solid rgba(51, 65, 85, 0.6);
            padding: 4px;
            border-radius: 8px;
            gap: 4px;
        }
        .segment-btn {
            background: transparent;
            border: none;
            color: #94A3B8;
            padding: 6px 16px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
        }
        .segment-btn.active {
            background: #38BDF8;
            color: #0F172A;
            font-weight: 600;
            box-shadow: 0 2px 8px rgba(56, 189, 248, 0.3);
        }
        .segment-btn:hover:not(.active) {
            color: #F8FAFC;
            background: rgba(255, 255, 255, 0.05);
        }

        /* Main Workspace layout */
        .app-container {
            display: flex;
            flex: 1;
            overflow: hidden;
            position: relative;
        }
        
        #network { 
            flex: 1; 
            height: 100%; 
            background: #0B0F19; 
        }

        /* Sidebar styling */
        .sidebar {
            width: 360px;
            background: rgba(17, 24, 39, 0.8);
            backdrop-filter: blur(16px);
            border-right: 1px solid rgba(51, 65, 85, 0.5);
            display: flex;
            flex-direction: column;
            overflow-y: auto;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            z-index: 10;
        }
        .sidebar.collapsed {
            width: 0;
            border-right: none;
        }
        
        .sidebar-section {
            padding: 20px;
            border-bottom: 1px solid rgba(51, 65, 85, 0.3);
        }
        .sidebar-section:last-child {
            border-bottom: none;
        }
        .sidebar-title {
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: #64748B;
            margin-bottom: 14px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        /* Node Info Card */
        .info-card {
            background: rgba(30, 41, 59, 0.4);
            border: 1px solid rgba(51, 65, 85, 0.4);
            border-radius: 12px;
            padding: 16px;
            display: flex;
            flex-direction: column;
            gap: 10px;
        }
        .info-header {
            font-size: 16px;
            font-weight: 600;
            color: #F8FAFC;
            word-break: break-all;
        }
        .info-row {
            display: flex;
            flex-direction: column;
            gap: 4px;
        }
        .info-label {
            font-size: 11px;
            color: #64748B;
            text-transform: uppercase;
            font-weight: 500;
        }
        .info-value {
            font-size: 13px;
            color: #CBD5E1;
            word-break: break-all;
        }
        .info-value.filepath {
            font-family: monospace;
            background: rgba(15, 23, 42, 0.5);
            padding: 4px 8px;
            border-radius: 4px;
            border: 1px solid rgba(51, 65, 85, 0.3);
        }

        .btn-primary {
            background: linear-gradient(135deg, #0EA5E9 0%, #0284C7 100%);
            color: white;
            border: none;
            padding: 10px 16px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            transition: all 0.2s;
            box-shadow: 0 4px 12px rgba(14, 165, 233, 0.25);
            margin-top: 6px;
        }
        .btn-primary:hover {
            transform: translateY(-1px);
            box-shadow: 0 6px 16px rgba(14, 165, 233, 0.35);
        }
        .btn-primary:active {
            transform: translateY(0);
        }
        .btn-primary:disabled {
            background: rgba(51, 65, 85, 0.5);
            color: #64748B;
            box-shadow: none;
            cursor: not-allowed;
            transform: none;
        }

        /* Neighborhood Lists */
        .node-list {
            list-style: none;
            display: flex;
            flex-direction: column;
            gap: 8px;
            max-height: 250px;
            overflow-y: auto;
        }
        .node-item {
            background: rgba(30, 41, 59, 0.25);
            border: 1px solid rgba(51, 65, 85, 0.2);
            border-radius: 8px;
            padding: 8px 12px;
            font-size: 13px;
            color: #CBD5E1;
            cursor: pointer;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
        }
        .node-item:hover {
            background: rgba(56, 189, 248, 0.1);
            border-color: rgba(56, 189, 248, 0.4);
            color: #38BDF8;
            transform: translateX(2px);
        }
        .node-item-label {
            font-weight: 500;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        .node-item-relation {
            font-size: 10px;
            background: rgba(15, 23, 42, 0.6);
            color: #64748B;
            padding: 2px 6px;
            border-radius: 4px;
            border: 1px solid rgba(51, 65, 85, 0.2);
        }
        
        .empty-text {
            font-size: 13px;
            color: #64748B;
            font-style: italic;
            text-align: center;
            padding: 10px 0;
        }
        
        /* Depth Selector */
        .depth-control {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: rgba(15, 23, 42, 0.4);
            padding: 8px 12px;
            border-radius: 8px;
            border: 1px solid rgba(51, 65, 85, 0.3);
            margin-bottom: 12px;
        }
        .depth-select {
            background: #1E293B;
            border: 1px solid rgba(51, 65, 85, 0.6);
            color: #F8FAFC;
            padding: 4px 8px;
            border-radius: 4px;
            outline: none;
            font-size: 12px;
            cursor: pointer;
        }

        /* Tooltip styling */
        div.vis-tooltip {
            background-color: #1E293B !important;
            color: #F8FAFC !important;
            border: 1px solid rgba(255, 255, 255, 0.1) !important;
            border-radius: 12px !important;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5) !important;
            font-family: 'Outfit', sans-serif !important;
            padding: 10px 14px !important;
            font-size: 13px !important;
            line-height: 1.5 !important;
        }
        
        /* Legends and badges */
        .legend-dot {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 6px;
        }
        .legend-target { background: #F43F5E; }
        .legend-upstream { background: #0EA5E9; }
        .legend-downstream { background: #10B981; }
    </style>
</head>
<body>
    <header>
        <h1>
            <span>
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#38BDF8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:-3px; margin-right:6px;">
                    <path d="M9.5 3.5A4.5 4.5 0 0 0 5 8c0 1.25.5 2.4 1.3 3.2A4.5 4.5 0 0 0 5 15.5c0 2.2 1.6 4 3.7 4.4"/>
                    <path d="M14.5 3.5A4.5 4.5 0 0 1 19 8c0 1.25-.5 2.4-1.3 3.2A4.5 4.5 0 0 1 19 15.5c0 2.2-1.6 4-3.7 4.4"/>
                    <path d="M12 3v18" stroke-dasharray="2 2"/>
                    <circle cx="12" cy="12" r="1.5" fill="#38BDF8"/>
                </svg>DevMind Knowledge Graph
            </span> 
            <span class="badge">v3.0</span>
        </h1>
        
        <div class="header-center">
            <div class="segmented-control">
                <button class="segment-btn active" id="btnFull" onclick="setViewMode('full')">Global Graph</button>
                <button class="segment-btn" id="btnImpact" onclick="setViewMode('impact')">Impact Path</button>
            </div>
            
            <div class="stats">
                <span>Nodes: <b>__NODES_COUNT__</b></span>
                <span>Edges: <b>__EDGES_COUNT__</b></span>
            </div>
        </div>
        
        <div class="controls">
            <div class="search-container">
                <span class="search-icon">
                    <svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
                </span>
                <input type="text" id="searchInput" placeholder="Search symbol, file or node..." oninput="filterGraph()">
            </div>
        </div>
    </header>

    <div class="app-container">
        <!-- Sidebar for details -->
        <div class="sidebar" id="sidebar">
            <div class="sidebar-section">
                <div class="sidebar-title">
                    <span>Selection Details</span>
                    <span id="closeSidebarBtn" style="cursor: pointer; display: none;" onclick="clearSelection()">Clear</span>
                </div>
                <div id="noSelectionText" class="empty-text">
                    Select a node in the graph or search for a file/symbol to inspect its impact neighborhood.
                </div>
                <div id="selectionCard" class="info-card" style="display: none;">
                    <div class="info-header" id="nodeLabel">Node Name</div>
                    <div class="info-row">
                        <span class="info-label">File Type</span>
                        <span class="info-value" id="nodeFileType">code</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Source File</span>
                        <span class="info-value filepath" id="nodeSourceFile">file_path.py</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Location</span>
                        <span class="info-value" id="nodeLocation">Line 0</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Community ID</span>
                        <span class="info-value" id="nodeCommunity">0</span>
                    </div>
                    <button class="btn-primary" id="openFileBtn" onclick="openFileInEditor()">
                        <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path><polyline points="15 3 21 3 21 9"></polyline><line x1="10" y1="14" x2="21" y2="3"></line></svg>
                        Open File in VS Code
                    </button>
                </div>
            </div>

            <!-- Impact Controls (Visible only when node selected or searched) -->
            <div class="sidebar-section" id="impactControlsSection" style="display: none;">
                <div class="sidebar-title">Impact Scope</div>
                <div class="depth-control">
                    <span style="font-size: 13px; color: #CBD5E1;">Analysis Depth</span>
                    <select class="depth-select" id="depthSelect" onchange="changeDepth()">
                        <option value="1">1 (Direct Neighbors)</option>
                        <option value="2" selected>2 (Transitive)</option>
                        <option value="3">3 (Deep)</option>
                        <option value="all">All Connected</option>
                    </select>
                </div>
            </div>

            <div class="sidebar-section" id="upstreamSection" style="display: none;">
                <div class="sidebar-title">
                    <span>Upstream Dependencies</span>
                    <span class="badge" style="background:#0EA5E9;" id="upstreamCount">0</span>
                </div>
                <ul class="node-list" id="upstreamList"></ul>
            </div>

            <div class="sidebar-section" id="downstreamSection" style="display: none;">
                <div class="sidebar-title">
                    <span>Downstream Dependents</span>
                    <span class="badge" style="background:#10B981;" id="downstreamCount">0</span>
                </div>
                <ul class="node-list" id="downstreamList"></ul>
            </div>
        </div>

        <!-- Vis.js network container -->
        <div id="network"></div>
    </div>

    <script type="text/javascript">
        const vscode = typeof acquireVsCodeApi === 'function' ? acquireVsCodeApi() : null;

        const rawNodesData = __VIS_NODES__;
        const edgesData = __VIS_EDGES__;

        // Index of nodes by ID for quick lookups
        const nodesById = {};
        rawNodesData.forEach(n => {
            nodesById[n.id] = n;
        });

        // Parse HTML title labels to readable DOM elements for tooltips
        const nodesData = rawNodesData.map(node => {
            const el = document.createElement('div');
            el.innerHTML = node.title;
            return {
                ...node,
                title: el,
                rawTitle: node.title
            };
        });

        const container = document.getElementById('network');
        const data = {
            nodes: new vis.DataSet(nodesData),
            edges: new vis.DataSet(edgesData)
        };
        
        const options = {
            nodes: {
                borderWidth: 2,
                shadow: true
            },
            edges: {
                width: 1.5,
                smooth: { type: 'continuous' }
            },
            physics: {
                stabilization: false,
                barnesHut: {
                    gravitationalConstant: -3000,
                    springLength: 120,
                    springConstant: 0.04
                }
            },
            interaction: {
                hover: true,
                tooltipDelay: 100
            }
        };

        const network = new vis.Network(container, data, options);

        // State variables
        let selectedNodeId = null;
        let viewMode = 'full'; // 'full' or 'impact'
        let currentDepth = 2;

        // Set view mode (full vs impact)
        function setViewMode(mode) {
            viewMode = mode;
            
            // Update UI buttons
            document.getElementById('btnFull').classList.toggle('active', mode === 'full');
            document.getElementById('btnImpact').classList.toggle('active', mode === 'impact');
            
            // Reapply filtering & highlighting
            applyFilteringAndHighlighting();
        }

        // Depth changed
        function changeDepth() {
            const val = document.getElementById('depthSelect').value;
            currentDepth = val === 'all' ? Infinity : parseInt(val, 10);
            applyFilteringAndHighlighting();
        }

        // Open active file in Editor
        function openFileInEditor() {
            if (!selectedNodeId || !vscode) return;
            const node = nodesById[selectedNodeId];
            if (node && node.source_file) {
                vscode.postMessage({
                    command: 'openFile',
                    filePath: node.source_file
                });
            }
        }

        // Select a node by ID and show details
        function selectNodeAndShowDetails(nodeId) {
            selectedNodeId = nodeId;
            const node = nodesById[nodeId];
            if (!node) {
                clearSelection();
                return;
            }

            // Update UI card
            document.getElementById('noSelectionText').style.display = 'none';
            document.getElementById('selectionCard').style.display = 'flex';
            document.getElementById('closeSidebarBtn').style.display = 'inline';
            document.getElementById('nodeLabel').innerText = node.label;
            document.getElementById('nodeFileType').innerText = node.shape === 'box' ? 'document/file' : 'symbol/code';
            document.getElementById('nodeSourceFile').innerText = node.source_file || 'N/A';
            document.getElementById('nodeLocation').innerText = node.source_location || 'N/A';
            document.getElementById('nodeCommunity').innerText = node.community;
            
            // Enable/disable open file button
            const openBtn = document.getElementById('openFileBtn');
            if (node.source_file) {
                openBtn.disabled = false;
                openBtn.style.opacity = '1';
            } else {
                openBtn.disabled = true;
                openBtn.style.opacity = '0.5';
            }

            // Update neighborhood lists
            updateNeighborhoodUI(nodeId);
            
            // Focus in network
            network.selectNodes([nodeId]);
            
            // Re-apply filter/highlighting
            applyFilteringAndHighlighting();
        }

        // Update lists in sidebar
        function updateNeighborhoodUI(nodeId) {
            const { upstream, downstream } = getNeighborhood([nodeId], 1); // direct neighbors for the sidebar listing
            
            const upstreamList = document.getElementById('upstreamList');
            const downstreamList = document.getElementById('downstreamList');
            
            upstreamList.innerHTML = '';
            downstreamList.innerHTML = '';
            
            // Render upstream
            document.getElementById('upstreamSection').style.display = 'block';
            document.getElementById('upstreamCount').innerText = upstream.size;
            if (upstream.size > 0) {
                upstream.forEach(id => {
                    const uNode = nodesById[id];
                    if (uNode) {
                        const li = document.createElement('li');
                        li.className = 'node-item';
                        li.onclick = () => selectNodeAndShowDetails(id);
                        
                        // Find relation/edge label if any
                        const edge = edgesData.find(e => e.from === id && e.to === nodeId);
                        const relLabel = edge ? edge.label : '';
                        
                        li.innerHTML = `
                            <span class="node-item-label" title="${uNode.label}">${uNode.label}</span>
                            ${relLabel ? `<span class="node-item-relation">${relLabel}</span>` : ''}
                        `;
                        upstreamList.appendChild(li);
                    }
                });
            } else {
                upstreamList.innerHTML = '<div class="empty-text">No dependencies</div>';
            }

            // Render downstream
            document.getElementById('downstreamSection').style.display = 'block';
            document.getElementById('downstreamCount').innerText = downstream.size;
            if (downstream.size > 0) {
                downstream.forEach(id => {
                    const dNode = nodesById[id];
                    if (dNode) {
                        const li = document.createElement('li');
                        li.className = 'node-item';
                        li.onclick = () => selectNodeAndShowDetails(id);
                        
                        // Find relation/edge label if any
                        const edge = edgesData.find(e => e.from === nodeId && e.to === id);
                        const relLabel = edge ? edge.label : '';
                        
                        li.innerHTML = `
                            <span class="node-item-label" title="${dNode.label}">${dNode.label}</span>
                            ${relLabel ? `<span class="node-item-relation">${relLabel}</span>` : ''}
                        `;
                        downstreamList.appendChild(li);
                    }
                });
            } else {
                downstreamList.innerHTML = '<div class="empty-text">No dependents</div>';
            }

            document.getElementById('impactControlsSection').style.display = 'block';
        }

        // Clear active selection
        function clearSelection() {
            selectedNodeId = null;
            document.getElementById('selectionCard').style.display = 'none';
            document.getElementById('noSelectionText').style.display = 'block';
            document.getElementById('closeSidebarBtn').style.display = 'none';
            document.getElementById('upstreamSection').style.display = 'none';
            document.getElementById('downstreamSection').style.display = 'none';
            document.getElementById('impactControlsSection').style.display = 'none';
            
            network.unselectAll();
            applyFilteringAndHighlighting();
        }

        // Calculate neighborhood using BFS
        function getNeighborhood(targetIds, maxDepth = Infinity) {
            const visited = new Set(targetIds);
            const upstream = new Set();
            const downstream = new Set();
            
            const incoming = {};
            const outgoing = {};
            
            edgesData.forEach(edge => {
                const from = edge.from;
                const to = edge.to;
                if (!outgoing[from]) outgoing[from] = [];
                outgoing[from].push(to);
                
                if (!incoming[to]) incoming[to] = [];
                incoming[to].push(from);
            });
            
            // BFS Upstream
            let queue = targetIds.map(id => ({ id, depth: 0 }));
            while (queue.length > 0) {
                const { id, depth } = queue.shift();
                if (depth >= maxDepth) continue;
                
                const parents = incoming[id] || [];
                parents.forEach(p => {
                    if (!visited.has(p) && !upstream.has(p)) {
                        upstream.add(p);
                        queue.push({ id: p, depth: depth + 1 });
                    }
                });
            }
            
            // BFS Downstream
            queue = targetIds.map(id => ({ id, depth: 0 }));
            while (queue.length > 0) {
                const { id, depth } = queue.shift();
                if (depth >= maxDepth) continue;
                
                const children = outgoing[id] || [];
                children.forEach(c => {
                    if (!visited.has(c) && !downstream.has(c)) {
                        downstream.add(c);
                        queue.push({ id: c, depth: depth + 1 });
                    }
                });
            }
            
            return { upstream, downstream };
        }

        // Apply filtering and highlighting based on state
        function applyFilteringAndHighlighting() {
            const query = document.getElementById('searchInput').value.toLowerCase();
            const depthLimit = currentDepth;

            // Step 1: Find matched nodes from search query
            let matchedIds = [];
            if (query) {
                matchedIds = nodesData.filter(node => 
                    node.label.toLowerCase().includes(query) || 
                    (node.rawTitle && node.rawTitle.toLowerCase().includes(query)) ||
                    (node.id && node.id.toLowerCase().includes(query))
                ).map(n => n.id);
            }

            // Target Node ID to build neighborhood around
            // Priority: Clicked node > Best match from query
            let targetId = selectedNodeId;
            if (!targetId && matchedIds.length > 0) {
                targetId = matchedIds[0];
            }

            // Step 2: Compute neighborhood if we have a target node
            let upstream = new Set();
            let downstream = new Set();
            if (targetId) {
                const neighborhood = getNeighborhood([targetId], depthLimit);
                upstream = neighborhood.upstream;
                downstream = neighborhood.downstream;
            }

            // Step 3: Update Nodes DataSet
            const updatedNodes = nodesData.map(node => {
                const isTarget = node.id === targetId;
                const isUpstream = upstream.has(node.id);
                const isDownstream = downstream.has(node.id);
                const isMatched = query ? matchedIds.includes(node.id) : false;
                
                const isPartofImpactPath = isTarget || isUpstream || isDownstream;

                if (viewMode === 'impact') {
                    // Impact view: show only target, upstream, and downstream. Hide everything else.
                    const isVisible = targetId ? isPartofImpactPath : (query ? isMatched : true);
                    let color = node.color;
                    
                    if (targetId && isPartofImpactPath) {
                        color = isTarget ? { background: '#F43F5E', border: '#FFFFFF' } :
                                isUpstream ? { background: '#0EA5E9', border: '#0284C7' } :
                                { background: '#10B981', border: '#064E3B' };
                    }

                    return {
                        ...node,
                        hidden: !isVisible,
                        color: color
                    };
                } else {
                    // Global/Full Graph view: show all nodes, but highlight impact path or query matches, dim others.
                    let color = node.color;
                    
                    if (targetId) {
                        // Highlight target, upstream, downstream. Dim others.
                        if (isPartofImpactPath) {
                            color = isTarget ? { background: '#F43F5E', border: '#FFFFFF' } :
                                    isUpstream ? { background: '#0EA5E9', border: '#0284C7' } :
                                    { background: '#10B981', border: '#064E3B' };
                        } else {
                            color = { background: '#1E293B', border: '#334155' }; // dimmed
                        }
                    } else if (query) {
                        // Highlight matches, dim others.
                        if (isMatched) {
                            color = { background: '#EF4444', border: '#FFFFFF' };
                        } else {
                            color = { background: '#1E293B', border: '#334155' };
                        }
                    }

                    return {
                        ...node,
                        hidden: false,
                        color: color
                    };
                }
            });
            data.nodes.update(updatedNodes);

            // Step 4: Update Edges DataSet
            const updatedEdges = edgesData.map(edge => {
                const fromVisible = edge.from === targetId || upstream.has(edge.from) || downstream.has(edge.from);
                const toVisible = edge.to === targetId || upstream.has(edge.to) || downstream.has(edge.to);
                const isPartofImpact = fromVisible && toVisible;

                if (viewMode === 'impact') {
                    return {
                        ...edge,
                        hidden: targetId ? !isPartofImpact : false,
                        color: { color: '#38BDF8', highlight: '#F43F5E' }
                    };
                } else {
                    return {
                        ...edge,
                        hidden: false,
                        color: targetId ? 
                            (isPartofImpact ? { color: '#38BDF8', highlight: '#F43F5E' } : { color: '#1E293B' }) :
                            { color: '#475569', highlight: '#38BDF8' }
                    };
                }
            });
            data.edges.update(updatedEdges);

            // Select node and center in view
            if (targetId) {
                network.selectNodes([targetId]);
                network.focus(targetId, { scale: 1.0, animation: { duration: 500 } });
            }
        }

        // Handle network selection directly
        network.on("selectNode", function (params) {
            if (params.nodes.length > 0) {
                selectNodeAndShowDetails(params.nodes[0]);
            }
        });

        network.on("deselectNode", function (params) {
            // Delay clear to check if we are selecting another node
            setTimeout(() => {
                if (network.getSelectedNodes().length === 0) {
                    clearSelection();
                }
            }, 100);
        });

        // Handle search query
        function filterGraph(queryVal) {
            const query = (queryVal !== undefined ? queryVal : document.getElementById('searchInput').value).toLowerCase();
            if (queryVal !== undefined) {
                document.getElementById('searchInput').value = queryVal;
            }

            if (query) {
                // Find node that matches
                const matched = nodesData.filter(node => 
                    node.label.toLowerCase().includes(query) || 
                    (node.id && node.id.toLowerCase().includes(query))
                );
                
                if (matched.length > 0) {
                    // Auto-select and show details of the first match
                    // This switches view to show its neighborhood
                    selectNodeAndShowDetails(matched[0].id);
                } else {
                    applyFilteringAndHighlighting();
                }
            } else {
                clearSelection();
            }
        }

        // Listen for message from VS Code extension
        window.addEventListener('message', event => {
            const message = event.data;
            if (message && message.type === 'search') {
                const query = message.query || '';
                
                // If it is opened from "impact analysis", default viewMode to 'impact'!
                setViewMode('impact');
                filterGraph(query);
            }
        });
    </script>
</body>
</html>
"""

    html_content = html_template.replace("__VIS_NODES__", json.dumps(vis_nodes))
    html_content = html_content.replace("__VIS_EDGES__", json.dumps(vis_edges))
    html_content = html_content.replace("__NODES_COUNT__", str(len(nodes)))
    html_content = html_content.replace("__EDGES_COUNT__", str(len(links)))

    with html_path.open("w", encoding="utf-8") as f:
        f.write(html_content)

    print(f"Successfully generated HTML Graph Visualization: {html_path}")

if __name__ == "__main__":
    base_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    json_p = base_dir / "graphify-out" / "graph.json"
    html_p = base_dir / "graphify-out" / "graph.html"
    generate_html_graph(json_p, html_p)
