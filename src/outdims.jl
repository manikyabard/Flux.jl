module NilNumber

using NNlib

"""
    Nil <: Number

Nil is a singleton type with a single instance `nil`.
Unlike `Nothing` and `Missing` it subtypes `Number`.
"""
struct Nil <: Number end

const nil = Nil()

Nil(::T) where T<:Number = nil
(::Type{T})(::Nil) where T<:Number = nil
Base.convert(::Type{Nil}, ::Number) = nil

Base.float(::Type{Nil}) = Nil

for f in [:copy, :zero, :one, :oneunit,
          :+, :-, :abs, :abs2, :inv,
          :exp, :log, :log1p, :log2, :log10,
          :sqrt, :tanh, :conj]
  @eval Base.$f(::Nil) = nil
end

for f in [:+, :-, :*, :/, :^, :mod, :div, :rem]
  @eval Base.$f(::Nil, ::Nil) = nil
end

Base.isless(::Nil, ::Nil) = true
Base.isless(::Nil, ::Number) = true
Base.isless(::Number, ::Nil) = true

Base.isnan(::Nil) = false

Base.typemin(::Type{Nil}) = nil
Base.typemax(::Type{Nil}) = nil

Base.promote_rule(x::Type{Nil}, y::Type{<:Number}) = Nil

end  # module

using .NilNumber: Nil, nil

"""
    outdims(m, isize; padbatch = true)

Calculate the output size of model/function `m` given an input of size `isize` (w/o computing results).
`isize` should include all dimensions (except the batch dimension can be excluded when `padbatch == true`).
If `m` is a `Tuple` or `Vector`, `outdims` treats `m` like a `Chain`.

*Note*: this method should work out of the box for custom layers.

# Examples
```jldoctest
julia> outdims(Dense(10, 4), (10,))
(4, 1)

julia> m = Chain(Conv((3, 3), 3 => 16), Conv((3, 3), 16 => 32));

julia> m(randn(Float32, 10, 10, 3, 64)) |> size
(6, 6, 32, 64)

julia> outdims(m, (10, 10, 3))
(6, 6, 32, 1)

julia> outdims(m, (10, 10, 3, 64); padbatch = false)
(6, 6, 32, 64)

julia> try outdims(m, (10, 10, 7, 64); padbatch = false) catch e println(e) end
DimensionMismatch("Input channels must match! (7 vs. 3)")

julia> outdims([Dense(10, 4), Dense(4, 2)], (10,))
(2, 1)

julia> using LinearAlgebra: norm

julia> f(x) = x ./ norm.(eachcol(x));

julia> outdims(f, (10, 1); padbatch = false) # manually specify batch size as 1
(10, 1)

julia> outdims(f, (10,)) # no need to mention batch size
(10, 1)
```
"""
function outdims(m, isize; padbatch = true)
  isize = padbatch ? (isize..., 1) : isize
  
  return size(m(fill(nil, isize)))
end

## make tuples and vectors be like Chains

outdims(m::Tuple, isize) = outdims(Chain(m...), isize)
outdims(m::AbstractVector, isize) = outdims(Chain(m...), isize)

## bypass statistics in normalization layers

for layer in (:LayerNorm, :BatchNorm, :InstanceNorm, :GroupNorm)
  @eval (l::$layer)(x::AbstractArray{Nil}) = x
end

## fixes for layers that don't work out of the box

for (fn, Dims) in ((:conv, DenseConvDims), (:depthwiseconv, DepthwiseConvDims))
  @eval begin
    function NNlib.$fn(a::AbstractArray{Nil}, b::AbstractArray{Nil}, dims::$Dims)
      fill(nil, NNlib.output_size(dims)..., NNlib.channels_out(dims), size(a)[end])
    end

    function NNlib.$fn(a::AbstractArray{<:Real}, b::AbstractArray{Nil}, dims::$Dims)
      NNlib.$fn(fill(nil, size(a)), b, dims)
    end

    function NNlib.$fn(a::AbstractArray{Nil}, b::AbstractArray{<:Real}, dims::$Dims)
      NNlib.$fn(a, fill(nil, size(b)), dims)
    end
  end
end
