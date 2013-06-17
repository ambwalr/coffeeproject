body=$("body")

V = _VectorLib.V2D
matrixtransform = _VectorLib.matrixtransform

#xml generation
tagatts = (attobj) ->
  attstr=""
  for k,v of attobj
    attstr += " #{k}=\"#{v}\""
  attstr
tag = (type,att,body="") ->
  return "<#{type} #{tagatts att}>#{body}</#{type}>"

output = $ "<div id=output></div>"
body.append output

controlpanel= $ "<div style='background-color: silver'></div>"
body.append controlpanel
controlpanel.append $ "<p>WASD (or JK) to move, mouse click to fire.</p>"
controlpanel.append $ "<p>alternatively HL or QE rotate, B shoots in direction you're heading</p>"
controlpanel.append $ "<p>kinda wonky and might not work correctly in all browsers, try a webkit-based browser like safari or chrome</p>"

butt = $ tag "button", undefined , "dump map data"
butt.click ->
  console.log JSON.stringify map
controlpanel.append butt


outputqueue = []
out = (text) ->
  outputqueue.push (text)
flush = () ->
  output.append outputqueue.join(' ')
  outputqueue = []


holdbindings=[]
tapbindings=[]
running = false

tapkeylistener = (e) ->
  key=e.keyCode
  charkey = String.fromCharCode(key)
  funct = tapbindings[charkey]
  if funct
    funct()
tickcalls = []
holdkeylistener = (e) ->
  running = e.shiftKey
  testrun()
  key=e.keyCode
  charkey = String.fromCharCode(key)
  funct = holdbindings[charkey]
  if funct and funct not in tickcalls
    tickcalls.push funct
releasekeylistener = (e) ->
  running = e.shiftKey
  testrun()
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

degstorads = ( deg ) -> deg * Math.PI/180

rotate2d = ( vec, deg ) ->
  theta = degstorads deg
  matrix=
  [[Math.cos(theta),-Math.sin(theta)]
  [Math.sin(theta),Math.cos(theta)]]
  newv = matrixtransform matrix, [vec.x, vec.y]
  return V newv[0], newv[1]

mouselistener = (e) ->
  clickpoint = V e.offsetX, e.offsetY
  clickpoint = clickpoint.add cam.loc()
  
  poit = clickpoint.sub(dude.loc)
  adjustedpoint = rotate2d poit, -dude.dir
  clickpoint = adjustedpoint.add dude.loc

  aimdirection = clickpoint.sub(dude.loc).norm()
  if editingmode
    buildwall clickpoint
  else
    entspraybullets dude, aimdirection, 4

map = []

prevclickpos = false
buildwall = ( clickpoint ) ->
  if not prevclickpos
    prevclickpos = clickpoint
    return
  linedefs = gameworld.entitylist.filter (ent) -> ent instanceof LineDef
  start = prevclickpos.ndiv 25
  start = V Math.round(start.x), Math.round(start.y)
  start = start.nmul 25
  prevclickpos = false
  end = clickpoint.ndiv 25
  end = V Math.round(end.x), Math.round(end.y)
  end = end.nmul 25
  if start.sub(end).mag() != 0
    map.push [ start , end ]
    gameworld.addent new LineDef start, end

output.bind('mousedown',{}, mouselistener )

keyholdbind = (key,funct) ->
  holdbindings[key]=funct
keytapbind = (key,funct) ->
  tapbindings[key]=funct

#Collision code

boxCollision = ( boxa, boxb ) ->
  if boxa.bottomright.y < boxb.topleft.y
    return false
  if boxa.topleft.y > boxb.bottomright.y
    return false
  if boxa.bottomright.x < boxb.topleft.x
    return false
  if boxa.topleft.x > boxb.bottomright.x
    return false
  return true

#based on an implementation by cortijon
getLineIntersection = ( linea, lineb ) ->
  p0 = linea.loc
  p1 = linea.to
  p2 = lineb.loc
  p3 = lineb.to
  s1 = p1.sub p0
  s2 = p3.sub p2
  s = (-s1.y * (p0.x - p2.x) + s1.x * (p0.y - p2.y)) / (-s2.x * s1.y + s1.x * s2.y);
  t = ( s2.x * (p0.y - p2.y) - s2.y * (p0.x - p2.x)) / (-s2.x * s1.y + s1.x * s2.y);
  if (s >= 0 && s <= 1 && t >= 0 && t <= 1)
  #Collision detected
    return p0.add s1.nmul t
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

#Game ents

class Entity
  loc=V 0,0
  tick: () ->
    #nop
  draw: () ->
    #nop
  kill: () ->
    at = gameworld.entitylist.indexOf @
    gameworld.entitylist.splice at, 1
  oncollide: ( otherent ) ->
    #nop

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

class HealthPack extends Entity
  constructor: ( @loc=V(0,0) ) ->
  onpickup: ( player ) ->
    player.health+=10
    @kill()
  oncollide: ( otherent ) ->
    if otherent instanceof Player
      @onpickup otherent
  draw: () ->
    return "<rect x=#{@loc.x} y=#{@loc.y} width=8 height=8 fill=blue />"
HealthPack::gethitbox = () ->
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
      return
    @movetick()
  
  movetick: () ->
    @handlecoll()
    newv = @loc.add @vel
    friction = 9/10
    @vel = @vel.nmul friction
    @loc = newv
    
  handlecoll: () ->
    allactors = gameworld.entitylist.filter (ent) -> ent instanceof Actor
    notme = allactors.filter (actor) => actor isnt @
    notme = notme.concat gameworld.entitylist.filter (ent) -> ent instanceof HealthPack
    collisions=notme.filter (actor) => boxCollision @.gethitbox(), actor.gethitbox()
    collisions.forEach ( col ) =>
      @vel = @vel.add entDir( col, @ )
      col.oncollide @

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

Entity::hit = () ->

bullethit = ( ent, trace ) ->
  ent.damage 1
  tracenormal = trace.to.sub(trace.loc).norm()
  #bullets send dudes flying back FOR EXTRA REALISM
  ent.vel = ent.vel.add tracenormal.nmul 1/2
  bloodspray ent.loc, tracenormal.nmul 30
  ent.hit()

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
  tracerange = 500
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
    @vel= V 0,0
    @loc= V 50,-50
  draw: () ->
    o = @draworientation()
    #return "<circle fill=orange r=10 cx=#{@loc.x} cy=#{@loc.y} />"
    size=32
    atts = x:@loc.x - size/2 , y:@loc.y - size/2, width: size, height: size
    atts["xlink:href"]='images/dude.PNG';
    dudegraphics=tag "image", atts
    return dudegraphics+o
  tick: () ->
    super()
  move: (x,y) ->
    fixedangle = angletonorm @.dir + normtoangle V x,y
    @vel = @vel.add fixedangle.nmul dudespeed
    
randompoint = ->
  return V Math.random(), Math.random()

nearby = ( entA, entB ) ->
  return entA.loc.dist(entB.loc) < 200

normtoangle = ( vec ) -> Math.atan2( vec.x, vec.y  )*180/Math.PI
angletonorm = ( degs ) ->
  augh = degstorads degs
  return V Math.sin( augh ), Math.cos( augh )

class Enemy extends Actor
  constructor: () ->
    super()
    @loc=randompoint().nmul 600
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
      norm = entDir @, target
      @dir=normtoangle norm
    if spotted and Math.random()*30 < 1
      entfirebullet @, norm
    
    @jostle()
    super()
  jostle: () ->
    @dir = ( @dir-1 ) + Math.random() * 2
    @vel = @vel.add randompoint().nmul(2).nsub(1).ndiv(10)
    @vel = @vel.add angletonorm(@dir).ndiv 10

Enemy::hit = () ->
  target = dude
  norm = entDir @, target
  @dir=normtoangle norm

class Turret extends Actor
  constructor: () ->
    super()
    @loc=randompoint().nmul 600
    @vel= V 1, 1
  seesplayer: () ->
    #hasLineOfSight @, dude
    #= ( enta, entb ) ->
    target = dude
    trace=firetracer @loc, angletonorm(@dir)
    res=trace.checkEnts [target]
    return res.length > 0

    
  draw: () ->
    o = @draworientation()
    basic = "<circle fill=yellow r=10 cx=#{@loc.x} cy=#{@loc.y} />"+o
    trace=firetracer @loc, angletonorm(@dir)
    atts = x1: @loc.x, y1: @loc.y, x2: trace.to.x, y2: trace.to.y, stroke: 'red', 'stroke-width': '1px'
    laser = tag "line", atts
    basic += laser
    if @seesplayer()
      size = V 20, 20
      loc = @loc.sub size.ndiv 2 #center
      atts = height:size.x, width:size.y, 'xlink:href':'images/exclamation.svg', x:loc.x, y:loc.y
      alert = tag "image", atts
      return basic + alert

    else
      return basic

  tick: () ->
    target = dude
    spotted = @seesplayer()
    if not spotted
      @dir += 1
    if spotted #flip the fuck out
      @dir -= 1
      entfirebullet @, dude.loc.sub(@loc).norm()
    super()

dude = new Player()

dudespeed = 1
startrun = () -> dudespeed = 4
endrun = () -> dudespeed = 0.5
testrun = () ->
  if running
    startrun()
  else
    endrun()

north = -> dude.move(0,-1)
west = ->  dude.move(-1,0)
south = -> dude.move(0,1)
east = ->  dude.move(1,0)

reset = ->
  console.log "supposed to be resetting now"
  gameworld.reset()

keyholdbind 'W', north
keyholdbind 'A', west
keyholdbind 'S', south
keyholdbind 'D', east
keytapbind 'R', reset


editingmode=false
wepon1 = ->
  console.log "cool u got ur first gun, the crowbar"
  editingmode=true
wepon2 = ->
  console.log "guns don't kill people i kill people, with guns"
  editingmode=false 

keytapbind '1', wepon1
keytapbind '2', wepon2


tickwaitms = 20
toggleslowmo = ->
  if tickwaitms > 20
    tickwaitms = 20
  else
    tickwaitms = 200

keytapbind 'X', toggleslowmo

turnleft = -> dude.dir+=3
turnright = -> dude.dir-=3

keyholdbind 'Q', turnleft
keyholdbind 'E', turnright
keyholdbind 'H', turnleft
keyholdbind 'L', turnright

keyholdbind 'K', north
keyholdbind 'J', south

blam = ->
  aimdirection = angletonorm dude.dir
  entspraybullets dude, aimdirection, 4

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

entDist = ( enta, entb ) -> enta.loc.dist entb.loc
entDir = ( enta, entb ) -> enta.loc.dir entb.loc

hasLineOfSight = ( enta, entb ) ->
  trace=firetracer enta.loc, entDir(enta,entb)
  res=trace.checkEnts [entb]
  return res.length > 0

lineofsighttowalls = ( ent ) ->
  allLineDefs = gameworld.entitylist.filter (ent) -> ent instanceof LineDef
  seenlinedefs = allLineDefs.filter (ld) ->
      ldcenter = ld.to.add(ld.loc).ndiv(2)
      dir = ent.loc.dir ldcenter
      trace = firetracer ent.loc, dir
      res = getLineIntersection trace, ld
      return res
  return seenlinedefs

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
    
    allLineDefs = gameworld.getLineDefs()
    #linedefstodraw = lineofsighttowalls( dude )
    #linedefstodraw.forEach (ent) -> out ent.draw()
    allLineDefs.forEach (ld) -> out ld.draw()
    
    restEntities.forEach (ent) -> out ent.draw()
    allEnemies.forEach( (ent) ->
      if hasLineOfSight dude, ent
        out ent.draw()
    )
    out "</g>"
    out "</svg>"
    #lol no gui
    out "<b>#{dude.health} HP</b>"
    out "<hr />"
    if @winState()
      out "<b>YOU WIN!</b>"
    if @loseState()
      out "<b>YOU LOSE!</b>"
    if @winState() and @loseState()
      out "<b>ACHIEVEMENT GET: PYRRHIC VICTORY</b>"
    
    flush()
  
  tick: ->
    @entitylist.forEach (ent) -> ent.tick()
World::winState = () ->
  enemies = @entitylist.filter (ent) -> ent instanceof Enemy
  return enemies.length == 0
World::loseState = () ->
  dude.health <= 0
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

gameworld=new World
#demo world
gameworld.addent dude
for i in [0..8]
  gameworld.addent new Enemy()
for i in [0..4]
  gameworld.addent new Turret()
    
#gameworld.addent new LineDef V( 0, 300 ) , V( 0, 0 )
#gameworld.addent new LineDef V( 200, 0 ) , V( 0, 0 )
#gameworld.addent new LineDef V( 0, 300 ) , V( 200, 250 )
#gameworld.addent new LineDef V( 200, 0 ) , V( 200, 200 )
#gameworld.addent new LineDef V( 200, 200 ) , V( 400, 200 )
#gameworld.addent new LineDef V( 200, 250 ) , V( 400, 250 )

gameworld.addent new HealthPack randompoint().nmul 400
gameworld.addent new HealthPack randompoint().nmul 400
gameworld.addent new HealthPack randompoint().nmul 400
gameworld.addent new HealthPack randompoint().nmul 400

success = (data) ->
  data.forEach (d) ->
    from = V(0,0).add d[0]
    to = V(0,0).add d[1]
    gameworld.addent new LineDef from, to

jQuery.getJSON 'map01.json', success

mainloop = ->
  tickcalls.forEach (func) -> func()
  gameworld.tick()
  gameworld.render()
  setTimeout mainloop , tickwaitms
mainloop()

