part of slack_reminder.client_app;

@CustomTag('app-nl2br')
class AppNl2br extends PolymerElement {
  @observable String text;
  @observable List<String> lines;

  AppNl2br.created(): super.created();

  void domReady() {
    this.lines = this.text.split("\n");
    onPropertyChange(this, #text, () => this.lines = this.text.split("\n"));
  }
}