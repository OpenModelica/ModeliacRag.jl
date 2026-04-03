# ModelicaRag.jl

Semantic search over Modelica libraries via a local RAG (Retrieval-Augmented Generation) pipeline. Parses Modelica source files using [OMParser.jl](https://github.com/OpenModelica/OMCompiler), embeds each class with a local embedding model, stores the index in SQLite, and exposes search through an [MCP](https://modelcontextprotocol.io) server that Claude Code can query.

## How it works

1. **Parse** — `OMParser.jl` parses each `.mo` file into an Absyn AST. The walker extracts every non-package class (model, function, record, block, connector, type, ...) as a chunk with its fully qualified name (e.g. `Modelica.Electrical.Analog.Basic.Resistor`) and source lines.
2. **Embed** — chunks are sent to a local embedding model (Ollama or llama-server). Only files that changed since the last run are re-indexed.
3. **Store** — embeddings are stored as binary blobs in SQLite alongside chunk metadata. Cosine similarity search is computed in Julia at query time.
4. **Serve** — an MCP stdio server exposes three tools: `search_codebase`, `lookup_symbol`, and `rebuild_index`.

## Requirements

- Julia 1.9+
- OMParser.jl (from the OM.jl monorepo)
- One of:
  - [Ollama](https://ollama.ai) with an embedding model (e.g. `nomic-embed-text`, `mxbai-embed-large`)
  - [llama.cpp](https://github.com/ggerganov/llama.cpp) `llama-server` with a GGUF embedding model

## Installation

```julia
import Pkg

# Develop the OM.jl local dependencies (adjust path as needed)
Pkg.develop(path="/path/to/OM.jl/OMParser.jl")

# Develop this package — runs setup.jl automatically via deps/build.jl
Pkg.develop(path="/path/to/ModelicaRag.jl")
```

`setup.jl` detects Ollama and llama-server on your system and writes a `config.toml`. If the Modelica library path is not found automatically, edit `config.toml` and set `[codebase] root`.

You can also run setup manually at any time (it will not overwrite an existing `config.toml`):

```
julia setup.jl
```

## Configuration

`config.toml` is machine-specific and not tracked by git. Copy the provided example and edit the paths:

```
cp config.toml.example config.toml
```

Then open `config.toml` and fill in the paths for your system. The key fields:

```toml
[embeddings]
backend    = "ollama"              # "ollama" or "llama"
url        = "http://localhost:11434"
model      = "nomic-embed-text"    # Ollama model; ignored for llama backend
batch_size = 32

[server]
# Only used when backend = "llama"
llama_server = "/path/to/llama.cpp/build/bin/llama-server"
model_path   = "/path/to/models/some-embedding-model.gguf"

[store]
path = "/path/to/ModelicaRag.jl/data/index.db"

[codebase]
root       = "/path/to/Modelica/library"
extensions = [".mo"]
```

When `backend = "ollama"`, pull a model first:

```
ollama pull nomic-embed-text
```

When `backend = "llama"`, Julia starts `llama-server` automatically if it is not already running.

## Usage

```julia
using ModelicaRag

# Build or update the index (incremental by default)
ModelicaRag.main(["index"])

# Force a full rebuild
ModelicaRag.main(["index", "--force"])

# Search from the REPL
ModelicaRag.main(["search", "thermal resistor", "--top-k", "5"])

# Start the MCP stdio server
ModelicaRag.main(["serve"])
```

A custom config path can be passed with `--config path/to/config.toml`.

## MCP integration (Claude Code)

Add `.mcp.json` to your Claude Code MCP settings, or symlink the included `.mcp.json` into a project:

```json
{
  "mcpServers": {
    "modelica-rag": {
      "command": "julia",
      "args": [
        "--project=/path/to/ModelicaRag.jl",
        "-e",
        "using ModelicaRag; ModelicaRag.main([\"serve\"])"
      ]
    }
  }
}
```

Once connected, three tools are available:

| Tool | Description |
|------|-------------|
| `search_codebase` | Semantic search over indexed Modelica classes |
| `lookup_symbol` | Exact lookup by qualified name (case-insensitive) |
| `rebuild_index` | Incremental or full index rebuild |

## Project structure

```
ModelicaRag.jl/
├── Project.toml
├── config.toml.example  # template — copy to config.toml and fill in paths
├── setup.jl             # auto-detects backend and library, writes config.toml
├── deps/build.jl        # local dev only: Pkg.develop local copies of OM packages
├── data/             # SQLite index (created on first run)
└── src/
    ├── ModelicaRag.jl   # package entry point
    ├── Parser.jl        # Absyn AST walker
    ├── Embedder.jl      # Ollama and llama-server backends
    ├── Store.jl         # SQLite storage and cosine similarity search
    ├── MCP.jl           # MCP stdio server
    └── CLI.jl           # index / serve / search commands
```
