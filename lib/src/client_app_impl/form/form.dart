part of slack_reminder.client_app;

@CustomTag('app-event-form')
class AppEventForm extends PolymerElement {
  AppEventForm.created() : super.created(){
    var defaultTiming = new DateTime.now().add(new Duration(minutes: 5));
    this.timingDate = this.timingFormatterDate.format(defaultTiming);
    this.timingTime = this.timingFormatterTime.format(defaultTiming);
  }

  StreamController<Map<String, dynamic>> _saveStreamController = new StreamController<Map<String, dynamic>>();
  final DateFormat timingFormatterDate = new DateFormat("yyyy-MM-dd");
  final DateFormat timingFormatterTime = new DateFormat("HH:mm:ss");

  @observable String name;
  @observable String user_name;
  @observable String channel_name;
  @observable String timing;
  @observable String notification_type = NotificationTypes.DM.name;
  @observable String description = '';

  @observable String timingDate;
  @observable String timingTime;

  Stream<Map<String, dynamic>> get saveStream => this._saveStreamController.stream;

  List<PaperInputDecorator> _decorators;

  PaperToast _invalidFieldsToast;

  PaperInputDecorator _nameDecorator;
  CoreInput _nameInput;
  PaperRadioGroup _notificationType;
  CoreItem _userNameContainer;
  PaperInputDecorator _userNameDecorator;
  CoreInput _userNameInput;
  CoreItem _channelNameContainer;
  PaperInputDecorator _channelNameDecorator;
  CoreInput _channelNameInput;
  PaperInputDecorator timingDateDecorator;
  PaperInputDecorator timingTimeDecorator;
  CoreInput timingDateInput;
  CoreInput timingTimeInput;

  void domReady() {
    this._decorators = shadowRoot.querySelectorAll('paper-input-decorator').toList();
    this._invalidFieldsToast = shadowRoot.querySelector('#toast-invalid-fields');
    this._nameDecorator = shadowRoot.querySelector('#decorator-name');
    this._nameInput = shadowRoot.querySelector('#input-event-name');
    this._notificationType = shadowRoot.querySelector('#notification-type');
    this._userNameContainer = shadowRoot.querySelector('#user-name-container');
    this._userNameDecorator = shadowRoot.querySelector('#decorator-user-name');
    this._userNameInput = shadowRoot.querySelector('#input-event-user-name');
    this._channelNameContainer = shadowRoot.querySelector('#channel-name-container');
    this._channelNameDecorator = shadowRoot.querySelector('#decorator-channel-name');
    this._channelNameInput = shadowRoot.querySelector('#input-event-channel-name');
    this.timingDateDecorator = shadowRoot.querySelector('#decorator-timing-date');
    this.timingTimeDecorator = shadowRoot.querySelector('#decorator-timing-time');
    this.timingDateInput = shadowRoot.querySelector('#input-event-timing-date');
    this.timingTimeInput = shadowRoot.querySelector('#input-event-timing-time');

    shadowRoot.querySelector('#save-button').onClick.listen(this._save);
    shadowRoot.querySelector('#form').onSubmit.listen(this._save);
    this.timingDateInput.onChange.listen(this._timingValidation);
    this.timingTimeInput.onChange.listen(this._timingValidation);
    this._notificationType.on['core-select'].listen(this._notificationTypeValidation);

    this._validation();
  }

  void timingChanged() {
    var timing = new DateTime.fromMillisecondsSinceEpoch(int.parse(this.timing));
    this.timingDate = this.timingFormatterDate.format(timing);
    this.timingTime = this.timingFormatterTime.format(timing);
  }

  void setErrors(Map errors) {
    if (errors.containsKey('name')) {
      this._nameInput.setCustomValidity(errors['name']);
      this._nameDecorator.validate();
    }
    if (errors.containsKey('notification_type')) {
      //TODO
    }
    if (errors.containsKey('user_name')) {
      this._userNameInput.setCustomValidity(errors['user_name']);
      this._userNameDecorator.validate();
    }
    if (errors.containsKey('channel_name')) {
      this._channelNameInput.setCustomValidity(errors['channel_name']);
      this._channelNameDecorator.validate();
    }
    if (errors.containsKey('timing')) {
      this.timingDateInput.setCustomValidity(errors['timing']);
      this.timingDateDecorator.validate();
    }
  }

  void _validation() {
    this._decorators.forEach((PaperInputDecorator decorator) => decorator.validate());
    this._notificationTypeValidation(null);
    this._timingValidation(null);
  }

  bool _notificationTypeValidation(_) {
    bool channelDisabled = this._notificationType.selected == 'dm';
    this._channelNameDecorator.disabled = channelDisabled;
    this._channelNameInput.disabled = channelDisabled;
    this._channelNameContainer.hidden = channelDisabled;
    this._userNameDecorator.disabled = channelDisabled;
    this._userNameInput.disabled = channelDisabled;
    this._userNameContainer.hidden = channelDisabled;
    if (channelDisabled) {
      this._channelNameDecorator.isInvalid = false;
      this._userNameDecorator.isInvalid = false;
    } else {
      this._channelNameDecorator.validate();
      this._userNameDecorator.validate();
    }
  }

  bool _timingValidation(_) {
    String date = this.timingDateInput.value;
    String time = this.timingTimeInput.value;
    bool hasDateFormatError = false;
    bool hasTimeFormatError = false;
    if (time.length == 5) {
      time = "${time}:00";
    }

    try {
      this.timingFormatterDate.parse(date);
    } on FormatException catch (_) {
      hasDateFormatError = true;
    }

    try {
      this.timingFormatterTime.parse(time);
    } on FormatException catch (_) {
      hasTimeFormatError = true;
    }
    if (hasDateFormatError || hasTimeFormatError) {
      if (hasDateFormatError) {
        this.timingDateInput.setCustomValidity('YYYY-MM-DDの日付形式で入力してください');
      }
      if (hasTimeFormatError) {
        this.timingTimeInput.setCustomValidity('HH:MM:SSの時間形式で入力してください');
      }
    } else {
      DateTime dateTime = DateTime.parse("${date} ${time}");
      DateTime now = new DateTime.now().add(new Duration(minutes: 3));
      if (dateTime.isBefore(now)) {
        if (now.difference(dateTime).inDays > 0) {
          this.timingDateInput.setCustomValidity('未来の日付を入力してください');
          hasDateFormatError = true;
        } else {
          this.timingTimeInput.setCustomValidity('未来の時間を入力してください');
          hasTimeFormatError = true;
        }
      }
    }


    if (!hasDateFormatError) {
      this.timingDateInput.setCustomValidity('');
    }
    if (!hasTimeFormatError) {
      this.timingTimeInput.setCustomValidity('');
    }
    this.timingTimeDecorator.validate();
    this.timingDateDecorator.validate();

    return !hasDateFormatError && !hasTimeFormatError;
  }

  void _save(_) {
    this._validation();
    if (this._decorators.any((PaperInputDecorator decorator) => decorator.isInvalid)) {
      this._invalidFieldsToast.show();
      return;
    }

    DateTime timing = DateTime.parse("${this.timingDateInput.value} ${this.timingTimeInput.value}");
    this._saveStreamController.add({
      "name": this.name,
      "user_name": this.user_name,
      "channel_name": this.channel_name,
      "notification_type": this._notificationType.selected,
      "timing": timing,
      "description": this.description,
    });
  }
}