module ConstantTests

using Interpolations, Base.Test

a = rand(5)
knots = (collect(linspace(1,length(a),length(a))),)
itp = @inferred(interpolate(knots, a, Gridded{Constant}))
@inferred(getindex(itp, 2))
@inferred(getindex(itp, CartesianIndex((2,))))
for i = 2:length(a)-1
    @test_approx_eq itp[i] a[i]
    @test_approx_eq itp[CartesianIndex((i,))] a[i]
end
@inferred(getindex(itp, knots...))
@test_approx_eq itp[knots...] a

A = rand(6,5)
knots = (collect(linspace(1,size(A,1),size(A,1))),collect(linspace(1,size(A,2),size(A,2))))
itp = @inferred(interpolate(knots, A, Gridded{Constant}))
@inferred(getindex(itp, 2, 2))
@inferred(getindex(itp, CartesianIndex((2,2))))
for j = 2:size(A,2)-1, i = 2:size(A,1)-1
    @test_approx_eq itp[i,j] A[i,j]
    @test_approx_eq itp[CartesianIndex((i,j))] A[i,j]
end
@test_approx_eq itp[knots...] A
@inferred(getindex(itp, knots...))

A = rand(8,20)
knots = ([x^2 for x = 1:8], [0.2y for y = 1:20])
itp = interpolate(knots, A, Gridded{Linear})
@test_approx_eq itp[4,1.2] A[2,6]

end
