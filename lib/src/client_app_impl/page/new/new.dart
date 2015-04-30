part of slack_reminder.client_app;

@CustomTag('app-page-new')
class AppPageNew extends PolymerElement {
  AppPageNew.created() : super.created();

  final Events _events = new Events();

  AppEventForm _form;

  void domReady() {
    this._form = shadowRoot.querySelector('app-event-form');
    _form.saveStream.listen(this._save);
  }

  _save(Map<String, dynamic> eventData) async {
    try {
      Event newEvent = await this._events.addNewEvent(
          eventData['name'],
          eventData['description'],
          eventData['user_name'],
          eventData['notification_type'],
          eventData['channel_name'],
          eventData['timing']
      );
      if (newEvent is Event) {
        AppMain.router.gotoUrl('/events/${newEvent.id}');
      }
    } on ServerValidateException catch (error) {
      this._form.setErrors(error.errors);
    }
  }
}