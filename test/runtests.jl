using Test
using ModelicaRag
using ModelicaRag: Parser, Store

const FIXTURE_DIR = joinpath(
    dirname(Base.find_package("OMParser")), "..", "test"
) |> normpath

include("test_parser.jl")
include("test_store.jl")
include("test_integration.jl")
