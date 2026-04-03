#!/usr/bin/env julia
# setup.jl — detect embedding backend and Modelica library, generate config.toml.
# Safe to re-run: will NOT overwrite an existing config.toml.

const PROJECT_DIR = dirname(abspath(@__FILE__))
const CONFIG_PATH = joinpath(PROJECT_DIR, "config.toml")

if isfile(CONFIG_PATH)
    println("config.toml already exists — delete it to regenerate.")
    exit(0)
end

# ── detect Ollama ──────────────────────────────────────────────────────────

ollama_bin = Sys.which("ollama")
has_ollama = ollama_bin !== nothing

# ── detect llama-server ────────────────────────────────────────────────────

llama_candidates = [
    expanduser("~/llama.cpp/build/bin/llama-server"),
    "/usr/local/bin/llama-server",
    "/usr/bin/llama-server",
]
llama_exe_idx = findfirst(isfile, llama_candidates)
llama_exe     = llama_exe_idx !== nothing ? llama_candidates[llama_exe_idx] : ""

# ── find an embedding GGUF model ──────────────────────────────────────────

function find_embed_model()
    model_dirs = [expanduser("~/llama.cpp/models")]
    for d in model_dirs
        isdir(d) || continue
        candidates = filter(readdir(d)) do f
            endswith(f, ".gguf") && occursin("embed", lowercase(f))
        end
        isempty(candidates) || return joinpath(d, first(candidates))
    end
    return ""
end

gguf_model = find_embed_model()

# ── find Modelica Standard Library ────────────────────────────────────────

function find_modelica_library()
    search_roots = [
        "/usr/share/openmodelica/libraries",
        "/usr/lib/omlibrary",
        "/usr/local/lib/omlibrary",
        expanduser("~/.openmodelica/libraries"),
    ]
    for root in search_roots
        isdir(root) || continue
        for entry in readdir(root)
            if startswith(entry, "Modelica") && isdir(joinpath(root, entry))
                return joinpath(root, entry)
            end
        end
    end
    return ""
end

mo_lib = find_modelica_library()

# ── decide backend ─────────────────────────────────────────────────────────

backend   = has_ollama ? "ollama" : "llama"
embed_url = has_ollama ? "http://localhost:11434" : "http://localhost:8080"

# ── report ─────────────────────────────────────────────────────────────────

println("=== Modelica RAG Setup ===\n")

println("Embedding backend:")
if has_ollama
    println("  found  Ollama at $ollama_bin  →  backend = \"ollama\"")
else
    println("  miss   Ollama (not in PATH)")
end
if !isempty(llama_exe)
    println("  found  llama-server at $llama_exe")
else
    println("  miss   llama-server")
end
if !has_ollama && isempty(llama_exe)
    println("\n  WARNING: no embedding backend found.")
    println("  Install Ollama (https://ollama.ai) or build llama.cpp, then re-run setup.jl.")
end

println("\nGGUF model : $(isempty(gguf_model) ? "not found" : gguf_model)")
println("Modelica   : $(isempty(mo_lib)    ? "not found — set [codebase] root manually" : mo_lib)")
println()

# ── write config.toml ─────────────────────────────────────────────────────

mkpath(joinpath(PROJECT_DIR, "data"))

open(CONFIG_PATH, "w") do io
    write(io, """
[embeddings]
backend    = "$backend"
url        = "$embed_url"
model      = "nomic-embed-text"   # Ollama model name; ignored for llama backend
batch_size = 32

[server]
# Only used when backend = "llama". Julia starts llama-server automatically if needed.
llama_server = "$(isempty(llama_exe) ? "~/llama.cpp/build/bin/llama-server" : llama_exe)"
model_path   = "$(isempty(gguf_model) ? "~/llama.cpp/models/Qwen3-Embedding-8B-Q8_0.gguf" : gguf_model)"

[store]
path = "$(joinpath(PROJECT_DIR, "data", "index.db"))"

[codebase]
$(isempty(mo_lib) ? "# TODO: set this to your Modelica library path\nroot       = \"/path/to/Modelica/library\"" :
                    "root       = \"$mo_lib\"")
extensions = [".mo"]
""")
end

println("Written: $CONFIG_PATH")
isempty(mo_lib) && println("\n  ACTION REQUIRED: edit config.toml and set [codebase] root")
