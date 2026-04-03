module ModelicaRag

include("Parser.jl")
include("Embedder.jl")
include("Store.jl")
include("MCP.jl")
include("CLI.jl")

using .CLI: main
export main

end
