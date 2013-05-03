#requires amb's shitty vector library
Vector=@_VectorLib.Vector

#maths and vectors and functions and etc

rand = Math.random
sq = (n) -> n*n

randelem = (arr) ->
  arr[Math.floor Math.random()*(arr.length)]


V = (x,y,z) -> new Vector x,y,z

randf = -> rand()*2-1
randpoint = -> V randf(), randf(), randf()

#some functions that generate some point clouds
pointsquare = (n) ->
  pts =[]
  n--
  [0..n].forEach (x) ->
    [0..n].forEach (y) ->
      pts.push V x/n, y/n, 0
  pts

pointcross = (n) ->
  pc=[]
  pc=pc.concat [1..n].map (i) ->
    V i/n, 0, 0
  pc=pc.concat [1..n].map (i) ->
    V 0, i/n, 0
  pc=pc.concat [1..n].map (i) ->
    V 0, 0, i/n

pointcube = (n) ->
  pc=[]
  n--
  [0..n].forEach (i) ->
    pc=pc.concat cloudshift( pointsquare(n+1), V(0,0,i/n) )
  pc

#manipulating point clouds
cloudscale = ( cl , factor ) -> cl.map (v) -> v.nmul factor
cloudshift = ( cl , offset ) -> cl.map (v) -> v.add offset
cloudrotate = ( cl, q ) -> cl.map (v) -> v.rotate(q)

#output
cache = []
flush = -> $("#out").append cache.join " "; cache = []
out = (text) -> cache.push text
clearout = -> $("#out").html ""

#xml generation
tagatts = (attobj) ->
  attstr=""
  for k,v of attobj
    attstr += " #{k}=\"#{v}\""
  attstr
tag = (type,att,body="") ->
  return "<#{type} #{tagatts att}>#{body}</#{type}>"

svgpoly = (pts,atts) ->
  atts.points = pts.map( (p) ->
    p.x + "," + p.y ).join(" ")
  tag "polygon",atts


class Camera
  constructor: ->
    @zoom= 100
    @rotation = 0
    @offset = V 0,0,0
  setrotation: (degrees) -> @rotation = degrees
  setzoom: (num) -> @zoom = num
  setxcoord: ( x ) -> @offset.x = x
  setycoord: ( y ) -> @offset.y = y
  setzcoord: ( z ) -> @offset.z = z

camera = new Camera

wellnamedpointfunction = ( p ) ->
  np= V 0,0,p.z
  zoom = camera.zoom
  np.x = p.x / p.z * zoom
  np.y = p.y / p.z * zoom
  np.x += 100
  np.y += 100
  return np

projectpoint = (point) ->
  p=point.rotate Math.PI*2*(camera.rotation/360)
  p=p.add camera.offset
  return wellnamedpointfunction p

projectcloud = (points) ->
  points.map projectpoint 

pointcolor = (pt) -> "hsl(120,50%,#{Math.round((128-pt.z*20))}%)"

class Primitive
  z: -> 2

class Pointcloud extends Primitive
  constructor: (@points,@color) ->
  draw: ->
    points=projectcloud @points
    points.sort (a,b) -> b.z - a.z
    points.forEach (p) =>
      fillcolor = @color or pointcolor(p)
      atts= cx: p.x, cy: p.y, r: 1, fill: fillcolor
      out tag "circle",atts

class Polygon extends Primitive
  constructor: (@points,@atts={stroke:"gray"}) ->
  z: ->
    pr=projectcloud @points
    zeds= pr.map (p) -> p.z
    res= zeds.reduce (a,b) -> Math.max(a,b)
    return res 
  draw: ->
    out svgpoly projectcloud(@points),@atts
class Quad extends Polygon

class Sphere extends Primitive
  constructor: (@pos, @radius, @atts={stroke:"#333",fill:"white"}) ->
  z: ->
    p=projectpoint @pos
    return p.z
  draw: ->
    p=projectpoint @pos
    @atts.cx= p.x
    @atts.cy= p.y
    dist = p.z
    @atts.fill = pointcolor p
    
    zoom = camera.zoom
    ratio=zoom/Math.sqrt(sq(@radius)+sq(dist))
    
    @atts.r=@radius*ratio
    out tag "circle",@atts

class Point extends Primitive
  constructor: (@pos, @color='red' ) ->
  draw: ->
    p=projectpoint @pos
    atts= cx: p.x, cy: p.y, r: 2, fill: @color
    out tag "circle",atts

class Edge extends Primitive
  constructor: (@from,@to) ->
  draw: ->
    pf=projectpoint @from
    pt=projectpoint @to
    atts= cx: pf.x, cy: pf.y, r: 1, fill: "#eee", stroke: "#444", "stroke-width": 0.6
    out tag "circle",atts
    atts= cx: pt.x, cy: pt.y, r: 1, fill: "#eee", stroke: "#444", "stroke-width": 0.6
    out tag "circle",atts
    atts= x1: pf.x, y1: pf.y, x2: pt.x, y2: pt.y, stroke: "#222", "stroke-width": 0.75
    out tag "line",atts

class Polyline extends Primitive
  constructor: (@points) ->
  draw: ->
    ps = projectcloud @points
    lastpoint = false
    ps.forEach( (p) ->
      #atts= cx: p.x, cy: p.y, r: 1, fill: "#eee", stroke: "#444", "stroke-width": 0.6
      #out tag "circle",atts
      if lastpoint
        last=lastpoint
        atts= x1: last.x, y1: last.y, x2: p.x, y2: p.y, stroke: "#222", "stroke-width": 0.75
        atts.stroke = pointcolor last
        out tag "line",atts
      lastpoint=p
    )

class Ballpit extends Primitive
  constructor: (@locations=[]) ->
    @balls = []
    locations.forEach ( pos ) =>
      @balls.push new Sphere pos,0.1
  draw: ->
    balls = @balls.sort (a,b) -> return b.z() - a.z()
    balls.forEach (ball) ->
      ball.draw()

projectsize = ( pos, size ) ->
  p=projectpoint pos
  dist = p.z
  zoom = camera.zoom
  ratio=zoom/Math.sqrt(sq(size)+sq(dist))
  projsize = size * ratio
  return projsize

class Target extends Primitive
  constructor: (@pos, @size=0.5, @atts={}) ->
  z: ->
    p=projectpoint @pos
    return p.z
  draw: ->
    p=projectpoint @pos
    projsize = projectsize( @pos, @size )

    @atts.x= p.x- projsize/2
    @atts.y= p.y - projsize/2
    
    @atts.width = Math.ceil projsize
    @atts.height = Math.ceil projsize
    @atts["xlink:href"] = "images/Nopenis.svg"
    out tag "image",@atts

class Group extends Primitive
  constructor: (@children=[]) ->
  draw: ->
    out "<g>" 
    @children.forEach (child) -> child.draw()
    out "</g>" 

class World
  constructor: (@contents = []) ->
  addobj: (object) -> @contents.push object
  addobjs: (objects) -> objects.forEach (object) => @addobj object
  render: ->
    @contents.forEach (thing) -> thing.draw()

#set up scenes yo
scenes = []

world = new World

square =[]
square.push V -1, 0, -1
square.push V 1, 0, -1
square.push V 1, 0, 1
square.push V -1, 0, 1

world.addobj new Quad cloudshift(square,V(0,-1.5,0)), {fill:"#dbb",stroke:"gray"}
world.addobj new Quad cloudshift(square,V(0,2,0)), {fill:"#beb",stroke:"gray"}
world.addobj new Quad cloudshift(square,V(0,1.5,0)), {fill:"#bbf",stroke:"gray"}
rcolor = ->
  randelem [ "magenta", "cyan", "yellow", "lime", "red" ]

tri = ->
  ps=[1..3].map(randpoint)
  ps=cloudscale(ps,0.2)
  ps=cloudshift ps,randpoint()
  
  t=new Quad ps,{"stroke-width":"0.5pt",stroke:"white",fill:rcolor()}
  return t

world.addobj new Group [0..100].map tri

scenes.push world

lineworld = new World
lineworld.addobj new Polyline [0..100].map randpoint

scenes.push lineworld

lineworld = new World
randchain = ->
  linepoints = []
  linepoints.push V 0,0,0
  for i in [0..50]
    lastpoint = linepoints[linepoints.length-1]
    linepoints.push lastpoint.add randpoint().ndiv 8
  return linepoints

[0..2].forEach ->
  lineworld.addobj new Polyline randchain()

scenes.push lineworld

polyworld = new World
polyworld.addobj new Polygon [0..16].map( -> randpoint().nmul 2),{fill:'orange'}

scenes.push polyworld

pointcloud=[1..400].map randpoint
pointcloud = pointcloud.concat cloudshift( cloudscale( pointcross(8), 0.5 ), V(0,0,0) )
pointcloud = pointcloud.concat cloudshift( cloudscale( pointcross(8), -0.5 ), V(0,0,0) )
pcworld = new World
pcworld.addobj new Pointcloud pointcloud
scenes.push pcworld

scenes.push world=new World
cube = pointcube 10
centerpoint = V(0,0,0)
onev = V(1,1,1)
negone = centerpoint.sub onev

world.addobj new Pointcloud cloudscale cloudshift( cube, negone.ndiv 2 ), 2
#cloudshift cloudscale( pointcube(8), 2 ), V(-1,-1,-1)

scenes.push world=new World
world.addobj new Ballpit [ V( 1,1,1 ), V( 1,-1,1 ), V( -1,1,1 ), V( -1,-1,1 ), V( 1,1,-1 ), V( 1,-1,-1 ), V( -1,1,-1 ), V( -1,-1,-1 ) ]
scenes.push world=new World
world.addobj new Polyline [ V( 1,1,1 ), V( 1,-1,1 ), V( -1,1,1 ), V( -1,-1,1 ), V( 1,1,-1 ), V( 1,-1,-1 ), V( -1,1,-1 ), V( -1,-1,-1 ) ]

scenes.push world=new World
world.addobj new Ballpit [0..50].map randpoint

scenes.push world=new World
world.addobjs [0..10].map -> new Target randpoint()

now = -> new Date().getTime()

svgdraw = ->
  size = 400
  viewbox = "0 0 200 200"
  atts = width: size, height: size, viewbox: viewbox
  out "<svg #{tagatts atts}>"
  world.contents = world.contents.sort (a,b) ->
    return b.z() - a.z()
  begin = now()
  world.render()
  rendertime = now() - begin
  out "</svg>"
  out tag "div",{},"time taken to write svg for last frame: #{rendertime} ms"
  
update = () ->
  clearout()
  svgdraw() 

  #stereoscopy whoaohaoao
  ###
  interoculardist = 1/6
  tempx=camera.offset.x
  camera.offset.x=tempx+interoculardist
  svgdraw() 
  camera.offset.x=tempx
  ###

  flush()

body=$ "body"

tagslider = ( min, max, step=1 ) ->
  slider = $ tag "input", { type:"range", min:min, max:max, step:step, style:"width: 400px" }
  slider.change -> this.title=this.value
  return slider

label = (text) -> tag "label",{},text

form=$ tag "form",{class:"panel"}
body.append form

form.append $ tag "span",{}, "camera settings:<br/>"

form.append $(label "rotation").prepend slid = tagslider 0,360
slid.change ->
  camera.setrotation 0 - parseFloat this.value

timer = setTimeout()
spin = ->
  camera.setrotation camera.rotation-0.3
  timer = setTimeout( spin, 50 )
  update()

chk = $ tag "input",{type:"checkbox"}
form.append $(label "spin").prepend chk
chk.change ->
  if this.checked
    spin()
  else
    clearTimeout(timer)

form.append $(label "zoom").prepend tagslider(10,500).change -> camera.setzoom parseFloat this.value
form.append $(label "distance").prepend tagslider(1,8,0.01).change -> camera.setzcoord parseFloat this.value

form.append $(label "pan x").prepend tagslider(-4,4,0.01).change -> camera.setxcoord parseFloat this.value
form.append $(label "pan y").prepend tagslider(-4,4,0.01).change -> camera.setycoord parseFloat this.value

form.append $ tag "hr"
resetbutton = $ tag "input",{type:"reset"}
form.append resetbutton

$("input").change update
$("input").change()

resetbutton.click ->
  fun = -> $("input").change()
  setTimeout( fun, 10 )

num=0
scenes.forEach (scene) ->
  buton=$ tag "button",{},"scene ##{num++}"
  body.append buton
  buton.click ->
    world = scene
    update()

