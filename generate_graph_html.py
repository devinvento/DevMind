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
            "color": {
                "background": color,
                "border": "#1E293B",
                "highlight": {"background": "#F43F5E", "border": "#FFFFFF"}
            },
            "shape": shape,
            "font": {"color": "#F8FAFC", "face": "Inter, sans-serif", "size": 14},
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

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Graphify Knowledge Graph Visualizer</title>
    <script type="text/javascript" src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js"></script>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }}
        body {{ background-color: #0F172A; color: #F8FAFC; overflow: hidden; height: 100vh; display: flex; flex-direction: column; }}
        header {{ background: #1E293B; padding: 16px 24px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #334155; }}
        h1 {{ font-size: 18px; font-weight: 600; color: #38BDF8; display: flex; align-items: center; gap: 8px; }}
        .badge {{ background: #0284C7; color: white; padding: 2px 8px; border-radius: 12px; font-size: 12px; }}
        .controls {{ display: flex; gap: 12px; align-items: center; }}
        input[type="text"] {{ background: #0F172A; border: 1px solid #334155; color: #F8FAFC; padding: 6px 12px; border-radius: 6px; outline: none; font-size: 14px; width: 220px; }}
        input[type="text"]:focus {{ border-color: #38BDF8; }}
        #network {{ flex: 1; width: 100%; height: 100%; background: #0F172A; }}
        .stats {{ font-size: 13px; color: #94A3B8; display: flex; gap: 16px; }}
        div.vis-tooltip {{
            background-color: #1E293B !important;
            color: #F8FAFC !important;
            border: 1px solid #334155 !important;
            border-radius: 8px !important;
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.5) !important;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
            padding: 8px 12px !important;
            font-size: 13px !important;
            line-height: 1.5 !important;
        }}
    </style>
</head>
<body>
    <header>
        <h1><span><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#38BDF8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:-3px; margin-right:6px;"><path d="M9.5 3.5A4.5 4.5 0 0 0 5 8c0 1.25.5 2.4 1.3 3.2A4.5 4.5 0 0 0 5 15.5c0 2.2 1.6 4 3.7 4.4"/><path d="M14.5 3.5A4.5 4.5 0 0 1 19 8c0 1.25-.5 2.4-1.3 3.2A4.5 4.5 0 0 1 19 15.5c0 2.2-1.6 4-3.7 4.4"/><path d="M12 3v18" stroke-dasharray="2 2"/><circle cx="12" cy="12" r="1.5" fill="#38BDF8"/></svg>DevMind Knowledge Graph</span> <span class="badge">v2.0</span></h1>
        <div class="stats">
            <span>Nodes: <b>{len(nodes)}</b></span>
            <span>Edges: <b>{len(links)}</b></span>
        </div>
        <div class="controls">
            <input type="text" id="searchInput" placeholder="Search node or file..." oninput="filterGraph()">
        </div>
    </header>
    <div id="network"></div>

    <script type="text/javascript">
        const rawNodesData = {json.dumps(vis_nodes)};
        const edgesData = {json.dumps(vis_edges)};

        const nodesData = rawNodesData.map(node => {{
            const el = document.createElement('div');
            el.innerHTML = node.title;
            return {{
                ...node,
                title: el,
                rawTitle: node.title
            }};
        }});

        const container = document.getElementById('network');
        const data = {{
            nodes: new vis.DataSet(nodesData),
            edges: new vis.DataSet(edgesData)
        }};
        
        const options = {{
            nodes: {{
                borderWidth: 2,
                shadow: true
            }},
            edges: {{
                width: 1.5,
                smooth: {{ type: 'continuous' }}
            }},
            physics: {{
                stabilization: false,
                barnesHut: {{
                    gravitationalConstant: -3000,
                    springLength: 120,
                    springConstant: 0.04
                }}
            }},
            interaction: {{
                hover: true,
                tooltipDelay: 100
            }}
        }};

        const network = new vis.Network(container, data, options);

        function filterGraph(queryVal) {{
            const query = (queryVal !== undefined ? queryVal : document.getElementById('searchInput').value).toLowerCase();
            if (queryVal !== undefined) {{
                document.getElementById('searchInput').value = queryVal;
            }}
            const filteredNodes = nodesData.map(node => {{
                const match = node.label.toLowerCase().includes(query) || 
                              (node.rawTitle && node.rawTitle.toLowerCase().includes(query)) ||
                              (node.id && node.id.toLowerCase().includes(query));
                return {{
                    ...node,
                    hidden: query ? !match : false
                }};
            }});
            data.nodes.update(filteredNodes);

            if (query) {{
                const matchingIds = nodesData.filter(node => 
                    node.label.toLowerCase().includes(query) || 
                    (node.id && node.id.toLowerCase().includes(query))
                ).map(n => n.id);

                if (matchingIds.length > 0 && matchingIds.length <= 10) {{
                    network.selectNodes(matchingIds);
                    network.focus(matchingIds[0], {{ scale: 1.2, animation: true }});
                }}
            }}
        }}

        window.addEventListener('message', event => {{
            const message = event.data;
            if (message && message.type === 'search') {{
                filterGraph(message.query || '');
            }}
        }});
    </script>
</body>
</html>
"""

    with html_path.open("w", encoding="utf-8") as f:
        f.write(html_content)

    print(f"Successfully generated HTML Graph Visualization: {html_path}")

if __name__ == "__main__":
    base_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    json_p = base_dir / "graphify-out" / "graph.json"
    html_p = base_dir / "graphify-out" / "graph.html"
    generate_html_graph(json_p, html_p)
