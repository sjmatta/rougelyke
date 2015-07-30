Rooms = new Mongo.Collection 'Rooms'
Actors = new Mongo.Collection 'Actors'

rows = 20
cols = 40

Meteor.methods
  movePlayer: (id, row, col) ->
    actor = Actors.findOne { id: id }
    room = Rooms.findOne { id: actor.room }
    canMove = (actor, row, col) -> 
      newTile = room?.map[row]?[col]
      return true if newTile? and newTile != '#'
    if canMove(actor, actor.row + row, actor.col + col)
      Actors.update(actor._id, $set: { row: actor.row += row, col: actor.col += col })

if Meteor.isClient
  # Meteor.subscribe 'Rooms'

  game = null
  room = null
  player = null
  actors = []
  cursors = null
  fontSize = 24
  style = { font: fontSize + 'px monospace', fill: '#fff' }
  multiplier = 0.8

  getX = (col) -> fontSize * multiplier * col
  getY = (row) -> fontSize * multiplier * row
  addText = (row, col, chr) -> game.add.text(getX(col), getY(row), chr, style)
  initMap = (map) -> addText(row_i, col_i, chr) for chr in col for col, col_i in row for row, row_i in map
  initActors = (actors) -> actor.sprite = addText(actor.row, actor.col, actor.chr) for actor in actors
  
  drawActors = () ->
    Tracker.autorun () ->
      Actors.find({ room: room.id }).forEach (sActor) ->
        actor = _.findWhere(actors, { id: sActor.id })
        [actor.row, actor.col, actor.chr] = [sActor.row, sActor.col, sActor.chr]
        [actor.sprite.x, actor.sprite.y] = [getX(actor.col), getY(actor.row)]

  handleKeyPress = (event) ->
    move = (actor, row, col) -> Meteor.call('movePlayer', player.id, row, col)
    switch event.keyCode
      when Phaser.Keyboard.UP then move(player, -1,  0)
      when Phaser.Keyboard.DOWN then move(player,  1,  0)
      when Phaser.Keyboard.LEFT then move(player,  0, -1)
      when Phaser.Keyboard.RIGHT then move(player,  0,  1)

  mainState =
    preload: () ->
    create: () ->
      player = Actors.findOne { id: 1 }
      game.input.keyboard.addCallbacks(null, handleKeyPress)
      initMap room.map
      initActors [player]
      actors = [player]
      drawActors()
    update: () ->   

  start = () ->
    game = new Phaser.Game cols * fontSize * multiplier, rows * fontSize * multiplier, Phaser.AUTO, '', () ->
      game.state.add('Main', mainState)
      game.state.start 'Main'

  Tracker.autorun () ->
    room = Rooms.findOne { id: 1 }
    actors = Actors.find { room: 1 }
    if !_.isUndefined(room) and !_.isUndefined(actors)
      start()
      @.stop()

if Meteor.isServer
  createRooms = () ->
    getMapObject = () -> if _.random(100) > 80 then '#' else '.'
    map = ( ( getMapObject() for col in [1..cols]) for [1..rows] )
    room = { id: 1, map: map }
    Rooms.upsert({ id: room.id }, $set: { map: map })

  Meteor.startup () ->
    createRooms()
    Actors.upsert({ id: 1 }, $set: { room: 1, chr: 'e', row: 5, col: 5 })
    # Meteor.publish 'Rooms', () -> return Rooms.find()
