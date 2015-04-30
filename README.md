# SlackReminder

**Note: I'm not good at English. If I make a mistake with my English, please correct me.**

## About

Slackに登録した日時に通知を送るアプリケーションです。
SlackのOAuth経由でログインし、通知内容を設定します。

This is a application that send notification to your slack when you scheduled.
This application login is via Slack OAuth, and you can schedule.

フロントエンドもバックエンドもDartで書いていて、
フロントエンドは[Polymer](https://www.polymer-project.org/)、バックエンドは[start](https://pub.dartlang.org/packages/start)を利用しています。
どちらも初めて使ったフレームワークなのであまり上手に使えてないとは思います。

This application's frontend and backend written in Dart.
The frontend with [Polymer](https://www.polymer-project.org/), and backend with [start](https://pub.dartlang.org/packages/start).
The first time I use these frameworks.  

## Demo

**Note: Please do not register with your company's Slack.**
**A access token is very dangerous.**
**This application is currently alpha version.**

http://sr.takyam.com/

Now, supports japanese only.

## Development

### Required

* System required (see detail pubspec.yaml)
	* Dart SDK >= 1.9
	* MySQL
* othres
	* Register slack application
		* Get your client ID and client secret.

### Install

```
$ git clone https://github.com/takyam-git/slack_reminder.git
$ cd slack_reminder
$ pub get
$ cp config/app.json.example config/app.json
$ vi config/app.json
     # edit config for your application settings
$ mysql -u user_name -p -e 'CREATE DATABASE database_name;'
$ mysql -u user_name -p database_name < sql/create_tables.sql
```

#### For production

```
$ mkdir config/production
$ cp config/production/app.json.example config/production/app.json
$ vi config/production/app.json
```

### Launch server

```
# For development
$ dart bin/server.dart

# For production
$ SR_MODE=production dart bin/server.dart 
```

