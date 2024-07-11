/*
 * @Description: example
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:51
 * @LastEditors: ekibun
 * @LastEditTime: 2020-12-02 11:28:06
 */

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_js/extensions/fetch.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/javascriptcore/jscore_runtime.dart';

import 'highlight.dart';
class CoderPage extends StatefulWidget {
  const CoderPage({super.key});

  @override
  State<StatefulWidget> createState() => _CoderPageState();
}

class MDartObject {
  String? p1;
  final int p2 = 100;
  MDartObject? nested;

  MDartObject([this.p1]);

  int add(int a1, int a2) {
    return p2 + a1 + a2;
  }

  static final Map<String, dynamic> JS_CLASS = {
    "className": "MDartObject",
    "new": () => MDartObject(),
    "getP1": (MDartObject mDartObject) {
      return mDartObject.p1;
    },
    "setP1": (MDartObject mDartObject, String p1) {
      mDartObject.p1 = p1;
    },
    "getNested": (MDartObject mDartObject) {
      return mDartObject.nested;
    },
    "setNested": (MDartObject mDartObject, MDartObject nested) {
      mDartObject.nested = nested;
    },
    "add": (MDartObject mDartObject, int a1, int a2) {
      return mDartObject.add(a1, a2);
    },
  };

  Map<String, dynamic> toJsObject() {
    return {
      "p1": p1,
      "setP1": (String val) {
        this.p1 = val;
      },
      "add": add
    };
  }
}

String defaultModuleHandler(String module) {
  log("load module $module", name: "APP");
  return "export const a";
}

final String PROXY_JS_OBJECT_JS_FUNC_STR = """
(handler) => {
    this[handler['className']] = function(obj){
        const opaque = obj ? obj : handler["new"]();  
        const target = {};
        const nestedProxy = {};
        Object.setPrototypeOf(target, {
            get(){
               //println(`JS: get \${JSON.stringify(proxyObj)}`);
               return opaque;
            },
            setProxy(key, proxy){
              nestedProxy[key] = proxy;
            }
        });
        Object.getOwnPropertyNames(handler)
        .filter(key=>key.startsWith("get"))
        .map(key=>{
            key=key.substr(3);
            return key[0].toLowerCase()+key.substr(1);
         })
        .forEach(key=>target[key]=null);
        const proxyObj = new Proxy(target, {
            set: (target, key, value) => {
                const setterName = `set\${key[0].toUpperCase()}\${key.substr(1)}`;
                const propSetter = handler[setterName];
                if(!propSetter){
                      return null;
                }
                //println(`JS: set \${key}=\${value} by \${setterName}`);
                //if(Array.isArray(value) && value.length === 2 && typeof value[1] === 'function'){
                //   nestedProxy[key] = value[1](value[0]);
                //   value = value[0];
                //}
                propSetter(opaque, value);
            },
            get: (target, key) => {
                if (key.startsWith("\$\$")) {
                   return target[key.substr(2)];
                }
                if (key.startsWith("\$")) {
                    const funcName=key.substr(1);
                    if(!handler[funcName]){
                      return null;
                    }
                    return new Proxy(() => {}, {
                        apply: function (func, thisArg, argumentsList) {
                            return handler[funcName](opaque, ...argumentsList);
                        }
                    });
                }
                if(nestedProxy[key])return nestedProxy[key];
                const getterName = `get\${key[0].toUpperCase()}\${key.substr(1)}`;
                const propGetter = handler[getterName];
                if(!propGetter){
                      return null;
                }
                //println(`JS: get \${key} by \${getterName}`);
                return propGetter(opaque);
            }
        });
        return proxyObj;
    }
}
  """;

JavascriptRuntime getJsRuntime(
    {bool forceJavascriptCoreOnAndroid = false,
    bool xhr = true,
    int stackSize = 1024 * 1024,
    String Function(String name) moduleHandler = defaultModuleHandler}) {
  JavascriptRuntime runtime;
  if ((Platform.isAndroid && !forceJavascriptCoreOnAndroid)) {
    runtime =
        QuickJsRuntime2(moduleHandler: moduleHandler, stackSize: stackSize);
  } else if (Platform.isWindows) {
    runtime = QuickJsRuntime2(moduleHandler: moduleHandler);
  } else if (Platform.isLinux) {
    runtime = QuickJsRuntime2(moduleHandler: moduleHandler);
  } else {
    runtime = JavascriptCoreRuntime();
  }
  if (xhr) runtime.enableFetch();
  runtime.enableHandlePromises();
  return runtime;
}

class _CoderPageState extends State<CoderPage> {
  String? resp;
  JavascriptRuntime? javaScriptRuntime;

  CodeInputController _controller = CodeInputController(
      text: '1+1;');

  _ensureEngine() async {
    if (javaScriptRuntime != null) return;
    javaScriptRuntime = getJsRuntime();

    final classDeclareFunc =
        javaScriptRuntime!.evaluate(PROXY_JS_OBJECT_JS_FUNC_STR).rawResult as JSInvokable;
    await classDeclareFunc.invoke([MDartObject.JS_CLASS]);
    JSRef.freeRecursive(classDeclareFunc);

    final setToGlobalObject =
        javaScriptRuntime!.evaluate("(key, val) => { this[key] = val; }").rawResult as JSInvokable;
    await setToGlobalObject.invoke([
      "println",
      (message) {
        print(message);
      }
    ]);
    await setToGlobalObject.invoke([
      "callDartTest",
      IsolateFunction((String type) {
        print("MDartObject.JS_CLASS = ${MDartObject.JS_CLASS}");
        switch (type) {
          case "number":
            return 1;
          case "string":
            return "string";
          case "bool":
            return true;
          case "map":
            return {
              "k1": "v1",
              "f1": (arg) {
                return "arg=${arg}";
              }
            };
          case "obj":
            return MDartObject("v1").toJsObject();
          case "dartObj":
            return MDartObject("v1");
        }
      }),
    ]);
    JSRef.freeRecursive(setToGlobalObject);
  }

  @override
  void dispose() {
    javaScriptRuntime?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("JS engine test"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton(
                      child: Text("evaluate"),
                      onPressed: () async {
                        await _ensureEngine();
                        try {
                          resp = javaScriptRuntime!.evaluate(_controller.text ?? '', sourceUrl: "<eval>")
                              .stringResult;
                        } catch (e) {
                          resp = e.toString();
                        }
                        setState(() {});
                      }),
                  TextButton(
                      child: Text("reset engine"),
                      onPressed: () async {
                        if (javaScriptRuntime == null) return;
                        javaScriptRuntime!.dispose();
                        javaScriptRuntime = null;
                      }),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.withOpacity(0.1),
              constraints: BoxConstraints(minHeight: 200),
              child: TextField(
                  autofocus: true,
                  controller: _controller,
                  decoration: null,
                  expands: true,
                  maxLines: null),
            ),
            SizedBox(height: 16),
            Text("result:"),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.green.withOpacity(0.05),
              constraints: BoxConstraints(minHeight: 100),
              child: Text(resp ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}
