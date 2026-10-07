#!/usr/bin/env julia
# Usage: julia --project=. scripts/summarize.jl results/main/instances.jsonl
# A directory argument (e.g. results/main) is also accepted.
using JSON3

Base.@kwdef mutable struct Summary
    total::Int = 0
    discarded::Int = 0
    timeouts::Int = 0
    crashes::Int = 0
    checked::Int = 0
    A_fail::Int = 0
    B_fail::Int = 0
    C_fail::Int = 0
    equal::Int = 0
    strict::Int = 0
    slacks::Vector{Float64} = Float64[]
end

const COUNT_FIELDS = (:total, :discarded, :timeouts, :crashes, :checked,
                      :A_fail, :B_fail, :C_fail, :equal, :strict)
const STAT_HEADERS = [string.(COUNT_FIELDS)..., "slack_mean", "slack_median", "slack_max"]

# The sweep records crashes as error strings; boolean crash flags also work.
has_crash(x) = !(x === nothing || x === false || (x isa AbstractString && isempty(x)))
cds_violated(a) = any(i -> a[i] < sum(a[j] - 1 for j in 1:(i - 1)), 3:length(a))

function add!(s, regular, timeout, crash, checked, record)
    s.total += 1
    s.discarded += !regular
    s.timeouts += timeout
    s.crashes += crash
    if checked
        s.checked += 1
        s.A_fail += record[:A] === false
        s.B_fail += record[:B] === false
        s.C_fail += record[:C] === false
        slack = Float64(record[:slack])
        s.equal += slack == 0
        s.strict += slack > 0
        push!(s.slacks, slack)
    end
end

function values_for(s)
    counts = Any[getfield(s, field) for field in COUNT_FIELDS]
    isempty(s.slacks) && return [counts; ["", "", ""]]
    v = sort(s.slacks)
    k = length(v)
    median = isodd(k) ? v[(k + 1) ÷ 2] : v[k ÷ 2] / 2 + v[k ÷ 2 + 1] / 2
    return [counts; [sum(v) / k, median, last(v)]]
end

function csv_cell(value)
    s = string(value)
    return any(c -> c in (',', '"', '\n', '\r'), s) ? "\"" * replace(s, "\"" => "\"\"") * "\"" : s
end
csv_row(io, values) = println(io, join(csv_cell.(values), ','))
md_row(io, values) = println(io, "| ", join(string.(values), " | "), " |")
degrees(a) = JSON3.write(collect(a))

function summarize(path)
    input = isdir(path) ? joinpath(path, "instances.jsonl") : path
    outdir = dirname(abspath(input))
    by_kind = Dict{Tuple{Int,Tuple,String},Summary}()
    by_na = Dict{Tuple{Int,Tuple},Summary}()
    overall = Summary()
    samples = String[]

    # Bound the read to the current file size so an active sweep cannot extend
    # this run indefinitely. Ignore an unfinished last line, but accept a valid
    # final JSON object without a newline. Other malformed lines are errors.
    snapshot = open(input, "r") do io
        read(io, filesize(io))
    end
    content = String(snapshot)
    lines = split(content, '\n')
    for (line_number, line) in enumerate(lines)
        isempty(strip(line)) && continue
        record = try
            JSON3.read(line)
        catch err
            if line_number == length(lines) && !endswith(content, "\n")
                @warn "Skipping unfinished final JSONL line" input line_number
                break
            end
            error("Invalid JSON at $input:$line_number: $(sprint(showerror, err))")
        end
        n = Int(record[:n])
        a = Tuple(Int.(record[:a]))
        kind = String(record[:kind])
        regular = get(record, :regular, false) === true
        timeout = get(record, :timeout, false) === true
        crash = has_crash(get(record, :crash, nothing))
        checked = regular && !timeout && !crash
        if checked
            for field in (:A, :B, :C)
                get(record, field, nothing) isa Bool || error("Missing/invalid $field at $input:$line_number")
            end
            slack = get(record, :slack, nothing)
            (slack isa Real && !(slack isa Bool) && isfinite(Float64(slack))) ||
                error("Missing/invalid slack at $input:$line_number")
            length(samples) < 200 && push!(samples, JSON3.write(record))
        end
        for s in (get!(Summary, by_kind, (n, a, kind)),
                  get!(Summary, by_na, (n, a)), overall)
            add!(s, regular, timeout, crash, checked, record)
        end
    end

    kind_keys = sort!(collect(keys(by_kind)))
    na_keys = sort!(collect(keys(by_na)))
    open(joinpath(outdir, "summary.csv"), "w") do io
        csv_row(io, ["n", "a", "kind", STAT_HEADERS...])
        for (n, a, kind) in kind_keys
            csv_row(io, [n, degrees(a), kind, values_for(by_kind[(n, a, kind)])...])
        end
    end
    open(joinpath(outdir, "summary_by_na.csv"), "w") do io
        csv_row(io, ["n", "a", "cds_violated", STAT_HEADERS...])
        for (n, a) in na_keys
            csv_row(io, [n, degrees(a), cds_violated(a), values_for(by_na[(n, a)])...])
        end
    end
    open(joinpath(outdir, "summary.md"), "w") do io
        println(io, "# Instance summary\n")
        println(io, "Checked means regular=true with neither timeout nor crash. Discarded counts every regular=false record; status counts may overlap (in particular, crashes can also be discarded). Failures and slack statistics use checked records only. Empty slack statistics mean no checked records.\n")
        println(io, "Equal means slack == 0 (identical Betti tables); strict means slack > 0. Negative slack contributes to the statistics but neither count.\n")
        println(io, "cds_violated marks failure of a_i >= sum_{j<i}(a_j - 1) for any i >= 3; tuples of length below three satisfy the condition. The overall marker is not applicable.\n")
        headers = ["n", "a", "cds_violated", STAT_HEADERS...]
        md_row(io, headers)
        md_row(io, fill("---", length(headers)))
        for (n, a) in na_keys
            md_row(io, [n, degrees(a), cds_violated(a), values_for(by_na[(n, a)])...])
        end
        md_row(io, ["Overall", "—", "—", values_for(overall)...])
    end
    open(joinpath(outdir, "sample.jsonl"), "w") do io
        for sample in samples
            println(io, sample)
        end
    end
    println("Summarized $(overall.total) instances ($(overall.checked) checked) in $outdir")
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 1 || error("Usage: julia --project=. scripts/summarize.jl <instances.jsonl or directory>")
    summarize(ARGS[1])
end
