# Ember AI Data Flow & Component Integration

## Detailed Component Roles

### LiteLLM

LiteLLM serves as our LLM abstraction layer. Instead of workflows connecting directly to OpenAI, Anthropic, or local models, everything points to the LiteLLM proxy.

- **Endpoint:** `http://litellm:4000`
- **Benefits:**
  - One unified API format (OpenAI format).
  - Automatic fallbacks (if GPT-4 is down, fallback to Claude-3).
  - Centralized cost tracking per user/app.
  - Caching responses via Valkey to reduce latency and spend.

### n8n (Orchestrator)

n8n is the nervous system.

- **RAG Workflows:**
  - **Ingestion:** Watch for new documents (e.g., in a shared drive or wiki), extract text, generate embeddings via LiteLLM, and store them in the Vector DB.
  - **Retrieval:** Receive user query from frontend -> Embed query -> Search Vector DB -> Inject results into prompt -> Query LiteLLM -> Return answer.
- **MCP (Model Context Protocol) Routing:**
  - n8n acts as the host/client for MCP servers.
  - When an LLM requires external data (e.g., "Check Jira for ticket 123"), n8n handles the protocol translation between the LLM's tool-call format and the specific MCP server.

### Valkey (Cache)

- High-speed semantic cache backend for LiteLLM.
- Session state storage for n8n webhooks.
- Ephemeral shared memory if we deploy custom Python worker scripts.

### OpenZiti (Network Security)

- Replaces traditional VPNs and secures all traffic via zero-trust overlays.
- Neither n8n nor LiteLLM are exposed to the internet.
- Developers and users access the platform via Ziti Desktop/Mobile Edges, ensuring strict access control, posture checks, and seamless connectivity without public IP exposure.

---

_Note: This architecture is currently in the Planning Phase._
