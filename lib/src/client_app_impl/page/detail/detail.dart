part of slack_reminder.client_app;

@CustomTag('app-page-detail')
class AppPageDetail extends PolymerElement with AppLinkHandlerMixin {
  AppPageDetail.created() : super.created();

  final Events events = new Events();
  @observable Event event;

  AppEventDeleteDialog _deleteDialog;

  domReady() async {
    var eventID = int.parse(this.getAttribute('eventid') as String);
    this.event = await this.events.getById(eventID);
    this._deleteDialog = shadowRoot.querySelector('app-event-delete-dialog');
    this._deleteDialog.deleteStream.listen(this._onDelete);
    shadowRoot.querySelector('#delete-button').onClick.listen(this._onDeleteButtonClicked);
  }

  void _onDeleteButtonClicked(_) {
    this._deleteDialog.open();
  }

  _onDelete(_) async {
    String name = "${this.event.name}";
    var result = await this.events.removeEvent(this.event);
    var toast = new PaperToast();
    if (result) {
      toast.text = "イベント「${name}」を削除しました";
    } else {
      toast.text = "イベント「${name}」の削除に失敗しました。あとで再試行してみてください。";
    }
    document.body.append(toast);
    toast.show();
    toast.on['core-overlay-close-completed'].listen((_) => toast.remove());

    if (result) {
      AppMain.router.gotoUrl('/');
    }
  }
}