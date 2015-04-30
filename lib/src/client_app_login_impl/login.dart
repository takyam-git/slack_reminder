part of slack_reminder.client_app_login;

@CustomTag('app-login')
class AppEventForm extends PolymerElement {
  AppEventForm.created() : super.created();

  PaperButton _loginButton;

  void domReady() {
    this._loginButton = shadowRoot.querySelector('#login-button');
    this._loginButton.onClick.listen(this._login);
  }

  void _login(_) {
    window.location.assign('/login/redirect');
  }
}