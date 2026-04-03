@testset "Parser — HelloWorld.mo" begin
    path   = joinpath(FIXTURE_DIR, "HelloWorld.mo")
    chunks = Parser.parse_file(path)

    @test length(chunks) == 1

    c = only(chunks)
    @test c.symbol_name == "HelloWorld"
    @test c.symbol_type == "model"
    @test c.start_line >= 1
    @test c.end_line >= c.start_line
    @test !isempty(c.content)
    @test contains(c.content, "HelloWorld")
    @test c.file_path == path
end

@testset "Parser — BreakingPendulum.mo (multiple classes per file)" begin
    path   = joinpath(FIXTURE_DIR, "BreakingPendulum.mo")
    chunks = Parser.parse_file(path)
    names  = [c.symbol_name for c in chunks]

    @test "BouncingBall"    in names
    @test "Pendulum"        in names
    @test "BreakingPendulum" in names

    for c in chunks
        @test c.start_line >= 1
        @test c.end_line >= c.start_line
        @test !isempty(c.content)
        @test c.file_path == path
    end
end

@testset "Parser — Influenza.mo (connectors and components)" begin
    path   = joinpath(FIXTURE_DIR, "Influenza.mo")
    chunks = Parser.parse_file(path)

    @test length(chunks) >= 1
    for c in chunks
        @test c.start_line >= 1
        @test c.end_line >= c.start_line
        @test !isempty(c.content)
    end
end

@testset "Parser — Casc12800.mo" begin
    path   = joinpath(FIXTURE_DIR, "Casc12800.mo")
    chunks = Parser.parse_file(path)

    @test length(chunks) == 1
    @test chunks[1].symbol_name == "Casc12800"
    @test chunks[1].symbol_type == "model"
end

@testset "Parser — msl.mo (Modelica Standard Library)" begin
    path   = joinpath(FIXTURE_DIR, "msl.mo")
    chunks = Parser.parse_file(path)
    names  = [c.symbol_name for c in chunks]
    types  = [c.symbol_type for c in chunks]

    # The MSL contains thousands of classes
    @test length(chunks) > 500

    # Packages must NOT be emitted as chunks
    @test !("package" in types)

    # All chunks have valid, non-empty content
    @test all(c.start_line >= 1 for c in chunks)
    @test all(c.end_line >= c.start_line for c in chunks)
    @test all(!isempty(c.content) for c in chunks)

    # Qualified names: MSL classes live inside packages, so names contain dots
    @test any(contains(n, ".") for n in names)

    # A few known MSL classes must be present
    @test any(endswith(n, "Resistor")   for n in names)
    @test any(endswith(n, "Capacitor")  for n in names)
    @test any(endswith(n, "Inductor")   for n in names)

    # Every chunk's content contains its own (unqualified) class name
    for c in chunks
        local_name = split(c.symbol_name, ".")[end]
        @test contains(c.content, local_name)
    end
end
