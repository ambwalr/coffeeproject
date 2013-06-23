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
p = (text) -> controlpanel.append $ tag p,{},text
p "WASD (or JK) to move, mouse click to fire."
p "alternatively HL or QE rotate, B shoots in direction you're heading"
p "kinda wonky and might not work correctly in all browsers, try a webkit-based browser like safari or chrome"

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

class InputHandler
  constructor: ->
    @target = dude
    body.bind 'keydown',{}, tapkeylistener
    body.bind 'keydown',{}, holdkeylistener
    body.bind 'keyup',{}, releasekeylistener


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

control = new InputHandler()

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
  clickpoint = clickpoint.div gameworld.dim
  #format clickpoint is now in a fraction of the screen
  clickpoint = clickpoint.mul gameworld.camera.size
  clickpoint = clickpoint.add gameworld.camera.cornerloc()
  
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
  if boxa.bottomright.y < boxb.topleft.y then return false
  if boxa.topleft.y > boxb.bottomright.y then return false
  if boxa.bottomright.x < boxb.topleft.x then return false
  if boxa.topleft.x > boxb.bottomright.x then return false
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
  kill: () -> @killme=true
  oncollide: ( otherent ) ->
    #nop

class MovingEnt extends Entity

class Emitter extends Entity
  constructor: ( @loc ) ->
    @age = 100
  tick: () ->
    @age = @age + 1
    if @age > 50
      test.addents bloodspray @loc, V(30,0)
      @age=0

class Blood extends MovingEnt
  constructor: ( @loc, @vel ) ->
    @age = 100
  draw: () ->
    fraction=@age/100

    size = 3+(1-fraction)*4
    color = "HSLA( 0, 90%, 45%, #{fraction} )" 
    atts= r: size, cx:@loc.x, cy:@loc.y, fill:color
    return tag "circle", atts
  tick: () ->
    @loc = @loc.add @vel
    friction = 0.5
    @vel = @vel.nmul friction
    @age--
    if @age <= 0
      @kill()

bleed = ( loc, vel ) ->
  blood = new Blood loc, vel
  return blood
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
    friction = 8/10
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

randangle = () -> Math.random()*360
Actor::kill = ->
  [0..4].forEach => gameworld.addents bloodspray( @loc, angletonorm(randangle()).nmul(30) )
  [0..4].forEach => gameworld.addents bloodspray( @loc, angletonorm(randangle()).nmul(10) )
  super()

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
  spray=[]
  spray.push bleed loc, vel.mul randompoint()
  spray.push bleed loc, vel.mul randompoint()
  spray.push bleed loc, vel.mul randompoint()
  spray.push bleed loc, vel.mul randompoint()
  return spray

Entity::hit = () ->

bullethit = ( ent, trace ) ->
  ent.damage 1
  tracenormal = trace.to.sub(trace.loc).norm()
  #bullets send dudes flying back FOR EXTRA REALISM
  ent.vel = ent.vel.add tracenormal.nmul 1/2
  gameworld.addents bloodspray ent.loc, tracenormal.nmul 30
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
      wallnormal = @to.sub(@loc).norm()
      wallnormal = V -wallnormal.y, wallnormal.x
      target = ent
      targetsize = 10
      hitbox = new Square target.loc.nsub(targetsize), target.loc.nadd(targetsize)
      velnorm = target.vel.norm()
      radiustracer = new Tracer target.loc, target.loc.sub wallnormal.nmul targetsize
      speedtracer = new Tracer target.loc, target.loc.add(target.vel).add(velnorm.nmul(targetsize))
      intersection = getLineIntersection speedtracer, @
      #if not intersection
      #  intersection = getLineIntersection speedtracer, @
      hitbool = HitboxRayIntersect( hitbox, @ )
      if intersection
        target.vel = ricochet target.vel, wallnormal
        target.vel = target.vel.nmul 1/10
        a=intersection
        b=target.loc
        dirr = a.dir b
        target.loc = intersection.add dirr.nmul targetsize + (1/100)
  
  draw: () ->
    normal = @to.sub(@loc).norm()
    normal = V -normal.y, normal.x
    atts = x1:@loc.x, y1:@loc.y, x2:@to.x, y2:@to.y, stroke:"brown", "stroke-width": "4px"
    wall= tag "line", atts
    avg = @loc.add(@to).ndiv 2
    nend = avg.add normal.nmul 10
    atts = x1:avg.x, y1:avg.y, x2:nend.x, y2:nend.y, stroke:"blue", "stroke-width": "1px"
    ntag = tag "line", atts
    return wall+ntag

class Player extends Actor

  constructor: () ->
    super()
    @vel= V 0,0
    @loc= V 50,-50
  draw: () ->
    o = @draworientation()
    size=10
    #atts = x:@loc.x - size/2 , y:@loc.y - size/2, width: size, height: size
    #atts["xlink:href"]='images/dude.PNG';
    #dudegraphics=tag "image", atts
    dudegraphics = circletag @loc, size, "orange"
    return dudegraphics+o
  tick: () ->
    super()
  move: (x,y) ->
    fixedangle = angletonorm @.dir + normtoangle V x,y
    @vel = @vel.add fixedangle.nmul dudespeed*2
    maxspeed = dudespeed*10
    if @vel.mag() > maxspeed
      @vel = @vel.norm().nmul maxspeed
    
randompoint = ->
  return V Math.random(), Math.random()

nearby = ( entA, entB ) ->
  return entA.loc.dist(entB.loc) < 200

normtoangle = ( vec ) -> Math.atan2( vec.x, vec.y  )*180/Math.PI
angletonorm = ( degs ) ->
  augh = degstorads degs
  return V Math.sin( augh ), Math.cos( augh )

class Ally extends Actor
  constructor: () ->
    super()
    @loc=randompoint().nmul 100
    @vel= V 1, 1
    @walkgoal = undefined
    @topthreat = undefined
    @squadleader = dude
  draw: () ->
    o = @draworientation()
    size= 10*2
    color="pink"
    atts = fill: color, x:@loc.x-size/2, y:@loc.y-size/2, width:size, height:size
    basic = tag("rect",atts) + o
    if @topthreat and @seestarget @topthreat
      alert = exclamation @loc
      return basic + alert
    else
      return basic
  seestarget: (target) -> hasLineOfSight(@, target)
  flipout: () ->
    norm = entDir @, @topthreat
    @dir=normtoangle norm
    if Math.random()*20 < 1
      entfirebullet @, norm
  tick: () ->
    super()
    if @walkgoal
      @dir= normtoangle @.loc.dir @walkgoal
      if @.loc.dist(@walkgoal) > 100 then @jostle()
    if @topthreat == undefined and hasLineOfSight(@, @squadleader )
      @walkgoal = @squadleader.loc
    if @topthreat and @topthreat.killme then @topthreat = undefined
    if @topthreat
      @walkgoal = @topthreat.loc
      if @seestarget(@topthreat) then @flipout()
  jostle: () ->
    @dir = ( @dir-1 ) + Math.random() * 2
    @vel = @vel.add randompoint().nmul(2).nsub(1).ndiv(10)
    @vel = @vel.add angletonorm(@dir).nmul 1/2

class Enemy extends Actor
  constructor: () ->
    super()
    @loc=randompoint().nmul 600
    @vel= V 0, 0
  draw: () ->
    o = @draworientation()
    basic = "<circle fill=green r=10 cx=#{@loc.x} cy=#{@loc.y} />"+o
    if @seestarget dude
      alert = exclamation @loc
      return basic + alert
    else
      return basic
  seestarget: ( target ) -> nearby( @, target ) and hasLineOfSight(@, target)
  tick: () ->
    target = dude
    spotted = @seestarget target
    if spotted
      norm = entDir @, target
      @dir=normtoangle norm
    if spotted and Math.random()*30 < 1
      entfirebullet @, norm
    
    super()
    @jostle()
  jostle: () ->
    @dir = ( @dir-1 ) + Math.random() * 2
    @vel = @vel.add randompoint().nmul(2).nsub(1).ndiv(10)
    @vel = @vel.add angletonorm(@dir).ndiv 10

exclamation = ( loc ) ->
  size = V 20, 20
  loc = loc.sub size.ndiv 2 #center
  atts = height:size.x, width:size.y, 'xlink:href':'images/exclamation.svg', x:loc.x, y:loc.y
  return tag "image", atts

circletag = ( loc, radius, color ) ->
  atts = cx: loc.x, cy: loc.y, r: radius, fill: color
  return tag "circle", atts

class Stalker extends Enemy
  constructor: () ->
    super()
    @loc=randompoint().nmul 600
    @vel= V 1, 1
  draw: () ->
    o = @draworientation()
    basic = circletag(@loc,10,"cyan")+o
    if @seestarget dude
      alert = exclamation @loc
      return basic + alert
    else
      return basic
  seestarget: ( target ) -> hasLineOfSight @, target
  tick: () ->
    super()
    target = dude
    spotted = @seestarget target
    if spotted
      norm = entDir @, target
      @dir=normtoangle norm
      @jostle()
    
    @jostle()
  jostle: () ->
    @dir = ( @dir-1 ) + Math.random() * 2
    @vel = @vel.add randompoint().nmul(2).nsub(1).ndiv(10)
    @vel = @vel.add angletonorm(@dir).ndiv 4

Enemy::hit = () ->
  target = dude
  norm = entDir @, target
  @dir=normtoangle norm
  
  allies = gameworld.entitylist.filter (ent) -> ent instanceof Ally
  allies.forEach (ally) => ally.topthreat = @

class Turret extends Enemy
  constructor: () ->
    super()
    @loc=randompoint().nmul 600
    @vel= V 1, 1
  draw: () ->
    o = @draworientation()
    color = "steelblue"
    basic = "<circle fill=#{color} r=10 cx=#{@loc.x} cy=#{@loc.y} />"+o
    trace=firetracer @loc, angletonorm(@dir)
    atts = x1: @loc.x, y1: @loc.y, x2: trace.to.x, y2: trace.to.y, stroke: 'red', 'stroke-width': '1px'
    laser = tag "line", atts
    basic += laser
    if @seestarget dude
      alert = exclamation @loc
      return basic + alert

    else
      return basic
  seestarget: ( target ) ->
    trace = firetracer @loc, angletonorm @dir
    res = trace.checkEnts [target]
    return res.length > 0
  tick: () ->
    target = dude
    spotted = @seestarget target
    if not spotted
      @dir += 1
    if spotted #flip the fuck out
      entfirebullet @, dude.loc.sub(@loc).norm()
    super()

dude = new Player()

dudespeed = 1
startrun = () -> dudespeed = 4
endrun = () -> dudespeed = 1
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

suicide = -> dude.kill()

keyholdbind 'W', north
keyholdbind 'A', west
keyholdbind 'S', south
keyholdbind 'D', east
keytapbind 'R', reset
keytapbind 'P', suicide


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
    @dim = V 640, 480
    @camera = new Camera dude #follow the dude
  addent: ( ent ) -> @entitylist.push ent
  addents: ( ents ) -> @entitylist = @entitylist.concat ents
  reset: ->
    @constructor()
  render: ->
    
    camloc = @camera.cornerloc()
    size = @camera.size
    out "<svg id='screenout' width=#{@dim.x} height=#{@dim.y} viewbox='"+camloc.x+" "+camloc.y+" "+size.x+" "+size.y+"'>"
    out "<g transform='rotate(#{dude.dir},#{dude.loc.x},#{dude.loc.y})'>"
    
    allLineDefs = @getLineDefs()
    restEntities = @entitylist.filter (ent) -> not ( ent instanceof LineDef )
    allEnemies = @entitylist.filter (ent) -> ent instanceof Enemy
    
    restEntities = restEntities.filter (ent) -> not ( ent in allEnemies )
    
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
    
    flush()
  
  tick: ->
    #prune dead ents
    @entitylist.filter( (ent) -> ent.killme != undefined ).forEach (ent) =>
      at = @entitylist.indexOf ent
      if at >= 0
        @entitylist.splice at, 1
    allLineDefs = @getLineDefs()
    restEntities = @entitylist.filter (ent) -> not ( ent instanceof LineDef )
    allLineDefs.forEach (ent) -> ent.tick()
    restEntities.forEach (ent) -> ent.tick()

World::winState = () ->
  enemies = @entitylist.filter (ent) -> ent instanceof Enemy
  return enemies.length == 0
World::loseState = () ->
  dude.health <= 0
World::getLineDefs = () ->
  return @entitylist.filter (ent) -> ent instanceof LineDef

class Camera extends Entity
  constructor: ( @target=undefined, @loc=V(0,0) ) ->
    @size = V 640, 480
  cornerloc: () ->
    camloc= @target.loc.sub @size.ndiv 2
    return camloc
  tick: () ->
    if @target 
      @loc = @target.loc

gameworld=new World

#demo world
gameworld.addent dude
for i in [0..8] then gameworld.addent new Enemy()
for i in [0..4] then gameworld.addent new Turret()
for i in [0..4] then gameworld.addent new Stalker()
for i in [0..4] then gameworld.addent new Ally()

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

class ParticleWorld extends World
  constructor: ->
    super()
    @dim = V 200, 200
test=new ParticleWorld
emit = new Emitter V 0,0
test.addent emit
test.camera = new Camera emit
test.camera.size = V 200, 200

drawgui = ->
  #lol no gui
  out "<div>"
  out "<b>#{dude.health} HP</b>"
  out "<i>#{ gameworld.entitylist.length } entities</i>"
  won=gameworld.winState()
  lost=gameworld.loseState()
  if won then out "<b>YOU WIN!</b>"
  if lost then out "<b>YOU LOSE!</b>"
  if won and lost then out "<b>ACHIEVEMENT GET: PYRRHIC VICTORY</b>"
  out "</div>"
  flush()

mainloop = ->
  output.html('')
  tickcalls.forEach (func) -> func()
  gameworld.tick()
  gameworld.render()
  test.tick()
  test.render()
  drawgui()
  setTimeout mainloop , tickwaitms
mainloop()

