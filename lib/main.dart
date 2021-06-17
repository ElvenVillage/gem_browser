import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strelka/content.dart';

void main() {
  runApp(ProviderScope(child: Strelka()));
}

class Strelka extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SafeArea(
          child: Scaffold(
              body: WillPopScope(
        onWillPop: () async {
          return context.read(tabProvider.notifier).goBack();
        },
        child: Container(
            color: Colors.black,
            child: Column(
              children: [
                SizedBox(
                  height: 60,
                  child: TextField(
                    onSubmitted: (url) {
                      context.read(tabProvider.notifier).goToUri(url);
                    },
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                Expanded(child: SingleChildScrollView(child: Content())),
              ],
            )),
      ))),
    );
  }
}

class Content extends ConsumerWidget {
  @override
  Widget build(BuildContext context, watch) {
    final content = watch(tabProvider);
    return content.when(
        data: (data) {
          return SelectableText.rich(TextSpan(
              children: data.content.map((e) {
            if (e is Paragraph)
              return TextSpan(
                  text: e.content + '\n',
                  style: TextStyle(color: Colors.white));
            if (e is Link)
              return TextSpan(
                  text: e.link + '\n',
                  style: TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      context.read(tabProvider.notifier).goToUri(e.address);
                    });
            return TextSpan(text: '', style: TextStyle(color: Colors.white));
          }).toList()));
        },
        loading: () => CircularProgressIndicator(),
        error: (err, stackTrace) => Text(err.toString()));
  }
}
