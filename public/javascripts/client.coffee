he = {}
preload = new PreloadJS()
fields = 
  b: "./images/block.jpg"
  s: "./images/stone.jpg"
  o: "./images/bomb.png"
  f: "./images/fire.png"
  g: "./images/grass.jpg"
  c: "./images/chara.png"
  if: "./images/item2.png"
  io: "./images/item3.png"
  e: "./images/item7.png"
manifest = []
for key, val of fields
  manifest.push({src: val})
he.static = new Stage("static")
he.flow = new Stage('flow')
he.dead = false
preload.loadManifest(manifest);
preload.onComplete = ->
  socket = io.connect('http://localhost:3000/');
  socket.on 'char dead', ()->
    he.dead = true
  socket.on 'stage init', (ini)->
    he.static.objmap = []
    he.flow.objmap = []
    he.flow.chars = {}
    for y, row of ini.map
      he.static.objmap[y] ||= []
      for x, info of row
        setPart(he.static, {x: x, y: y, type: info.type})
    for y, row of ini.flow
      he.flow.objmap[y] ||= []
      for x, info of row
        setPart(he.flow, {x: x, y: y, type: info.type}) if typeof info.type != 'undefined'
    for id, info of ini.char
      if typeof he.flow.chars[id] is 'undefined'
        setPart(he.flow, {x: info.x, y: info.y, type: info.type}, info.id)
      else
        he.flow.chars[id].x = info.x*30
        he.flow.chars[id].y = info.y*30
    setTimeout(->
      he.static.update()
      he.flow.update()
    , 20)
  
  socket.on 'stage sync', (diff) ->
    for info in diff.flow.delete
      delPart(he.flow, {x: info.x, y: info.y, type: info.type})
    for info in diff.flow.add
      setPart(he.flow, {x: info.x, y: info.y, type: info.type})
    for id, info of diff.char
      if typeof he.flow.chars[id] is 'undefined'
        setPart(he.flow, {x: info.x, y: info.y, type: info.type}, id)
      else
        he.flow.chars[id].x = info.x*30
        he.flow.chars[id].y = info.y*30
    for id, obj of he.flow.chars
      if typeof diff.char[id] is 'undefined'
        he.flow.removeChild(he.flow.chars[id])
        delete(he.flow.chars[id])
    setTimeout(->
      he.flow.update()
      if he.dead
        he.dead = false
        alert('あぼーん')
    , 20)
  window.document.onkeydown = (e) ->
    code = 's' if e.keyCode == 32
    code = 'l' if e.keyCode == 37
    code = 'u' if e.keyCode == 38
    code = 'r' if e.keyCode == 39
    code = 'd' if e.keyCode == 40
    socket.send(code)

setPart = (canvas, opt, id) ->
  image = new Bitmap(fields[opt.type])
  image.width = image.height = 30
  image.x = opt.x * 30
  image.y = opt.y * 30
  if typeof id is 'undefined'
    if typeof canvas.objmap[opt.y][opt.x] == 'undefined' || canvas.objmap[opt.y][opt.x] == null
      canvas.objmap[opt.y][opt.x] = canvas.addChild(image)
  else
    canvas.chars[id] = canvas.addChild(image)

delPart = (canvas, opt, id) ->
  if typeof id is 'undefined'
    canvas.removeChild(canvas.objmap[opt.y][opt.x])
    canvas.objmap[opt.y][opt.x] = null
  else
    canvas.removeChild(canvas.chars[id])
    delete(canvas.chars[id])