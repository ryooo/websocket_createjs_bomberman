class Stage
  constructor: ->
    @map = []
    @flow = []
    @char = {}
    @diffA = []
    @diffD = []
    @charCanStay = []
    @frame = 0
    for y in [0..20]
      @map[y] = []
      @flow[y] = []
      for x in [0..20]
        @flow[y][x] ||= {}
        if (x % 2 is 1) and (y % 2 is 1)
          @map[y][x] = new Stone()
        else
          @map[y][x] = new Grass()
          if Math.random() <= 0.3
            @flow[y][x] = new Block()
          else
            @charCanStay.push({x:x, y:y})
  bornChar: (socket = null) ->
    pos = @charCanStay[parseInt(Math.random()*@charCanStay.length)]
    if socket is null
      id = parseInt(Math.random()*10000)
      @char[id] = new Enemy(@, pos.x, pos.y, id)
    else
      @char[socket.id] = new Char(@, pos.x, pos.y, socket)
  deadChar: (id) ->
    @char[id].socket.emit('char dead')
    delete(@char[id])
  isEmpty: (x, y) ->
    return @getField(x, y).solid is false
  getField: (x, y) ->
    x = Math.max(Math.min(x, 20), 0)
    y = Math.max(Math.min(y, 20), 0)
    return @map[y][x] if @map[y][x].type in ['s']
    return @flow[y][x] if @flow[y][x].type in ['b', 'f', 'o', 'io', 'if']
    return new Element()
  getChar: -> 
    ret = {}
    for id, obj of @char
      ret[id] = {id: id, x: obj.x, y: obj.y, type: obj.type}
    return ret
  getFlowDiff: ->
    ret = {add: @diffA, delete: @diffD}
    @diffA = []
    @diffD = []
    return ret
  putBomb: (owner, x, y) ->
    @flow[y][x] = new Bomb(@, x, y, owner)
  tick: ->
    @frame++
    for y in [0..20]
      for x in [0..20]
        if typeof @flow[y][x].limit is 'number'
          if @flow[y][x].limit <= @frame
            @flow[y][x].limitReached()
      for id, char of @char
        if char instanceof Char
          @deadChar(id) if @getField(char.x, char.y).type is 'f'
          @deadChar(id) if @enemyExist(char.x, char.y)
  enemyExist: (x, y) ->
    for id, enemy of @char
      if enemy instanceof Enemy
        if x is enemy.x && y is enemy.y
          return enemy
    return false
  fire:(x, y) ->
    field = @getField(x, y)
    return false if field.type is 's'
    itemType = null
    if field.type is 'b'
      if Math.random() <= 0.3
        itemType = if Math.random() <= 0.5 then 'if' else 'io'
    @flow[y][x] = new Fire(@, x, y, itemType)
    return field if field instanceof Bomb
    enemy = @enemyExist(x, y)
    enemy.dead() if enemy != false
    return not (field.type in ['b', 'io', 'if'])

class Element
  constructor: ->
    @type = null
    @solid = false

class Stone extends Element
  constructor: ->
    super
    @type = 's'
    @solid = true
    @gettable = false

class Grass extends Element
  constructor: ->
    super
    @type = 'g'

class Block extends Element
  constructor: ->
    super
    @type = 'b'
    @solid = true

class Fire extends Element
  constructor: (stage, x, y, itemType) ->
    super
    @type = 'f'
    @stage = stage
    @x = x
    @y = y
    @itemType = itemType
    @limit = stage.frame + 10
    @stage.diffD.push({x:x, y: y})
    @stage.diffA.push({x:x, y: y, type: 'f'})
  limitReached: ->
    @stage.flow[@y][@x] = {}
    @stage.diffD.push({x:@x, y: @y})
    if @itemType
      @stage.flow[@y][@x] = new Item(@stage, @x, @y, @itemType)

class Bomb extends Element
  constructor: (stage, x, y, owner)->
    super
    @stage = stage
    @x = x
    @y = y
    @owner = owner
    @limit = stage.frame + 30
    @type = 'o'
    @solid = true
    @stage.diffA.push({x: x, y: y, type: 'o'})
  limitReached: ->
    chain = []
    @owner.bomb--
    @stage.fire(@x, @y)
    for direction in ['u', 'd', 'l', 'r']
      for i in [0..@owner.fireLen]
        x = @x
        y = @y
        x -= i if direction is 'l'
        x += i  if direction is 'r'
        y -= i if direction is 'u'
        y += i  if direction is 'd'
        x = Math.max(Math.min(x, 20), 0)
        y = Math.max(Math.min(y, 20), 0)
        ret = @stage.fire(x, y)
        chain.push(ret) if ret instanceof Bomb
        break if ret is false
    for bomb in chain
      bomb.limitReached()

class Item extends Element
  constructor: (stage, x, y, type)->
    super
    @stage = stage
    @x = x
    @y = y
    @type = type
    @gettable = true
    @stage.diffA.push({x: x, y: y, type: type})
  get: (char)->
    switch @type
      when 'if'
        char.fireLen++
      when 'io'
        char.maxBomb++
    @stage.diffD.push({x: @x, y: @y})
    @stage.flow[@y][@x] = {}

class Movable
  constructor: (stage, x, y)->
    @stage = stage
    @x = x
    @y = y
  move: (x, y) ->
    newX = Math.max(Math.min(@x + x, 20), 0)
    newY = Math.max(Math.min(@y + y, 20), 0)
    if @stage.isEmpty(newX, newY)
      @x = Math.max(Math.min(newX, 20), 0)
      @y = Math.max(Math.min(newY, 20), 0)

class Char extends Movable
  constructor: (stage, x, y, socket)->
    super(stage, x, y)
    @bomb = 0
    @maxBomb = 2
    @fireLen = 2
    @socket = socket
    @type = 'c'
  putBomb: ->
    if @bomb < @maxBomb
      @stage.putBomb(@, @x, @y)
      @bomb++
  move: (x, y) ->
    super(x, y)
    field = @stage.getField(@x, @y)
    field.get(@) if field.gettable

class Enemy extends Movable
  constructor: (stage, x, y, id)->
    super(stage, x, y)
    @type = 'e'
    @id = id
    @timer = setInterval(=>
      rand = Math.random()
      @move(-1, 0) if 0 < rand && rand <= 0.25
      @move(1, 0) if 0.25 < rand && rand <= 0.5
      @move(0, -1) if 0.5 < rand && rand <= 0.75
      @move(0, 1) if 0.75 < rand && rand <= 1
      @dead() if @stage.getField(@x, @y).type is 'f'
    , 1000)
  dead: ->
    clearInterval(@timer)
    delete(@stage.char[@id])

global.stage = new Stage()
socketio = require('socket.io').listen(global.app)
socketio.on('connection', (socket)->
  socket.on('message', (val)->
    char = global.stage.char[socket.id]
    return if typeof char is 'undefined'
    char.move(-1, 0) if val is 'l'
    char.move(1, 0)  if val is 'r'
    char.move(0, -1) if val is 'u'
    char.move(0, 1)  if val is 'd'
    char.putBomb() if val is 's'
  )
  socket.on('disconnect', (v) ->
    global.stage.deadChar(socket.id)
  )
  if typeof global.timer is 'undefined'
    for i in [0..3]
      global.stage.bornChar()
    global.timer = setInterval(->
      global.stage.tick()
      diff = {flow:global.stage.getFlowDiff(), char: global.stage.getChar()}
      socket.emit('stage sync', diff)
      socket.broadcast.emit('stage sync', diff);
      global.stage.bornChar() if Math.random() <= 0.005
    , 100)
  charId = global.stage.bornChar(socket)
  socket.emit('stage init', { map: global.stage.map, flow: global.stage.flow, char: global.stage.getChar()})
)