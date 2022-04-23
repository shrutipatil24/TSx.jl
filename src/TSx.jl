module TSx

using DataFrames, Dates, ShiftedArrays, RecipesBase, RollingFunctions

import Base.convert
import Base.diff
import Base.filter
import Base.getindex
import Base.join
import Base.log
import Base.names
import Base.print
import Base.==
import Base.show
import Base.summary
import Base.size
import Base.vcat

import Dates.Period

export TS,
    JoinBoth,
    JoinAll,
    JoinLeft,
    JoinRight,
    Matrix,
    apply,
    convert,
    cbind,
    describe,
    diff,
    getindex,
    index,
    join,
    lag,
    lead,
    names,
    nr,
    nrow,
    nc,
    ncol,
    pctchange,
    plot,
    log,
    rbind,
    show,
    size,
    subset,
    summary,
    rollapply,
    vcat


####################################
# The TS structure
####################################
"""
    struct TS
      coredata :: DataFrame
    end

`::TS` - A type to hold ordered data with an index.

A TS object is essentially a `DataFrame` with a specific column marked
as an index. The input `DataFrame` is sorted during construction and
is stored under the property `coredata`. The index is stored in the
`Index` column of `coredata`.

Permitted data inputs to the constructors are `DataFrame`, `Vector`,
and 2-dimensional `Array`. If an index is already not present in the
constructor then a sequential integer index is created
automatically.

`TS(coredata::DataFrame)`: Here, the constructor looks for a column
named `Index` in `coredata` as the index column, if this is not found
then the first column of `coredata` is made the index by default. If
`coredata` only has a single column then a new sequential index is
generated.

Since `TS.coredata` is a DataFrame it can be operated upon
independently using methods provided by the DataFrames package
(ex. `transform`, `combine`, etc.).

# Constructors
```julia
TS(coredata::DataFrame, index::Union{String, Symbol, Int})
TS(coredata::DataFrame, index::AbstractVector{T}) where {T<:Union{Int, TimeType}}
TS(coredata::DataFrame)
TS(coredata::DataFrame, index::UnitRange{Int})
TS(coredata::AbstractVector{T}, index::AbstractVector{V}) where {T, V}
TS(coredata::AbstractVector{T}) where {T}
TS(coredata::AbstractArray{T,2}) where {T}
TS(coredata::AbstractArray{T,2}, index::AbstractVector{V}) where {T, V}
```

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random;
julia> random(x) = rand(MersenneTwister(123), x);

julia> df = DataFrame(x1 = random(10))
10×1 DataFrame
 Row │ x1
     │ Float64
─────┼───────────
   1 │ 0.768448
   2 │ 0.940515
   3 │ 0.673959
   4 │ 0.395453
   5 │ 0.313244
   6 │ 0.662555
   7 │ 0.586022
   8 │ 0.0521332
   9 │ 0.26864
  10 │ 0.108871

julia> ts = TS(df)   # generates index
(10 x 1) TS with Int64 Index

 Index  x1
 Int64  Float64
──────────────────
     1  0.768448
     2  0.940515
     3  0.673959
     4  0.395453
     5  0.313244
     6  0.662555
     7  0.586022
     8  0.0521332
     9  0.26864
    10  0.108871

# ts.coredata is a DataFrame
julia> combine(ts.coredata, :x1 => Statistics.mean, DataFrames.nrow)
1×2 DataFrame
 Row │ x1_mean  nrow
     │ Float64  Int64
─────┼────────────────
   1 │ 0.49898    418

julia> df = DataFrame(ind = [1, 2, 3], x1 = random(3))
3×2 DataFrame
 Row │ ind    x1
     │ Int64  Float64
─────┼─────────────────
   1 │     1  0.768448
   2 │     2  0.940515
   3 │     3  0.673959

julia> ts = TS(df, 1)        # the first column is index
(3 x 1) TS with Int64 Index

 Index  x1
 Int64  Float64
─────────────────
     1  0.768448
     2  0.940515
     3  0.673959

julia> df = DataFrame(x1 = random(3), x2 = random(3), Index = [1, 2, 3]);
3×3 DataFrame
 Row │ x1        x2        Index
     │ Float64   Float64   Int64
─────┼───────────────────────────
   1 │ 0.768448  0.768448      1
   2 │ 0.940515  0.940515      2
   3 │ 0.673959  0.673959      3

julia> ts = TS(df)   # uses existing `Index` column
(3 x 2) TS with Int64 Index

 Index  x1        x2
 Int64  Float64   Float64
───────────────────────────
     1  0.768448  0.768448
     2  0.940515  0.940515
     3  0.673959  0.673959

julia> dates = collect(Date(2017,1,1):Day(1):Date(2017,1,10));

julia> df = DataFrame(dates = dates, x1 = random(10))
10×2 DataFrame
 Row │ dates       x1
     │ Date        Float64
─────┼───────────────────────
   1 │ 2017-01-01  0.768448
   2 │ 2017-01-02  0.940515
   3 │ 2017-01-03  0.673959
   4 │ 2017-01-04  0.395453
   5 │ 2017-01-05  0.313244
   6 │ 2017-01-06  0.662555
   7 │ 2017-01-07  0.586022
   8 │ 2017-01-08  0.0521332
   9 │ 2017-01-09  0.26864
  10 │ 2017-01-10  0.108871

julia> ts = TS(df, :dates)
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64
───────────────────────
 2017-01-01  0.768448
 2017-01-02  0.940515
 2017-01-03  0.673959
 2017-01-04  0.395453
 2017-01-05  0.313244
 2017-01-06  0.662555
 2017-01-07  0.586022
 2017-01-08  0.0521332
 2017-01-09  0.26864
 2017-01-10  0.108871


julia> ts = TS(DataFrame(x1=random(10)), dates);


julia> ts = TS(random(10))
(10 x 1) TS with Int64 Index

 Index  x1
 Int64  Float64
──────────────────
     1  0.768448
     2  0.940515
     3  0.673959
     4  0.395453
     5  0.313244
     6  0.662555
     7  0.586022
     8  0.0521332
     9  0.26864
    10  0.108871

julia> ts = TS(random(10), dates);


julia> ts = TS([random(10) random(10)], dates) # matrix object
(10 x 2) TS with Date Index

 Index       x1         x2
 Date        Float64    Float64
──────────────────────────────────
 2017-01-01  0.768448   0.768448
 2017-01-02  0.940515   0.940515
 2017-01-03  0.673959   0.673959
 2017-01-04  0.395453   0.395453
 2017-01-05  0.313244   0.313244
 2017-01-06  0.662555   0.662555
 2017-01-07  0.586022   0.586022
 2017-01-08  0.0521332  0.0521332
 2017-01-09  0.26864    0.26864
 2017-01-10  0.108871   0.108871

```
"""
struct TS

    coredata :: DataFrame

    # From DataFrame, index number/name/symbol
    function TS(coredata::DataFrame, index::Union{String, Symbol, Int})
        if (DataFrames.ncol(coredata) == 1)
            TS(coredata, collect(Base.OneTo(DataFrames.nrow(coredata))))
        end

        sorted_cd = sort(coredata, index)
        index_vals = sorted_cd[!, index]

        cd = sorted_cd[:, Not(index)]
        insertcols!(cd, 1, :Index => index_vals, after=false, copycols=true)

        new(cd)
    end

    # From DataFrame, external index
    function TS(coredata::DataFrame, index::AbstractVector{T}) where {T<:Union{Int, TimeType}}
        sorted_index = sort(index)

        cd = copy(coredata)
        insertcols!(cd, 1, :Index => sorted_index, after=false, copycols=true)

        new(cd)
    end

end



####################################
# Constructors
####################################

function TS(coredata::DataFrame)
    if "Index" in names(coredata)
        return TS(coredata, :Index)
    elseif DataFrames.ncol(coredata) == 1
        return TS(coredata, collect(1:DataFrames.nrow(coredata)))
    else
        return TS(coredata, 1)
    end
end

# From DataFrame, index range
function TS(coredata::DataFrame, index::UnitRange{Int})
    index_vals = collect(index)
    cd = copy(coredata)
    insertcols!(cd, 1, :Index => index_vals, after=false, copycols=true)
    TS(cd, :Index)
end

# From AbstractVector
function TS(coredata::AbstractVector{T}, index::AbstractVector{V}) where {T, V}
    df = DataFrame([coredata], :auto)
    TS(df, index)
end

function TS(coredata::AbstractVector{T}) where {T}
    index_vals = collect(Base.OneTo(length(coredata)))
    TS(coredata, index_vals)
end


# From Matrix and meta
# FIXME: use Metadata.jl
function TS(coredata::AbstractArray{T,2}) where {T}
    index_vals = collect(Base.OneTo(size(coredata)[1]))
    df = DataFrame(coredata, :auto, copycols=true)
    TS(df, index_vals)
end

function TS(coredata::AbstractArray{T,2}, index::AbstractVector{V}) where {T, V}
    df = DataFrame(coredata, :auto, copycols=true)
    TS(df, index)
end


####################################
# Displays
####################################

# Show
function Base.show(io::IO, ts::TS)
    println("(", TSx.nrow(ts), " x ", TSx.ncol(ts), ") TS with ", eltype(index(ts)), " Index")
    println("")
    DataFrames.show(ts.coredata, show_row_number=false, summary=false)
    return nothing
end
Base.show(ts::TS) = show(stdout, ts)

"""
# Summary statistics

```julia
describe(ts::TS)
```

Compute summary statistics of `ts`. The output is a `DataFrame`
containing standard statistics along with number of missing values and
data types of columns.

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random;
julia> random(x) = rand(MersenneTwister(123), x...);
julia> ts = TS(random(([1, 2, 3, 4, missing], 10)))
julia> describe(ts)
```
"""
function describe(io::IO, ts::TS)
    DataFrames.describe(ts.coredata)
end

function Base.summary(io::IO, ts::TS)
    println("(", nr(ts), " x ", nc(ts), ") TS")
end

#######################
# Indexing
#######################
## Date-time type conversions for indexing
function _convert(::Type{Date}, str::String)
    Date(Dates.parse_components(str, Dates.dateformat"yyyy-mm-dd")...)
end

function _convert(::Type{String}, date::Date)
    Dates.format(date, "yyyy-mm-dd")
end

"""
# Conversion of non-Index data to Matrix

```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random;
julia> random(x) = rand(MersenneTwister(123), x);
julia> ts = TS([random(10) random(10)])
julia> show(ts)
(10 x 2) TS with Int64 Index

 Index  x1         x2        
 Int64  Float64    Float64   
─────────────────────────────
     1  0.768448   0.768448
     2  0.940515   0.940515
     3  0.673959   0.673959
     4  0.395453   0.395453
     5  0.313244   0.313244
     6  0.662555   0.662555
     7  0.586022   0.586022
     8  0.0521332  0.0521332
     9  0.26864    0.26864
    10  0.108871   0.108871

julia> Matrix(ts)
10×2 Matrix{Float64}:
 0.768448   0.768448
 0.940515   0.940515
 0.673959   0.673959
 0.395453   0.395453
 0.313244   0.313244
 0.662555   0.662555
 0.586022   0.586022
 0.0521332  0.0521332
 0.26864    0.26864
 0.108871   0.108871

julia> convert(Matrix, ts)
10×2 Matrix{Float64}:
 0.768448   0.768448
 0.940515   0.940515
 0.673959   0.673959
 0.395453   0.395453
 0.313244   0.313244
 0.662555   0.662555
 0.586022   0.586022
 0.0521332  0.0521332
 0.26864    0.26864
 0.108871   0.108871

"""
function Base.convert(::Type{Matrix}, ts::TS)
    Matrix(ts.coredata[!, Not(:Index)])
end

function (Matrix)(ts::TS)
    convert(Matrix, ts)
end

"""
# Subsetting/Indexing

`TS` can be subset using row and column indices. The row selector
could be an integer, a range, an array or it could also be a `Date`
object or an ISO-formatted date string ("2007-04-10"). There are
methods to subset on year, year-month, and year-quarter. The latter
two subset `coredata` by matching on the index column.

Column selector could be an integer or any other selector which
`DataFrame` indexing supports. You can use a Symbols to fetch specific
columns (ex: `ts[:x1]`, `ts[[:x1, :x2]]`). For fetching column values
as `Vector` or `Matrix`, use `Colon`: `ts[:, :x1]` and `ts[:, [:x1,
:x2]]`.

For fetching the index column vector use the `index()` method.

# Examples

```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random;

julia> random(x) = rand(MersenneTwister(123), x);

julia> ts = TS([random(10) random(10) random(10)])
julia> show(ts)

# first row
julia> ts[1]
(1 x 3) TS with Int64 Index

 Index  x1        x2        x3
 Int64  Float64   Float64   Float64
─────────────────────────────────────
     1  0.768448  0.768448  0.768448

# first five rows
julia> ts[1:5]
(5 x 3) TS with Int64 Index

 Index  x1        x2        x3
 Int64  Float64   Float64   Float64
─────────────────────────────────────
     1  0.768448  0.768448  0.768448
     2  0.940515  0.940515  0.940515
     3  0.673959  0.673959  0.673959
     4  0.395453  0.395453  0.395453
     5  0.313244  0.313244  0.313244

# first five rows, second column
julia> ts[1:5, 2]
(5 x 1) TS with Int64 Index

 Index  x2
 Int64  Float64
─────────────────
     1  0.768448
     2  0.940515
     3  0.673959
     4  0.395453
     5  0.313244


julia> ts[1:5, 2:3]
(5 x 2) TS with Int64 Index

 Index  x2        x3
 Int64  Float64   Float64
───────────────────────────
     1  0.768448  0.768448
     2  0.940515  0.940515
     3  0.673959  0.673959
     4  0.395453  0.395453
     5  0.313244  0.313244

# individual rows
julia> ts[[1, 9]]
(2 x 3) TS with Int64 Index

 Index  x1        x2        x3
 Int64  Float64   Float64   Float64
─────────────────────────────────────
     1  0.768448  0.768448  0.768448
     9  0.26864   0.26864   0.26864

julia> ts[:, :x1]            # returns a Vector
10-element Vector{Float64}:
 0.7684476751965699
 0.940515000715187
 0.6739586945680673
 0.3954531123351086
 0.3132439558075186
 0.6625548164736534
 0.5860221243068029
 0.05213316316865657
 0.26863956854495097
 0.10887074134844155


julia> ts[:, [:x1, :x2]]
(10 x 2) TS with Int64 Index

 Index  x1         x2
 Int64  Float64    Float64
─────────────────────────────
     1  0.768448   0.768448
     2  0.940515   0.940515
     3  0.673959   0.673959
     4  0.395453   0.395453
     5  0.313244   0.313244
     6  0.662555   0.662555
     7  0.586022   0.586022
     8  0.0521332  0.0521332
     9  0.26864    0.26864
    10  0.108871   0.108871


julia> dates = collect(Date(2007):Day(1):Date(2008, 2, 22));
julia> ts = TS(random(length(dates)), dates)
julia> show(ts[1:10])
(10 x 1) TS with Date Index

 Index       x1        
 Date        Float64   
───────────────────────
 2007-01-01  0.768448
 2007-01-02  0.940515
 2007-01-03  0.673959
 2007-01-04  0.395453
 2007-01-05  0.313244
 2007-01-06  0.662555
 2007-01-07  0.586022
 2007-01-08  0.0521332
 2007-01-09  0.26864
 2007-01-10  0.108871

julia> ts[Date(2007, 01, 01)]
(1 x 1) TS with Dates.Date Index

 Index       x1
 Date        Float64
──────────────────────
 2007-01-01  0.768448


julia> ts[Date(2007)]
(1 x 1) TS with Dates.Date Index

 Index       x1
 Date        Float64
──────────────────────
 2007-01-01  0.768448


julia> ts[Year(2007)]
(365 x 1) TS with Dates.Date Index

 Index       x1
 Date        Float64
───────────────────────
 2007-01-01  0.768448
 2007-01-02  0.940515
 2007-01-03  0.673959
 2007-01-04  0.395453
 2007-01-05  0.313244
 2007-01-06  0.662555
 2007-01-07  0.586022
 2007-01-08  0.0521332
     ⋮           ⋮
 2007-12-24  0.468421
 2007-12-25  0.0246652
 2007-12-26  0.171042
 2007-12-27  0.227369
 2007-12-28  0.695758
 2007-12-29  0.417124
 2007-12-30  0.603757
 2007-12-31  0.346659
       349 rows omitted


julia> ts[Year(2007), Month(11)]
(30 x 1) TS with Date Index

 Index       x1        
 Date        Float64   
───────────────────────
 2007-11-01  0.214132
 2007-11-02  0.672281
 2007-11-03  0.373938
 2007-11-04  0.317985
 2007-11-05  0.110226
 2007-11-06  0.797408
 2007-11-07  0.095699
 2007-11-08  0.186565
 2007-11-09  0.586859
 2007-11-10  0.623613
 2007-11-11  0.62035
 2007-11-12  0.830895
 2007-11-13  0.72423
 2007-11-14  0.493046
 2007-11-15  0.767975
 2007-11-16  0.462157
 2007-11-17  0.779754
 2007-11-18  0.398596
 2007-11-19  0.941196
 2007-11-20  0.578657
 2007-11-21  0.702451
 2007-11-22  0.746427
 2007-11-23  0.301046
 2007-11-24  0.619772
 2007-11-25  0.425161
 2007-11-26  0.410939
 2007-11-27  0.0883656
 2007-11-28  0.135477
 2007-11-29  0.693611
 2007-11-30  0.557009


julia> ts[Year(2007), Quarter(2)];


julia> ts["2007-01-01"]
(1 x 1) TS with Date Index

 Index       x1       
 Date        Float64  
──────────────────────
 2007-01-01  0.768448


julia> ts[1, :x1]
(1 x 1) TS with Dates.Date Index

 Index       x1
 Date        Float64
──────────────────────
 2007-01-01  0.768448


julia> ts[1, "x1"]
(1 x 1) TS with Date Index

 Index       x1       
 Date        Float64  
──────────────────────
 2007-01-01  0.768448


```
"""
function Base.getindex(ts::TS, i::Int)
    TS(ts.coredata[[i], :])
end

# By row-range
function Base.getindex(ts::TS, r::UnitRange)
    TS(ts.coredata[collect(r), :])
end

# By row-array
function Base.getindex(ts::TS, a::AbstractVector{Int64})
    TS(ts.coredata[a, :])
end

# By date
function Base.getindex(ts::TS, d::Date)
    sdf = filter(x -> x.Index == d, ts.coredata)
    TS(sdf)
end

# By period
function Base.getindex(ts::TS, y::Year)
    sdf = filter(:Index => x -> Dates.Year(x) == y, ts.coredata)
    TS(sdf)
end

function Base.getindex(ts::TS, y::Year, q::Quarter)
    sdf = filter(:Index => x -> (Year(x), Quarter(x)) == (y, q), ts.coredata)
    TS(sdf)
end

# XXX: ideally, Dates.YearMonth class should exist
function Base.getindex(ts::TS, y::Year, m::Month)
    sdf = filter(:Index => x -> (Year(x), Month(x)) == (y, m), ts.coredata)
    TS(sdf)
end

# By string timestamp
function Base.getindex(ts::TS, i::String)
    ind = findall(x -> x == TSx._convert(eltype(ts.coredata[!, :Index]), i), ts.coredata[!, :Index]) # XXX: may return duplicate indices
    TS(ts.coredata[ind, :])     # XXX: check if data is being copied
end

# By {TimeType, Period} range
# function Base.getindex(ts::TS, r::StepRange{T, V}) where {T<:TimeType, V<:Period}
# end

# By row-column
function Base.getindex(ts::TS, i::Int, j::Int)
    TS(ts.coredata[[i], Cols(:Index, j+1)])
end

# By row-range, column
function Base.getindex(ts::TS, i::UnitRange, j::Int)
    return TS(ts.coredata[i, Cols(:Index, j+1)])
end

function Base.getindex(ts::TS, i::Int, j::UnitRange)
    return TS(ts.coredata[[i], Cols(:Index, 1 .+(j))])
end

function Base.getindex(ts::TS, i::UnitRange, j::UnitRange)
    return TS(ts.coredata[i, Cols(:Index, 1 .+(j))])
end

function Base.getindex(ts::TS, i::Int, j::Symbol)
    return TS(ts.coredata[[i], Cols(:Index, j)])
end

function Base.getindex(ts::TS, i::Int, j::String)
    return TS(ts.coredata[[i], Cols("Index", j)])
end

function Base.getindex(ts::TS, i::Vector{Int}, j::Int)
    TS(ts.coredata[i, Cols(:Index, j+1)]) # increment: account for Index
end

function Base.getindex(ts::TS, i::Vector{Int}, j::UnitRange)
    ts[i, collect(j)]
end

function Base.getindex(ts::TS, i::UnitRange, j::Vector{Int})
    ts[collect(i), j]
end

function Base.getindex(ts::TS, i::Int, j::Vector{Int})
    TS(ts.coredata[[i], Cols(:Index, j.+1)]) # increment: account for Index
end

function Base.getindex(ts::TS, i::Vector{Int}, j::Vector{Int})
    TS(ts.coredata[i, Cols(:Index, j.+1)]) # increment: account for Index
end

function Base.getindex(ts::TS, i::Int, j::Vector{T}) where {T<:Union{String, Symbol}}
    TS(ts.coredata[[i], Cols(:Index, j)])
end

## Column indexing with Colon
# returns a TS object
function Base.getindex(ts::TS, ::Colon, j::Vector{Int})
    TS(select(ts.coredata, :Index, j.+1), :Index)  # increment: account for Index
end

# returns a TS object
function Base.getindex(ts::TS, ::Colon, j::Vector{T}) where {T<:Union{String, Symbol}}
    TS(select(ts.coredata, :Index, j), :Index)  # increment: account for Index
end

# returns a Vector
function Base.getindex(ts::TS, ::Colon, j::Int)
    ts.coredata[!, j+1]
end

# returns a Vector
function Base.getindex(ts::TS, ::Colon, j::T) where {T<:Union{String, Symbol}}
    ts.coredata[!, j]
end
####

"""
# Subsetting based on Index

```julia
subset(ts::TS, from::T, to::T) where {T<:Union{Int, TimeType}}
```

Create a subset of `ts` based on the `Index` starting `from`
(inclusive) till `to` (inclusive).

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random;
julia> random(x) = rand(MersenneTwister(123), x);
julia> dates = Date("2022-02-01"):Week(1):Date("2022-02-01")+Month(9);
julia> ts = TS(random(length(dates)), dates)
julia> show(ts)
(40 x 1) TS with Date Index

 Index       x1        
 Date        Float64   
───────────────────────
 2022-02-01  0.768448
 2022-02-08  0.940515
 2022-02-15  0.673959
 2022-02-22  0.395453
 2022-03-01  0.313244
 2022-03-08  0.662555
 2022-03-15  0.586022
 2022-03-22  0.0521332
 2022-03-29  0.26864
 2022-04-05  0.108871
 2022-04-12  0.163666
 2022-04-19  0.473017
 2022-04-26  0.865412
 2022-05-03  0.617492
 2022-05-10  0.285698
 2022-05-17  0.463847
 2022-05-24  0.275819
 2022-05-31  0.446568
 2022-06-07  0.582318
 2022-06-14  0.255981
 2022-06-21  0.70586
 2022-06-28  0.291978
 2022-07-05  0.281066
 2022-07-12  0.792931
 2022-07-19  0.20923
 2022-07-26  0.918165
 2022-08-02  0.614255
 2022-08-09  0.802665
 2022-08-16  0.555668
 2022-08-23  0.940782
 2022-08-30  0.48
 2022-09-06  0.790201
 2022-09-13  0.356221
 2022-09-20  0.900925
 2022-09-27  0.529253
 2022-10-04  0.031831
 2022-10-11  0.900681
 2022-10-18  0.940299
 2022-10-25  0.621379
 2022-11-01  0.348173

julia> subset(ts, Date(2022, 03), Date(2022, 07))
(18 x 1) TS with Date Index

 Index       x1        
 Date        Float64   
───────────────────────
 2022-03-01  0.313244
 2022-03-08  0.662555
 2022-03-15  0.586022
 2022-03-22  0.0521332
 2022-03-29  0.26864
 2022-04-05  0.108871
 2022-04-12  0.163666
 2022-04-19  0.473017
 2022-04-26  0.865412
 2022-05-03  0.617492
 2022-05-10  0.285698
 2022-05-17  0.463847
 2022-05-24  0.275819
 2022-05-31  0.446568
 2022-06-07  0.582318
 2022-06-14  0.255981
 2022-06-21  0.70586
 2022-06-28  0.291978

julia> subset(TS(1:20, -9:10), -4, 5)
(10 x 1) TS with Int64 Index

 Index  x1    
 Int64  Int64 
──────────────
    -4      6
    -3      7
    -2      8
    -1      9
     0     10
     1     11
     2     12
     3     13
     4     14
     5     15
```

"""
function subset(ts::TS, from::T, to::T) where {T<:Union{Int, TimeType}}
    TS(subset(ts.coredata, :Index => x -> x .>= from .&& x .<= to))
end


########################
# Parameters
########################

# Number of rows
"""
# Size methods

```julia
nrow(ts::TS)
nr(ts::TS)
```

Return the number of rows of `ts`. `nr` is an alias for `nrow`.

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> ts = TS(collect(1:10))


julia> TSx.nrow(ts)
10
```
"""
function nrow(ts::TS)
    DataFrames.size(ts.coredata)[1]
end
# alias
nr = TSx.nrow

# Number of columns
"""
# Size methods

```julia
ncol(ts::TS)
```

Return the number of columns of `ts`. `nc` is an alias for `ncol`.

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random;

julia> random(x) = rand(MersenneTwister(123), x);

julia> TSx.ncol(TS([random(100) random(100) random(100)]))
3

julia> nc(TS([random(100) random(100) random(100)]))
3
```
"""
function ncol(ts::TS)
    DataFrames.size(ts.coredata)[2] - 1
end
# alias
nc = TSx.ncol

# Size of
"""
# Size methods
```julia
size(ts::TS)
```

Return the number of rows and columns of `ts` as a tuple.

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> TSx.size(TS([collect(1:100) collect(1:100) collect(1:100)]))
(100, 3)
```
"""
function size(ts::TS)
    nr = TSx.nrow(ts)
    nc = TSx.ncol(ts)
    (nr, nc)
end

# Return index column
"""
# Index column

```julia
index(ts::TS)
```

Return the index vector from the `coredata` DataFrame.

# Examples

```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random;

julia> random(x) = rand(MersenneTwister(123), x);

julia> ts = TS(random(10), Date("2022-02-01"):Month(1):Date("2022-02-01")+Month(9));


julia> show(ts)
(10 x 1) TS with Dates.Date Index

 Index       x1
 Date        Float64
───────────────────────
 2022-02-01  0.768448
 2022-03-01  0.940515
 2022-04-01  0.673959
 2022-05-01  0.395453
 2022-06-01  0.313244
 2022-07-01  0.662555
 2022-08-01  0.586022
 2022-09-01  0.0521332
 2022-10-01  0.26864
 2022-11-01  0.108871

julia> index(ts)
10-element Vector{Date}:
 2022-02-01
 2022-03-01
 2022-04-01
 2022-05-01
 2022-06-01
 2022-07-01
 2022-08-01
 2022-09-01
 2022-10-01
 2022-11-01

julia>  eltype(index(ts))
Date
```
"""
function index(ts::TS)
    ts.coredata[!, :Index]
end

"""
# Column names
```julia
names(ts::TS)
```

Return a `Vector{String}` containing column names of the TS object,
excludes index.

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> names(TS([1:10 11:20]))
2-element Vector{String}:
 "x1"
 "x2"
```
"""
function names(ts::TS)
    names(ts.coredata[!, Not(:Index)])
end

# convert to period
"""
# Apply/Period conversion
```julia
apply(ts::TS,
      period::Union{T,Type{T}},
      fun::V,
      index_at::Function=first)
     where {
           T <: Union{DatePeriod,TimePeriod},
           V <: Function
           }
```

Apply `fun` to `ts` object based on `period` and return correctly
indexed rows. This method is used for doing aggregation over a time
period or to convert `ts` into an object of lower frequency (ex. from
daily series to monthly).

`period` is any of `Period` types in the `Dates` module. Conversion
from lower to a higher frequency will throw an error as interpolation
isn't currently handled by this method.

By default, the method uses the first value of the index within the
period to index the resulting aggregated object. This behaviour can be
controlled by `index_at` argument which can take `first` or `last` as
an input.

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random, Statistics;
julia> random(x) = rand(MersenneTwister(123), x);
julia> dates = collect(Date(2017,1,1):Day(1):Date(2018,3,10));

julia> ts = TS(random(length(dates)), dates)
julia> show(ts[1:10])
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64
───────────────────────
 2017-01-01  0.768448
 2017-01-02  0.940515
 2017-01-03  0.673959
 2017-01-04  0.395453
 2017-01-05  0.313244
 2017-01-06  0.662555
 2017-01-07  0.586022
 2017-01-08  0.0521332
 2017-01-09  0.26864
 2017-01-10  0.108871

julia> apply(ts, Month, first)
(15 x 1) TS with Date Index

 Index       x1_first
 Date        Float64
───────────────────────
 2017-01-01  0.768448
 2017-02-01  0.790201
 2017-03-01  0.467219
 2017-04-01  0.783473
 2017-05-01  0.651354
 2017-06-01  0.373346
 2017-07-01  0.83296
 2017-08-01  0.132716
 2017-09-01  0.27899
 2017-10-01  0.995414
 2017-11-01  0.214132
 2017-12-01  0.832917
 2018-01-01  0.0409471
 2018-02-01  0.720163
 2018-03-01  0.87459

# alternate months
julia> apply(ts, Month(2), first)
(8 x 1) TS with Date Index

 Index       x1_first
 Date        Float64
───────────────────────
 2017-01-01  0.768448
 2017-03-01  0.467219
 2017-05-01  0.651354
 2017-07-01  0.83296
 2017-09-01  0.27899
 2017-11-01  0.214132
 2018-01-01  0.0409471
 2018-03-01  0.87459


julia> ts_weekly = apply(ts, Week, Statistics.std) # weekly standard deviation
julia> show(ts_weekly[1:10])
(10 x 1) TS with Date Index

 Index       x1_std
 Date        Float64
────────────────────────
 2017-01-01  NaN
 2017-01-02    0.28935
 2017-01-09    0.270842
 2017-01-16    0.170197
 2017-01-23    0.269573
 2017-01-30    0.326687
 2017-02-06    0.279935
 2017-02-13    0.319216
 2017-02-20    0.272058
 2017-02-27    0.23651


julia> ts_weekly = apply(ts, Week, Statistics.std, last) # indexed by last date of the week
julia> show(ts_weekly[1:10])
(10 x 1) TS with Date Index

 Index       x1_std
 Date        Float64
────────────────────────
 2017-01-01  NaN
 2017-01-08    0.28935
 2017-01-15    0.270842
 2017-01-22    0.170197
 2017-01-29    0.269573
 2017-02-05    0.326687
 2017-02-12    0.279935
 2017-02-19    0.319216
 2017-02-26    0.272058
 2017-03-05    0.23651

```
"""
function apply(ts::TS, period::Union{T,Type{T}}, fun::V, index_at::Function=first) where {T<:Union{DatePeriod,TimePeriod}, V<:Function}
    sdf = transform(ts.coredata, :Index => i -> Dates.floor.(i, period))
    gd = groupby(sdf, :Index_function)

    ## Columns to exclude from operation.
    # Note: Not() does not support more
    # than one Symbol so we have to find Int indexes.
    ##
    n = findfirst(r -> r == "Index", names(gd))
    r = findfirst(r -> r == "Index_function", names(gd))

    df = combine(gd,
                 :Index => index_at => :Index,
                 names(gd)[Not(n, r)] .=> fun,
                 keepkeys=false)
    TS(df, :Index)
end

"""
# Lagging
```julia
lag(ts::TS, lag_value::Int = 1)
```

Lag the `ts` object by the specified `lag_value`. The rows corresponding
to lagged values will be rendered as `missing`. Negative values of lag are
also accepted (see `TSx.lead`).

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random, Statistics;

julia> random(x) = rand(MersenneTwister(123), x);

julia> dates = collect(Date(2017,1,1):Day(1):Date(2017,1,10));

julia> ts = TS(random(length(dates)), dates);
julia> show(ts)
(10 x 1) TS with Dates.Date Index

 Index       x1
 Date        Float64
───────────────────────
 2017-01-01  0.768448
 2017-01-02  0.940515
 2017-01-03  0.673959
 2017-01-04  0.395453
 2017-01-05  0.313244
 2017-01-06  0.662555
 2017-01-07  0.586022
 2017-01-08  0.0521332
 2017-01-09  0.26864
 2017-01-10  0.108871


julia> lag(ts)
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64?
─────────────────────────────
 2017-01-01  missing
 2017-01-02        0.768448
 2017-01-03        0.940515
 2017-01-04        0.673959
 2017-01-05        0.395453
 2017-01-06        0.313244
 2017-01-07        0.662555
 2017-01-08        0.586022
 2017-01-09        0.0521332
 2017-01-10        0.26864

julia> lag(ts, 2) # lags by 2 values
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64?
─────────────────────────────
 2017-01-01  missing
 2017-01-02  missing
 2017-01-03        0.768448
 2017-01-04        0.940515
 2017-01-05        0.673959
 2017-01-06        0.395453
 2017-01-07        0.313244
 2017-01-08        0.662555
 2017-01-09        0.586022
 2017-01-10        0.0521332

```
"""
function lag(ts::TS, lag_value::Int = 1)
    sdf = DataFrame(ShiftedArrays.lag.(eachcol(ts.coredata[!, Not(:Index)]), lag_value), TSx.names(ts))
    insertcols!(sdf, 1, :Index => ts.coredata[!, :Index])
    TS(sdf, :Index)
end

"""
# Leading
```julia
lead(ts::TS, lead_value::Int = 1)
```

Similar to lag, this method leads the `ts` object by `lead_value`. The
lead rows are inserted with `missing`. Negative values of lead are
also accepted (see `TSx.lag`).

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random, Statistics;

julia> random(x) = rand(MersenneTwister(123), x);

julia> dates = collect(Date(2017,1,1):Day(1):Date(2018,3,10));

julia> ts = TS(DataFrame(Index = dates, x1 = random(length(dates))))
julia> show(ts)
(434 x 1) TS with Dates.Date Index

 Index       x1
 Date        Float64
───────────────────────
 2017-01-01  0.768448
 2017-01-02  0.940515
 2017-01-03  0.673959
 2017-01-04  0.395453
 2017-01-05  0.313244
 2017-01-06  0.662555
 2017-01-07  0.586022
 2017-01-08  0.0521332
     ⋮           ⋮
 2018-03-03  0.127635
 2018-03-04  0.147813
 2018-03-05  0.873555
 2018-03-06  0.486486
 2018-03-07  0.495525
 2018-03-08  0.64075
 2018-03-09  0.375126
 2018-03-10  0.0338698
       418 rows omitted


julia> lead(ts)[1:10]        # leads once
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64?
───────────────────────
 2017-01-01  0.940515
 2017-01-02  0.673959
 2017-01-03  0.395453
 2017-01-04  0.313244
 2017-01-05  0.662555
 2017-01-06  0.586022
 2017-01-07  0.0521332
 2017-01-08  0.26864
 2017-01-09  0.108871
 2017-01-10  0.163666

julia> lead(ts, 2)[1:10]     # leads by 2 values
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64?
───────────────────────
 2017-01-01  0.673959
 2017-01-02  0.395453
 2017-01-03  0.313244
 2017-01-04  0.662555
 2017-01-05  0.586022
 2017-01-06  0.0521332
 2017-01-07  0.26864
 2017-01-08  0.108871
 2017-01-09  0.163666
 2017-01-10  0.473017

```
"""
function lead(ts::TS, lead_value::Int = 1)
    sdf = DataFrame(ShiftedArrays.lead.(eachcol(ts.coredata[!, Not(:Index)]), lead_value), TSx.names(ts))
    insertcols!(sdf, 1, :Index => ts.coredata[!, :Index])
    TS(sdf, :Index)
end

"""
# Differencing
```julia
diff(ts::TS, periods::Int = 1)
```

Return the discrete difference of successive row elements.
Default is the element in the next row. `periods` defines the number
of rows to be shifted over. The skipped rows are rendered as `missing`.

`diff` returns an error if column type does not have the method `-`.

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random, Statistics;

julia> random(x) = rand(MersenneTwister(123), x);

julia> dates = collect(Date(2017,1,1):Day(1):Date(2018,3,10));

julia> ts = TS(random(length(dates)), dates);
julia> ts[1:10]
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64
───────────────────────
 2017-01-01  0.768448
 2017-01-02  0.940515
 2017-01-03  0.673959
 2017-01-04  0.395453
 2017-01-05  0.313244
 2017-01-06  0.662555
 2017-01-07  0.586022
 2017-01-08  0.0521332
 2017-01-09  0.26864
 2017-01-10  0.108871

julia> diff(ts)[1:10]        # difference over successive rows
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64?
─────────────────────────────
 2017-01-01  missing
 2017-01-02        0.172067
 2017-01-03       -0.266556
 2017-01-04       -0.278506
 2017-01-05       -0.0822092
 2017-01-06        0.349311
 2017-01-07       -0.0765327
 2017-01-08       -0.533889
 2017-01-09        0.216506
 2017-01-10       -0.159769

julia> diff(ts, 3)[1:10]     # difference over the third row
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64?
─────────────────────────────
 2017-01-01  missing
 2017-01-02  missing
 2017-01-03  missing
 2017-01-04       -0.372995
 2017-01-05       -0.627271
 2017-01-06       -0.0114039
 2017-01-07        0.190569
 2017-01-08       -0.261111
 2017-01-09       -0.393915
 2017-01-10       -0.477151

```
"""

# Diff
function diff(ts::TS, periods::Int = 1)
    if periods <= 0
        error("periods must be a postive int")
    end
    ddf = ts.coredata[:, Not(:Index)] .- TSx.lag(ts, periods).coredata[:, Not(:Index)]
    insertcols!(ddf, 1, "Index" => ts.coredata[:, :Index])
    TS(ddf, :Index)
end

"""
# Percent Change

```julia
pctchange(ts::TS, periods::Int = 1)
```

Return the percentage change between successive row elements.
Default is the element in the next row. `periods` defines the number
of rows to be shifted over. The skipped rows are rendered as `missing`.

`pctchange` returns an error if column type does not have the method `/`.

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random, Statistics;

julia> random(x) = rand(MersenneTwister(123), x);

julia> dates = collect(Date(2017,1,1):Day(1):Date(2017,1,10));

julia> ts = TS(random(length(dates)), dates)
julia> show(ts)
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64
───────────────────────
 2017-01-01  0.768448
 2017-01-02  0.940515
 2017-01-03  0.673959
 2017-01-04  0.395453
 2017-01-05  0.313244
 2017-01-06  0.662555
 2017-01-07  0.586022
 2017-01-08  0.0521332
 2017-01-09  0.26864
 2017-01-10  0.108871

# Pctchange over successive rows
julia> pctchange(ts)
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64?
────────────────────────────
 2017-01-01  missing
 2017-01-02        0.223915
 2017-01-03       -0.283415
 2017-01-04       -0.413238
 2017-01-05       -0.207886
 2017-01-06        1.11514
 2017-01-07       -0.115511
 2017-01-08       -0.911039
 2017-01-09        4.15295
 2017-01-10       -0.594733


# Pctchange over the third row
julia> pctchange(ts, 3)
(10 x 1) TS with Date Index

 Index       x1
 Date        Float64?
─────────────────────────────
 2017-01-01  missing
 2017-01-02  missing
 2017-01-03  missing
 2017-01-04       -0.485387
 2017-01-05       -0.666944
 2017-01-06       -0.0169207
 2017-01-07        0.4819
 2017-01-08       -0.83357
 2017-01-09       -0.59454
 2017-01-10       -0.814221

```
"""

# Pctchange
function pctchange(ts::TS, periods::Int = 1)
    if periods <= 0
        error("periods must be a positive int")
    end
    ddf = (ts.coredata[:, Not(:Index)] ./ TSx.lag(ts, periods).coredata[:, Not(:Index)]) .- 1
    insertcols!(ddf, 1, "Index" => ts.coredata[:, :Index])
    TS(ddf, :Index)
end

"""
# Log Function

```julia
log(ts::TS, complex::Bool = false)
```

This method computes the log value of non-index columns in the TS
object.

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random
julia> random(x) = rand(MersenneTwister(123), x...);
julia> ts = TS(random(([1, 2, 3, 4, missing], 10)))
julia> show(ts)
(10 x 1) TS with Int64 Index

 Index  x1
 Int64  Int64?
────────────────
     1  missing
     2        2
     3        2
     4        3
     5        4
     6        3
     7        3
     8  missing
     9        2
    10        3

julia> log(ts)
(10 x 1) TS with Int64 Index

 Index  x1_log
 Int64  Float64?
───────────────────────
     1  missing
     2        0.693147
     3        0.693147
     4        1.09861
     5        1.38629
     6        1.09861
     7        1.09861
     8  missing
     9        0.693147
    10        1.09861

```
"""
function Base.log(ts::TS)
    df = select(ts.coredata, :Index,
                Not(:Index) .=> (x -> log.(x))
                => colname -> string(colname, "_log"))
    TS(df)
end


######################
# Rolling Function
######################

"""
# Rolling Functions

```julia
rollapply(fun::Function, ts::TS, column::Any, windowsize::Int)
```

Apply a function to a column of `ts` for each continuous set of rows
of size `windowsize`. `column` could be any of the `DataFrame` column
selectors.

The output is a TS object with `(nrow(ts) - windowsize + 1)` rows
indexed with the last index value of each window.

This method uses `RollingFunctions` package to implement this
functionality.

# Examples

```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> ts = TS(1:12, Date("2022-02-01"):Month(1):Date("2022-02-01")+Month(11))

julia> show(ts)
(12 x 1) TS with Dates.Date Index

 Index       x1
 Date        Int64
───────────────────
 2022-02-01      1
 2022-03-01      2
 2022-04-01      3
 2022-05-01      4
 2022-06-01      5
 2022-07-01      6
 2022-08-01      7
 2022-09-01      8
 2022-10-01      9
 2022-11-01     10
 2022-12-01     11
 2023-01-01     12

julia> rollapply(sum, ts, :x1, 10)
(3 x 1) TS with Dates.Date Index

 Index       x1_rolling_sum
 Date        Float64
────────────────────────────
 2022-11-01            55.0
 2022-12-01            65.0
 2023-01-01            75.0

julia> rollapply(Statistics.mean, ts, 1, 5)
(8 x 1) TS with Dates.Date Index

 Index       x1_rolling_mean
 Date        Float64
─────────────────────────────
 2022-06-01              3.0
 2022-07-01              4.0
 2022-08-01              5.0
 2022-09-01              6.0
 2022-10-01              7.0
 2022-11-01              8.0
 2022-12-01              9.0
 2023-01-01             10.0

```
"""
function rollapply(fun::Function, ts::TS, column::Any, windowsize::Int) # TODO: multiple columns
    if windowsize < 1
        error("windowsize must be greater than or equal to 1")
    end
    col = Int(1)
    if typeof(column) <: Int
        col = copy(column)
        col = col+1             # index is always 1
    else
        col = column
    end
    res = RollingFunctions.rolling(fun, ts.coredata[!, col], windowsize)
    idx = TSx.index(ts)[windowsize:end]
    colname = names(ts.coredata[!, [col]])[1]
    res_df = DataFrame([idx, res], ["Index", "$(colname)_rolling_$(fun)"])
    return TS(res_df)
end

######################
# Plot
######################

"""
# Plotting

```julia
plot(ts::TS, cols::Vector{Int} = collect(1:TSx.ncol(ts)))
plot(ts::TS, cols::Vector{T}) where {T<:Union{String, Symbol}}
plot(ts::TS, cols::T) where {T<:Union{Int, String, Symbol}}
```

Plots a TS object with the index on the x-axis and selected `cols` on
the y-axis. By default, plot all the columns. Columns can be selected
using Int indexes, String(s), or Symbol(s).

# Example
```jldoctest; setup = :(using TSx, DataFrames, Dates, Plots, Random, Statistics)
julia> using Random;
julia> random(x) = rand(MersenneTwister(123), x);
julia> dates = Date("2022-01-01"):Month(1):Date("2022-01-01")+Month(11);

julia> df = DataFrame(Index = dates,
        val1 = random(12),
        val2 = random(12),
        val3 = random(12));

julia> ts = TS(df)
julia> show(ts)
(12 x 3) TS with Dates.Date Index

 Index       val1        val2        val3
 Date        Float64     Float64     Float64
────────────────────────────────────────────────
 2022-01-01  -0.319954    0.974594   -0.552977
 2022-02-01  -0.0386735  -0.171675    0.779539
 2022-03-01   1.67678    -1.75251     0.820462
 2022-04-01   1.69702    -0.0130037   1.0507
 2022-05-01   0.992128    0.76957    -1.28008
 2022-06-01  -0.315461   -0.543976   -0.117256
 2022-07-01  -1.18952    -1.12867    -0.0829082
 2022-08-01   0.159595    0.450044   -0.231828
 2022-09-01   0.501436    0.265327   -0.948532
 2022-10-01  -2.10516    -1.11489     0.285194
 2022-11-01  -0.781082   -1.20202    -0.639953
 2022-12-01  -0.169184    1.34879     1.33361


julia> using Plots

julia> # plot(ts)

# plot first 6 rows with selected columns
julia> # plot(ts[1:6], [:val1, :val3]);

# plot columns 1 and 2 on a specified window size
julia> # plot(ts, [1, 2], size=(600, 400));
```
"""
@recipe function f(ts::TS, cols::Vector{Int} = collect(1:TSx.ncol(ts)))
    seriestype := :line
    size --> (1200, 1200)
    xlabel --> :Index
    ylabel --> join(TSx.names(ts)[cols], ", ")
    legend := true
    label := permutedims(TSx.names(ts)[cols])
    (TSx.index(ts), Matrix(ts.coredata[!, cols.+1])) # increment to account for Index
end

@recipe function f(ts::TS, cols::Vector{T}) where {T<:Union{String, Symbol}}
    colindices = [DataFrames.columnindex(ts.coredata, i) for i in cols]
    colindices .-= 1            # decrement to account for Index
    (ts, colindices)
end

@recipe function f(ts::TS, cols::T) where {T<:Union{Int, String, Symbol}}
    (ts, [cols])
end

######################
# Joins
######################
struct JoinBoth    # inner
end
struct JoinAll    # inner
end
struct JoinLeft     # left
end
struct JoinRight    # right
end

"""
# Joins/Column-binding

`TS` objects can be combined together column-wise using `Index` as the
column key. There are four kinds of column-binding operations possible
as of now. Each join operation works by performing a Set operation on
the `Index` column and then merging the datasets based on the output
from the Set operation. Each operation changes column names in the
final object automatically if the operation encounters duplicate
column names amongst the TS objects.

The following join types are supported:

`join(ts1::TS, ts2::TS, ::Type{JoinBoth})`

a.k.a. inner join, takes the intersection of the indexes of `ts1` and
`ts2`, and then merges the columns of both the objects. The resulting
object will only contain rows which are present in both the objects'
indexes. The function will rename columns in the final object if
they had same names in the TS objects.

`join(ts1::TS, ts2::TS, ::Type{JoinAll})`:

a.k.a. outer join, takes the union of the indexes of `ts1` and `ts2`
before merging the other columns of input objects. The output will
contain rows which are present in all the input objects while
inserting `missing` values where a row was not present in any of the
objects. This is the default behaviour if no `JoinType` object is
provided.

`join(ts1::TS, ts2::TS, ::Type{JoinLeft})`:

Left join takes the index values which are present in the left
object `ts1` and finds matching index values in the right object
`ts2`. The resulting object includes all the rows from the left
object, the column values from the left object, and the values
associated with matching index rows on the right. The operation
inserts `missing` values where in the unmatched rows of the right
object.

`join(ts1::TS, ts2::TS, ::Type{JoinRight})`

Right join, similar to left join but works in the opposite
direction. The final object contains all the rows from the right
object while inserting `missing` values in rows missing from the left
object.

The default behaviour is to assume `JoinAll` if no `JoinType` object
is provided to the `join` method.

`cbind` is an alias for `join` method.

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random;

julia> random(x) = rand(MersenneTwister(123), x);

julia> ts1 = TS(random(10), 1:10)


julia> ts2 = TS(random(10), 1:10)


julia> join(ts1, ts2, JoinAll)


julia> join(ts1, ts2);


julia> join(ts1, ts2, JoinBoth);


julia> join(ts1, ts2, JoinLeft);


julia> join(ts1, ts2, JoinRight);


julia> dates = collect(Date(2017,1,1):Day(1):Date(2017,1,10));

julia> ts1 = TS(random(length(dates)), dates)
julia> show(ts1)
(10 x 1) TS with Dates.Date Index

 Index       x1
 Date        Float64
───────────────────────
 2017-01-01  0.768448
 2017-01-02  0.940515
 2017-01-03  0.673959
 2017-01-04  0.395453
 2017-01-05  0.313244
 2017-01-06  0.662555
 2017-01-07  0.586022
 2017-01-08  0.0521332
 2017-01-09  0.26864
 2017-01-10  0.108871

julia> dates = collect(Date(2017,1,1):Day(1):Date(2017,1,30));

julia> ts2 = TS(random(length(dates)), dates);
julia> show(ts2)
(10 x 1) TS with Int64 Index

 Index  x1
 Int64  Float64
──────────────────
     1  0.768448
     2  0.940515
     3  0.673959
     4  0.395453
     5  0.313244
     6  0.662555
     7  0.586022
     8  0.0521332
     9  0.26864
    10  0.108871
(10 x 1) TS with Int64 Index

 Index  x1
 Int64  Float64
──────────────────
     1  0.768448
     2  0.940515
     3  0.673959
     4  0.395453
     5  0.313244
     6  0.662555
     7  0.586022
     8  0.0521332
     9  0.26864
    10  0.108871
(30 x 1) TS with Dates.Date Index

 Index       x1
 Date        Float64
───────────────────────
 2017-01-01  0.768448
 2017-01-02  0.940515
 2017-01-03  0.673959
 2017-01-04  0.395453
 2017-01-05  0.313244
 2017-01-06  0.662555
 2017-01-07  0.586022
 2017-01-08  0.0521332
     ⋮           ⋮
 2017-01-23  0.281066
 2017-01-24  0.792931
 2017-01-25  0.20923
 2017-01-26  0.918165
 2017-01-27  0.614255
 2017-01-28  0.802665
 2017-01-29  0.555668
 2017-01-30  0.940782
        14 rows omitted


# calls `JoinAll` method
julia> join(ts1, ts2);
# alias
julia> cbind(ts1, ts2);
```
"""
function Base.join(ts1::TS, ts2::TS)
    join(ts1, ts2, JoinAll)
end

function Base.join(ts1::TS, ts2::TS, ::Type{JoinBoth})
    result = DataFrames.innerjoin(ts1.coredata, ts2.coredata, on = :Index, makeunique=true)
    return TS(result)
end

function Base.join(ts1::TS, ts2::TS, ::Type{JoinAll})
    result = DataFrames.outerjoin(ts1.coredata, ts2.coredata, on = :Index, makeunique=true)
    return TS(result)
end

function Base.join(ts1::TS, ts2::TS, ::Type{JoinLeft})
    result = DataFrames.leftjoin(ts1.coredata, ts2.coredata, on = :Index, makeunique=true)
    return TS(result)
end

function Base.join(ts1::TS, ts2::TS, ::Type{JoinRight})
    result = DataFrames.rightjoin(ts1.coredata, ts2.coredata, on = :Index, makeunique=true)
    return TS(result)
end
# alias
cbind = join

"""
# Row-merging (vcat/rbind)

```julia
vcat(ts1::TS, ts2::TS; colmerge::Symbol=:union)
```

Concatenate rows of two TS objects, append `ts2` to `ts1`.

The `colmerge` keyword argument specifies the column merge
strategy. The value of `colmerge` is directly passed to `cols`
argument of `DataFrames.vcat`.

Currently, `DataFrames.vcat` supports four types of column-merge strategies:

1. `:setequal`: only merge if both objects have same column names, use the order of columns in `ts1`.
2. `:orderequal`: only merge if both objects have same column names and columns are in the same order.
3. `:intersect`: only merge the columns which are common to both objects, ignore the rest.
4. `:union`: merge even if columns differ, the resulting object has all the columns filled with `missing`, if necessary.

# Examples
```jldoctest; setup = :(using TSx, DataFrames, Dates, Random, Statistics)
julia> using Random;

julia> random(x) = rand(MersenneTwister(123), x);

julia> dates1 = collect(Date(2017,1,1):Day(1):Date(2017,1,10));

julia> dates2 = collect(Date(2017,1,11):Day(1):Date(2017,1,30));

julia> ts1 = TS([randn(length(dates1)) randn(length(dates1))], dates1)
julia> show(ts1)
(10 x 1) TS with Dates.Date Index

 Index       x1
 Date        Float64
────────────────────────
 2017-01-01  -0.420348
 2017-01-02   0.109363
 2017-01-03  -0.0702014
 2017-01-04   0.165618
 2017-01-05  -0.0556799
 2017-01-06  -0.147801
 2017-01-07  -2.50723
 2017-01-08  -0.099783
 2017-01-09   0.177526
 2017-01-10  -1.08461

julia> df = DataFrame(x1 = randn(length(dates2)), y1 = randn(length(dates2)))
julia> ts2 = TS(df, dates2)
julia> show(ts2)
(20 x 1) TS with Dates.Date Index

 Index       x1
 Date        Float64
────────────────────────
 2017-01-11   2.15087
 2017-01-12   0.9203
 2017-01-13  -0.0879142
 2017-01-14  -0.930109
 2017-01-15   0.061117
 2017-01-16   0.0434627
 2017-01-17   0.0834733
 2017-01-18  -1.52281
     ⋮           ⋮
 2017-01-23  -0.756143
 2017-01-24   0.491623
 2017-01-25   0.549672
 2017-01-26   0.570689
 2017-01-27  -0.380011
 2017-01-28  -2.09965
 2017-01-29   1.37289
 2017-01-30  -0.462384
          4 rows omitted


julia> vcat(ts1, ts2)
(30 x 3) TS with Date Index

 Index       x1          x2              y1
 Date        Float64     Float64?        Float64?
─────────────────────────────────────────────────────────
 2017-01-01  -0.524798        -1.4949    missing
 2017-01-02  -0.719611        -1.1278    missing
 2017-01-03   0.0926092        1.19778   missing
 2017-01-04   0.236237         1.39115   missing
 2017-01-05   0.369588         1.21792   missing
 2017-01-06   1.65287         -0.930058  missing
 2017-01-07   0.761301         0.23794   missing
 2017-01-08  -0.571046        -0.480486  missing
 2017-01-09  -2.01905         -0.46391   missing
 2017-01-10   0.193942        -1.01471   missing
 2017-01-11   0.239041   missing              -0.473429
 2017-01-12   0.286036   missing              -0.90377
 2017-01-13   0.683429   missing              -0.128489
 2017-01-14  -1.51442    missing              -2.39843
 2017-01-15  -0.581341   missing              -0.12265
 2017-01-16   1.07059    missing              -0.916064
 2017-01-17   0.859396   missing               0.0162969
 2017-01-18  -1.93127    missing               2.11127
 2017-01-19   0.529477   missing               0.636964
 2017-01-20   0.817429   missing              -0.34038
 2017-01-21  -0.682296   missing              -0.971262
 2017-01-22   1.36232    missing              -0.236323
 2017-01-23   0.143188   missing              -0.501722
 2017-01-24   0.621845   missing              -1.20016
 2017-01-25   0.076199   missing              -1.36616
 2017-01-26   0.379672   missing              -0.555395
 2017-01-27   0.494473   missing               1.05389
 2017-01-28   0.278259   missing              -0.358983
 2017-01-29   0.0231765  missing               0.712526
 2017-01-30   0.516704   missing               0.216855

julia> vcat(ts1, ts2; colmerge=:intersect)
(30 x 1) TS with Date Index

 Index       x1
 Date        Float64
────────────────────────
 2017-01-01  -0.524798
 2017-01-02  -0.719611
 2017-01-03   0.0926092
 2017-01-04   0.236237
 2017-01-05   0.369588
 2017-01-06   1.65287
 2017-01-07   0.761301
 2017-01-08  -0.571046
 2017-01-09  -2.01905
 2017-01-10   0.193942
 2017-01-11   0.239041
 2017-01-12   0.286036
 2017-01-13   0.683429
 2017-01-14  -1.51442
 2017-01-15  -0.581341
 2017-01-16   1.07059
 2017-01-17   0.859396
 2017-01-18  -1.93127
 2017-01-19   0.529477
 2017-01-20   0.817429
 2017-01-21  -0.682296
 2017-01-22   1.36232
 2017-01-23   0.143188
 2017-01-24   0.621845
 2017-01-25   0.076199
 2017-01-26   0.379672
 2017-01-27   0.494473
 2017-01-28   0.278259
 2017-01-29   0.0231765
 2017-01-30   0.516704

```
"""
function Base.vcat(ts1::TS, ts2::TS; colmerge=:union)
    result_df = DataFrames.vcat(ts1.coredata, ts2.coredata; cols=colmerge)
    return TS(result_df)
end
# alias
rbind = vcat

end                             # END module TSx
