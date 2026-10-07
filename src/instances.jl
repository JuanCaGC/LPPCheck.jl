# Reproducible instance generation. An instance is pure data (integer coefficients),
# so the same instance can be rebuilt over QQ or over GF(p).

using Random

const Poly = Vector{Tuple{Vector{Int},Int}}     # [(exponent vector, integer coeff)]

struct Instance
    seed::Int
    n::Int
    a::Vector{Int}
    kind::Symbol            # :generic, :sparse, :neardeg_mono, :neardeg_linear, :symmetric, :monomial
    fs::Vector{Poly}        # the regular-sequence candidates, deg fs[i] = a[i]
    extras::Vector{Poly}    # additional generators
end

"Σ over nonzero terms -> polynomial in S"
function build_poly(S, p::Poly)
    n = ngens(S)
    sum((c * prod(gen(S, i)^e[i] for i in 1:n) for (e, c) in p); init = zero(S))
end

function _clean(p::Poly)
    d = Dict{Vector{Int},Int}()
    for (e, c) in p
        d[e] = get(d, e, 0) + c
    end
    sort!([(e, c) for (e, c) in d if c != 0]; by = t -> t[1], rev = true)
end

_dense(rng, n, deg, cr) = _clean([(m, rand(rng, -cr:cr)) for m in monomials_lex(n, deg)])
_sparse(rng, n, deg, pr; cr = 2) = begin
    ms = monomials_lex(n, deg)
    p = _clean([(m, rand(rng, [-cr:-1; 1:cr])) for m in ms if rand(rng) < pr])
    isempty(p) ? [(rand(rng, ms), 1)] : p
end

function _linear_product(rng, n, deg)
    p = Poly([(zeros(Int, n), 1)])
    for _ in 1:deg
        l = Poly([(Base.setindex!(zeros(Int, n), 1, i), rand(rng, -1:1)) for i in 1:n])
        l = _clean(l); isempty(l) && (l = [(Base.setindex!(zeros(Int, n), 1, 1), 1)])
        p = _clean([(e1 .+ e2, c1 * c2) for (e1, c1) in p for (e2, c2) in l])
    end
    p
end

# "symmetric" family: the SEQUENCE is permuted by the cyclic group Z/n. For each degree one random
# dense form g is drawn and the k-th form of that degree is g with variables shifted cyclically
# by k. (Pointwise S_n-invariant forms span too small a space to ever be regular.)
function _cyclic_shift(p::Poly, k::Int)
    _clean([(circshift(e, k), c) for (e, c) in p])
end

"""
    make_fs(rng, n, a, kind)

kind ∈ :generic (dense, coefficients in −2..2), :sparse, :neardeg_mono (xi^ai plus a few
±1 terms), :neardeg_linear (product of random {−1,0,1} linear forms, plus a sparse
perturbation), :symmetric (S_n-invariant forms), :monomial (xi^ai).
"""
function make_fs(rng, n, a, kind)
    base = Dict{Int,Poly}(); used = Dict{Int,Int}()
    map(enumerate(a)) do (i, ai)
        if kind == :symmetric
            g = get!(() -> (q = _dense(rng, n, ai, 2); isempty(q) ? _sparse(rng, n, ai, 0.5) : q), base, ai)
            k = get(used, ai, 0); used[ai] = k + 1
            return _cyclic_shift(g, k)
        end
        p = _make_f(rng, n, i, ai, kind)
        isempty(p) ? _sparse(rng, n, ai, 0.3) : p     # a cancelled-to-zero form is replaced
    end
end

function _make_f(rng, n, i, ai, kind)
    begin
        if kind == :generic
            p = _dense(rng, n, ai, 2); isempty(p) ? _sparse(rng, n, ai, 0.5) : p
        elseif kind == :sparse
            _sparse(rng, n, ai, 0.3)
        elseif kind == :neardeg_mono
            m = Base.setindex!(zeros(Int, n), ai, i)
            _clean(vcat([(m, 1)], _sparse(rng, n, ai, 0.08, cr = 1)))
        elseif kind == :neardeg_linear
            _clean(vcat(_linear_product(rng, n, ai), _sparse(rng, n, ai, 0.05, cr = 1)))
        elseif kind == :monomial
            [(Base.setindex!(zeros(Int, n), ai, i), 1)]
        else
            error("unknown kind $kind")
        end
    end
end

"1–6 extra generators, degrees in [min(a), top]; monomials, binomials, or sparse forms."
function make_extras(rng, n, a, top)
    k = rand(rng, 1:6)
    map(1:k) do _
        d = rand(rng, minimum(a):top)
        t = rand(rng, 1:3)
        if t == 1
            [(rand(rng, monomials_lex(n, d)), 1)]
        elseif t == 2
            ms = monomials_lex(n, d)
            m1, m2 = rand(rng, ms), rand(rng, ms)
            m1 == m2 ? [(m1, 1)] : _clean([(m1, 1), (m2, rand(rng, [-1, 1]))])
        else
            _sparse(rng, n, d, 0.25, cr = 2)
        end
    end
end

"""
    make_instance(seed, n, a, kind) -> Instance

Fully determined by (seed, n, a, kind). The extras' top degree is the socle degree
Σ(ai−1) (Artinian case) — beyond it every form lies in the ideal anyway.
"""
function make_instance(seed::Int, n::Int, a::Vector{Int}, kind::Symbol)
    rng = Xoshiro(seed)
    fs = make_fs(rng, n, a, kind)
    # c = 0 (no powers): degrees 2..4 so the ideal is non-trivial but small
    top = isempty(a) ? 4 : max(maximum(a), socle_degree(a))
    ex = make_extras(rng, n, isempty(a) ? [2] : a, top)
    Instance(seed, n, a, kind, fs, ex)
end

"""
    run_instance(inst; field=QQ) -> NamedTuple

Builds ideals over `field`, discards non-regular fs (`regular=false`), otherwise runs
`check_instance`. Pure data in / pure data out (safe to ship between workers).
"""
function run_instance(inst::Instance; field = QQ)
    t0 = time()
    S, _ = graded_polynomial_ring(field, ["x$i" for i in 1:inst.n])
    fs = [build_poly(S, p) for p in inst.fs]
    ex = [build_poly(S, p) for p in inst.extras]
    ex = filter(!iszero, ex)
    reg = isempty(fs) || is_regular_sequence(fs)
    if !reg
        return (; inst.seed, inst.n, inst.a, inst.kind, regular = false, report = nothing,
                  runtime = time() - t0, fs = inst.fs, extras = inst.extras)
    end
    I = ideal(S, vcat(fs, ex))
    rep = check_instance(I, fs, inst.a)
    (; inst.seed, inst.n, inst.a, inst.kind, regular = true, report = rep,
       runtime = time() - t0, fs = inst.fs, extras = inst.extras)
end

# ---------------------------------------------------------------------------
# Plain-data job interface used by scripts/run_sweep.jl (worker side)
# ---------------------------------------------------------------------------

_betti_rows(B) = [[p, j, v] for ((p, j), v) in sort!(collect(B))]
_poly_rows(P) = [[[e, c] for (e, c) in p] for p in P]

"""
    run_job(seed, n, a, kind, p) -> Dict{String,Any}

p = 0 → QQ, p > 0 → GF(p). Returns only JSON-friendly data.
"""
function run_job(seed::Int, n::Int, a::Vector{Int}, kind::Symbol, p::Int)
    field = p == 0 ? QQ : GF(p)
    inst = make_instance(seed, n, a, kind)
    r = run_instance(inst; field)
    d = Dict{String,Any}("seed" => seed, "n" => n, "a" => a, "kind" => String(kind), "char" => p,
        "regular" => r.regular, "runtime" => r.runtime, "timeout" => false,
        "fs" => _poly_rows(inst.fs), "extras" => _poly_rows(inst.extras))
    if r.regular
        rep = r.report
        d["dmax"] = rep.dmax; d["HF_I"] = rep.HF_I; d["HF_J"] = rep.HF_J
        d["betti_I"] = _betti_rows(rep.betti_I); d["betti_J"] = _betti_rows(rep.betti_J)
        d["A"] = rep.A; d["B"] = rep.B; d["C"] = rep.C; d["slack"] = rep.slack
        d["q"] = rep.q; d["stable_tail"] = rep.stable_tail; d["algo_ok"] = rep.algo_ok; d["error"] = rep.error
    end
    d
end
export run_job
