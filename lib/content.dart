import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strelka/net.dart';

final tabProvider = StateNotifierProvider<TabNotifier, AsyncValue<Page>>(
    (ref) => TabNotifier(ref));

abstract class ContentElement {}

class Paragraph implements ContentElement {
  final String content;
  Paragraph(this.content);
}

class Link implements ContentElement {
  final String address;
  final String link;
  Link({required this.address, required this.link});
}

class Page {
  final List<ContentElement> content;
  Page(this.content);

  factory Page.parse(String rawText) {
    final lines = rawText.split('\n');
    final content = <ContentElement>[];

    for (final line in lines) {
      if (line.startsWith('=>')) {
        final linkComponents = line.split(' ');
        content.add(Link(
            address: linkComponents[1],
            link: linkComponents.sublist(2).join(' ')));
      } else {
        content.add(Paragraph(line));
      }
    }

    return Page(content);
  }
}

class HistoryEntry {
  final DateTime time;
  final Uri address;

  HistoryEntry(this.time, this.address);
}

class TabNotifier extends StateNotifier<AsyncValue<Page>> {
  final List<HistoryEntry> _history = [];
  final ProviderReference _ref;

  TabNotifier(this._ref) : super(AsyncValue.loading());

  void goToUri(String url) async {
    state = AsyncValue.loading();

    var uri = Uri.parse(url);
    if (!uri.hasScheme) uri = uri.replace(scheme: 'gemini://');
    if (!uri.hasAuthority) uri = uri.replace(host: _history.last.address.host);

    try {
      final content = await (_ref.watch(geminiProvider(uri).future));
      state = AsyncValue.data(Page.parse(content));
      _history.add(HistoryEntry(DateTime.now(), uri));
    } catch (e) {
      state = AsyncValue.error('a');
    }
  }

  bool goBack() {
    if (_history.isEmpty) return true;
    final prev = _history[_history.length - 2];
    _history.removeLast();
    goToUri(prev.address.toString());
    return false;
  }
}
