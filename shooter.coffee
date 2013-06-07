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

#xml generation
tagatts = (attobj) ->
  attstr=""
  for k,v of attobj
    attstr += " #{k}=\"#{v}\""
  attstr
tag = (type,att,body="") ->
  return "<#{type} #{tagatts att}>#{body}</#{type}>"

holdbindings=[]
tapbindings=[]

tapkeylistener = (e) ->
  key=e.keyCode
  charkey = String.fromCharCode(key)
  funct = tapbindings[charkey]
  if funct
    funct()
tickcalls = []
holdkeylistener = (e) ->
  key=e.keyCode
  charkey = String.fromCharCode(key)
  funct = holdbindings[charkey]
  if funct and funct not in tickcalls
    tickcalls.push funct
releasekeylistener = (e) ->
  key=e.keyCode
  charkey = String.fromCharCode(key)
  funct = holdbindings[charkey]
  if funct and funct in tickcalls
    tickcalls.splice tickcalls.indexOf(funct), 1

body.bind('keydown',{}, tapkeylistener )
body.bind('keydown',{}, holdkeylistener )
body.bind('keyup',{}, releasekeylistener )

#(mobile) devices with accelerometer
accellistener = (e) ->
  acc=e.accelerationIncludingGravity
  accv = V acc.x, -acc.y
  if accv.mag()>2
    dude.vel = dude.vel.add accv.ndiv 2

window.ondevicemotion = accellistener

spraybullets = ( loc, end, num ) ->
  [1..num].forEach -> firebullet loc,end

mouselistener = (e) ->
  bulletrange = 200
  clickpoint = V e.offsetX, e.offsetY
  console.log e
  clickpoint = clickpoint.add cam.loc()
  
  aimdirection = clickpoint.sub(dude.loc).norm()
  
  endpoint = dude.loc.add aimdirection.nmul bulletrange
  spraybullets( dude.loc, endpoint, 6 )

output.bind('mousedown',{}, mouselistener )

keyholdbind = (key,funct) ->
  holdbindings[key]=funct
keytapbind = (key,funct) ->
  tapbindings[key]=funct

ricochet = ( v, n ) ->
  # projectile of velocity v
  # wall with surface normal n
  #split v into components u perpendicular to the wall and w parallel to it
  #u=(v*n/n*n)n
  u = n.nmul v.dot2d(n) / n.dot2d(n)
  #w=v-u
  w = v.sub u
  # friction f
  # coefficient of restitution r
  # v' = f w - r u
  vprime = w.sub u
  return vprime

bloodspray = ( location, velocity ) ->
  bleed location.add velocity.mul(randompoint())
  bleed location.add velocity.mul(randompoint())
  bleed location.add velocity.mul(randompoint())
  bleed location.add velocity.mul(randompoint())

bullethit = ( ent, trace ) ->
  ent.damage 1
  tracenormal = trace.to.sub(trace.loc).norm()
  #bullets send dudes flying back FOR EXTRA REALISM
  ent.vel = ent.vel.add tracenormal.nmul 2
  bloodspray ent.loc, tracenormal.nmul 30

firebullet = (from,to) ->
  fromloc = V from.x, from.y
  toloc = V to.x, to.y
  toloc = toloc.add randompoint().nsub(1/2).nmul 50
  trace = new Tracer( fromloc, toloc )

  allLineDefs = gameworld.entitylist.filter (ent) -> ent instanceof LineDef
  
  #allLineDefs.forEach (linedef) ->
  results = ( getLineIntersection( trace, linedef ) for linedef in allLineDefs )
  intersections = results.filter (n) -> n isnt null
  # now we have all wall collisions yo
  if intersections.length > 0
    firsthit = intersections.reduce ( prev, curr ) ->
      if fromloc.dist(prev) > fromloc.dist(curr)
        return curr
      else return prev
    trace = new Tracer( trace.loc , firsthit )
  
  allactors = gameworld.entitylist.filter (ent) -> ent instanceof Enemy

  allactors.forEach (ent) ->
    targetsize = 8
    hitbox = new Square ent.loc.nsub(targetsize), ent.loc.nadd(targetsize)
    hitbool= HitboxRayIntersect hitbox, trace
    if hitbool
      bullethit ent, trace
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
        normal = @to.sub(@loc).norm()
        normal = V -normal.y, normal.x
        target.vel = ricochet target.vel, normal
        #force an extra move
        #possibly helps avoid getting stuck in walls?
        target.loc = target.loc.add target.vel.nmul 2
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
    if @age > 100
      @kill()
bleed = ( loc ) ->
  blood=new Blood(loc)
  gameworld.addent(blood)

class Actor extends Entity
  constructor: ( @loc=V(0,0) ) ->
    @health = 10
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

maketracer = (from,to) ->
  fromloc = V from.x, from.y
  toloc = V to.x, to.y
  trace = new Tracer( fromloc, toloc )

  allLineDefs = gameworld.entitylist.filter (ent) -> ent instanceof LineDef
  
  #allLineDefs.forEach (linedef) ->
  results = ( getLineIntersection( trace, linedef ) for linedef in allLineDefs )
  intersections = results.filter (n) -> n isnt null
  # now we have all wall collisions yo
  if intersections.length > 0
    firsthit = intersections.reduce ( prev, curr ) ->
      if fromloc.dist(prev) > fromloc.dist(curr)
        return curr
      else return prev
    trace = new Tracer( trace.loc , firsthit )
  
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
haslineofsight = ( entA, entB ) ->
  if entA.loc.dist(entB.loc) < 100
    return true
  else
    return false

class Enemy extends Actor
  constructor: () ->
    super()
    @loc=randompoint().nmul 200
    @vel= V 1, 1
  draw: () ->
    basic = "<circle fill=green r=10 cx=#{@loc.x} cy=#{@loc.y} />"
    if haslineofsight( @, dude )
      size = V 20, 20
      loc = @loc.sub size.ndiv 2 #center
      atts = height:size.x, width:size.y, 'xlink:href':'images/exclamation.svg', x:loc.x, y:loc.y
      alert = tag "image", atts
      return basic + alert
    else
      return basic

  tick: () ->
    target = dude
    if haslineofsight( @, target) and Math.random()*100 < 1
      firebullet( @loc, dude.loc )
    
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

reset = ->
  console.log "supposed to be resetting now"
  gameworld.reset()

keyholdbind 'W', north
keyholdbind 'A', west
keyholdbind 'S', south
keyholdbind 'D', east
keytapbind 'R', reset

dudeangle = 0
turnleft = -> dudeangle+=3
turnright = -> dudeangle-=3

keyholdbind 'H', turnleft
keyholdbind 'L', turnright

blam = ->
  console.log dudeangle
  augh = (dudeangle/360)*Math.PI*2
  aimdirection = V Math.sin( augh ), Math.cos( augh )
  console.log aimdirection
  bulletrange = 200
  endpoint = dude.loc.sub aimdirection.nmul bulletrange
  spraybullets( dude.loc, endpoint, 6 )

keytapbind 'B', blam

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
  reset: ->
    @constructor()
  render: ->
    output.html('')
    
    camloc = cam.loc()
    size = cam.size()

    out "<svg id='screenout' width=640 height=480 viewbox='"+camloc.x+" "+camloc.y+" "+size.x+" "+size.y+"'>"
    out "<g transform='rotate(#{dudeangle},#{dude.loc.x},#{dude.loc.y})'>"
     
    @entitylist.forEach( (ent) ->
      out ent.draw()
    )
    out "</g>"
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

#based on an implementation by cortijon
getLineIntersection = ( linea, lineb ) ->
  p0_x = linea.loc.x
  p0_y = linea.loc.y
  p1_x = linea.to.x
  p1_y = linea.to.y
  p2_x = lineb.loc.x
  p2_y = lineb.loc.y
  p3_x = lineb.to.x
  p3_y = lineb.to.y
  result=jsgetLineIntersection(p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y)
  if result isnt null
    result = V result[0],result[1]
  return result

jsgetLineIntersection = (p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y) ->
  s1_x = p1_x - p0_x;
  s1_y = p1_y - p0_y;
  s2_x = p3_x - p2_x;
  s2_y = p3_y - p2_y;
  s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y);
  t = ( s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y);
  if (s >= 0 && s <= 1 && t >= 0 && t <= 1)
  #Collision detected
    intX = p0_x + (t * s1_x);
    intY = p0_y + (t * s1_y);
    return [intX, intY];
  return null; #No collision

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
