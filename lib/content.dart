import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strelka/net.dart';

final tabProvider =
    StateNotifierProvider.family<TabNotifier, AsyncValue<GeminiPage>, int>(
        (ref, idx) => TabNotifier(ref));

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

class HeaderElement implements ContentElement {
  final String content;
  final int level;

  HeaderElement({required this.content, required this.level});
}

class GeminiPage {
  final String url;
  final List<ContentElement> content;
  GeminiPage({required this.content, required this.url});

  GeminiPage.empty()
      : content = const [],
        url = '';

  factory GeminiPage.parse(List<String> lines, String url) {
    final content = <ContentElement>[];

    for (final line in lines) {
      if (line.startsWith('=>')) {
        final linkComponents = line.split(RegExp('\\s+'));
        content.add(Link(
            address: linkComponents[1],
            link: linkComponents.sublist(2).join(' ')));
        continue;
      } else {
        if (line.startsWith('##')) {
          content
              .add(HeaderElement(content: line.replaceAll('#', ''), level: 2));
          continue;
        }
        if (line.startsWith('#')) {
          content
              .add(HeaderElement(content: line.replaceAll('#', ''), level: 1));
          continue;
        }
        content.add(Paragraph(line));
      }
    }

    return GeminiPage(content: content, url: url);
  }
}

class HistoryEntry {
  final DateTime time;
  final Uri address;

  HistoryEntry(this.time, this.address);
}

class TabNotifier extends StateNotifier<AsyncValue<GeminiPage>> {
  final List<HistoryEntry> _history = [];
  final ProviderReference _ref;

  TabNotifier(this._ref) : super(AsyncValue.data(GeminiPage.empty()));

  void goToUri(String url, {bool ignoreHistory = false}) async {
    state = AsyncValue.loading();

    var uri = Uri.parse(url);
    if (!uri.hasAuthority) {
      var lastAddress = _history.last.address.toString();
      if (!url.startsWith('/')) uri = Uri.parse('/$url');
      if (lastAddress.endsWith('/'))
        lastAddress = lastAddress.substring(0, lastAddress.length - 1);
      uri = Uri.parse((lastAddress + url));
    }
    if (!uri.hasScheme) uri = uri.replace(scheme: 'gemini');

    try {
      final content = await (_ref.watch(geminiProvider(uri).future));
      final lines = content.split('\n');
      final header = lines.first;
      final statusCode = int.parse(header.substring(0, 3));
      if (statusCode >= 20 && statusCode < 30) {
        state = AsyncValue.data(
            GeminiPage.parse(lines.skip(1).toList(), uri.toString()));
        if (!ignoreHistory) _history.add(HistoryEntry(DateTime.now(), uri));
      }
      if (statusCode >= 30 && statusCode < 40) {
        final elements = header.split(RegExp('\\s+'));
        goToUri(elements[1].trim());
      }
      if (statusCode >= 40) {
        state = AsyncValue.error('Status Code $statusCode');
        if (!ignoreHistory) _history.add(HistoryEntry(DateTime.now(), uri));
      }
    } catch (e) {
      state = AsyncValue.error('Error loading page');
      if (!ignoreHistory) _history.add(HistoryEntry(DateTime.now(), uri));
    }
  }

  bool goBack() {
    if (_history.isEmpty || _history.length == 1) return true;
    final prev = _history[_history.length - 2];
    _history.removeLast();
    goToUri(prev.address.toString(), ignoreHistory: true);
    return false;
  }
}
