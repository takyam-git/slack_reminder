part of slack_reminder.client_app;

@CustomTag('app-page-edit')
class AppPageEdit extends PolymerElement {
  AppPageEdit.created() : super.created();

  final Events events = new Events();

  Event _event;
  @observable Map event;

  PaperButton _saveButton;
  AppEventForm _form;

  attached() async {
    super.attached();
    var eventID = int.parse(this.getAttribute('eventid') as String);
    this._event = await this.events.getById(eventID);
    if (this._event.isCompleted) {
      AppMain.router.gotoUrl('/events/${eventID}');
      return;
    }
    this.event = {
      "id": "${this._event.id}",
      "name": "${this._event.name}",
      "user_name": this._event.user.name,
      "channel_name": this._event.channel.name,
      "timing": "${this._event.timing.millisecondsSinceEpoch}",
      "description": "${this._event.description}",
      "notification_type": "${this._event.notificationType.name}",
    };
    this._form = shadowRoot.querySelector('app-event-form');
  }

  void domReady() {
    (shadowRoot.querySelector('app-event-form') as AppEventForm).saveStream.listen(this._save);
  }

  _save(Map<String, dynamic> eventData) async {
    this._updateEventData(eventData);
    try {
      await this.events.updateEvent(this._event);
      AppMain.router.gotoUrl("/events/${this._event.id}");
    } on ServerValidateException catch (error) {
      this._form.setErrors(error.errors);
    }
  }

  void _updateEventData(Map<String, dynamic> eventData) {
    if (this._event.name != eventData['name']) {
      this._event.name = eventData['name'];
    }
    if (this._event.user.name != eventData['user_name']) {
      this._event.user = new SlackUser(eventData['user_name']);
    }
    if (this._event.notificationType.name != eventData['user_name']) {
      this._event.notificationType = eventData['notification_type'] == NotificationTypes.DM.name ? NotificationTypes.DM : NotificationTypes.CHANNEL;
    }
    if (this._event.channel.name != eventData['channel_name']) {
      this._event.channel = new Channel(eventData['channel_name']);
    }
    if (this._event.timing.millisecondsSinceEpoch != (eventData['timing'] as DateTime).millisecondsSinceEpoch) {
      this._event.timing = eventData['timing'];
    }
    if (this._event.description != eventData['description']) {
      this._event.description = eventData['description'];
    }
  }
}