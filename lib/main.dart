import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strelka/content.dart';

void main() {
  runApp(ProviderScope(
      child: MaterialApp(
    routes: {'/list': (_) => TabListScreen(), '/tabs': (_) => Strelka()},
    initialRoute: '/tabs',
  )));
}

class TabsState {
  final int currentId;
  final int numOfTabs;
  final List<String> tabNames;

  TabsState(
      {required this.currentId,
      required this.numOfTabs,
      required this.controller,
      required this.tabNames});

  TabsState.empty()
      : controller = PageController(),
        currentId = 0,
        tabNames = ['StartPage'],
        numOfTabs = 1;

  TabsState copyWith({int? currentId, int? numOfTabs, List<String>? tabNames}) {
    return TabsState(
        controller: this.controller,
        currentId: currentId ?? this.currentId,
        tabNames: tabNames ?? this.tabNames,
        numOfTabs: numOfTabs ?? this.numOfTabs);
  }

  final PageController controller;
}

class TabListNotifier extends StateNotifier<TabsState> {
  final ProviderReference _ref;
  TabListNotifier(this._ref) : super(TabsState.empty());

  void selectTab(int tab) {
    if (tab >= 0 && tab < state.numOfTabs) {
      state.controller.jumpToPage(tab);
      state = state.copyWith(currentId: tab);
    }
  }

  void createTab({String? url, bool silent = false}) {
    state = state.copyWith(
        currentId: silent ? null : state.numOfTabs + 1,
        numOfTabs: state.numOfTabs + 1,
        tabNames: [...state.tabNames, 'Blank Page']);
    if (url != null)
      _ref.watch(tabProvider(state.currentId).notifier).goToUri(url);
  }

  void setTabName({required int idx, required String name}) {
    final newTabNames = state.tabNames;
    newTabNames[idx] = name;
    state = state.copyWith(tabNames: newTabNames);
  }

  void removeTab(int idx) {
    final newTabsNames = state.tabNames..removeAt(idx);
    state =
        state.copyWith(numOfTabs: state.numOfTabs - 1, tabNames: newTabsNames);
  }
}

final tabListProvider = StateNotifierProvider<TabListNotifier, TabsState>(
    (ref) => TabListNotifier(ref));

class TabListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Consumer(
            builder: (context, watch, child) {
              final tabsState = watch(tabListProvider);
              final listOfTabs = watch(tabListProvider).tabNames;
              return Column(
                children: [
                  Text('GEMPODS',
                      style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white,
                          fontSize: 23)),
                  for (var i = 0; i < tabsState.numOfTabs; i++)
                    Dismissible(
                      onDismissed: (_) {
                        watch(tabListProvider.notifier).removeTab(i);
                      },
                      key: UniqueKey(),
                      child: MaterialButton(
                          onPressed: () {
                            watch(tabListProvider.notifier).selectTab(i);
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            listOfTabs[i],
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                decoration: i == tabsState.currentId
                                    ? TextDecoration.underline
                                    : null),
                          )),
                    ),
                  MaterialButton(
                      onPressed: () {
                        watch(tabListProvider.notifier).createTab(
                            url: 'gemini://geminispace.info', silent: true);
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        '+',
                        style: TextStyle(color: Colors.white),
                      )),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class Strelka extends ConsumerWidget {
  @override
  Widget build(BuildContext context, watch) {
    final tabsCount = watch(tabListProvider).numOfTabs;
    final controller = watch(tabListProvider).controller;
    return PageView.builder(
      itemBuilder: (context, index) {
        return Tab(
          index,
          initialUrl: 'gemini://geminispace.info',
        );
      },
      itemCount: tabsCount,
      controller: controller,
    );
  }
}

class Tab extends StatefulWidget {
  Tab(this._idx, {this.initialUrl}) : super(key: ValueKey(_idx));
  final int _idx;
  final String? initialUrl;

  @override
  _TabState createState() => _TabState();
}

class _TabState extends State<Tab> with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();

  @override
  void initState() {
    if (widget.initialUrl != null)
      context
          .read(tabProvider(widget._idx).notifier)
          .goToUri(widget.initialUrl!);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: WillPopScope(
        onWillPop: () async {
          return context.read(tabProvider(widget._idx).notifier).goBack();
        },
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 60,
                floating: true,
                backgroundColor: Colors.black,
                automaticallyImplyLeading: false,
                title: ProviderListener(
                  provider: tabProvider(widget._idx),
                  onChange: (context, AsyncValue<GeminiPage> value) {
                    value.whenData((value) {
                      _controller.text = value.url;
                      context
                          .read(tabListProvider.notifier)
                          .setTabName(idx: widget._idx, name: value.url);
                    });
                  },
                  child: Row(
                    children: [
                      Flexible(
                        flex: 6,
                        child: Container(
                          padding: const EdgeInsets.only(left: 8),
                          child: SizedBox(
                            height: 60,
                            child: TextField(
                              controller: _controller,
                              style: const TextStyle(
                                  color: Colors.white, fontFamily: 'monospace'),
                              onSubmitted: (url) {
                                context
                                    .read(tabProvider(widget._idx).notifier)
                                    .goToUri(url);
                              },
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        child: IconButton(
                          icon: Icon(
                            Icons.grid_3x3,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(context).pushNamed('/list');
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: Content(widget._idx))
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}

class Content extends ConsumerWidget {
  final textStyle = TextStyle(color: Colors.white, fontFamily: 'monospace');
  final int _idx;
  Content(this._idx);
  @override
  Widget build(BuildContext context, watch) {
    final content = watch(tabProvider(_idx));
    return content.when(
        data: (data) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: SelectableText.rich(TextSpan(
                children: data.content.map((e) {
              if (e is Paragraph)
                return TextSpan(
                    text: '  ' + e.content + '\n', style: textStyle);
              if (e is HeaderElement)
                return TextSpan(
                    text: (e.level == 1 ? '# ' : '## ') + e.content,
                    style: TextStyle(
                        fontSize: e.level == 1 ? 24 : 18,
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold));
              if (e is Link)
                return TextSpan(
                    text: '\n' + e.link + '\n',
                    style: TextStyle(
                        decoration: TextDecoration.underline,
                        fontFamily: 'monospace',
                        color: Colors.white),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        context
                            .read(tabProvider(_idx).notifier)
                            .goToUri(e.address);
                      });
              return TextSpan(
                text: '',
              );
            }).toList())),
          );
        },
        loading: () => Center(
            child: SizedBox(
                height: 50, width: 50, child: CircularProgressIndicator())),
        error: (err, stackTrace) => Text(err.toString()));
  }
}
