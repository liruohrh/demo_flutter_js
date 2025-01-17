import 'package:demo_flutter_js/coder/index.dart';
import 'package:flutter/material.dart';
import 'model.reflectable.dart';
import 'js.dart';

void main() {
  initializeReflectable();

  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_js Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'flutter_js Demo Home Page'),
    );
  }
}
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}
class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const CoderPage(),
                ),
              ),
              child: const Text('edit and evaluate js in app'),
            ),
            ElevatedButton(
              child: const Text('basic usage'),
              onPressed: ()  {
                 testQuickJS();
              },
            ),
            ElevatedButton(
              child: const Text('module'),
              onPressed: ()  {
                testModule();
              },
            ),
            ElevatedButton(
              child: const Text('Promise'),
              onPressed: ()  {
                testPromise();
              },
            ),
            ElevatedButton(
              child: const Text('Extra JS API'),
              onPressed: ()  {
                testExtraJSAPI();
              },
            ),
            ElevatedButton(
              child: const Text('proxy object'),
              onPressed: ()  {
                testProxy();
              },
            ),
          ],
        ),
      )
    );
  }
}
