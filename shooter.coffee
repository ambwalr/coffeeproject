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

entspraybullets = ( ent, dir, num ) ->
  [1..num].forEach -> entfirebullet ent,dir

mouselistener = (e) ->
  clickpoint = V e.offsetX, e.offsetY
  clickpoint = clickpoint.add cam.loc()
  aimdirection = clickpoint.sub(dude.loc).norm()
  firetracer dude.loc, aimdirection
  entspraybullets dude, aimdirection, 6

output.bind('mousedown',{}, mouselistener )

keyholdbind = (key,funct) ->
  holdbindings[key]=funct
keytapbind = (key,funct) ->
  tapbindings[key]=funct

class Entity
  loc=V 0,0
  tick: () ->
    #nop
  draw: () ->
    #nop
  kill: () ->
    at = gameworld.entitylist.indexOf @
    gameworld.entitylist.splice at, 1

class MovingEnt extends Entity

class Blood extends MovingEnt
  constructor: ( @loc, @vel ) ->
    @age = 0
  draw: () ->
    "<circle r=4 cx=#{@loc.x} cy=#{@loc.y} fill=red/>"
  tick: () ->
    @loc = @loc.add @vel
    friction = 0.5
    @vel = @vel.nmul friction
    @age++
    if @age > 100
      @kill()
bleed = ( loc, vel ) ->
  blood = new Blood loc, vel
  gameworld.addent(blood)
Blood::gethitbox = () ->
  targetsize = 4
  hitbox = new Square @loc.nsub(targetsize), @loc.nadd(targetsize)
  return hitbox

class Actor extends MovingEnt
  constructor: ( @loc=V(0,0) ) ->
    @health = 10
    @vel= V 0,0
    @dir = 0
  draworientation: () ->
    normal = angletonorm @dir
    loc = @loc.add normal.nmul 12
    return "<circle fill=black r=3 cx=#{loc.x} cy=#{loc.y} />"
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


class Tracer extends Entity
  constructor: (@loc, @to) ->
    @age = 0
  tick: () ->
    @age++
    if @age > 4
      @kill()
  draw: () ->
    "<line x1=#{@loc.x} y1=#{@loc.y} x2=#{@to.x} y2=#{@to.y} stroke=black stroke-dasharray='2,3'/>"

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

bloodspray = ( loc, vel ) ->
  bleed loc, vel.mul randompoint()
  bleed loc, vel.mul randompoint()
  bleed loc, vel.mul randompoint()
  bleed loc, vel.mul randompoint()
  #velocity.mul( Math.random() )

bullethit = ( ent, trace ) ->
  ent.damage 1
  tracenormal = trace.to.sub(trace.loc).norm()
  #bullets send dudes flying back FOR EXTRA REALISM
  ent.vel = ent.vel.add tracenormal.nmul 2
  bloodspray ent.loc, tracenormal.nmul 30

Actor::gethitbox = () ->
  targetsize = 8
  hitbox = new Square @loc.nsub(targetsize), @loc.nadd(targetsize)
  return hitbox

Tracer::checkEnts = ( entities ) ->
  entities.filter (ent) =>
    hitbox = ent.gethitbox()
    hitbool = HitboxRayIntersect hitbox, @
    return hitbool

firetracer = ( fromloc, dir ) ->
  tracerange = 2000
  toloc = fromloc.add dir.norm().nmul tracerange
  trace = new Tracer( fromloc, toloc )
  allLineDefs = gameworld.getLineDefs()
  results = ( getLineIntersection( trace, linedef ) for linedef in allLineDefs )
  intersections = results.filter (n) -> n isnt null
  # now we have all wall collisions yo
  if intersections.length > 0
    firsthit = intersections.reduce ( prev, curr ) ->
      if fromloc.dist(prev) > fromloc.dist(curr)
        return curr
      else return prev
    trace = new Tracer( trace.loc , firsthit )
  return trace

getTargets = () -> return gameworld.entitylist.filter (ent) -> ent instanceof Enemy

firebullet = ( fromloc, dir ) ->
  targets = getTargets()
  #some scatter
  dir = dir.add( randompoint().nsub(1/2).ndiv(200) ).norm()
  trace = firetracer fromloc, dir
  
  targets = allactors
  targets.forEach (ent) ->
    targetsize = 8
    hitbox = new Square ent.loc.nsub(targetsize), ent.loc.nadd(targetsize)
    hitbool= HitboxRayIntersect hitbox, trace
    if hitbool
      bullethit ent, trace

  gameworld.addent trace

entfirebullet = ( ent, dir ) ->
  bulletrange = 200

  fromloc = ent.loc.nadd 0
  #some scatter
  dir = dir.add( randompoint().nsub(1/2).ndiv(4) ).norm()
  trace = firetracer fromloc, dir

  allactors = gameworld.entitylist.filter (ent) -> ent instanceof Actor
  targets = allactors.filter (actor) -> actor isnt ent
  hits = trace.checkEnts targets
  hits.forEach (hitent) ->
    bullethit hitent, trace
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

class LineDef extends Entity
  constructor: (@loc, @to) ->
  tick: () ->
    allactors = gameworld.entitylist.filter (ent) -> ent instanceof MovingEnt

    allactors.forEach (ent) =>
      target = ent
      targetsize = 8
      veltrace = new Tracer ent.loc, ent.loc.add(ent.vel)
      
      hitbox = new Square target.loc.nsub(targetsize), target.loc.nadd(targetsize)
      hitbool = HitboxRayIntersect( hitbox, @ )
      if hitbool
        normal = @to.sub(@loc).norm()
        normal = V -normal.y, normal.x
        target.vel = ricochet target.vel, normal
	#force an extra move
        #possibly helps avoid getting stuck in walls?
        target.loc = target.loc.add target.vel
  
  draw: () ->
    "<line x1=#{@loc.x} y1=#{@loc.y} x2=#{@to.x} y2=#{@to.y} stroke=brown stroke-width=4px />"

class Player extends Actor

  constructor: () ->
    super()
    @vel= V 0,1
    @loc= V 300,100
  draw: () ->
    o = @draworientation()
    return "<circle fill=orange r=10 cx=#{@loc.x} cy=#{@loc.y} />"+o
  tick: () ->
    @movetick()
  move: (x,y) ->
    @vel.x += x
    @vel.y += y

randompoint = ->
  return V Math.random(), Math.random()

nearby = ( entA, entB ) ->
  if entA.loc.dist(entB.loc) < 100
    return true
  else
    return false

normtoangle = ( vec ) -> Math.atan2( vec.x, vec.y  )*180/Math.PI
angletonorm = ( degs ) ->
  augh = (degs/360)*Math.PI*2
  return V(0,0).sub V Math.sin( augh ), Math.cos( augh )

class Enemy extends Actor
  constructor: () ->
    super()
    @loc=randompoint().nmul 200
    @vel= V 1, 1
  draw: () ->
    o = @draworientation()
    basic = "<circle fill=green r=10 cx=#{@loc.x} cy=#{@loc.y} />"+o
    if nearby( @, dude )
      size = V 20, 20
      loc = @loc.sub size.ndiv 2 #center
      atts = height:size.x, width:size.y, 'xlink:href':'images/exclamation.svg', x:loc.x, y:loc.y
      alert = tag "image", atts
      return basic + alert
    else
      return basic

  tick: () ->
    target = dude
    spotted = nearby @, target
    if spotted
      norm = @loc.sub(target.loc).norm()
      @dir=normtoangle norm
    if spotted and Math.random()*100 < 1
      entfirebullet @, dude.loc.sub(@loc).norm()
    
    @jostle()
    super()
  jostle: () ->
    @dir = @dir-1+Math.random() * 3
    @vel = @vel.add randompoint().nmul(2).nsub(1).ndiv(10)
    @vel = @vel.add angletonorm(@dir).ndiv 50

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

tickwaitms = 20
toggleslowmo = ->
  if tickwaitms > 20
    tickwaitms = 20
  else
    tickwaitms = 200

keytapbind 'X', toggleslowmo

turnleft = -> dude.dir+=3
turnright = -> dude.dir-=3

keyholdbind 'H', turnleft
keyholdbind 'L', turnright

blam = ->
  aimdirection = angletonorm dude.dir
  entspraybullets dude, aimdirection, 6

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

entDist = ( enta, entb ) -> Math.abs entb.loc.sub enta.loc
entDir = ( enta, entb ) -> entb.loc.sub(enta.loc).norm()

class World
  constructor: ( @entitylist = []  ) ->
  addent: ( ent ) ->
    @entitylist.push ent
  reset: ->
    @constructor()
  render: ->
    output.html('')
    
    camloc = cam.loc()
    size = cam.size()

    out "<svg id='screenout' width=640 height=480 viewbox='"+camloc.x+" "+camloc.y+" "+size.x+" "+size.y+"'>"
    out "<g transform='rotate(#{dude.dir},#{dude.loc.x},#{dude.loc.y})'>"
    
    allLineDefs = @entitylist.filter (ent) -> ent instanceof LineDef
    restEntities = @entitylist.filter (ent) -> not ( ent instanceof LineDef )
    allEnemies = @entitylist.filter (ent) -> ent instanceof Enemy

    restEntities = restEntities.filter (ent) -> not ( ent in allEnemies )

    allLineDefs.forEach (ent) -> out ent.draw()

    restEntities.forEach (ent) -> out ent.draw()
    allEnemies.forEach( (ent) ->
      trace=firetracer dude.loc, entDir(dude,ent)

      res=trace.checkEnts [ent]
      if res.length > 0
        out ent.draw()
    )
    out "</g>"
    out "</svg>"
    flush()
  
  tick: ->
    @entitylist.forEach (ent) -> ent.tick()
World::getLineDefs = () ->
  return @entitylist.filter (ent) -> ent instanceof LineDef

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
#demo world
gameworld.addent dude
for i in [0..8]
  gameworld.addent new Enemy()
    
gameworld.addent new LineDef V( 0, 300 ) , V( 0, 0 )
gameworld.addent new LineDef V( 200, 0 ) , V( 0, 0 )
gameworld.addent new LineDef V( 0, 300 ) , V( 200, 250 )
gameworld.addent new LineDef V( 200, 0 ) , V( 200, 200 )
gameworld.addent new LineDef V( 200, 200 ) , V( 400, 200 )
gameworld.addent new LineDef V( 200, 250 ) , V( 400, 250 )

mainloop = ->
  tickcalls.forEach (func) -> func()
  gameworld.tick()
  gameworld.render()
  setTimeout mainloop , tickwaitms
mainloop()


