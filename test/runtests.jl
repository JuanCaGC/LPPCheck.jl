using Test, Oscar
using LPPCheck

@testset "LPPCheck" begin
    @testset "Betti tables are minimal" begin
        S, (x, y, z) = graded_polynomial_ring(QQ, ["x", "y", "z"])
        # Koszul complex of (x,y,z): 1,3,3,1 in degrees 0,1,2,3
        B = betti_dict(ideal(S, [x, y, z]))
        @test B == Dict((0,0)=>1, (1,1)=>3, (2,2)=>3, (3,3)=>1)
        # redundant generators must not inflate the minimal table
        B2 = betti_dict(ideal(S, [x, y, z, x + y, x*y]))
        @test B2 == B
        # CI (x^2,y^2,z^2): 1,3,3,1 in degrees 0,2,4,6
        B3 = betti_dict(ideal(S, [x^2, y^2, z^2]))
        @test B3 == Dict((0,0)=>1, (1,2)=>3, (2,4)=>3, (3,6)=>1)
    end

    @testset "regular sequence" begin
        S, (x, y, z) = graded_polynomial_ring(QQ, ["x", "y", "z"])
        for fs in ([x^2, y^2, z^2], [x^2+y*z, y^2+x*z, z^2+x*y], [x*y, y*z, x*z], [x^2, x*y, z^2], [x^2-y^2, x*y, z^3])
            @test LPPCheck.is_regular_sequence(fs) == LPPCheck.is_regular_sequence(fs; method = :codim)
        end
        @test LPPCheck.is_regular_sequence([x^2, y^2, z^2])
        @test !LPPCheck.is_regular_sequence([x*y, y*z, x*z])
        @test !LPPCheck.is_regular_sequence([x^2, x*y, z^2])
    end

    @testset "hand example n=3, a=(2,2,2)" begin
        S, (x, y, z) = graded_polynomial_ring(QQ, ["x", "y", "z"])
        # I = (x²,y²,z²,yz): HF(S/I) = 1,3,2,0.  Outside P in degree 2: xy>xz>yz, q_2 = 6-... 
        # dim I_2 = 4, dim P_2 = 3, q_2 = 1 -> J_2 = P_2 + xy.  q_3 = 1 -> xyz.
        I = ideal(S, [x^2, y^2, z^2, y*z])
        r = check_instance(I, [x^2, y^2, z^2], [2, 2, 2])
        @test r.HF_I == [1, 3, 2, 0, 0]
        @test r.q == [0, 0, 1, 1, 0]
        @test r.A && r.B && r.C
        L = lpp_ideal(S, [2,2,2], r.HF_I, r.dmax)
        @test [1,1,0] in L.monos[3]       # xy ∈ J_2
        @test !([0,1,1] in L.monos[3])    # yz ∉ J_2
        @test sort(L.gens) == sort([[2,0,0],[0,2,0],[0,0,2],[1,1,0]])
        # a non-LPP-like case with a non-monomial regular sequence
        fs = [x^2 + y*z, y^2 + x*z, z^2 + x*y]
        @test LPPCheck.is_regular_sequence(fs)
        r2 = check_instance(ideal(S, fs), fs, [2,2,2])
        @test r2.HF_I == [1,3,3,1,0]
        @test r2.A && r2.B && r2.C && r2.slack == 0
    end

    @testset "n=2 never fails" begin
        S, (x, y) = graded_polynomial_ring(QQ, ["x", "y"])
        fs = [x^2 + y^2, x*y]
        I = ideal(S, [fs..., x^2*y + 2*y^3 - x*y^2])
        r = check_instance(I, fs, [2, 2])
        @test r.A && r.B && r.C
    end

    @testset "monomial regular sequence (Mermin–Murai)" begin
        S, (x, y, z) = graded_polynomial_ring(QQ, ["x", "y", "z"])
        fs = [x^2, y^3, z^3]
        I = ideal(S, [fs..., x*y*z, y^2*z])
        r = check_instance(I, fs, [2, 3, 3])
        @test r.A && r.B && r.C
    end

    @testset "c = 0: lex ideal (Bigatti–Hulett–Pardue)" begin
        S, (x, y, z) = graded_polynomial_ring(QQ, ["x", "y", "z"])
        I = ideal(S, [x*y + z^2, y^2 - x*z, x^3 + y*z^2])
        r = check_instance(I, typeof(x)[], Int[])
        @test r.A && r.B && r.C
    end

    @testset "EGHViolation is raised, not hidden" begin
        S, _ = graded_polynomial_ring(QQ, ["x", "y"])
        # HF too large: more room than monomials outside P  -> q_d < 0
        @test_throws LPPCheck.EGHViolation lpp_ideal(S, [2, 2], [1, 2, 5, 0, 0], 4)
        # HF(S/I,2) = -1 is impossible: q_2 = 1 - (-1) = 2 > #outside P (= 1)
        @test_throws LPPCheck.EGHViolation lpp_ideal(S, [2, 2], [1, 2, -1, 0, 0], 4)
    end

    @testset "regression: Oscar :fres spurious beta_5 (verification/REPORT.md)" begin
        inst = make_instance(4, 4, [3, 3, 3, 4], :neardeg_mono)
        r = run_instance(inst).report
        @test r.algo_ok && r.A && r.B && r.C
        @test sum(values(r.betti_I)) == 84 && sum(values(r.betti_J)) == 132   # Macaulay2 values
    end
end
