# Foresight Engine

US-focused adaptation of [amadad/mirofish](https://github.com/amadad/mirofish) (itself an English fork of [666ghj/MiroFish](https://github.com/666ghj/MiroFish)). A multi-agent swarm intelligence prediction engine. Upload documents describing any scenario, and Foresight Engine simulates AI agents reacting on social media to predict how events will unfold.

This is v0 software: a powerful concept that is still maturing. Outputs are plausible scenario exploration, not probability estimates. There are no published accuracy benchmarks.

## Tech Stack

- **Frontend**: Vue 3 + Vite + D3.js (graph visualization), served on port 3000
- **Backend**: Python 3.11+ Flask, served on port 5001
- **Graph DB**: KuzuDB (embedded, no external service needed)
- **Simulation**: OASIS (camel-ai/oasis) multi-agent social media simulation
- **LLM**: Anthropic Claude API (primary), OpenAI (secondary/fallback). Claude Code CLI is for local dev only, not suitable for multi-user production.
- **Package managers**: npm (frontend), uv (backend Python)

## The 5-Stage Pipeline

1. **Graph Building** (Step1GraphBuild.vue / `build_graph.py`) -- Upload documents (PDF, markdown, text). LLM extracts entities and relationships into a knowledge graph stored in KuzuDB.
2. **Environment Setup** (Step2EnvSetup.vue / `prepare_simulation.py`) -- Filter entities, generate AI agent personas. Each agent gets a unique personality, background, stance on the topic, influence level, and long-term memory.
3. **Simulation** (Step3Simulation.vue / `run_simulation.py`) -- OASIS runs as a subprocess (via `scripts/run_twitter_simulation.py` and `scripts/run_reddit_simulation.py`) for a dual-platform simulation where agents post, reply, like, argue, and follow each other.
4. **Report Generation** (Step4Report.vue / `generate_report.py`) -- A ReACT agent with tool-calling analyzes all simulation data and produces prediction findings.
5. **Deep Interaction** (Step5Interaction.vue / report API) -- Chat with the report agent or interview individual simulated agents.

## Backend Architecture

The backend is being refactored toward a "workbench pattern" with pluggable resource adapters and composable tools.

Key services in `backend/app/services/`:

| Service | Role |
|---------|------|
| `graph_storage.py` | GraphStorage abstraction with KuzuDB and JSON backends |
| `entity_extractor.py` | LLM-based entity and relationship extraction |
| `graph_builder.py` | Ontology-to-graph pipeline |
| `simulation_runner.py` | OASIS subprocess management |
| `report_agent.py` | ReACT agent with tool-calling for report generation |
| `graph_tools.py` | Search, interview, and analysis tools for the report agent |
| `oasis_profile_generator.py` | Generates agent personas with personality, stance, and influence |
| `simulation_config_generator.py` | Builds OASIS simulation configs from graph data |
| `graph_memory_updater.py` | Updates knowledge graph with simulation results |

Core infrastructure in `backend/app/core/`:
- `workbench_session.py` -- Session state for a single prediction workbench
- `session_manager.py` -- Registry of active sessions
- `task_manager.py` -- Async task tracking for long-running operations
- `resource_loader.py` -- Pluggable resource adapter loader

## File Structure

```
frontend/                  Vue 3 + Vite SPA
  src/
    components/            Step1-Step5 pipeline components, GraphPanel, HistoryDatabase
    views/                 Home, MainView, Process, SimulationView, ReportView, InteractionView
    api/                   Axios API clients (graph, simulation, report)
    store/                 Vue state (pendingUpload)
    router/                Vue Router config
backend/
  app/
    api/                   Flask REST endpoints (graph.py, simulation.py, report.py)
    core/                  Workbench session, session registry, resource loader, task manager
    resources/             Adapters: projects, documents, KuzuDB graph, simulations, reports, LLM provider
    tools/                 Composable pipeline operations (ingest, build, prepare, run, report)
    services/              Business logic (see Backend Architecture above)
    utils/                 LLM client (multi-provider), file parser, logger, retry helpers
    config.py              Central config (reads .env)
  scripts/                 Standalone OASIS simulation runners (Twitter, Reddit, parallel)
  uploads/                 Runtime data: workbench sessions, simulations, tasks
  data/                    KuzuDB database files, JSON graph fallback
codex-proxy/               Docker sidecar for routing Codex CLI traffic (Docker deployments only)
docs/                      Project documentation
```

## Key Commands

```bash
# Install everything (frontend npm + backend Python via uv)
npm run setup:all

# Run both dev servers concurrently (frontend :3000, backend :5001)
npm run dev

# Run servers individually
npm run frontend          # Vite dev server on port 3000
npm run backend           # Flask on port 5001

# Build frontend for production
npm run build

# Docker (single container serves API + built frontend)
docker compose up -d --build
```

## Coding Conventions

- Write in active voice, use Oxford commas, no em dashes (use commas or parentheses instead)
- **Frontend**: Vue 3 Composition API with `<script setup>`, NOT React
- **Backend**: Flask, NOT FastAPI or Django
- **LLM calls**: Default to Anthropic Claude API for all new code. The LLM client lives at `backend/app/utils/llm_client.py`
- All prompts, UI text, and agent personas must be in English and US-context-aware
- Keep explanations clear for someone comfortable with code but not a full-time developer

## LLM Provider Config

Set in `.env`. Default is `anthropic` with `claude-sonnet-4-20250514`.

| Provider | Env vars needed |
|----------|----------------|
| `anthropic` | `LLM_API_KEY`, `LLM_MODEL_NAME` |
| `openai` | `LLM_API_KEY`, `LLM_MODEL_NAME`, optionally `LLM_BASE_URL` |
| `claude-cli` | Just `LLM_PROVIDER=claude-cli` (local dev only, uses Claude Code subscription) |
| `codex-cli` | Just `LLM_PROVIDER=codex-cli` (local dev only, uses Codex CLI subscription) |

### Model Strategy

Use cheaper models for high-volume calls, stronger models for quality-critical steps:

| Pipeline Stage | Recommended Model | Why |
|---------------|-------------------|-----|
| Entity extraction | Claude Sonnet | Accuracy matters, low volume |
| Agent persona generation | Claude Sonnet | Quality matters, low volume |
| Agent reasoning (simulation) | Claude Haiku or GPT-4o-mini | High volume, cost-sensitive |
| Report generation | Claude Sonnet | Quality matters, uses ReACT tools |
| Deep interaction chat | Claude Sonnet | User-facing, quality matters |

## LLM Cost Breakdown

Simulations consume significant tokens. Each round triggers multiple LLM calls per agent.

| Stage | Approximate Cost |
|-------|-----------------|
| Graph building (entity extraction) | A few cents |
| Agent persona generation | A few cents |
| Full simulation (100 agents, 20 rounds) | $1-10+ depending on prompt length |
| Report generation (ReACT agent) | Moderate (multiple tool calls) |

**Start with fewer than 40 rounds.** Monitor your [Anthropic dashboard](https://console.anthropic.com) during runs.

## Known Limitations

- **No accuracy benchmarks.** Outputs are plausible scenario exploration, not calibrated probability estimates.
- **Herd behavior bias.** OASIS research notes that LLM agents polarize faster than real humans. Simulation results may overstate consensus.
- **v0 maturity.** The upstream MiroFish project and this adaptation are both early-stage. Expect rough edges, especially around error handling and edge cases.
- **Single-model per run.** The current LLM client uses one model for all calls in a run. The multi-model strategy (cheap for simulation, strong for extraction) requires code changes.

## US Adaptation Goals

These are the planned changes to differentiate Foresight Engine from upstream MiroFish:

- [x] All UI, prompts, and agent personas fully English and US-context-aware
- [ ] Seed material optimized for US news sources, SEC filings, policy documents, financial reports
- [ ] Authentication and user accounts
- [ ] Rate limiting per user
- [ ] Stripe integration for usage-based billing
- [ ] Custom landing page and onboarding flow
- [ ] Multi-model support (cheap models for simulation, strong models for extraction/reports)

## Current Status (updated 2026-03-31)

Pipeline validated end-to-end through Stage 4 (Report Generation) with the NIL collective collapse scenario (seed_nil_collective_collapse.md).

- **Graph visualization**: Working. D3 renders color-coded nodes (#168A53 green palette) and labeled edges (#2A3746 dark blue). 82 nodes, 59 edges for the NIL scenario.
- **Entity extraction**: Stable. Extracts 2-8 entities per chunk with full logging.
- **Simulation**: OASIS subprocess completes 10/10 rounds (Reddit platform). Twitter simulation untested in recent runs.
- **Report generation**: ReACT agent produces structured findings with tool-calling.
- **KuzuDB**: Connection caching and graceful lock retry are stable. Background build threads now push Flask app context to share cached connections with the API.
- **Total API spend**: ~$11 across all development and testing.

### Known Issues

- **Agent Interview**: Returns "No successful interviews" because the OASIS subprocess shuts down before the report agent can interview individual agents. Stage 5 (Deep Interaction) is untested.
- **Graph build thread context**: Fixed 2026-03-31. The build thread now pushes Flask app context (`build_graph.py`) so it shares KuzuDB connections with the API. Without this fix, the graph visualization panel shows empty data.

### Next Priorities

- Test Stage 5 (Deep Interaction / chat with agents)
- Docker build and Railway deployment
- D3 graph polish (node sizing by influence, better label positioning, zoom controls)

## Deployment Architecture

**Local development:**
- Frontend Vite dev server on port 3000 (proxies `/api/*` to backend)
- Backend Flask on port 5001

**Production (Docker):**
- Single container: Flask serves the built Vue frontend from `frontend/dist` and the API, all on port 5001
- Deployed to Railway.app

**Production (split):**
- Frontend static files on Cloudflare Pages
- Backend Docker container on Railway.app
- Frontend makes direct API calls to the Railway backend URL

## Licensing

- **Foresight Engine**: AGPL-3.0 (source must be public if deployed as a network service)
- **OASIS** (camel-ai/oasis): Apache 2.0

## Developer Context

The maintainer (Sam) is an MMS student at Duke Fuqua, comfortable with Python, SQL, and Excel but not a full-time developer. When making changes:
- Explain decisions and show real commands
- Flag cost implications for anything that triggers LLM calls
- Provide step-by-step guidance, not just code dumps
