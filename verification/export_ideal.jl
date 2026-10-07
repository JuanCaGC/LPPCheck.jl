# usage: julia --project=. verification/export_ideal.jl seed n "a1,a2,.." kind outprefix
# Rebuilds an instance, writes I and J as Macaulay2 scripts printing graded Betti tables.
using Oscar, LPPCheck
seed, n, a, kind, out = parse(Int, ARGS[1]), parse(Int, ARGS[2]), parse.(Int, split(ARGS[3], ",")), Symbol(ARGS[4]), ARGS[5]
inst = make_instance(seed, n, a, kind)
S,_ = graded_polynomial_ring(QQ, ["x$i" for i in 1:n])
fs = [build_poly(S,p) for p in inst.fs]; ex = filter(!iszero, [build_poly(S,p) for p in inst.extras])
I = ideal(S, vcat(fs, ex)); rep = check_instance(I, fs, inst.a)
L = lpp_ideal(S, inst.a, rep.HF_I, rep.dmax)
vars = join(["x$i" for i in 1:n], ",")
mono(m) = join(["x$i^$(m[i])" for i in 1:n if m[i] > 0], "*")
open(out * "_I.m2", "w") do io
    println(io, "R = QQ[$vars]; I = ideal(", join(string.(gens(I)), ", "), "); print betti res I; print(\"\\n\"); print toString(sum flatten entries (betti res I).matrix)")
end
open(out * "_J.m2", "w") do io
    println(io, "R = QQ[$vars]; J = ideal(", join([mono(m) for m in L.gens], ", "), "); print betti res J")
end
