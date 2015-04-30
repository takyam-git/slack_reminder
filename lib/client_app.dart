library slack_reminder.client_app;

//core libraries
import 'dart:html';
import 'dart:async';
import 'dart:convert';

//packages
import 'package:route_hierarchical/client.dart';
import "package:intl/intl.dart";
import 'package:polymer/polymer.dart';
import 'package:http/browser_client.dart';
import "package:http/http.dart" as http;

//core-elements
import 'package:core_elements/core_drawer_panel.dart';
import 'package:core_elements/core_menu.dart';
import 'package:core_elements/core_input.dart';
import 'package:core_elements/core_item.dart';
import 'package:core_elements/core_list_dart.dart';

//paper-elements
import 'package:paper_elements/paper_icon_button.dart';
import 'package:paper_elements/paper_button.dart';
import 'package:paper_elements/paper_radio_group.dart';
import 'package:paper_elements/paper_input_decorator.dart';
import 'package:paper_elements/paper_action_dialog.dart';
import 'package:paper_elements/paper_toast.dart';

//non-pages
part "src/client_app_impl/event.dart";
part "src/client_app_impl/nl2br/nl2br.dart";
part "src/client_app_impl/form/form.dart";
part "src/client_app_impl/delete_dialog/delete_dialog.dart";

//pages
part "src/client_app_impl/page/index/index.dart";
part "src/client_app_impl/page/new/new.dart";
part "src/client_app_impl/page/detail/detail.dart";
part "src/client_app_impl/page/edit/edit.dart";

//entry
part "src/client_app_impl/main/main.dart";
