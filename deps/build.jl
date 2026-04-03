# deps/build.jl
# For local development only. Overrides [sources] entries in Project.toml with
# local copies when found, so edits are picked up immediately via Revise.jl.
#
# Resolution order for each package:
#   1. Env var <PKG>_PATH         — e.g. OMPARSER_PATH=/path/to/OMParser.jl
#   2. Sibling directory           — ../PackageName.jl relative to this project
#
# If neither is found the package is left to [sources] / Pkg.instantiate().
# Run this script once after cloning: julia --project deps/build.jl

import Pkg

const PROJECT_DIR = dirname(dirname(abspath(@__FILE__)))

const PACKAGES = ["MetaModelica", "Absyn", "OMParser"]

Pkg.activate(PROJECT_DIR)

developed_any = false

for name in PACKAGES
    env_key = uppercase(name) * "_PATH"
    explicit = get(ENV, env_key, "")
    local_path = if !isempty(explicit) && isdir(explicit)
        abspath(explicit)
    else
        sibling = abspath(joinpath(PROJECT_DIR, "..", name * ".jl"))
        isdir(sibling) ? sibling : nothing
    end

    if local_path !== nothing
        println("$name: developing from $local_path")
        Pkg.develop(path = local_path)
        developed_any = true
    else
        println("$name: no local copy found, using [sources]")
    end
end

if developed_any
    println("\nRun `Pkg.instantiate()` (or restart with --project) to resolve remaining deps.")
end
