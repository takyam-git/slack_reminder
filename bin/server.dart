import "dart:io";
import "dart:async";
import "dart:convert";

import "package:slack_reminder/server_app.dart";

main() async {
  var confDir = "config";
  if (Platform.environment.containsKey('SR_MODE')) {
    confDir = "${confDir}/${Platform.environment['SR_MODE']}";
  }

  var configFile = new File("${confDir}/app.json");
  String configJson = await configFile.readAsString();
  Map config = JSON.decode(configJson);

  AppServer server = new AppServer(config);
  runZoned(() {
    server.run();
  }, onError: (err, stackTrace) {
    print("${err}\n${stackTrace}");
  });
}