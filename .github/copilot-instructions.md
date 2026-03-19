# Copilot Instructions for Contoso Creative Writer

## Architecture

This is a multi-agent creative writing assistant built on Azure AI Foundry. A user provides a topic and instructions, and an orchestrated pipeline of AI agents produces a magazine-style article.

### Agent pipeline (`src/api/api/agents/orchestrator.py`)

The `write_article` generator drives this sequence:

1. **Researcher** — uses the Foundry Agent Service with `web_search_preview` tool to search the web for source material. Returns a research summary with URL citations.
2. **Product** — performs semantic similarity search against an Azure AI Search index (`contoso-products`) using text-embedding-ada-002 embeddings to find relevant Contoso products.
3. **Writer** — combines research + product data into a 300–500 word article using GPT-4o. Output is split on `---` into article and feedback sections.
4. **Editor** — reviews the article and returns a JSON decision (`accept`/reject) with feedback. If rejected, the orchestrator loops back through researcher → writer → editor (max 2 retries).
5. **Designer** — (defined but not currently called in the main pipeline).

Each agent has a `.prompty` file (prompt template) and a `.py` file (execution logic). Prompty files use Jinja2-style templating (`{{ }}`, `{% %}`) and are loaded via `promptflow.core.Prompty` or `promptflow.core.Flow`.

### Streaming response protocol

The API streams results as newline-delimited JSON chunks prefixed with `>>>`. Each chunk has `{ "type": "<agent_name>", "contents": <data> }`. The React frontend parses these by splitting on `>>>`.

### Services

- **Backend** (`src/api`): Python Flask app. Entry point is `api/app.py`. Single route: `GET /get_article?context=...&instructions=...`.
- **Frontend** (`src/web`): React + TypeScript app using Vite, Primer React components, and Redux Toolkit for state management.
- **Infrastructure** (`infra/`): Terraform configs for Azure AI Foundry (AIServices + project), AKS, Azure AI Search, Key Vault, ACR, and Application Insights.

## Build & Run Commands

### API (from `src/api`)

```bash
pip install -r requirements.txt
flask --debug --app api.app:app run --port 5000
```

Run the orchestrator directly (no web server):
```bash
python -m api.agents.orchestrator
```

### Web frontend (from `src/web`)

```bash
npm install
npm run dev      # dev server
npm run build    # production build (tsc && vite build)
npm run lint     # eslint
```

### Docker

```bash
docker-compose up    # runs both api (:5000) and web (:3000)
```

### Evaluation (from `src/api`)

```bash
python -m api.evaluate.evaluate
```

This runs the full orchestrator against `eval_inputs.jsonl` and scores results using promptflow evaluators (relevance, fluency, coherence, groundedness) with GPT-4.

### Deploy

```bash
azd auth login
azd up            # provisions infrastructure and deploys
```

## Key Conventions

- **Agent structure**: Each agent lives in `src/api/api/agents/<name>/` with a `.prompty` file for the prompt template and a `.py` file for execution. Follow this pattern when adding new agents.
- **Model configuration**: Prompty files define default model settings, but Python code overrides them with `AzureOpenAIModelConfiguration` at runtime using environment variables. The prompty defaults are not authoritative.
- **Environment variables**: Configured via `.env` file in `src/api/` (see `.env.sample`). Key vars: `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT_NAME` (GPT-4o), `AZURE_OPENAI_35_TURBO_DEPLOYMENT_NAME` (GPT-4o-mini), `AZURE_OPENAI_API_VERSION`, `FOUNDRY_PROJECT_ENDPOINT`, `AZURE_SEARCH_ENDPOINT`.
- **Authentication**: Uses `DefaultAzureCredential` (managed identity) for all Azure services including Azure OpenAI, AI Search, and the Foundry Agent Service.
- **Tracing**: All agent functions are decorated with `@trace` from `promptflow.tracing`. Telemetry goes to Application Insights when `APPLICATIONINSIGHTS_CONNECTION_STRING` is set. Local tracing uses PromptFlow's built-in tracing server.
- **Evaluation runs in background**: When tracing is active, `evaluate_article_in_background` spawns a thread to run evaluators without blocking the response stream.
- **Research format**: The researcher returns `{ "summary": str, "citations": [{ "url": str, "title": str }] }`. The writer prompty expects this structure.
