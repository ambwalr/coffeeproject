body=$("body")

V = _VectorLib.V2D

output = $ "<div id=output></div>"
body.append output

controlpanel= $ "<div style='background-color: silver'></div>"
body.append controlpanel
controlpanel.append $ "<p>WASD to move, mouse click to fire. kinda wonky but OH WELL</p>"


outputqueue = []
out = (text) ->
  outputqueue.push (text)
flush = () ->
  output.append outputqueue.join()
  outputqueue = []

bindings=[]

tapkeylistener = (e) ->
  key=e.keyCode
  charkey = String.fromCharCode(key)
  console.log e
  funct = bindings[charkey]
  if funct
    funct()
tickcalls = []
holdkeylistener = (e) ->
  key=e.keyCode
  charkey = String.fromCharCode(key)
  console.log e
  funct = bindings[charkey]
  if funct and funct not in tickcalls
    tickcalls.push funct
  console.log tickcalls
releasekeylistener = (e) ->
  key=e.keyCode
  charkey = String.fromCharCode(key)
  funct = bindings[charkey]
  if funct and funct in tickcalls
    tickcalls.splice tickcalls.indexOf(funct), 1

body.bind('keydown',{}, holdkeylistener )
body.bind('keyup',{}, releasekeylistener )

mouselistener = (e) ->
  bulletrange = 200
  clickpoint = V e.offsetX, e.offsetY
  console.log clickpoint
  console.log cam.loc()
  clickpoint = clickpoint.add cam.loc()
  
  #random spread
  clickpoint = clickpoint.add randompoint().nsub(.5).nmul(10)

  aimdirection = clickpoint.sub(dude.loc).norm()
  
  endpoint = dude.loc.add aimdirection.nmul bulletrange
  firebullet( dude.loc, endpoint )

output.bind('mousedown',{}, mouselistener )

keybind = (key,funct) ->
  bindings[key]=funct

firebullet = (from,to) ->
  fromloc = V from.x, from.y
  toloc = V to.x, to.y
  trace = new Tracer( fromloc, toloc )
  
  allactors = gameworld.entitylist.filter (ent) -> ent instanceof Enemy

  allactors.forEach (ent) ->
    targetsize = 8
    hitbox = new Square ent.loc.nsub(targetsize), ent.loc.nadd(targetsize)
    hitbool= HitboxRayIntersect hitbox, trace
    if hitbool
      ent.damage 1
      bleed V ent.loc.x, ent.loc.y
      gameworld.addent hitbox

  gameworld.addent trace

closestEntity = ( vector ) ->
  minDist = 1000
  closest = 0
  gameworld.entitylist.forEach (entity) ->
    dist = vector.dist entity.loc
    if dist < minDist
      closest = entity
      minDist = dist

  return closest

class Entity
  loc=V 0,0
  tick: () ->
    #nop
  draw: () ->
    #nop
  kill: () ->
    at = gameworld.entitylist.indexOf @
    gameworld.entitylist.splice at, 1

class Tracer extends Entity
  constructor: (@loc, @to) ->
    @age = 0
  tick: () ->
    @age++
    if @age > 4
      @kill()
  draw: () ->
    "<line x1=#{@loc.x} y1=#{@loc.y} x2=#{@to.x} y2=#{@to.y} stroke=black/>"

class LineDef extends Entity
  constructor: (@loc, @to) ->
  tick: () ->
    allactors = gameworld.entitylist.filter (ent) -> ent instanceof Actor

    allactors.forEach (ent) =>
      target = ent
      targetsize = 8
      hitbox = new Square target.loc.nsub(targetsize), target.loc.nadd(targetsize)
      hitbool = HitboxRayIntersect( hitbox, @ )
      if hitbool
        bleed V target.loc.x, target.loc.y
        target.vel = target.vel.nmul -1.5
        gameworld.addent hitbox
  
  draw: () ->
    "<line x1=#{@loc.x} y1=#{@loc.y} x2=#{@to.x} y2=#{@to.y} stroke=brown stroke-width=4px />"

class Blood extends Entity
  constructor: (@loc) ->
    @age = 0
  draw: () ->
    "<circle r=4 cx=#{@loc.x} cy=#{@loc.y} fill=red/>"
  tick: () ->
    @age++
    if @age > 4
      @kill()
bleed = ( loc ) ->
  blood=new Blood(loc)
  gameworld.addent(blood)

class Actor extends Entity
  constructor: ( @loc=V(0,0) ) ->
    @health = 3
    @vel= V 0,0
  draw: () ->
    return "<circle fill=magenta r=10 cx=#{@loc.x} cy=#{@loc.y} />"

  damage: () ->
    @health -= 1
  
  tick: () ->
    if @health <= 0
      @kill()
    @movetick()

  movetick: () ->
    newv = @loc.add @vel
    friction = 9/10
    @vel = @vel.nmul friction
    @loc = newv

class Player extends Actor

  constructor: () ->
    @vel= V 0,1
    @loc= V 10,20
  draw: () ->
    return "<circle fill=orange r=10 cx=#{@loc.x} cy=#{@loc.y} />"
  tick: () ->
    @movetick()
  move: (x,y) ->
    @vel.x += x
    @vel.y += y

randompoint = ->
  return V Math.random(), Math.random()

class Enemy extends Actor
  constructor: () ->
    super()
    @loc=randompoint().nmul 200
    @vel= V 1, 1
  draw: () ->
    return "<circle fill=green r=10 cx=#{@loc.x} cy=#{@loc.y} />"
  tick: () ->
    @jostle()
    super()
  jostle: () ->
    @vel = @vel.add randompoint().nmul(2).nsub(1).ndiv(10)

dude = new Player()

north = ->
  dude.move(0,-1)
west = ->
  dude.move(-1,0)
south = ->
  dude.move(0,1)
east = ->
  dude.move(1,0)
keybind 'W', north
keybind 'A', west
keybind 'S', south
keybind 'D', east


#GEOMETRY
class Point
  constructor: ( @pos ) ->
class LineSegment
  constructor: ( @startpoint, @endpoint ) ->
class Square extends Entity
  constructor: ( @topleft, @bottomright ) ->
    @loc = @topleft
    @age = 0
  tick: () ->
    @age++
    if @age > 4
      @kill()
  draw: () ->
    size = @bottomright.sub @topleft
    return "<rect x=#{@topleft.x} y=#{@topleft.y} width=#{size.x} height=#{size.y} stroke=magenta fill=none/>"


class World
  constructor: () ->
    @entitylist = [ dude ]
    for i in [0..8]
      @addent new Enemy()
    
    @addent new LineDef V( 0, 300 ) , V( 0, 0 )
    @addent new LineDef V( 200, 0 ) , V( 0, 0 )
    @addent new LineDef V( 0, 300 ) , V( 200, 250 )
    @addent new LineDef V( 200, 0 ) , V( 200, 200 )
    @addent new LineDef V( 200, 200 ) , V( 400, 200 )
    @addent new LineDef V( 200, 250 ) , V( 400, 250 )
  
  addent: ( ent ) ->
    @entitylist.push ent
  
  render: ->
    output.html('')
    
    camloc= cam.loc()
    size = cam.size()

    out "<svg width=640 height=480 viewbox='"+camloc.x+" "+camloc.y+" "+size.x+" "+size.y+"'>"

     
    @entitylist.forEach( (ent) ->
      out ent.draw()
    )
    out "</svg>"
    flush()
  
  tick: ->
    @entitylist.forEach (ent) -> ent.tick()

class Camera
  size: () ->
    V 640, 480
  loc: () ->
    size=@size()
    camloc= dude.loc.sub size.ndiv 2
    return camloc
cam = new Camera

#based on an implementation by metamal on stackoverflow
HitboxRayIntersect = ( rect, line ) ->
  minx = line.loc.x
  maxx = line.to.x
  if line.loc.x > line.to.x
    minx=line.to.x
    maxx=line.loc.x
  maxx = Math.min maxx, rect.bottomright.x
  minx = Math.max minx, rect.topleft.x
  if minx > maxx
    return false
  miny = line.loc.y
  maxy = line.to.y
  dx = line.to.x-line.loc.x
  if Math.abs(dx) > 0.0000001
    a=(line.to.y-line.loc.y)/dx
    b=line.loc.y-a*line.loc.x
    miny=a*minx+b
    maxy=a*maxx+b
  if miny > maxy
    tmp=maxy
    maxy = miny
    miny = tmp
  maxy=Math.min maxy, rect.bottomright.y
  miny=Math.max miny, rect.topleft.y
  if miny>maxy
    return false
  return true

gameworld=new World
mainloop = ->
  tickcalls.forEach (func) -> func()
  gameworld.tick()
  gameworld.render()
  setTimeout mainloop , 20
mainloop()
