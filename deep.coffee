Rooms = new Mongo.Collection 'Rooms'
Actors = new Mongo.Collection 'Actors'

rows = 20
cols = 40

Meteor.methods
  movePlayer: (row, col) ->
    actor = Actors.findOne { userId: Meteor.user()._id }
    room = Rooms.findOne { id: actor.room }
    canMove = (actor, row, col) ->
      newTile = room?.map?[row]?[col]
      return true if newTile? and newTile == '.'
    if canMove(actor, actor.row + row, actor.col + col)
      Actors.update(actor._id, $set: { row: actor.row + row, col: actor.col + col })
  getPlayer: () ->
    userId = Meteor.user()?._id
    if userId?
      existing = Actors.findOne { userId: userId }
      if !existing?
        _id = Actors.insert({ room: 1, chr: '@', row: 5, col: 5 , userId: userId})
        existing = Actors.findOne _id
      return existing?
    return false

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
  sessionId = null

  getX = (col) -> fontSize * multiplier * col
  getY = (row) -> fontSize * multiplier * row
  addText = (row, col, chr) -> game.add.text(getX(col), getY(row), chr, style)
  initMap = (map) -> addText(row_i, col_i, chr) for chr in col for col, col_i in row for row, row_i in map
  
  watchForChanges = () ->
    Tracker.autorun () ->
      newRoom = Rooms.findOne { id: 1 }
      if newRoom? and room?.id != newRoom?.id
        room = newRoom
        game.world.removeAll true
        initMap room.map
      if room?
        newActors = Actors.find({ room: room.id })
        newActors.forEach (newActor) ->
          actor = _.findWhere(actors, { _id: newActor._id })
          if !actor?
            actor = { _id: newActor._id, room: room.id }
            actors.push actor
          actor.sprite = addText(newActor.row, newActor.col, newActor.chr) if !actor.sprite
          [actor.row, actor.col, actor.chr] = [newActor.row, newActor.col, newActor.chr]
          [actor.sprite.x, actor.sprite.y] = [getX(actor.col), getY(actor.row)]

  handleKeyPress = (event) ->
    move = (row, col) -> Meteor.call('movePlayer', row, col)
    switch event.keyCode
      when Phaser.Keyboard.UP then move(-1,  0)
      when Phaser.Keyboard.DOWN then move(1,  0)
      when Phaser.Keyboard.LEFT then move(0, -1)
      when Phaser.Keyboard.RIGHT then move(0,  1)

  mainState =
    preload: () ->
    create: () ->
      game.input.keyboard.addCallbacks(null, handleKeyPress)
      watchForChanges()
    update: () ->

  start = () ->
    game = new Phaser.Game cols * fontSize * multiplier, rows * fontSize * multiplier, Phaser.AUTO, '', mainState, false, null

  Template.game.onRendered () ->
    Tracker.autorun () ->
      user = Meteor.userId()
      start() if (user? and !game?)
      if (!user? and game?)
        game.destroy()
        game = null

if Meteor.isServer
  createRooms = () ->
    getMapObject = () -> if _.random(100) > 80 then '#' else '.'
    map = ( ( getMapObject() for col in [1..cols]) for [1..rows] )
    room = { id: 1, map: map }
    Rooms.upsert({ id: room.id }, $set: { map: map })

  Meteor.startup () ->
    createRooms()
    # Meteor.publish 'Rooms', () -> return Rooms.find()
