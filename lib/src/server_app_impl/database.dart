part of slack_reminder.server_app;

class Database {
  static Database _instance = null;

  ConnectionPool _pool;

  Database(String host, int port, String user, String password, String database) {
    this._pool = new ConnectionPool(host: host, port: port, user:user, password: password, db: database);
  }

  Future<Results> query(String sql, [List values]) async {
    var completer = new Completer();

    if (values is! List) {
      values = [];
    }

    Query query = await this._pool.prepare(sql);
    Results results = await query.execute(values);

    completer.complete(results);

    return completer.future;
  }

  Future<Row> querySingleRow(String sql, [List values]) async {
    var completer = new Completer();
    if (values is! List) values = [];
    Results results = await this.query(sql, values);
    List<Row> rows = await results.toList();
    if (rows.length == 0) {
      completer.complete(null);
    } else {
      completer.complete(rows[0]);
    }
    return completer.future;
  }

  Future<int> queryInsert(String sql, [List values]) async {
    var completer = new Completer();
    if (values is! List) values = [];
    Results results = await this.query(sql, values);
    completer.complete(results.insertId is int ? results.insertId : 0);
    return completer.future;
  }

  Future<int> queryUpdate(String sql, [List values]) async {
    var completer = new Completer();
    if (values is! List) values = [];
    Results results = await this.query(sql, values);
    completer.complete(results.affectedRows);
    return completer.future;
  }
}