using LinearAlgebra: normalize

# Helper: build a minimal named-tuple chunk compatible with store.jl
function fake_chunk(name; file = "test.mo", line = 1, typ = "model", content = "model $name end $name;")
    (file_path = file, start_line = line, end_line = line + 5,
     symbol_name = name, symbol_type = typ, content = content)
end

@testset "Store — open and empty" begin
    db = Store.open_store(tempname() * ".db")
    @test Store.chunk_count(db) == 0
    @test isempty(Store.get_indexed_mtimes(db))
end

@testset "Store — insert and count" begin
    db  = Store.open_store(tempname() * ".db")
    vec = Float32[1.0, 0.0, 0.0]
    Store.insert_chunk(db, fake_chunk("M"), vec)
    @test Store.chunk_count(db) == 1
end

@testset "Store — cosine similarity: exact match scores 1.0" begin
    db  = Store.open_store(tempname() * ".db")
    vec = normalize(Float32[1.0, 2.0, 3.0])
    Store.insert_chunk(db, fake_chunk("X"), vec)

    results = Store.search_chunks(db, vec, 1)
    @test length(results) == 1
    @test results[1].similarity ≈ 1.0f0 atol = 1e-6
    @test results[1].chunk.symbol_name == "X"
end

@testset "Store — cosine similarity ordering" begin
    db = Store.open_store(tempname() * ".db")

    # Three vectors at known angles from the query [1, 0, 0]
    Store.insert_chunk(db, fake_chunk("A"), Float32[1.0, 0.0, 0.0])  # cos = 1.0
    Store.insert_chunk(db, fake_chunk("B"), Float32[0.0, 1.0, 0.0])  # cos = 0.0
    Store.insert_chunk(db, fake_chunk("C"), Float32[1.0, 1.0, 0.0])  # cos ≈ 0.707

    query   = Float32[1.0, 0.0, 0.0]
    results = Store.search_chunks(db, query, 3)
    ranked  = [r.chunk.symbol_name for r in results]

    @test ranked[1] == "A"
    @test ranked[2] == "C"
    @test ranked[3] == "B"
end

@testset "Store — lookup_symbol (case-insensitive)" begin
    db  = Store.open_store(tempname() * ".db")
    vec = Float32[1.0, 0.0, 0.0]
    Store.insert_chunk(db, fake_chunk("Resistor"), vec)

    @test length(Store.lookup_symbol(db, "Resistor")) == 1
    @test length(Store.lookup_symbol(db, "resistor")) == 1
    @test length(Store.lookup_symbol(db, "RESISTOR")) == 1
    @test isempty(Store.lookup_symbol(db, "Capacitor"))
end

@testset "Store — mtime tracking" begin
    db = Store.open_store(tempname() * ".db")

    Store.set_file_mtime(db, "a.mo", 1000.0)
    Store.set_file_mtime(db, "b.mo", 2000.0)
    mtimes = Store.get_indexed_mtimes(db)

    @test mtimes["a.mo"] == 1000.0
    @test mtimes["b.mo"] == 2000.0

    # Upsert — update existing mtime
    Store.set_file_mtime(db, "a.mo", 9999.0)
    @test Store.get_indexed_mtimes(db)["a.mo"] == 9999.0
end

@testset "Store — delete_file_chunks removes chunks and mtime" begin
    db  = Store.open_store(tempname() * ".db")
    vec = Float32[1.0, 0.0, 0.0]

    Store.insert_chunk(db, fake_chunk("M1"; file = "keep.mo"), vec)
    Store.insert_chunk(db, fake_chunk("M2"; file = "drop.mo"), vec)
    Store.set_file_mtime(db, "keep.mo", 1.0)
    Store.set_file_mtime(db, "drop.mo", 2.0)

    Store.delete_file_chunks(db, "drop.mo")

    @test Store.chunk_count(db) == 1
    @test !haskey(Store.get_indexed_mtimes(db), "drop.mo")
    @test  haskey(Store.get_indexed_mtimes(db), "keep.mo")

    results = Store.search_chunks(db, vec, 5)
    @test all(r.chunk.symbol_name != "M2" for r in results)
end

@testset "Store — clear_store empties everything" begin
    db  = Store.open_store(tempname() * ".db")
    vec = Float32[1.0, 0.0, 0.0]
    Store.insert_chunk(db, fake_chunk("M"), vec)
    Store.set_file_mtime(db, "test.mo", 1.0)

    Store.clear_store(db)

    @test Store.chunk_count(db) == 0
    @test isempty(Store.get_indexed_mtimes(db))
end
