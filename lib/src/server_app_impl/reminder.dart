part of slack_reminder.server_app;

class EventTimer {
  Event event;
  Timer _timer;

  EventTimer(this.event, Function _handler) {
    var now = new DateTime.now();
    var difference = event.timing.difference(now);
    if (difference.isNegative) {
      throw new Exception('passed time');
    }
    this._timer = new Timer(difference, () => _handler(this.event));
  }

  void cancel() {
    this._timer.cancel();
  }
}

class Reminder {
  Map<int, EventTimer> _events = new Map<int, EventTimer>();
  final SlackClient _slackClient;
  final EventRepository _eventRepository;
  final UserRepository _userRepository;
  final String _baseURL;
  final String _botName;

  Reminder(this._slackClient, this._eventRepository, this._userRepository, this._baseURL, this._botName);

  start() async {
    List<Event> events = await this._eventRepository.getEvents(ignoreCompleted: true, ignoreBackward: true);
    events.forEach((Event event) => this.add(event));
    this._eventRepository
      ..addSteram.listen(this._updateHandler)
      ..updateStream.listen(this._updateHandler)
      ..deleteStream.listen(this._removeHandler);
  }

  add(Event event) {
    var registered = false;
    if (event.timing.isAfter(new DateTime.now())) {
      try {
        this._events[event.id] = new EventTimer(event, this._timingHandler);
        registered = true;
      } on Exception catch (err) {
        registered = false;
      }
    }
    if (!registered) {
      this._eventRepository.setFailed(event, '通知キュー登録時点で予定時刻を経過していました');
    }
  }

  remove(Event event) {
    if (this._events.containsKey(event.id)) {
      this._events[event.id].cancel();
      this._events.remove(event.id);
    }
  }

  void _updateHandler(Event event) {
    if (event.isCompleted) {
      this.remove(event);
    } else {
      if (this._events.containsKey(event.id)) {
        if (event.timing.millisecondsSinceEpoch != this._events[event.id].event.timing.millisecondsSinceEpoch) {
          this._events[event.id].event = event;
        } else {
          this.remove(event);
          this.add(event);
        }
      } else {
        this.add(event);
      }
    }
  }

  void _removeHandler(Event event) {
    this.remove(event);
  }

  _timingHandler(Event event) async {
    User user = await this._userRepository.getByID(event.userID);
    if (user == null) {
      this._eventRepository.setFailed(event, 'ユーザー情報の取得に失敗');
      this._events.remove(event.id);
      return;
    }
    String channelName;
    String userName;
    if (event.notificationType == NotificationType.DIRECT_MESSAGE) {
      channelName = await this._slackClient.imOpen(user.accessToken, user.userID);
      userName = '@' + user.name;
    } else {
      channelName = event.channelName;
      userName = event.userName;
    }

    Result result = await this._slackClient.postMessage(
        user.accessToken,
        channelName,
        this._createSendMessageText(event, userName),
        userName: this._botName
    );

    if (result.ok) {
      this._eventRepository.setCompleted(event);
    } else {
      this._eventRepository.setFailed(event, result.error != null ? result.error : 'unknown reason');
    }
    this._events.remove(event.id);
  }

  String _createSendMessageText(Event event, String userName) {
    var message = """
    ${userName}「${event.name}」の時間になりましたのでお知らせいたします。
    詳細: ${this._baseURL}/events/${event.id}
    """;
    if (event.description is String) {
      var trimmed = event.description.trim();
      if (trimmed.length > 0) {
        message += "\n" + trimmed.split("\n").map((String line) => "> ${line}").join("\n");
      }
    }
    return message;
  }
}