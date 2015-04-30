part of slack_reminder.client_app;

/// Simple class which maps page names to paths.
class Page {
  final String name;
  final String displayName;
  final String path;
  final String icon;
  final bool isDefault;

  Page(this.name, this.displayName, this.path, {this.isDefault: false, this.icon:''});

  String toString() => '$name';
}

class AppLinkHandlerMixin {
  void handleMove(MouseEvent event, _, HtmlElement element) {
    if (element.attributes.containsKey('href')) {
      event.preventDefault();
      AppMain.router.gotoUrl(element.attributes['href']);
    }
  }
}

@CustomTag('app-main')
class AppMain extends PolymerElement with AppLinkHandlerMixin {
  /// The current selected [Page].
  @observable Page selectedPage;

  /// The path of the current [Page].
  @observable Route route;

  static final Router router = new Router(useFragment: false);

  final List<Page> pages = [
    new Page('index', '一覧', r'/', icon:'icons:list', isDefault: true),
    new Page('new', '新規登録', r'/new', icon:'icons:add-circle-outline'),
    new Page('detail', '詳細', r'/events/:event_id'),
    new Page('edit', '編集', r'/events/:event_id/edit'),
  ];

  CoreDrawerPanel drawerPanel;
  CoreMenu menu;
  SpanElement contentTitle;
  DivElement container;
  List<Node> sideHeaderClone;
  PaperActionDialog _logoutDialog;
  PaperButton _cancelButton;
  PaperButton _logoutButton;

  AppMain.created() : super.created();

  void domReady() {
    //メニュー開閉ボタン
    PaperIconButton navIcon = shadowRoot.querySelector("#navicon");
    this.drawerPanel = shadowRoot.querySelector("#drawerPanel");
    navIcon.onClick.listen((_) => this.drawerPanel.togglePanel());

    //DOM取得
    this.menu = shadowRoot.querySelector('#sidebar-menu');
    this.contentTitle = shadowRoot.querySelector('#content-title');
    this.container = shadowRoot.querySelector('#main-container');
    this._logoutDialog = shadowRoot.querySelector('#logout-dialog');

    //ルーティング登録
    this.pages.forEach((Page page) => AppMain.router.root
      ..addRoute(name: page.name, path: page.path, defaultRoute: page.isDefault, enter: this._enterRoute));

    //path
//    var params = Uri.parse(window.location.href).queryParameters;
//    if (params.containsKey('path')) {
//      AppMain.router.gotoUrl(params['path']);
//    }
    AppMain.router.listen();



    //logout
    shadowRoot.querySelector('#logout-menu').onClick.listen(this._confirmLogout);
    shadowRoot.querySelector('#cancel-logout-button').onClick.listen((_) => this._logoutDialog.close());
    shadowRoot.querySelector('#logout-button').onClick.listen(this._logout);
  }

  /// Updates [route] whenever we enter a new route.
  void _enterRoute(RouteEnterEvent event) {
    this.route = event.route;
    this.drawerPanel.closeDrawer();
  }

  /// Updates [selectedPage] and the current route whenever the route changes.
  void routeChanged() {
    if (this.route == null) {
      this.selectedPage = this.pages.firstWhere((page) => page.isDefault);
    } else {
      this.selectedPage = this.pages.firstWhere((page) => page.name == this.route.name);
    }
    this._movePage(this.selectedPage);
  }

  void _movePage(Page page) {
    this.container.children.clear();
    this.selectMenuItem(page);
    this.updateTitle(page);

    var tag = new Element.tag('app-page-${page.name}');
    tag.setAttribute('eventid', this.route.parameters.containsKey('event_id') ? this.route.parameters['event_id'] : '');
    this.container.append(tag);
  }

  void selectMenuItem(Page page) {
    this.menu.selected = page.name;
  }

  void updateTitle(Page page) {
    this.contentTitle.text = page.displayName;
  }

  void _confirmLogout(_) {
    this._logoutDialog.open();
  }

  void _logout(_) {
    window.location.assign('/logout');
  }
}