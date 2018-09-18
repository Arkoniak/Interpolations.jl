@inline sqr(x) = x*x
@inline cub(x) = x*x*x

modrange(x, r::AbstractUnitRange) = mod(x-first(r), length(r)) + first(r)

split_flag(f::Flag) = f, f
split_flag(t::Tuple) = t[1], Base.tail(t)

splitpaired(prs) = first.(prs), last.(prs)

fast_trunc(::Type{Int}, x) = unsafe_trunc(Int, x)
fast_trunc(::Type{Int}, x::Rational) = x.num ÷ x.den

iextract(f::Flag, d) = f
iextract(t::Tuple, d) = t[d]

# Substitution for gradient components
function substitute(default::NTuple{N,Any}, d::Integer, subst::NTuple{N,Any}) where N
    ntuple(i->ifelse(i==d, subst[i], default[i]), Val(N))
end
function substitute(default::NTuple{N,Any}, d::Integer, val) where N
    ntuple(i->ifelse(i==d, val, default[i]), Val(N))
end

# Substitution for hessian components
function substitute(default::NTuple{N,Any}, d1::Integer, d2::Integer, subst1::NTuple{N,Any}, subst2::NTuple{N,Any}) where N
    ntuple(i->ifelse(i==d1==d2, subst2[i], ifelse(i==d1, subst1[i], ifelse(i==d2, subst1[i], default[i]))), Val(N))
end

@inline skip_nointerp(x, rest...) = (x, skip_nointerp(rest...)...)
@inline skip_nointerp(::NoInterp, rest...) = skip_nointerp(rest...)
skip_nointerp() = ()
