part of slack_reminder.server_app;

class SlackOAuthClient {
  static const String SCOPE = 'post';

  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final Uri callbackUrl;
  final Uri authTestUrl;
  final String stateSalt;
  final String clientID;
  final String clientSecret;

  SlackOAuthClient(
      this.authorizationEndpoint,
      this.tokenEndpoint,
      this.callbackUrl,
      this.authTestUrl,
      this.stateSalt,
      this.clientID,
      this.clientSecret
      );

  Uri getAuthRedirectUri(String state) {
    return new Uri.https(this.authorizationEndpoint.authority, this.authorizationEndpoint.path, {
      'client_id': this.clientID,
      'redirect_uri': this.callbackUrl.toString(),
      'scope': SlackOAuthClient.SCOPE,
      'state': state,
    });
  }

  String createState(String original) {
    return Crypt.sha256(original, salt: "${this.stateSalt}:${new DateTime.now().millisecondsSinceEpoch}");
  }

  Future<Map<String, String>> getAccessTokenFromCallbackRequest(Request request) async {
    var completer = new Completer();

    try {
      if (!request.uri.hasQuery) {
        throw new Exception('response has no query');
      }
      Map<String, String> params = request.uri.queryParameters;
      if (!params.containsKey('code') || !params.containsKey('state')) {
        throw new Exception('response params invalid');
      }
      if (!request.session.containsKey('state')) {
        throw new Exception('missing state in session');
      }
      if (request.session['state'] != params['state']) {
        throw new Exception('invalid state');
      }

      //clear state
      request.session.remove('state');

      String code = params['code'];

      Uri tokenUrl = new Uri.https(this.tokenEndpoint.authority, this.tokenEndpoint.path, {
        'client_id': this.clientID,
        'client_secret': this.clientSecret,
        'code': code,
        'redirect_uri': this.callbackUrl.toString(),
      });

      //request access token
      http.Response response = await http.get(tokenUrl);

      //parse response
      Map<String, dynamic> data = JSON.decode(response.body);

      if (!data.containsKey('ok') || !data['ok']) {
        throw new Exception('ok is not true');
      }
      if (!data.containsKey('access_token') || !data.containsKey('scope')) {
        throw new Exception('access_token/scope does not exists in response');
      }

      completer.complete({
        "access_token":data['access_token'] as String,
        "scope": data['scope'] as String,
      });
    } catch (err) {
      completer.completeError(err);
    }
    return completer.future;
  }

  Future<Map<String, String>> getUserData(String accessToken) async {
    var completer = new Completer();
    try {
      var response = await http.get("https://slack.com/api/auth.test?token=${accessToken}");
      completer.complete(JSON.decode(response.body));
    } catch (err) {
      completer.completeError(err);
    }
    return completer.future;
  }
}

class SlackClient {
  final Uri imOpenUrl;
  final Uri postMessageUrl;

  SlackClient(this.imOpenUrl, this.postMessageUrl);

  /**
   * see https://api.slack.com/methods/im.open
   */
  Future<String> imOpen(String accessToken, String userID) async {
    var completer = new Completer();

    var url = new Uri.https(this.imOpenUrl.authority, this.imOpenUrl.path, {
      'token': accessToken,
      'user': userID,
    });
    Result result = new Result.fromResponse(await http.get(url));
    if (!result.ok) {
      completer.completeError(result.error);
    } else if (!result.data.containsKey('channel') || !result.data['channel'].containsKey('id')) {
      completer.completeError('failed. channel id does not exists.');
    } else {
      completer.complete(result.data['channel']['id']);
    }
    return completer.future;
  }

  /**
   * see: https://api.slack.com/methods/chat.postMessage
   */
  Future<Result> postMessage(
      String accessToken,
      String channelID,
      String messageText,
      {
      String userName,
      bool asUser: false,
      SlackParseMode parse: SlackParseMode.FULL,
      bool linkNames: true,
      bool unfurlLinks: true,
      bool unfurlMedia: true,
      String iconUrl,
      String iconEmoji
      }
      ) async {
    var completer = new Completer();

    Map params = {
      "token": accessToken,
      "channel": channelID,
      "text": messageText,
      "as_user": asUser ? "true" : "false",
      "parse": parse.mode,
      "link_names": linkNames ? "1" : "0",
      "unfurl_links": unfurlLinks ? "true" : "fale",
      "unfurl_media": unfurlMedia ? "true" : "false",
    };
    if (userName != null) {
      params["username"] = userName;
    }
    if (iconUrl != null) {
      params["icon_url"] = iconUrl;
    }
    if (iconEmoji != null) {
      params["icon_emoji"] = iconEmoji;
    }

    Result result = new Result.fromResponse(await http.post(this.postMessageUrl, body: params));
    completer.complete(result);

    return completer.future;
  }
}

class SlackParseMode {
  static const FULL = const SlackParseMode('full');
  static const NONE = const SlackParseMode('none');

  final String mode;

  const SlackParseMode(this.mode);
}

class Result {
  final bool ok;
  final String error;
  final Map data;

  Result(this.ok, this.data, this.error);

  factory Result.fromResponse(http.Response response){
    if (response.statusCode != 200) {
      throw new Exception('Invalid status code: ${response.statusCode}');
    }
    try {
      Map responseData = JSON.decode(response.body);
      if (responseData.containsKey('ok') && responseData['ok']) {
        return new Result(true, responseData, null);
      } else {
        return new Result(false, responseData, (responseData.containsKey('error') ? responseData['error'] : null));
      }
    } on FormatException catch (error) {
      throw new Exception('Invalid response format');
    }
  }
}