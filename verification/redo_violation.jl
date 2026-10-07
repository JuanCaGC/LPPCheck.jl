# Rebuild the flagged instance, export J to Macaulay2, and recompute I's Betti table with
# several Oscar resolution algorithms. Does not modify the package.
using Oscar, LPPCheck, JSON3
d = JSON3.read(readline(open("results/main/VIOLATIONS.jsonl")))
inst = make_instance(d.seed, d.n, collect(d.a), Symbol(d.kind))
S,_ = graded_polynomial_ring(QQ, ["x$i" for i in 1:inst.n])
fs = [build_poly(S,p) for p in inst.fs]; ex = [build_poly(S,p) for p in inst.extras]
I = ideal(S, vcat(fs, ex))
rep = check_instance(I, fs, inst.a)
L = lpp_ideal(S, inst.a, rep.HF_I, rep.dmax)
open("verification/violation_J.m2","w") do io
    println(io, "R = QQ[x1,x2,x3,x4];")
    println(io, "J = ideal(", join(["x1^$(m[1])*x2^$(m[2])*x3^$(m[3])*x4^$(m[4])" for m in L.gens], ", "), ");")
    println(io, "print betti res J; print(\"pd S/J = \" | toString pdim(R^1/J));")
end
println("Oscar default I:  ", sort(collect(LPPCheck.betti_dict(I))))
Q,_ = quo(S,I)
for alg in (:mres, :sres, :fres, :nres)
    try
        F = free_resolution(Q; algorithm = alg)
        B = Oscar.as_dictionary(minimal_betti_table(F))
        println(alg, " -> max p = ", maximum(k[1] for k in keys(B)), ", total = ", sum(values(B)))
    catch e
        println(alg, " -> ", sprint(showerror, e)[1:min(end,100)])
    end
end
