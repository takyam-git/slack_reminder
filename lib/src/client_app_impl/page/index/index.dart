part of slack_reminder.client_app;

@CustomTag('app-page-index')
class AppPageIndex extends PolymerElement with AppLinkHandlerMixin {

  Events _events;

  AppPageIndex.created() : super.created() {
    this._events = new Events();
  }

  @observable ObservableList data = new ObservableList();
  CoreList list;

  domReady() async {
    await this._events.fetchEvents();
    this.list = shadowRoot.querySelector('#item-list') as CoreList;
    this._events.events.forEach((Event event) => this.data.add(event));
  }

  List<Event> sortEvents(List<Event> events) {
    events.sort((Event a, Event b) {
      if (a.isCompleted && !b.isCompleted) {
        return 1;
      } else if (!a.isCompleted && b.isCompleted) {
        return -1;
      } else {
        var now = new DateTime.now();
        var as = a.timing.difference(now).inSeconds;
        var bs = b.timing.difference(now).inSeconds;
        if (as > bs) {
          return 1;
        } else if (as < bs) {
          return -1;
        } else {
          return 0;
        }
      }
    });
    return events;
  }
}