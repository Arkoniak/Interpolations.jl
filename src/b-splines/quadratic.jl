immutable Quadratic{BC<:BoundaryCondition} <: Degree{2} end
Quadratic{BC<:BoundaryCondition}(::Type{BC}) = Quadratic{BC}

function define_indices{BC}(::Type{BSpline{Quadratic{BC}}}, N, pad)
    quote
        @nexprs $N d->begin
            # ensure that all three ix_d, ixm_d, and ixp_d are in-bounds no matter
            # the value of pad
            ix_d = clamp(round(Int, real(x_d)), 2-$pad, size(itp,d)+$pad-1)
            fx_d = x_d - ix_d
            ix_d += $pad # padding for oob coefficient
            ixp_d = ix_d + 1
            ixm_d = ix_d - 1
        end
    end
end
function define_indices(::Type{BSpline{Quadratic{Periodic}}}, N, pad)
    quote
        @nexprs $N d->begin
            ix_d = clamp(round(Int, real(x_d)), 1, size(itp,d))
            fx_d = x_d - ix_d
            ixp_d = mod1(ix_d + 1, size(itp,d))
            ixm_d = mod1(ix_d - 1, size(itp,d))
        end
    end
end

function coefficients{Q<:Quadratic}(::Type{BSpline{Q}}, N)
    :(@nexprs $N d->($(coefficients(BSpline{Q}, N, :d))))
end

function coefficients{Q<:Quadratic}(::Type{BSpline{Q}}, N, d)
    symm, sym, symp =  symbol(string("cm_",d)), symbol(string("c_",d)), symbol(string("cp_",d))
    symfx = symbol(string("fx_",d))
    quote
        $symm = sqr($symfx - SimpleRatio(1,2))/2
        $sym  = SimpleRatio(3,4) - sqr($symfx)
        $symp = sqr($symfx + SimpleRatio(1,2))/2
    end
end

function gradient_coefficients{Q<:Quadratic}(::Type{Q}, N, d)
    symm, sym, symp =  symbol(string("cm_",d)), symbol(string("c_",d)), symbol(string("cp_",d))
    symfx = symbol(string("fx_",d))
    quote
        $symm = $symfx - SimpleRatio(1,2)
        $sym = -2 * $symfx
        $symp = $symfx + SimpleRatio(1,2)
    end
end

# This assumes integral values ixm_d, ix_d, and ixp_d,
# coefficients cm_d, c_d, and cp_d, and an array itp.coefs
function index_gen{Q<:Quadratic}(::Type{BSpline{Q}}, N::Integer, offsets...)
    if length(offsets) < N
        d = length(offsets)+1
        symm, sym, symp =  symbol(string("cm_",d)), symbol(string("c_",d)), symbol(string("cp_",d))
        return :($symm * $(index_gen(BSpline{Q}, N, offsets...,-1)) + $sym * $(index_gen(BSpline{Q}, N, offsets..., 0)) +
                 $symp * $(index_gen(BSpline{Q}, N, offsets..., 1)))
    else
        indices = [offsetsym(offsets[d], d) for d = 1:N]
        return :(itp.coefs[$(indices...)])
    end
end

padding{BC<:BoundaryCondition}(::Type{BSpline{Quadratic{BC}}}) = Val{1}()
padding(::Type{BSpline{Quadratic{Periodic}}}) = Val{0}()

function inner_system_diags{T,Q<:Quadratic}(::Type{T}, n::Int, ::Type{Q})
    du = fill(convert(T, SimpleRatio(1,8)), n-1)
    d = fill(convert(T, SimpleRatio(3,4)), n)
    dl = copy(du)
    (dl,d,du)
end

function prefiltering_system{T,TCoefs,BC<:Union(Flat,Reflect)}(::Type{T}, ::Type{TCoefs}, n::Int, ::Type{Quadratic{BC}}, ::Type{OnCell})
    dl,d,du = inner_system_diags(T,n,Quadratic{BC})
    d[1] = d[end] = -1
    du[1] = dl[end] = 1
    lufact!(Tridiagonal(dl, d, du), Val{false}), zeros(TCoefs, n)
end

function prefiltering_system{T,TCoefs,BC<:Union(Flat,Reflect)}(::Type{T}, ::Type{TCoefs}, n::Int, ::Type{Quadratic{BC}}, ::Type{OnGrid})
    dl,d,du = inner_system_diags(T,n,Quadratic{BC})
    d[1] = d[end] = -1
    du[1] = dl[end] = 0

    rowspec = zeros(T,n,2)
    # first row     last row
    rowspec[1,1] = rowspec[n,2] = 1
    colspec = zeros(T,2,n)
    # third col     third-to-last col
    colspec[1,3] = colspec[2,n-2] = 1
    valspec = zeros(T,2,2)
    # [1,3]         [n,n-2]
    valspec[1,1] = valspec[2,2] = 1

    Woodbury(lufact!(Tridiagonal(dl, d, du), Val{false}), rowspec, valspec, colspec), zeros(TCoefs, n)
end

function prefiltering_system{T,TCoefs,GT<:GridType}(::Type{T}, ::Type{TCoefs}, n::Int, ::Type{Quadratic{Line}}, ::Type{GT})
    dl,d,du = inner_system_diags(T,n,Quadratic{Line})
    d[1] = d[end] = 1
    du[1] = dl[end] = -2

    rowspec = zeros(T,n,2)
    # first row     last row
    rowspec[1,1] = rowspec[n,2] = 1
    colspec = zeros(T,2,n)
    # third col     third-to-last col
    colspec[1,3] = colspec[2,n-2] = 1
    valspec = zeros(T,2,2)
    # [1,3]         [n,n-2]
    valspec[1,1] = valspec[2,2] = 1

    Woodbury(lufact!(Tridiagonal(dl, d, du), Val{false}), rowspec, valspec, colspec), zeros(TCoefs, n)
end

function prefiltering_system{T,TCoefs,GT<:GridType}(::Type{T}, ::Type{TCoefs}, n::Int, ::Type{Quadratic{Free}}, ::Type{GT})
    dl,d,du = inner_system_diags(T,n,Quadratic{Free})
    d[1] = d[end] = 1
    du[1] = dl[end] = -3

    rowspec = zeros(T,n,4)
    # first row     first row       last row       last row
    rowspec[1,1] = rowspec[1,2] = rowspec[n,3] = rowspec[n,4] = 1
    colspec = zeros(T,4,n)
    # third col     fourth col     third-to-last col  fourth-to-last col
    colspec[1,3] = colspec[2,4] = colspec[3,n-2] = colspec[4,n-3] = 1
    valspec = zeros(T,4,4)
    # [1,3]          [n,n-2]
    valspec[1,1] = valspec[3,3] = 3
    # [1,4]          [n,n-3]
    valspec[2,2] = valspec[4,4] = -1

    Woodbury(lufact!(Tridiagonal(dl, d, du), Val{false}), rowspec, valspec, colspec), zeros(TCoefs, n)
end

function prefiltering_system{T,TCoefs,GT<:GridType}(::Type{T}, ::Type{TCoefs}, n::Int, ::Type{Quadratic{Periodic}}, ::Type{GT})
    dl,d,du = inner_system_diags(T,n,Quadratic{Periodic})

    rowspec = zeros(T,n,2)
    # first row       last row
    rowspec[1,1] = rowspec[n,2] = 1
    colspec = zeros(T,2,n)
    # last col         first col
    colspec[1,n] = colspec[2,1] = 1
    valspec = zeros(T,2,2)
    # [1,n]            [n,1]
    valspec[1,1] = valspec[2,2] = SimpleRatio(1,8)

    Woodbury(lufact!(Tridiagonal(dl, d, du), Val{false}), rowspec, valspec, colspec), zeros(TCoefs, n)
end

sqr(x) = x*x
