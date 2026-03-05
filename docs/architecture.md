# Ember AI Platform

Ember AI is an internal, secure, and performant AI orchestration platform. It is designed to act as the central nervous system for internal AI operations, seamlessly integrating various AI models, internal data sources (via Retrieval-Augmented Generation), and tools (via MCP servers).

## Core Principles

1. **Zero-Trust Security**: All access to the platform and its components must be securely routed and authenticated via OpenZiti (EmberNet Flux). The platform is strictly for internal use.
2. **Modularity & Flexibility**: Components must be loosely coupled, allowing for easy swapping of models, vector databases, or orchestration tools.
3. **High Performance**: Caching layers and optimized routing ensure low-latency responses for end-users.

## Architecture Overview

The Ember AI platform is composed of the following core technologies:

### 1. Zero-Trust Access Layer (`OpenZiti` / `EmberNet Flux`)

- **Purpose**: Provides secure, authenticated, internal-only access to all underlying services without exposing them to the public internet.
- **Role**: All user requests and internal service-to-service communication (where applicable) are gated through OpenZiti access policies.

### 2. Identity & Access Management (`Keycloak` - External)

- **Purpose**: Provides Single Sign-On (SSO) and centralized identity management.
- **Role**: Applications (n8n, LiteLLM) authenticate users via OpenID Connect (OIDC) or SAML through the external Keycloak instance. This ensures unified role-based access control and limits access to authorized personnel.

### 3. Secrets Management (`Bitwarden`)

- **Purpose**: Secure, centralized storage for all operational secrets and API keys.
- **Role**: Injects secrets (e.g., LLM provider keys, database credentials) securely into the K3s environment, preventing secrets from being hardcoded or exposed in configuration files.

### 4. API Gateway & Domain Configuration (`LiteLLM`)

- **Purpose**: Acts as the central router and standardizer for all LLM API calls.
- **Role**:
  - Standardizes inputs and outputs across different LLM providers (OpenAI, Anthropic, local models, etc.).
  - Handles API key management, rate limiting, and cost tracking.
  - Serves as the primary entry point for any service needing LLM inferences.

### 5. Workflow & Orchestration Engine (`n8n`)

- **Purpose**: Connects different services, databases, and logic flows seamlessly.
- **Role**:
  - Routes requests between the user/frontend, the LLM gateway (LiteLLM), RAG databases, and external tools/APIs.
  - Orchestrates Model Context Protocol (MCP) servers to give the LLMs access to internal systems and tools.
  - Manages the logic for multi-step AI tasks and data ingestion pipelines.

### 6. Caching & Fast Storage (`Valkey`)

- **Purpose**: High-performance, open-source, in-memory data structure store (Redis alternative).
- **Role**:
  - Caches frequent LLM responses to reduce latency and API costs.
  - Stores temporary session data, conversation history, and workflow states for n8n.
  - Facilitates fast queuing for asynchronous AI tasks.

### 7. RAG Storage (`pgvector` / `PostgreSQL`)

- **Purpose**: Relational database with vector extension to store numerical representations (embeddings) of company data for semantic search and Retrieval-Augmented Generation.
- **Role**: Allows the AI to "read" and reference internal documents accurately before answering queries.
- **Benefits**: Can be deployed as a single cluster alongside n8n's required backend, reducing the number of distinct services to maintain.

## High-Level Data Flow

1. **Request Initiation & Authentication**: A client (user or internal app) connects via OpenZiti (EmberNet Flux). The user is prompted to authenticate via Keycloak (SSO) before accessing the n8n or LiteLLM interfaces.
2. **Orchestration**: The request hits an n8n webhook or triggered workflow.
3. **Context Gathering (RAG)**: If the task requires specialized knowledge, n8n queries the RAG Database for relevant document chunks.
4. **Tool Use (MCP)**: If the task requires action (e.g., querying an internal API, fetching a Jira ticket), n8n communicates with the relevant MCP servers.
5. **Inference**: n8n complies the system prompt, user prompt, retrieved context, and tool schemas, and sends this payload to LiteLLM.
6. **LLM Execution**: LiteLLM routes the request to the configured LLM, handles fallbacks, and logs the transaction.
7. **Response & Caching**: The response is returned to n8n, cached in Valkey if applicable, and finally delivered back to the client.
