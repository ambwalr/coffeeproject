class Vector
  constructor: (@x,@y,@z) ->

V = (x,y,z) -> new Vector x,y,z
V2D = (x,y) -> new Vector x,y
V3D = (x,y,z) -> new Vector x,y,z

vvop = (f) -> (v,u) -> V f(v.x,u.x), f(v.y,u.y), f(v.z,u.z)
vnop = (f) -> (v,n) -> V f(v.x,n), f(v.y,n), f(v.z,n)

add = (a,b) -> a+b
sub = (a,b) -> a-b
mul = (a,b) -> a*b
div = (a,b) -> a/b

# vx+ux vy+uy vz+uz etc
Vector::add = (v) -> vadd this, v
Vector::sub = (v) -> vsub this, v
Vector::mul = (v) -> vmul this, v
Vector::div = (v) -> vdiv this, v
# vx+n vy+n vz+n etc
Vector::nadd = (n) -> vnadd this, n
Vector::nsub = (n) -> vnsub this, n
Vector::nmul = (n) -> vnmul this, n
Vector::ndiv = (n) -> vndiv this, n

vadd = vvop add
vsub = vvop sub
vmul = vvop mul
vdiv = vvop div
vnadd = vnop add
vnsub = vnop sub
vnmul = vnop mul
vndiv = vnop div

Vector::rotate = (q) ->
  np= V 0,0,0
  qc = Math.cos(q)
  qs = Math.sin(q)
  np.z = @z * qc - @x * qs
  np.x = @z * qs + @x * qc
  np.y = @y
  np

sq = (n) -> Math.pow n, 2
Vector::mag = ->
  Math.abs Math.sqrt sq(@x)+sq(@y)
Vector::norm = -> @ndiv @mag() 
Vector::dist = (v) -> @sub(v).mag()

Vector::dot2d = (a,b) -> a.x*b.x + a.y*b.y
Vector::dot3d = (a,b) -> a.x*b.x + a.y*b.y + a.z*b.z

@_VectorLib = {
V: V
V3D: V3D
V2D: V2D
Vector: Vector
}

