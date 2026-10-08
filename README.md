# LPPCheck.jl

Computational stress test of the **Eisenbud–Green–Harris (EGH)** and **lex-plus-powers (LPP)** statements, using exact arithmetic over ℚ in [Oscar.jl](https://www.oscar-system.org/).

> **Disclaimer.** Computational evidence is **not a proof**. A sweep that finds no counterexample says nothing rigorous about the general statement. This project is **not affiliated with, endorsed by, or connected to OpenAI**. The result being tested comes from OpenAI preprints that, to the author's knowledge, are **not peer-reviewed and not formalized** (e.g. in Lean).

## What is tested

Let `S = F[x1,…,xn]` (char F = 0, standard grading, lex order `x1 > … > xn`), `1 ≤ c ≤ n`, `2 ≤ a1 ≤ … ≤ ac`, `P = (x1^a1,…,xc^ac)`, and `I ⊆ S` a homogeneous ideal containing a homogeneous regular sequence `f1..fc` with `deg fi = ai` (arbitrary extra generators allowed). With `q_d = dim I_d − dim P_d`, let `J_d = P_d +` span of the `q_d` lex-greatest degree-`d` monomials not in `P`. The claims checked for every instance:

* **(A)** `J = ⊕ J_d` is an ideal (`x_i·J_d ⊆ J_{d+1}`, verified explicitly);
* **(B)** `HF(S/I,d) = HF(S/J,d)` for all `d` (EGH; `HF(S/J)` is recomputed independently by Oscar, and `lpp_ideal` throws `EGHViolation` if some `q_d` is impossible);
* **(C)** `β_{p,j}(S/I) ≤ β_{p,j}(S/J)` for all `p, j` (LPP, graded Betti numbers).

The tested claims are those of OpenAI's family 200 in <https://github.com/openai/math> (cite both):

```bibtex
@misc{OAI:The-Artinian-Lex-Plus-Powers-Betti-Theorem-September-23-2026,
  author = {{OpenAI}},
  title = {{The Artinian Lex-Plus-Powers Betti Theorem}},
  howpublished = {OpenAI Math Release preprint
                  \href{https://github.com/openai/math/blob/main/preprints/The-Artinian-Lex-Plus-Powers-Betti-Theorem-September-23-2026/paper.pdf}{OAI:The-Artinian-Lex-Plus-Powers-Betti-Theorem-September-23-2026}},
  year = {2026}
}

@misc{OAI:Commuting-Division-Coefficient-Forms-and-the-Artinian-Eisenbud-Green-Harris-Conjecture-September-23-2026,
  author = {{OpenAI}},
  title = {{Commuting Division-Coefficient Forms and the Artinian Eisenbud--Green--Harris Conjecture}},
  howpublished = {OpenAI Math Release preprint
                  \href{https://github.com/openai/math/blob/main/preprints/Commuting-Division-Coefficient-Forms-and-the-Artinian-Eisenbud-Green-Harris-Conjecture-September-23-2026/paper.pdf}{OAI:Commuting-Division-Coefficient-Forms-and-the-Artinian-Eisenbud-Green-Harris-Conjecture-September-23-2026}},
  year = {2026}
}
```

## Install and run

```bash
git clone https://github.com/JuanCaGC/LPPCheck.jl && cd LPPCheck.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'      # installs Oscar (large, first run is slow)
julia --project=. test/runtests.jl                        # 27 tests
julia --project=. scripts/run_sweep.jl --suite main --seeds 10 --procs 4 --timeout 180 --out results/main
julia --project=. scripts/summarize.jl results/main       # summary.csv / summary.md / sample.jsonl
```

Suites: `sanity`, `main` (Artinian, n = 3,4), `cltn` (c < n), `highn` (n = 5). Options: `--seeds`, `--seed0`, `--procs`, `--timeout` (s, per instance), `--memgb` (kill a worker above this RSS; default 3), `--char` (0 = ℚ, or a prime). Runs are fully reproducible from `(seed, n, a, kind)`, and resumable (finished jobs in `instances.jsonl` are skipped). The sweep stops at the first violation not explained by an algorithm disagreement. The raw `instances.jsonl` (large) is not committed; regenerate it with the seeds above.

Note: `LPPCheck.is_regular_sequence` is not exported because Oscar exports a function of that name.

## Implementation notes

* Minimal Betti tables: `minimal_betti_table(free_resolution(Q; algorithm = :mres))`. **Oscar 1.8.2's default `:fres` and also `:nres` returned wrong Betti tables on some ideals** (spurious β_{n+1} in one case, an extra syzygy in another; both checked against Macaulay2, see [`verification/REPORT.md`](verification/REPORT.md)). Every instance is therefore resolved with `:mres`, `:nres`, `:fres`; `:mres` is accepted when it agrees with at least one of the others and has no β_{p,*} with p > n. In the sweeps below exactly one instance (n=5, a=(2,2,3,3,5), `neardeg_mono`, seed 2) failed this check: `:nres` and `:fres` both disagreed with `:mres`; Macaulay2 reproduces the `:mres` tables exactly for S/I and S/J, and (C) holds with them (`verification/export_ideal.jl` regenerates the M2 scripts). So `:nres`/`:fres` are unreliable on some ideals; no other instance was flagged. A first sweep run with the default algorithm flagged a false "violation" of (C), which is why this check exists.
* Regular sequences are tested through the Hilbert series (exact, complete), cross-validated against the codimension test on 900 random forms.
* **Degree bounds.** Artinian (c = n): `I_d = J_d = S_d` for `d >` socle degree `Σ(ai−1)`, so degrees `≤ Σ(ai−1)+1` are exhaustive. **c < n: the bound `max(reg(I), Σ(ai−1)) + n + 1` is a heuristic, not a proof**, and a `stable_tail` flag is recorded.
* Instances: kinds `generic`, `sparse`, `neardeg_mono` (monomial plus small perturbation), `neardeg_linear` (products of linear forms plus perturbation), `symmetric` (cyclically permuted sequence), `monomial`; 1–6 extra generators (monomials, binomials, sparse forms). Non-regular sequences are discarded and counted.

## Results (exact over ℚ)

"Memout/timeout" = job exceeded the 3 GB memory guard or the time limit (inconclusive, not counted as passes). "Equal" = identical Betti tables; "strict" = some Betti number of S/J strictly larger. Slack = Σ(β(S/J) − β(S/I)).

| Suite | Total | Checked | Discarded (not regular) | Memout/timeout | Violations of (A)/(B)/(C) | Equal | Strict | Slack mean / median / max |
|---|---|---|---|---|---|---|---|---|
| sanity (c=0, monomial, n=2) | 520 | 433 | 82 | 5 | **0** | 222 | 211 | 7.4 / 0 / 124 |
| main (Artinian, n=3,4, 45 types of a) | 2250 | 1011 | 823 | 416 | **0** | 108 | 903 | 18.8 / 12 / 116 |
| c < n (n=3,4; heuristic degree bound) | 975 | 611 | 36 | 328 | **0** | 29 | 582 | 80.5 / 34 / 1086 |
| n=5 (Artinian, 16 types of a) | 270 | 71 | 84 | 115 | **0** | 3 | 68 | 110.7 / 114 / 298 |

412 of the 1011 checked `main` instances have `a` violating the Caviglia–De Stefani growth condition `a_i ≥ Σ_{j<i}(a_j−1)` (i ≥ 3). Priority families (checked / equal / strict): (2,2,2): 32/28/4; (3,3,3): 27/7/20; (2,2,2,2): 31/7/24; (2,3,3,3): 21/1/20. Per-(n,a) tables are in `results/*/summary.md`; a sample of instances is in `results/*/sample.jsonl`. The memout fraction (18%) means the heaviest cases (large socle degree) are under-represented. n = 5 uses 3 seeds per type, a 240 s limit and a 4 GB cap, so it is a thin sample; many heavy types have no checked instance. The c < n row is complete for the catalog but relies on a heuristic degree bound; in particular it is evidence only up to that bound. In characteristic p only small Artinian cases were run.


### Characteristic p (secondary exploration; Artinian, n=2–4, products of degrees ≤ 120, 3 seeds per type)

EGH is open in positive characteristic and the cited preprints claim nothing there; any failure would be logged as data, not as a bug.

| char | Total | Checked | Discarded | Memout/timeout | Violations of (A)/(B)/(C) | Equal | Strict | Slack mean / median / max |
|---|---|---|---|---|---|---|---|---|
| 2 | 690 | 107 | 583 | 0 | **0** | 34 | 73 | 13.6 / 4 / 68 |
| 3 | 690 | 287 | 403 | 0 | **0** | 90 | 197 | 13.1 / 6 / 94 |
| 5 | 690 | 334 | 356 | 0 | **0** | 94 | 240 | 15.4 / 6.0 / 94 |
| 32003 | 690 | 415 | 275 | 0 | **0** | 105 | 310 | 16.2 / 8 / 94 |

## License

MIT. See `LICENSE`.
