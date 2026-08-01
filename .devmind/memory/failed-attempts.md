# Failed Approaches & Retrospectives

This log documents past technical attempts that failed or produced undesirable outcomes to prevent repeating past mistakes.

### 1. Manual Context Construction
- **Attempt**: Manually copying file snippets into chat prompts.
- **Result**: Lead to incomplete context, hallucinated symbols, and missed dependency couplings.
- **Solution**: Automated Graphify knowledge graph (`graphify-out/graph.json`) and live MCP server integration.
