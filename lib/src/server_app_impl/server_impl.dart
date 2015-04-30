part of slack_reminder.server_app;

class AppServer {
  static const CALLBACK_PATH = "/login/callback";

  String _baseUrl;

  Database _db;
  UserRepository _userRepository;
  EventRepository _eventRepository;

  File indexHtmlFile;
  File loginHtmlFile;

  final Map _config;

  SlackOAuthClient _slackOAuthClient;
  SlackClient _slackClient;
  Reminder _reminder;

  AppServer(this._config) {
    this._baseUrl = "http://${this._config['app']['host']}";
    if (this._config['app']['port'] != 80) {
      this._baseUrl = "${this._baseUrl}:${this._config['app']['port']}";
    }

    this._slackOAuthClient = new SlackOAuthClient(
        Uri.parse(this._config['slack']['authorizationUrl']),
        Uri.parse(this._config['slack']['tokenEndpointUrl']),
        Uri.parse("${this._baseUrl}${AppServer.CALLBACK_PATH}"),
        Uri.parse(this._config['slack']['authTestUrl']),
        this._config['app']['stateSalt'],
        this._config['slack']['clientID'],
        this._config['slack']['clientSecret']
    );

    this._slackClient = new SlackClient(
        Uri.parse(this._config['slack']['imOpenUrl']),
        Uri.parse(this._config['slack']['postMessageUrl'])
    );

    this._db = new Database(
        this._config['mysql']['host'],
        this._config['mysql']['port'],
        this._config['mysql']['user'],
        this._config['mysql']['password'],
        this._config['mysql']['database']
    );

    this._userRepository = new UserRepository(this._db);
    this._eventRepository = new EventRepository(this._db);

    this._reminder = new Reminder(
        this._slackClient,
        this._eventRepository,
        this._userRepository,
        this._baseUrl,
        this._config['bot']['name']
    );
    this._reminder.start();

    this.indexHtmlFile = new File('${this._config['app']['serveDirectory']}/index.html');
    this.loginHtmlFile = new File('${this._config['app']['serveDirectory']}/login.html');
  }

  run() async {
    String indexHtml = await this.indexHtmlFile.readAsString();
    String loginHtml = await this.loginHtmlFile.readAsString();

    start(port: this._config['app']['port']).then((Server app) {
      app.static(this._config['app']['serveDirectory'], listing: true, links:true, jail: this._config['app']['jailRoot']);
      app.get(new RegExp(r'^/(?:new|events|events\/\d+|events\/\d+\/edit)$')).listen((Request request) {
        request.response.redirect('/?path=${request.uri.path}');
      });
      app.get('/').listen((Request request) async {
        if (!(await this.isLoggedIn(request))) {
          request.response.redirect('/login');
          return;
        }
        this.responseCsrfToken(request);
        request.response
          ..status(200)
          ..header('Content-Type', 'text/html; charset=UTF-8')
          ..send(indexHtml);
      });
      app.get('/login').listen((Request request) async {
        if (await this.isLoggedIn(request)) {
          request.response.redirect('/');
          return;
        }
        request.response
          ..status(200)
          ..header('Content-Type', 'text/html; charset=UTF-8')
          ..send(loginHtml);
      });
      app.get('/logout').listen((Request request) async {
        request.session.clear();
        request.response.redirect('/');
      });
      app.get('/login/redirect').listen((Request request) async {
        if (await this.isLoggedIn(request)) {
          request.response.redirect('/');
          return;
        }

        String state = this._slackOAuthClient.createState(request.session.id);
        Uri redirectUri = this._slackOAuthClient.getAuthRedirectUri(state);

        //store state to session
        request.session.addAll({"state": state});

        request.response.redirect(redirectUri.toString());
      });
      app.get(AppServer.CALLBACK_PATH).listen(this._serveLoginCallback);
      app.get('/error').listen((request) {
        request.response
          ..add('error')
          ..close();
      });

      app.get('/api/events').listen((Request request) async {
        User user = await this.getUserFromSession(request);
        if (user == null) {
          this.responseErrorJson(request, message: 'requres login', status: 403);
          return;
        }
        this.responseCsrfToken(request);
        List<Event> events = await this._eventRepository.getByUserId(user.id);
        request.response
          ..header('Content-Type', 'application/json; charset=UTF-8')
          ..json(events.map((Event event) => event.toDataObject()).toList());
      });
      app.get('/api/events/:event_id').listen((Request request) async {
        User user = await this.getUserFromSession(request);
        if (user == null) {
          this.responseErrorJson(request, message: 'requres login', status: 403);
          return;
        }
        this.responseCsrfToken(request);
        Event event = await this.fetchEventFromRequest(request, user.id);
        if (event is Event) {
          request.response
            ..header('Content-Type', 'application/json; charset=UTF-8')
            ..json(event.toDataObject());
        }
      });
      app.post('/api/events').listen((Request request) async {
        User user = await this.getUserFromSession(request);
        if (user == null) {
          this.responseErrorJson(request, message: 'requres login', status: 403);
          return;
        }
        if (!this.hasValidToken(request)) {
          this.responseErrorJson(request, message: 'invalid token', status: 400);
          return;
        }

        Map params = await request.payload();
        Map<String, String> errors = this.validateEventParams(params);
        if (errors.isNotEmpty) {
          this.responseErrorJson(request, message: "入力に誤りがあります", status: 400, data: errors);
        } else {
          var notificationType = params['notification_type'] == NotificationType.DIRECT_MESSAGE.name ? NotificationType.DIRECT_MESSAGE : NotificationType.CHANNEL;
          var channelName = notificationType == NotificationType.CHANNEL ? params['channel_name'] : null;
          var userName = notificationType == NotificationType.CHANNEL ? params['user_name'] : null;
          var timing = DateTime.parse(params['timing']);
          Event event;
          try {
            event = await this._eventRepository.createNewEvent(
                user.id,
                params['name'],
                params['description'],
                notificationType,
                channelName,
                userName,
                timing
            );
          } catch (err) {
            this.responseErrorJson(request);
            return;
          }
          request.response
            ..header('Content-Type', 'application/json; charset=UTF-8')
            ..json(event.toDataObject());
        }
      });
      app.put('/api/events/:event_id').listen((Request request) async {
        User user = await this.getUserFromSession(request);
        if (user == null) {
          this.responseErrorJson(request, message: 'requres login', status: 403);
          return;
        }
        if (!this.hasValidToken(request)) {
          this.responseErrorJson(request, message: 'invalid token', status: 400);
          return;
        }
        Event event = await this.fetchEventFromRequest(request, user.id);
        if (event is! Event) {
          return;
        }

        //create validation object
        Map data = event.toDataObject();
        Map params = await request.payload();
        ['name', 'description', 'notification_type', 'channel_name', 'user_name', 'timing'].forEach((key) {
          if (params.containsKey(key)) {
            data[key] = params[key];
          }
        });

        //validation
        Map errors = this.validateEventParams(data);
        if (errors.isNotEmpty) {
          this.responseErrorJson(request, message: "入力に誤りがあります", status: 400, data: errors);
          return;
        }

        var notificationType = data['notification_type'] == NotificationType.DIRECT_MESSAGE.name ? NotificationType.DIRECT_MESSAGE : NotificationType.CHANNEL;
        var channelName = notificationType == NotificationType.CHANNEL ? data['channel_name'] : null;
        var userName = notificationType == NotificationType.CHANNEL ? data['user_name'] : null;
        var timing = DateTime.parse(data['timing']);

        Event updatedEvent;
        try {
          updatedEvent = await this._eventRepository.updateEvent(
              event,
              data['name'],
              data['description'],
              notificationType,
              channelName,
              userName,
              timing
          );
        } catch (err) {
          this.responseErrorJson(request);
          return;
        }
        request.response
          ..header('Content-Type', 'application/json; charset=UTF-8')
          ..json(updatedEvent.toDataObject());
      });
      app.delete('/api/events/:event_id').listen((Request request) async{
        User user = await this.getUserFromSession(request);
        if (user == null) {
          this.responseErrorJson(request, message: 'requres login', status: 403);
          return;
        }
        if (!this.hasValidToken(request)) {
          this.responseErrorJson(request, message: 'invalid token', status: 400);
          return;
        }
        Event event = await this.fetchEventFromRequest(request, user.id);
        if (event is! Event) {
          return;
        }
        bool deleted = await this._eventRepository.destroyEvent(event, userID: user.id);
        request.response
          ..header('Content-Type', 'application/json; charset=UTF-8')
          ..json({'event_id': event.id, 'succeed_delete': deleted});
      });
    });
  }

  Future<Event> fetchEventFromRequest(Request request, userID) async {
    var completer = new Completer();
    int eventID = int.parse(request.param('event_id'));
    if (eventID <= 0) {
      this.responseErrorJson(request, message: "invalid eventID", status: 400);
      completer.complete(null);
    } else {
      Event event = await this._eventRepository.getByID(eventID, userID: userID);
      if (event == null) {
        this.responseErrorJson(request, message: "Not Found", status: 404);
        completer.complete(null);
      } else {
        completer.complete(event);
      }
    }
    return completer.future;
  }

  Map<String, String> validateEventParams(Map params) {
    Map<String, String> errors = new Map<String, String>();
    if (!params.containsKey('name')) {
      errors['name'] = '必須項目です';
    } else if (!validator.isLength(params['name'], 1, 200)) {
      errors['name'] = '1文字以上200文字以内で入力してください';
    }

    if (params.containsKey('description')) {
      if (!validator.isLength(params['description'], 0, 1000)) {
        errors['description'] = '1000文字以内で入力してください';
      }
    }

    if (!params.containsKey('notification_type')) {
      errors['notification_type'] = '必須項目です';
    } else {
      String type = params['notification_type'];
      if (type != NotificationType.DIRECT_MESSAGE.name && type != NotificationType.CHANNEL.name) {
        errors['notification_type'] = 'DMかチャンネルを選んでください';
      } else if (type == NotificationType.CHANNEL.name) {
        if (!params.containsKey('channel_name')) {
          errors['channel_name'] = 'チャンネルの場合はチャンネル名を必ず入力してください';
        } else if (!validator.isLength(params['channel_name'], 2, 200) || !validator.matches(params['channel_name'], r'^#[0-9a-zA-Z_]+$')) {
          errors['channel_name'] = '#から始まる半角英数かアンダースコアのみで200文字以内で入力してください';
        }
        if (!params.containsKey('user_name')) {
          errors['user_name'] = 'チャンネルの場合はユーザー名を必ず入力してください';
        } else if (!validator.isLength(params['user_name'], 1, 200) || !validator.matches(params['user_name'], r'^[0-9a-zA-Z_@\.\-]+$')) {
          errors['user_name'] = '半角英数かアンダースコアのみで200文字以内で入力してください';
        }
      }
    }

    if (!params.containsKey('timing')) {
      errors['timing'] = '必須項目です';
    } else if (!validator.isDate(params['timing'])) {
      errors['timing'] = 'YYYY-MM-DD HH:MM:SS形式で入力してください';
    } else {
      var timing = DateTime.parse(params['timing']);
      if (timing.isBefore(new DateTime.now().add(new Duration(minutes: 3)))) {
        errors['timing'] = '3分以上未来の日時を選んでください';
      }
    }

    return errors;
  }

  Future<User> getUserFromSession(Request request) async {
    var completer = new Completer();
    if (request.session.containsKey('userID')) {
      int sessionUserID = request.session['userID'];
      completer.complete(await this._userRepository.getByID(sessionUserID));
    } else {
      completer.complete(null);
    }
    return completer.future;
  }

  Future<bool> isLoggedIn(Request request) async => (await this.getUserFromSession(request)) is User;

  bool hasValidToken(Request request) {
    if (!request.session.containsKey('csrf_token')) {
      return false;
    }
    for (Cookie cookie in request.cookies) {
      if (cookie is Cookie && cookie.name == 'onetime_token') {
        return request.session['csrf_token'] == cookie.value;
      }
    }
    return false;
  }

  void responseCsrfToken(Request request) {
    var token = Crypt.sha256("${request.session.id}@${new Random().nextDouble()}", salt: this._config['app']['csrfSalt']);
    request.session['csrf_token'] = token;
    request.response.cookie('onetime_token', token, {
      "path": "/",
      "httpOnly": true,
    });
  }

  void redirectError(Request request) {
    request.response.redirect('/error');
  }

  void responseErrorJson(Request request, {String message: "Internal Server Error", int status: 500, Map data}) {
    var responseData = {"error-message": message};
    if (data is Map) {
      responseData['data'] = data;
    }
    this.responseCsrfToken(request);
    request.response
      ..status(status)
      ..header('Content-Type', 'application/json; charset=UTF-8')
      ..send(JSON.encode(responseData));
  }

  _serveLoginCallback(Request request) async {
    try {
      Map<String, String> accessTokenData = await this._slackOAuthClient.getAccessTokenFromCallbackRequest(request);
      Map userData = await this._slackOAuthClient.getUserData(accessTokenData['access_token']);
      User user = await this._userRepository.getBySlackID(
          userData['team_id'],
          userData['user_id']
      );
      if (user == null) {
        user = await this._userRepository.createNewUser(
            userData['url'],
            userData['team'],
            userData['user'],
            userData['team_id'],
            userData['user_id'],
            accessTokenData['access_token'],
            accessTokenData['scope']
        );
      } else if (user.accessToken != accessTokenData['access_token'] || user.scope.join(',') != accessTokenData['scope']) {
        user = await this._userRepository.updateAccessTokenAndScope(user, accessTokenData['access_token'], accessTokenData['scope']);
      }

      request.session.addAll({'userID': user.id});

      this.responseCsrfToken(request);
      request.response.redirect('/');
    } catch (err) {
      this.redirectError(request);
    }
  }
}