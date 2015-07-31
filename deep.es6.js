const Rooms = new Mongo.Collection('Rooms');
const Actors = new Mongo.Collection('Actors');

const rows = 20;
const cols = 40;

Meteor.methods({
  movePlayer: (row, col) => {
    const actor = Actors.findOne({ userId: Meteor.user()._id });
    const room = Rooms.findOne({ id: actor.room });
    const newRow = actor.row + row;
    const newCol = actor.col + col;

    if (room.map && room.map[newRow] && room.map[newRow][newCol]) {
      const newTile = room.map[newRow][newCol];
      if (newTile === '.') {
        Actors.update(actor._id, { $set: { row: newRow, col: newCol } });
      }
    }
  },
  getPlayer: () => {
    const user = Meteor.user();
    if (user) {
      let existing = Actors.findOne({ userId: user.userId });
      if (!existing) {
        const _id = Actors.insert({ room: 1, chr: '@', row: 5, col: 5, userId: user.userId });
        existing = Actors.findOne(_id);
      }
      return true;
    }
    return false;
  },
});

if (Meteor.isClient) {
  Meteor.subscribe('Rooms');
  Meteor.subscribe('Actors');

  const fontSize = 24;
  const style = { font: fontSize + 'px monospace', fill: '#fff' };
  const multiplier = 0.8;

  let actors = [];
  let game = null;
  let room = null;

  const getX = (col) => fontSize * multiplier * col;
  const getY = (row) => fontSize * multiplier * row;
  const addText = (row, col, chr) => game.add.text(getX(col), getY(row), chr, style);
  const initMap = (map) => {
    _(map).each((row, rowI) => {
      _(row).each((col, colI) => {
        _(col).each((chr) => {
          addText(rowI, colI, chr);
        });
      });
    });
  };

  const updateMap = () => {
    const newRoom = Rooms.findOne({ id: 1 });
    if (newRoom && (!room || room.id !== newRoom.id)) {
      room = newRoom;
      game.world.removeAll(true);
      initMap(room.map);
    }
    if (room) {
      const newActors = Actors.find({ room: room.id });
      newActors.forEach((newActor) => {
        let actor = _.findWhere(actors, { _id: newActor._id });
        if (!actor) {
          actor = { _id: newActor._id, room: room.id };
          actors.push(actor);
        }
        if (!actor.sprite) {
          actor.sprite = addText(newActor.row, newActor.col, newActor.chr);
        }
        [actor.row, actor.col, actor.chr] = [newActor.row, newActor.col, newActor.chr];
        [actor.sprite.x, actor.sprite.y] = [getX(actor.col), getY(actor.row)];
      });
    }
  };

  const watchForChanges = _.once(() => { Tracker.autorun(() => { updateMap(); }); });

  const handleKeyPress = (event) => {
    const move = (row, col) => Meteor.call('movePlayer', row, col);
    switch (event.keyCode) {
      case Phaser.Keyboard.UP: move(-1, 0); break;
      case Phaser.Keyboard.DOWN: move(1, 0); break;
      case Phaser.Keyboard.LEFT: move(0, -1); break;
      case Phaser.Keyboard.RIGHT: move(0, 1); break;
    }
  };

  const mainState = {
    preload: () => { },
    create: () => {
      game.input.keyboard.addCallbacks(null, handleKeyPress);
      updateMap();
      watchForChanges();
    },
    update: () => { },
  };

  const start = () => {
    const width = cols * fontSize * multiplier;
    const height = rows * fontSize * multiplier;
    game = new Phaser.Game(width, height, Phaser.AUTO, '', mainState, false, null);
  };

  Template.game.onRendered(() => {
    Tracker.autorun(() => {
      const user = Meteor.userId();
      if (user && !game) {
        start();
      }
      if (!user) {
        game.destroy();
        actors = [];
        game = null;
        room = null;
      }
    });
  });
}

if (Meteor.isServer) {
  const createRooms = () => {
    const getMapObject = () => { return _.random(100) > 80 ? '#' : '.'; };
    const newMap = [];
    _(rows).times(row => {
      newMap.push([]);
      _(cols).times(() => {
        newMap[row].push(getMapObject());
      });
    });
    const room = { id: 1, map: newMap };
    Rooms.upsert({ id: room.id }, { $set: { map: newMap } });
  };

  Meteor.startup(() => {
    createRooms();
    Meteor.publish('Rooms', () => { return Rooms.find(); });
    Meteor.publish('Actors', () => { return Actors.find(); });
  });
}
