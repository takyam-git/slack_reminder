part of slack_reminder.server_app;

class User {
  final int id;
  String url;
  String team;
  String name;
  String teamID;
  String userID;
  String accessToken;
  List<String> scope;
  DateTime updatedAt;
  DateTime createdAt;

  User(
      this.id,
      this.url,
      this.team,
      this.name,
      this.teamID,
      this.userID,
      this.accessToken,
      this.scope,
      this.updatedAt,
      this.createdAt
      );

  factory User.fromRecord(Row row){
    if (row.length != 10) {
      throw new ArgumentError.value(row);
    }
    return new User(
        int.parse(row.id.toString()),
        row.url,
        row.team,
        row.name,
        row.team_id,
        row.user_id,
        row.access_token,
        (row.scope as String).split(',').toList(),
        row.updated_at,
        row.created_at
    );
  }
}


class UserRepository {
  final Database _db;

  UserRepository(this._db);

  Future<bool> exists(int userID) async {
    var completer = new Completer();

    Row row = await this._db.querySingleRow('SELECT COUNT(*) AS count FROM users WHERE id = ?', [userID]);
    if (row == null) {
      completer.completeError(new Exception('fetch failed'));
    } else {
      completer.complete(int.parse(row.count) > 0);
    }

    return completer.future;
  }

  Future<User> getByID(int userID) async {
    var completer = new Completer();
    Row row = await this._db.querySingleRow('SELECT * FROM users WHERE id = ?', [userID]);
    if (row == null) {
      completer.complete(null);
    } else {
      completer.complete(new User.fromRecord(row));
    }
    return completer.future;
  }

  Future<User> getBySlackID(String teamID, String userID) async {
    var completer = new Completer();
    Row row = await this._db.querySingleRow('SELECT * FROM users WHERE team_id = ? AND user_id = ?', [teamID, userID]);
    if (row == null) {
      completer.complete(null);
    } else {
      completer.complete(new User.fromRecord(row));
    }
    return completer.future;
  }

  Future<User> createNewUser(String url, String team, String name, String teamID, String userID, String accessToken, String scope) async {
    var completer = new Completer();
    var sql = 'INSERT INTO users (url, team, name, team_id, user_id, access_token, scope, created_at) VALUES (?,?,?,?,?,?,?,NOW())';
    var values = [url, team, name, teamID, userID, accessToken, scope];
    Results results = await this._db.query(sql, values);
    if (results.insertId > 0) {
      User user = await this.getByID(results.insertId);
      completer.complete(user);
    } else {
      completer.completeError(new Exception('insert failed'));
    }
    return completer.future;
  }

  Future<User> updateAccessTokenAndScope(User user, String newAccessToken, String newScope) async {
    var completer = new Completer();
    var sql = 'UPDATE users SET access_token = ?, scope = ? WHERE id = ?';
    var values = [newAccessToken, newScope, user.id];
    Results results = await this._db.query(sql, values);
    if (results.affectedRows != 1) {
      completer.completeError(new Exception('Update failed'));
    } else {
      user.accessToken = newAccessToken;
      user.scope = newScope.split(',').toList();
      completer.complete(user);
    }
    return completer.future;
  }
}