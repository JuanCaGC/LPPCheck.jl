"""
    LPPCheck

Computational stress test of the Eisenbud–Green–Harris (EGH) and lex-plus-powers
(LPP) statements, exactly as formulated in the project brief:

Let S = F[x1..xn] (char F = 0, standard grading, lex order x1 > ... > xn),
1 ≤ c ≤ n, 2 ≤ a1 ≤ ... ≤ ac, P = (x1^a1, ..., xc^ac), and I ⊆ S a homogeneous
ideal containing a homogeneous regular sequence f1..fc with deg fi = ai.
For each d let q_d = dim I_d − dim P_d and
J_d = P_d + span of the q_d lex-greatest degree-d monomials NOT in P.

  (A) J = ⊕ J_d is an ideal,
  (B) HF(S/I, d) = HF(S/J, d) for all d           [EGH],
  (C) β_{p,j}(S/I) ≤ β_{p,j}(S/J) for all p, j     [LPP].

Oscar API facts used (verified against Oscar 1.8.2, see README):
  * `hilbert_series(::MPolyQuoRing)` returns a tuple `(numerator, denominator)`.
  * `minimal_betti_table(::MPolyQuoRing)` gives the *minimal* graded Betti table;
    `betti_table(free_resolution(..))` is NOT guaranteed minimal.
  * `Oscar.as_dictionary(::BettiTable)` is `(p, degree) => count` (degree is the
    internal degree j, not j−p).
"""
module LPPCheck

using Oscar

# NB: `is_regular_sequence` is deliberately NOT exported (Oscar exports a function of that
# name); call it as `LPPCheck.is_regular_sequence`.
export hilbert_function_vec, lpp_ideal, is_ideal_degreewise,
       check_instance, betti_dict, ci_hilbert_function, LPPResult, InstanceReport,
       monomials_lex, socle_degree, regularity_bound, EGHViolation

# ---------------------------------------------------------------------------
# Monomials (exponent vectors) in lex order x1 > ... > xn
# ---------------------------------------------------------------------------

"""All degree-d exponent vectors in n variables, in DESCENDING lex order (x1 > ... > xn)."""
function monomials_lex(n::Int, d::Int)
    out = Vector{Vector{Int}}()
    cur = zeros(Int, n)
    function rec(i, rem)
        if i == n
            cur[n] = rem
            push!(out, copy(cur))
            return
        end
        for e in rem:-1:0
            cur[i] = e
            rec(i + 1, rem - e)
        end
    end
    n == 0 ? (d == 0 ? [Int[]] : Vector{Int}[]) : (rec(1, d); out)
end

"Is the monomial `m` in P = (x1^a1..xc^ac), i.e. m_i ≥ a_i for some i ≤ c?"
in_P(m::Vector{Int}, a::Vector{Int}) = any(i -> m[i] >= a[i], 1:length(a))

"Socle degree Σ(ai−1) of the complete intersection S/(f1..fc) (c = n)."
socle_degree(a::Vector{Int}) = sum((ai - 1 for ai in a); init = 0)

# ---------------------------------------------------------------------------
# Hilbert function helpers
# ---------------------------------------------------------------------------

"""Hilbert function of S/(x1^a1..xc^ac) (= that of any CI of type a) in degree d."""
function ci_hilbert_function(n::Int, a::Vector{Int}, d::Int)
    # coefficient of t^d in prod (1-t^ai)/(1-t)^n
    c = zeros(BigInt, d + 1); c[1] = 1
    for ai in a                      # multiply by (1 - t^ai)
        for k in d:-1:ai
            c[k+1] -= c[k+1-ai]
        end
    end
    for _ in 1:n                     # divide by (1-t): prefix sums
        for k in 2:d+1
            c[k] += c[k-1]
        end
    end
    Int(c[d+1])
end

"""
    hilbert_function_vec(I, dmax) -> Vector{Int}

[HF(S/I, 0), ..., HF(S/I, dmax)], from the exact Hilbert series of Oscar.
"""
function hilbert_function_vec(I::MPolyIdeal, dmax::Int)
    S = base_ring(I)
    Q, _ = quo(S, I)
    num, den = hilbert_series(Q)
    n = ngens(S)
    num, den = _plain(num), _plain(den)
    # den is (1-t)^k for the (possibly reduced) denominator; expand num/den to order dmax
    return _expand_series(num, den, dmax)
end

# Oscar returns the denominator as a FacElem (factored); evaluate to a plain polynomial.
_plain(p) = p isa Oscar.Hecke.FacElem ? Oscar.Hecke.evaluate(p) : p

function _coeffs(p, len)
    p = _plain(p)
    v = zeros(BigInt, len)
    for i in 0:min(Int(degree(p)), len - 1)
        v[i+1] = BigInt(coeff(p, i))
    end
    v
end

function _expand_series(num, den, dmax)
    # series = num / den; den has constant term 1.
    N = _coeffs(num, dmax + 1)
    Dn = _coeffs(den, dmax + 1)
    @assert Dn[1] == 1
    out = zeros(BigInt, dmax + 1)
    for k in 0:dmax
        s = N[k+1]
        for j in 1:k
            s -= Dn[j+1] * out[k-j+1]
        end
        out[k+1] = s
    end
    Int.(out)
end

# ---------------------------------------------------------------------------
# Regular sequences
# ---------------------------------------------------------------------------

"""
    is_regular_sequence(fs; method=:hilbert)

fs: homogeneous polynomials of S. Regular iff Hilbert series of S/(fs) equals
∏(1−z^ai)/(1−z)^n (:hilbert; exact and complete), or iff dim S/(f1..fi) = n−i for
every i (:codim; valid because S is Cohen–Macaulay and the fi are homogeneous).
"""
function is_regular_sequence(fs::Vector; method::Symbol = :hilbert)
    S = parent(first(fs))
    n = ngens(S)
    c = length(fs)
    c <= n || return false
    any(iszero, fs) && return false
    if method == :codim
        for i in 1:c
            Q, _ = quo(S, ideal(S, fs[1:i]))
            dim(Q) == n - i || return false
        end
        return true
    end
    Q, _ = quo(S, ideal(S, fs))
    num, den = hilbert_series(Q)
    num, den = _plain(num), _plain(den)
    a = [Int(total_degree(f)) for f in fs]
    Rt, t = polynomial_ring(ZZ, "t")
    # num/den == ∏(1-t^ai)/(1-t)^n   <=>   num*(1-t)^n == ∏(1-t^ai) * den
    dent = sum(coeff(den, i) * t^i for i in 0:Int(degree(den)); init = zero(Rt))
    numt = sum(coeff(num, i) * t^i for i in 0:Int(degree(num)); init = zero(Rt))
    lhs = numt * (1 - t)^n
    rhs = prod((1 - t^ai for ai in a); init = one(Rt)) * dent
    return lhs == rhs
end

# ---------------------------------------------------------------------------
# Betti tables
# ---------------------------------------------------------------------------

"""
    betti_dict(I; quotient=true) -> Dict{Tuple{Int,Int},Int}

Minimal graded Betti numbers β_{p,j}(S/I) (quotient=true, includes β_{0,0}=1)
or of I (quotient=false), as `(p, j) => count`, j = internal degree.
"""
function betti_dict(I::MPolyIdeal; quotient::Bool = true, algorithm::Symbol = :mres)
    S = base_ring(I)
    # Oscar 1.8.2's default :fres was observed to return a spurious β_{n+1,*} on some ideals
    # (verification/REPORT.md); :mres (Singular) agrees with Macaulay2, so it is the default here.
    B = if quotient
        Q, _ = quo(S, I)
        minimal_betti_table(free_resolution(Q; algorithm))
    else
        minimal_betti_table(free_resolution(I; algorithm))
    end
    D = Dict{Tuple{Int,Int},Int}()
    for ((p, deg), v) in Oscar.as_dictionary(B)
        D[(p, Int(deg[1]))] = v
    end
    D
end

# ---------------------------------------------------------------------------
# The LPP ideal J
# ---------------------------------------------------------------------------

"Raised when q_d is impossible: itself a counterexample to EGH (or a bug)."
struct EGHViolation <: Exception
    d::Int
    q::Int
    available::Int
    msg::String
end
Base.showerror(io::IO, e::EGHViolation) =
    print(io, "EGHViolation in degree ", e.d, ": q_d = ", e.q, ", monomials outside P = ", e.available, " (", e.msg, ")")

struct LPPResult
    S                                   # polynomial ring
    a::Vector{Int}
    monos::Vector{Set{Vector{Int}}}     # monos[d+1] = monomials of J_d
    q::Vector{Int}                      # q_d
    gens::Vector{Vector{Int}}           # minimal generators of the ideal generated by ⊕J_d (dmax-truncated)
    J::MPolyIdeal                       # the ideal generated by the above
    dmax::Int
end

"""
    lpp_ideal(S, a, HF_I, dmax) -> LPPResult

Builds J degree by degree (statement above):
  dim P_d = dim S_d − HF(S/P, d),   q_d = dim I_d − dim P_d = HF(S/P,d) − HF(S/I,d),
  J_d = P_d ∪ {q_d lex-greatest degree-d monomials not in P}.
Throws `EGHViolation` if q_d < 0 or q_d > #(monomials of degree d outside P).
HF_I[d+1] = HF(S/I, d) for d = 0..dmax.
"""
function lpp_ideal(S, a::Vector{Int}, HF_I::Vector{Int}, dmax::Int)
    n = ngens(S); c = length(a)
    monos = Vector{Set{Vector{Int}}}(undef, dmax + 1)
    qs = zeros(Int, dmax + 1)
    for d in 0:dmax
        all_m = monomials_lex(n, d)
        outside = [m for m in all_m if !in_P(m, a)]     # lex-descending
        q = length(outside) - HF_I[d+1]                  # = HF(S/P,d) − HF(S/I,d)
        # sanity: |outside| is HF(S/P, d)
        if q < 0 || q > length(outside)
            throw(EGHViolation(d, q, length(outside), "q_d outside [0, #monomials outside P]"))
        end
        # NB: |outside| = HF(S/P,d); q_d = HF(S/P,d) − HF(S/I,d) = dim I_d − dim P_d.
        # J_d = P_d + the q lex-greatest monomials outside P.
        Jd = Set{Vector{Int}}(m for m in all_m if in_P(m, a))
        for m in outside[1:q]
            push!(Jd, m)
        end
        monos[d+1] = Jd; qs[d+1] = q
    end
    gens = _min_gens(monos, n)
    J = ideal(S, [prod(gen(S, i)^m[i] for i in 1:n) for m in gens])
    LPPResult(S, a, monos, qs, gens, J, dmax)
end

# minimal generators of the ideal generated by the union of the J_d
function _min_gens(monos, n)
    gens = Vector{Vector{Int}}()
    for d in 1:length(monos)           # index d ↔ degree d−1
        prev = d == 1 ? Set{Vector{Int}}() : monos[d-1]
        for m in monos[d]
            covered = false
            for i in 1:n
                if m[i] > 0
                    m2 = copy(m); m2[i] -= 1
                    if m2 in prev
                        covered = true; break
                    end
                end
            end
            covered || push!(gens, m)
        end
    end
    gens
end

"""
    is_ideal_degreewise(L::LPPResult) -> Bool

Claim (A): explicitly verify x_i·J_d ⊆ J_{d+1} for all i and d < dmax.
"""
function is_ideal_degreewise(L::LPPResult)
    n = ngens(L.S)
    for d in 1:length(L.monos)-1
        for m in L.monos[d], i in 1:n
            m2 = copy(m); m2[i] += 1
            m2 in L.monos[d+1] || return false
        end
    end
    true
end

# ---------------------------------------------------------------------------
# Degree bounds
# ---------------------------------------------------------------------------

"""
    regularity_bound(I, a) -> Int

Degree up to which Hilbert functions / J are computed.

* Artinian case (c = n): S/I is a quotient of the CI S/(f), whose socle degree is
  s = Σ(ai−1); hence I_d = S_d = J_d for d > s, so degrees ≤ s+1 determine
  everything (J is then generated in degrees ≤ s+1 and (A) holds beyond because
  J_d = S_d for d ≥ s+1).
* c < n: dmax = max(reg(I), Σ_{i≤c}(ai−1)) + n + 1, where reg(I) is read from the minimal
  Betti table of I. HF(S/I,d) is a polynomial for d ≥ reg(I) − 1 (Castelnuovo–Mumford),
  while the lex-plus-powers part is controlled by the Gotzmann-type stabilisation; the
  extra `n+1` margin is a HEURISTIC, not a proof, and `check_instance` additionally
  reports whether J acquires minimal generators in the last n+1 degrees
  (`stable_tail`).
"""
function regularity_bound(I::MPolyIdeal, a::Vector{Int}; n = ngens(base_ring(I)))
    c = length(a)
    s = socle_degree(a)
    if c == n
        return s + 1
    end
    B = betti_dict(I; quotient = false)
    reg = maximum(j - p for ((p, j), _) in B)
    return max(reg, s) + n + 1
end

# ---------------------------------------------------------------------------
# Full instance check
# ---------------------------------------------------------------------------

Base.@kwdef struct InstanceReport
    n::Int
    a::Vector{Int}
    dmax::Int
    HF_I::Vector{Int}
    HF_J::Vector{Int}
    betti_I::Dict{Tuple{Int,Int},Int}
    betti_J::Dict{Tuple{Int,Int},Int}
    A::Bool
    B::Bool
    C::Bool
    q::Vector{Int}
    slack::Int
    stable_tail::Bool
    error::String = ""
    algo_ok::Bool = true      # :mres agrees with :nres or :fres on I and J, and no β_{p,*} with p > n
end

"""
    check_instance(I, fs, a) -> InstanceReport

I: ideal (must contain fs); fs: the regular sequence; a: degrees (sorted, length c).
Computes q_d, J, (A), (B), (C). Does NOT alter anything to make claims pass: an
`EGHViolation` is caught and reported in `error` with A=B=C=false.
"""
function check_instance(I::MPolyIdeal, fs::Vector, a::Vector{Int})
    S = base_ring(I)
    n = ngens(S)
    dmax = regularity_bound(I, a; n = n)
    HF_I = hilbert_function_vec(I, dmax)
    bI = betti_dict(I)
    bI2 = betti_dict(I; algorithm = :nres); bI3 = betti_dict(I; algorithm = :fres)
    L = try
        lpp_ideal(S, a, HF_I, dmax)
    catch e
        e isa EGHViolation || rethrow()
        return InstanceReport(; n, a, dmax, HF_I, HF_J = Int[], betti_I = bI,
            betti_J = Dict{Tuple{Int,Int},Int}(), A = false, B = false, C = false,
            q = Int[], slack = 0, stable_tail = false, error = sprint(showerror, e))
    end
    A = is_ideal_degreewise(L)
    # (B): independent recomputation of HF(S/J) with Oscar (J as generated by J_d's)
    HF_J = hilbert_function_vec(L.J, dmax)
    Bok = A && HF_J == HF_I
    bJ = betti_dict(L.J)
    bJ2 = betti_dict(L.J; algorithm = :nres); bJ3 = betti_dict(L.J; algorithm = :fres)
    # Oscar's :nres and :fres each returned wrong tables on some ideals (checked against Macaulay2),
    # so :mres is accepted if it agrees with at least one of them (majority vote of three).
    algo_ok = (bI == bI2 || bI == bI3) && (bJ == bJ2 || bJ == bJ3) &&
              all(p <= n for ((p, _), _) in bI) && all(p <= n for ((p, _), _) in bJ)
    # (C): β_{p,j}(S/I) ≤ β_{p,j}(S/J) for all (p,j)
    Cok = all(v <= get(bJ, k, 0) for (k, v) in bI)
    slack = sum(values(bJ)) - sum(values(bI))
    # stability heuristic for c<n: no new minimal generators in the last n+1 degrees
    tail = all(sum(values(L.gens[i])) <= dmax - n for i in eachindex(L.gens)) ||
           length(a) == n
    InstanceReport(; n, a, dmax, HF_I, HF_J, betti_I = bI, betti_J = bJ,
        A, B = Bok, C = Cok, q = L.q, slack, stable_tail = tail, algo_ok)
end

include("instances.jl")
export Instance, make_instance, run_instance, build_poly

end # module
