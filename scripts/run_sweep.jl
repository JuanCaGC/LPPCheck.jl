# Parallel sweep. Usage:
#   julia --project=. scripts/run_sweep.jl --suite main --seeds 20 --procs 8 --timeout 120 --out results/main
# Suites: sanity | main | highn   (see `catalog`)   --char 0 (QQ, default) or a prime p.
# One JSON object per line in <out>/instances.jsonl; stops at the first violation of (A),(B),(C).
using Distributed, JSON3, Dates

function parse_args(args)
    o = Dict("suite" => "main", "seeds" => "5", "procs" => "4", "timeout" => "120", "out" => "results/run",
             "char" => "0", "seed0" => "1", "nostop" => "false")
    i = 1
    while i <= length(args)
        startswith(args[i], "--") || error("bad arg $(args[i])")
        o[args[i][3:end]] = args[i+1]; i += 2
    end
    o
end
opt = parse_args(ARGS)
const TL = parse(Float64, opt["timeout"]); const NP = parse(Int, opt["procs"])
const MEM_KB = parse(Int, get(opt, "memgb", "3")) * 1024 * 1024
const CHAR = parse(Int, opt["char"]); const OUT = opt["out"]; mkpath(OUT)

# all sorted a-tuples of length c with 2 ≤ ai ≤ 5 and ∏ai ≤ bound
function tuples(c, bound)
    out = Vector{Vector{Int}}()
    rec(cur, lo) = begin
        if length(cur) == c
            prod(cur) <= bound && push!(out, copy(cur)); return
        end
        for v in lo:5
            prod(cur) * v^(c - length(cur)) > bound && break
            push!(cur, v); rec(cur, v); pop!(cur)
        end
    end
    rec(Int[], 2); out
end
# Caviglia–De Stefani growth condition: a_i ≥ Σ_{j<i}(a_j − 1) for all i ≥ 3
cds_holds(a) = all(i -> a[i] >= sum(a[j] - 1 for j in 1:i-1), 3:length(a))

const ALLKINDS = [:generic, :sparse, :neardeg_mono, :neardeg_linear, :symmetric]
function catalog(suite)
    jobs = Tuple{Int,Vector{Int},Symbol}[]    # (n, a, kind)
    if suite == "sanity"
        for k in (:monomial,), n in 2:4, a in tuples(n, 100); push!(jobs, (n, a, k)); end
        for k in ALLKINDS, a in tuples(2, 25); push!(jobs, (2, a, k)); end        # n = 2
        for k in ALLKINDS; push!(jobs, (3, Int[], k)); push!(jobs, (4, Int[], k)); end  # c = 0
    elseif suite == "main"
        for n in 3:4, a in tuples(n, 200), k in ALLKINDS; push!(jobs, (n, a, k)); end
        # priority families (violate the growth condition): listed first
        sort!(jobs; by = j -> (cds_holds(j[2]) ? 1 : 0, prod(j[2])))
    elseif suite == "cltn"      # c < n: dmax is the documented heuristic bound (see regularity_bound)
        for n in 3:4, c in 1:n-1, a in tuples(c, 40), k in ALLKINDS; push!(jobs, (n, a, k)); end
    elseif suite == "charp"     # secondary exploration in characteristic p (smaller Artinian suite)
        for n in 2:4, a in tuples(n, 120), k in ALLKINDS; push!(jobs, (n, a, k)); end
        sort!(jobs; by = j -> (cds_holds(j[2]) ? 1 : 0, prod(j[2])))
    elseif suite == "highn"
        for a in tuples(5, 250), k in ALLKINDS; push!(jobs, (5, a, k)); end
        sort!(jobs; by = j -> (cds_holds(j[2]) ? 1 : 0, prod(j[2])))
    else
        error("unknown suite")
    end
    jobs
end

addprocs(NP; exeflags = "--project=$(Base.active_project())")
@everywhere using LPPCheck
const workers_lock = ReentrantLock()
const PIDS = Dict{Int,Int}(w => remotecall_fetch(getpid, w) for w in workers())

function replace_worker!(wid)
    lock(workers_lock) do
        try
            w = Distributed.worker_from_id(wid)
            kill(w.config.process, Base.SIGKILL)
        catch; end
        try rmprocs(wid; waitfor = 5) catch; end
        new = addprocs(1; exeflags = "--project=$(Base.active_project())")[1]
        Distributed.remotecall_eval(Main, new, :(using LPPCheck))
        PIDS[new] = remotecall_fetch(getpid, new)
        new
    end
end

# resume: skip jobs already recorded in instances.jsonl (safe to re-run after an interruption)
doneset = Set{Tuple}()
let f = joinpath(OUT, "instances.jsonl")
    if isfile(f)
        for l in eachline(f)
            try d = JSON3.read(l); push!(doneset, (Int(d.seed), Int(d.n), collect(Int, d.a), Symbol(d.kind))) catch; end
        end
    end
end
jobs = Channel{Tuple}(Inf)
for (n, a, k) in catalog(opt["suite"]), s in parse(Int, opt["seed0"]):(parse(Int, opt["seed0"]) + parse(Int, opt["seeds"]) - 1)
    (s, n, a, k) in doneset || put!(jobs, (s, n, a, k))
end
println("resuming: $(length(doneset)) jobs already done")
close(jobs)
total = Base.n_avail(jobs)
println("suite=$(opt["suite"]) jobs=$total procs=$NP timeout=$(TL)s char=$CHAR"); flush(stdout)

io = open(joinpath(OUT, "instances.jsonl"), "a"); iolock = ReentrantLock()
stop = Ref(false); done = Threads.Atomic{Int}(0)
function record!(d)
    lock(iolock) do
        JSON3.write(io, d); write(io, '\n'); flush(io)
        c = Threads.atomic_add!(done, 1) + 1
        c % 50 == 0 && (println("[$(Dates.format(now(), "HH:MM:SS"))] $c / $total"); flush(stdout))
        if get(d, "regular", false) && !get(d, "timeout", false) && !get(d, "algo_ok", true)
            open(joinpath(OUT, "ALGO_DISAGREEMENTS.jsonl"), "a") do f; JSON3.write(f, d); write(f, '\n'); end
        end
        if get(d, "regular", false) && !get(d, "timeout", false) && get(d, "algo_ok", true) && !(d["A"] && d["B"] && d["C"])
            opt["nostop"] == "true" || (stop[] = true)   # char p: failures are logged as data, sweep continues
            open(joinpath(OUT, "VIOLATIONS.jsonl"), "a") do f; JSON3.write(f, d); write(f, '\n'); end
            println("\n!!! VIOLATION n=$(d["n"]) a=$(d["a"]) kind=$(d["kind"]) seed=$(d["seed"]) A=$(d["A"]) B=$(d["B"]) C=$(d["C"]) err=$(get(d,"error",""))"); flush(stdout)
        end
    end
end

@sync for wid0 in workers()
    @async begin
        wid = wid0
        for (s, n, a, k) in jobs
            stop[] && break
            fut = remotecall(LPPCheck.run_job, wid, s, n, a, k, CHAR)
            pid = PIDS[wid]       # fetched while the worker was idle (a busy worker cannot answer)
            # NB: isready(::Future) is a REMOTE call to the (busy) worker and would block the
            # watchdog; so a helper task fetches into a master-local Channel that we poll instead.
            res = Channel{Any}(1)
            @async try put!(res, (:ok, fetch(fut))) catch e; put!(res, (:err, e)) end
            t0 = time(); memout = false
            while !isready(res) && time() - t0 < TL
                sleep(0.5)
                rss = try parse(Int, strip(read(`ps -o rss= -p $pid`, String))) catch; 0 end
                if rss > MEM_KB; memout = true; break; end      # RSS in KB
            end
            if isready(res)
                tag, val = take!(res)
                if tag == :ok
                    record!(val)
                else
                    record!(Dict("seed" => s, "n" => n, "a" => a, "kind" => String(k), "char" => CHAR,
                                 "regular" => false, "timeout" => false, "crash" => sprint(showerror, val), "runtime" => 0.0))
                end
            else
                record!(Dict("seed" => s, "n" => n, "a" => a, "kind" => String(k), "char" => CHAR,
                             "regular" => true, "timeout" => true, "memout" => memout, "runtime" => time() - t0))
                wid = replace_worker!(wid)
            end
        end
    end
end
close(io)
println("done: $(done[]) records; violations: ", isfile(joinpath(OUT, "VIOLATIONS.jsonl")) ? "YES (see VIOLATIONS.jsonl)" : "none")
