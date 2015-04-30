part of slack_reminder.client_app;

class Channel extends Observable {
  @observable String name;

  Channel(this.name);
}

class SlackUser extends Observable {
  @observable String name;

  SlackUser(this.name);
}

class NotificationType {
  final String _name;
  final String _displayName;

  const NotificationType(this._name, this._displayName);

  String get name => this._name;

  String get displayName => this._displayName;
}

class NotificationTypes {
  static const DM = const NotificationType('dm', 'DirectMessage');
  static const CHANNEL = const NotificationType('channel', 'チャンネル');
}

class Event extends Observable {
  int id;
  @observable String name;
  @observable String description;
  @observable Channel channel;
  @observable NotificationType notificationType;
  @observable SlackUser user;
  @observable bool isCompleted;
  @observable String displayRestTime;
  @observable String error;
  @observable bool loading = false;

  StreamController<Event> _timingPassedStreamController = new StreamController<Event>.broadcast();

  DateTime _timing;
  Timer _timer;

  Event(this.id, this.name, this.description, this.user, this.notificationType, this.channel, DateTime timing, {this.isCompleted: false, this.error: null}) {
    this.timing = timing;
    this.updateRestTime(null);
  }

  factory Event.fromApiResponse(Map data){
    return new Event(
        data['id'],
        data['name'],
        data['description'],
        new SlackUser(data['user_name']),
        data['notification_type'] == NotificationTypes.DM.name ? NotificationTypes.DM : NotificationTypes.CHANNEL,
        new Channel(data['channel_name']),
        DateTime.parse(data['timing']),
        isCompleted: data['is_completed'],
        error: data['error']
    );
  }

  Stream<Event> get timingPassedStream => this._timingPassedStreamController.stream;

  @observable DateTime get timing => this._timing;

  void set timing(DateTime timing) {
    this._timing = timing;
    this.updateRestTime(null);
    this.registerTimer();
  }

  final DateFormat displayDateFormat = new DateFormat("yyyy-MM-dd HH:mm:ss");

  @observable get displayTiming => displayDateFormat.format(this.timing);

  void registerTimer() {
    if (this._timer is! Timer || !this._timer.isActive) {
      this._timer = new Timer.periodic(new Duration(seconds: 1), this.updateRestTime);
    }
  }

  void updateRestTime(_) {
    DateTime now = new DateTime.now();

    if (this._timing.isBefore(now)) {
      if (this._timer is Timer) this._timer.cancel();
      this.displayRestTime = '-';
      this._timingPassedStreamController.add(this);
      return;
    }

    Duration timeDiff = this._timing.difference(now);

    int days = timeDiff.inDays;
    int hours = timeDiff.inHours.remainder(Duration.HOURS_PER_DAY);
    int minutes = timeDiff.inMinutes.remainder(Duration.MINUTES_PER_HOUR);
    int seconds = timeDiff.inSeconds.remainder(Duration.SECONDS_PER_MINUTE);

    var values = {
      "days": "${days}日",
      "hours": "${hours}時間",
      "minutes": "${minutes}分",
      "seconds": "${seconds}秒",
    };
    if (days > 0) {
      //all ok
    } else if (hours > 0) {
      //ignore days
      values.remove("days");
    } else if (minutes > 0) {
      //ignore days and hours
      values.remove("days");
      values.remove("hours");
    } else {
      // only seconds
      values.remove("days");
      values.remove("hours");
      values.remove("minutes");
    }

    this.displayRestTime = values.values.join('');
  }

  void updateData(Map eventData) {
    if (eventData['name'] != this.name) this.name = eventData['name'];
    if (eventData['description'] != this.description) this.description = eventData['description'];
    if (eventData['notification_type'] != this.notificationType.name) {
      this.notificationType = eventData['notification_type'] == NotificationTypes.DM.name ? NotificationTypes.DM : NotificationTypes.CHANNEL;
    }
    if (eventData['channel_name'] != this.channel.name) this.channel.name = eventData['channel_name'];
    if (eventData['user_name'] != this.user.name) this.user.name = eventData['user_name'];
    if (eventData['is_completed'] != this.isCompleted) this.isCompleted = eventData['is_completed'];
    var timing = DateTime.parse(eventData['timing']);
    if (this.timing.compareTo(timing) != 0) this.timing = timing;
    if (eventData['error'] != this.error) this.error = eventData['error'];
  }

  String toString() {
    return {
      'id': this.id,
      'name': this.name,
      'description': this.description,
      'notificationType': this.notificationType.name,
      'channelName': this.channel.name,
      'userName': this.user.name,
      'timing': this.timing,
      'displayTiming': this.displayTiming,
      'displayRestTime': this.displayRestTime,
      'isCompleted': this.isCompleted,
      'error': this.error,
      'loading': this.loading,
    }.toString();
  }
}

class Events {
  static Events _instance = null;

  factory Events(){
    if (Events._instance == null) {
      Events._instance = new Events._internal();
    }
    return Events._instance;
  }

  final Map<int, Event>_events = new Map<int, Event>();
  final Map<int, StreamSubscription> _eventListeners = new Map<int, StreamSubscription>();
  final EventApiClient _client = new EventApiClient();

  Events._internal();

  List<Event> get events => this._events.values.toList();

  Future fetchEvents() async {
    var completer = new Completer();
    List<Map> eventDataList = await this._client.getEvents();
    eventDataList.forEach((Map data) => this.set(new Event.fromApiResponse(data)));
    completer.complete();
    return completer.future;
  }

  void set(Event event) {
    if (!this._events.containsKey(event.id) || this._events[event.id] != event) {
      this._events[event.id] = event;
      if (!event.isCompleted) {
        if (this._eventListeners.containsKey(event.id)) {
          this._eventListeners[event.id].cancel();
        }
        this._eventListeners[event.id] = event.timingPassedStream.listen(this._checkEventCompletedStart);
      }
    }
  }

  _checkEventCompletedStart(Event event) {
    event.loading = true;
    //DBに反映されるまで時間かかるかもしらんので少し待ってからアレする
    new Timer(new Duration(seconds: 3), () => this._checkEventCompletedHandler(event));
  }

  _checkEventCompletedHandler(Event event) async {
    Map eventData = await this._client.getByID(event.id);
    if (eventData == null) {
      return;
    }
    event.updateData(eventData);
    event.loading = false;
  }

  Future<Event> getById(int eventID) async {
    var completer = new Completer();
    if (this._events.containsKey(eventID)) {
      completer.complete(this._events[eventID]);
    } else {
      Map eventData = await this._client.getByID(eventID);
      if (eventData == null) {
        completer.complete(null);
      } else {
        Event event = new Event.fromApiResponse(eventData);
        this.set(event);
        completer.complete(event);
      }
    }
    return completer.future;
  }

  Future<Event> addNewEvent(String name, String description, String userName, String notificationTypeName, String channelName, DateTime timing) async {
    var completer = new Completer();

    NotificationType notificationType = notificationTypeName == NotificationTypes.DM.name ? NotificationTypes.DM : NotificationTypes.CHANNEL;
    Map eventData = await this._client.create(name, description, userName, notificationType, channelName, timing);
    Event event = new Event.fromApiResponse(eventData);
    this.set(event);
    completer.complete(event);
    return completer.future;
  }

  Future<Event> updateEvent(Event event) async {
    var completer = new Completer();
    await this._client.update(event);
    this.set(event);
    completer.complete(event);
    return completer.future;
  }

  Future<bool> removeEvent(Event event) async {
    var completer = new Completer();
    bool result = await this._client.destroy(event.id);
    if (result) {
      if (this._eventListeners.containsKey(event.id)) {
        this._eventListeners[event.id].cancel();
      }
      this._events.remove(event.id);
      completer.complete(true);
    } else {
      completer.complete(false);
    }
    return completer.future;
  }
}

class EventApiClient {
  static const API_URL = '/api/events';

  DateFormat _dateFormat = new DateFormat('yyyy-MM-dd HH:mm:ss');
  BrowserClient _client = new BrowserClient();

  Future<List<Map>> getEvents() async {
    var completer = new Completer();
    http.Response response = await this._client.get("${EventApiClient.API_URL}");
    if (response.statusCode != 200) {
      completer.completeError('failed');
    } else {
      completer.complete(JSON.decode(response.body));
    }
    return completer.future;
  }

  Future<Map> getByID(int eventID) async {
    var completer = new Completer();

    http.Response response = await this._client.get("${EventApiClient.API_URL}/${eventID}");
    if (response.statusCode != 200) {
      completer.complete(null);
    } else {
      completer.complete(JSON.decode(response.body));
    }
    return completer.future;
  }

  Future<Map> create(
      String name,
      String description,
      String userName,
      NotificationType notificationType,
      String channelName,
      DateTime timing) async {
    var completer = new Completer();
    http.Response response = await this._client.post("${EventApiClient.API_URL}", body: {
      'name': name,
      'description': description,
      'notification_type': notificationType.name,
      'user_name': userName == null ? '' : userName,
      'channel_name': channelName == null ? '' : channelName,
      'timing': this._dateFormat.format(timing),
    });
    if (response.statusCode != 200) {
      Map errorData;
      try {
        errorData = JSON.decode(response.body);
      } on FormatException catch (err) {
      }
      if (errorData is Map && errorData.containsKey('data')) {
        completer.completeError(new ServerValidateException(errorData['data']));
      } else {
        completer.completeError('failed create api request');
      }
    } else {
      completer.complete(JSON.decode(response.body));
    }

    return completer.future;
  }

  Future<Map> update(Event event) async {
    var completer = new Completer();
    http.Response response = await this._client.put("${EventApiClient.API_URL}/${event.id}", body: {
      'name': event.name,
      'description': event.description,
      'notification_type': event.notificationType.name,
      'user_name': event.user.name == null ? '' : event.user.name,
      'channel_name': event.channel.name == null ? '' : event.channel.name,
      'timing': this._dateFormat.format(event.timing),
    });
    if (response.statusCode != 200) {
      Map errorData;
      try {
        errorData = JSON.decode(response.body);
      } on FormatException catch (err) {
      }
      if (errorData is Map && errorData.containsKey('data')) {
        completer.completeError(new ServerValidateException(errorData['data']));
      } else {
        completer.completeError('failed update api request');
      }
    } else {
      completer.complete(JSON.decode(response.body));
    }

    return completer.future;
  }

  destroy(int eventID) async {
    var completer = new Completer();

    http.Response response = await this._client.delete("${EventApiClient.API_URL}/${eventID}");
    Map result = JSON.decode(response.body);
    completer.complete(result.containsKey('succeed_delete') && result['succeed_delete']);

    return completer.future;
  }
}

class ServerValidateException implements Exception {
  final Map errors;

  ServerValidateException(this.errors);
}