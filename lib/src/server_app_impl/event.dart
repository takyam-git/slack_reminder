part of slack_reminder.server_app;

class Event {
  final int id;
  final int userID;
  String name;
  String description;
  NotificationType notificationType;
  String channelName;
  String userName;
  DateTime timing;
  bool isCompleted;
  String error;
  DateTime updatedAt;
  final DateTime createdAt;

  Event(this.id, this.userID, this.name, this.description, this.notificationType, this.channelName, this.userName, this.timing, this.isCompleted, this.error, this.updatedAt, this.createdAt);

  factory Event.fromRecord(Row record){
    return new Event(
        record.id,
        record.user_id,
        record.name,
        record.description.toString(),
        (record.notification_type == 'dm' ? NotificationType.DIRECT_MESSAGE : NotificationType.CHANNEL),
        record.channel_name,
        record.user_name,
        record.timing,
        record.is_completed > 0,
        record.error,
        record.updated_at,
        record.created_at
    );
  }

  Map<String, dynamic> toDataObject() {
    return {
      "id": this.id,
      "user_id": this.userID,
      "name": this.name,
      "description": this.description,
      "notification_type": this.notificationType.name,
      "channel_name": this.channelName,
      "user_name": this.userName,
      "timing": this.timing.toString(),
      "is_completed": this.isCompleted,
      "error": this.error,
      "updated_at": this.updatedAt.toString(),
      "created_at": this.createdAt.toString(),
    };
  }
}

class NotificationType {
  static const NotificationType DIRECT_MESSAGE = const NotificationType('dm');
  static const NotificationType CHANNEL = const NotificationType('channel');

  final String name;

  const NotificationType(this.name);
}

class EventRepository {
  Database _db;

  final RegExp _lineEndMatcher = new RegExp(r"[\n\r]+");
  final StreamController<Event> _addStreamController = new StreamController<Event>();
  final StreamController<Event> _updateStreamController = new StreamController<Event>();
  final StreamController<Event> _deleteStreamController = new StreamController<Event>();

  EventRepository(this._db);

  Stream<Event> get addSteram => this._addStreamController.stream;

  Stream<Event> get updateStream => this._updateStreamController.stream;

  Stream<Event> get deleteStream => this._deleteStreamController.stream;

  Future<Event> getByID(int eventID, {int userID: null}) async {
    var completer = new Completer();
    var sql = 'SELECT * FROM events WHERE id = ?';
    var values = [eventID];
    if (userID != null) {
      sql = "${sql} AND user_id = ?";
      values.add(userID);
    }
    Row row = await this._db.querySingleRow(sql, values);
    if (row == null) {
      completer.complete(null);
    } else {
      Event event = new Event.fromRecord(row);
      completer.complete(event);
    }
    return completer.future;
  }

  Future<List<Event>> getEvents({
                                int userID,
                                int offset,
                                int limit,
                                bool ignoreCompleted: false,
                                bool ignoreBackward: false,
                                String orderBy
                                }) async {
    var completer = new Completer();

    var sql = 'SELECT * FROM events';
    var values = [];
    var wheres = [];

    if (userID is int && userID > 0) {
      wheres.add('user_id = ?');
      values.add(userID);
    }
    if (ignoreCompleted) {
      wheres.add('is_completed = 0');
    }
    if (ignoreBackward) {
      wheres.add('timing > NOW()');
    }

    if (wheres.length > 0) {
      sql += ' WHERE ${wheres.join(' AND ')}';
    }

    if (orderBy is String && orderBy.length > 0) {
      sql += ' ORDER BY ${orderBy}';
    }

    if (limit is int && limit > 0) {
      sql += ' LIMIT ?';
      values.add(limit);
    }

    if (offset is int && offset > 0) {
      sql += ' OFFSET ?';
      values.add(offset);
    }

    Results results = await this._db.query(sql, values);
    List<Event> events = new List<Event>();
    await results.forEach((Row row) {
      events.add(new Event.fromRecord(row));
    });
    completer.complete(events);
    return completer.future;
  }

  Future<List<Event>> getByUserId(int userID, {int offset, int limit}) async {
    return this.getEvents(userID: userID, offset: offset, limit: limit);
  }

  Future<Event> createNewEvent(
      int userID,
      String name,
      String description,
      NotificationType notificationType,
      String channelName,
      String userName,
      DateTime timing) async {
    var completer = new Completer();
    var sql = "INSERT INTO events (user_id,name,description,notification_type,channel_name,user_name,timing,created_at) VALUES (?,?,?,?,?,?,?,NOW())";
    var values = [userID, this._toSingleLine(name), description, notificationType.name, this._toSingleLine(channelName), this._toSingleLine(userName), timing.toString()];

    int eventID = await this._db.queryInsert(sql, values);
    if (eventID <= 0) {
      completer.completeError('failed to save new event');
    } else {
      Event event = await this.getByID(eventID, userID: userID);
      this._addStreamController.add(event);
      completer.complete(event);
    }

    return completer.future;
  }

  Future<Event> updateEvent(
      Event event,
      String name,
      String description,
      NotificationType notificationType,
      String channelName,
      String userName,
      DateTime timing) async {
    var completer = new Completer();
    var sql = "UPDATE events SET name = ?, description = ?, notification_type = ?, channel_name = ?, user_name = ?, timing = ? WHERE id = ?";
    var values = [this._toSingleLine(name), description, notificationType.name, this._toSingleLine(channelName), this._toSingleLine(userName), timing.toString(), event.id];
    await this._db.queryUpdate(sql, values);
    event.name = name;
    event.description = description;
    event.notificationType = notificationType;
    event.channelName = channelName;
    event.userName = userName;
    event.timing = timing;
    this._updateStreamController.add(event);
    completer.complete(event);


    return completer.future;
  }

  Future<bool> destroyEvent(Event event, {int userID}) async {
    var completer = new Completer();
    var sql = 'DELETE FROM events WHERE id = ?';
    var values = [event.id];
    if (userID is int && userID > 0) {
      sql = "${sql} AND user_id = ?";
      values.add(userID);
    }
    int deletedRows = await this._db.queryUpdate(sql, values);
    this._deleteStreamController.add(event);
    completer.complete(deletedRows > 0);

    return completer.future;
  }

  Future<bool> setCompleted(Event event) async {
    var completer = new Completer();

    var sql = 'UPDATE events SET is_completed = 1 WHERE id = ?';
    var values = [event.id];
    int updatedRowsCount = await this._db.queryUpdate(sql, values);
    event.isCompleted = true;
    this._updateStreamController.add(event);
    completer.complete(updatedRowsCount > 0);

    return completer.future;
  }

  Future<bool> setFailed(Event event, String error) async {
    var completer = new Completer();

    error = this._toSingleLine(error);
    var sql = 'UPDATE events SET is_completed = 1, error = ? WHERE id = ?';
    var values = [error, event.id];
    int updatedRowsCount = await this._db.queryUpdate(sql, values);
    event.isCompleted = true;
    event.error = error;
    this._updateStreamController.add(event);
    completer.complete(updatedRowsCount > 0);

    return completer.future;
  }

  String _toSingleLine(String text) {
    if (text is String) {
      return text.replaceAll(this._lineEndMatcher, '');
    }
    return text;
  }
}