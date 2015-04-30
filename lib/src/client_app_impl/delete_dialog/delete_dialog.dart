part of slack_reminder.client_app;

@CustomTag('app-event-delete-dialog')
class AppEventDeleteDialog extends PolymerElement {
  AppEventDeleteDialog.created() : super.created();

  StreamController<int> _deleteStreamController = new StreamController<int>();

  Stream<int> get deleteStream => this._deleteStreamController.stream;

  @observable String eventid;
  @observable String name;

  PaperActionDialog _dialog;

  void domReady() {
    this._dialog = shadowRoot.querySelector('paper-action-dialog');
    shadowRoot.querySelector('#cancel-button').onClick.listen(this._cancel);
    shadowRoot.querySelector('#delete-button').onClick.listen(this._delete);
  }

  void open() {
    this._dialog.open();
  }

  void close() {
    this._dialog.close();
  }

  void _cancel(_) {
    this.close();
  }

  void _delete(_) {
    this._deleteStreamController.add(int.parse(this.eventid));
    this.close();
  }
}