# Flagged "violation" of (C): n=4, a=(3,3,3,4), kind=neardeg_mono, seed=4 — FALSE POSITIVE

Found by `scripts/run_sweep.jl --suite main` (700/2250 jobs done, sweep stopped itself). Files:
`../results/main/VIOLATIONS.jsonl` (raw record), `violation_n4_a3334_seed4.{m2,sing}` (ideal I),
`violation_J.m2` (J), `redo_violation.jl` (recomputation script). Everything is over QQ.

* Reported: beta_{5,13}(S/I) = 1 > beta_{5,13}(S/J) = 0; HF(S/I) = HF(S/J), (A) and (B) hold.
* beta_5 is impossible: S has 4 variables, so pd(S/I) <= 4 (Hilbert syzygy theorem).
* Macaulay2 `res I` (default, Strategy 1, Strategy 2): pd 4, total 84 = 1+7+28+35+13, no (5,13).
* Oscar `free_resolution(...; algorithm=:mres)` and `:nres`: max p = 4, total 84.
  Oscar default (`:fres`): max p = 5, total 85. So the extra entry comes from Oscar 1.8.2's default
  resolution + `minimal_betti_table` on this ideal (cause not investigated; Oscar bug or misuse).
* With the M2 table for S/I, beta(S/I) <= beta(S/J) holds entrywise (J table from M2: total 132).

Conclusion: not a counterexample. Package code left UNCHANGED (as instructed). Proposed fix, pending approval:
use `:mres` as the primary algorithm, cross-check with `:nres` on every instance, report disagreement
or any beta_{p,*} with p > n as an explicit `algorithm_disagreement` flag instead of a (C) failure,
then re-run the sweep from scratch.
