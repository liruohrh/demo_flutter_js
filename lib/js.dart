import 'dart:developer';
import 'dart:io';

import 'package:demo_flutter_js/model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/javascriptcore/jscore_runtime.dart';
import 'package:reflectable/mirrors.dart';

final javaScriptRuntime = getJavascriptRuntime();

reflectableInvokeFunc(ClassMirror target, key, args) {
  return target.invoke(key, args);
}

reflectableInvokeGetterFunc(ClassMirror target, key) {
  return target.invokeGetter(key);
}

reflectableInvokeSetterFunc(ClassMirror target, key, value) =>
    target.invokeSetter(key, value);

reflectableInstanceInvokeFunc(InstanceMirror target, key, args) {
  print("dart: invoke $key, args=$args");
  return target.invoke(key, args);
}

reflectableInstanceInvokeGetterFunc(InstanceMirror target, key) {
  return target.invokeGetter(key);
}

reflectableInstanceInvokeSetterFunc(InstanceMirror target, key, value){
  return target.invokeSetter(key, value);
}

getProxyArgs(Type type,
    [List<dynamic> constructorPositionArgs = const [],
    Map<Symbol, dynamic> constructorNameArgs = const {}]) {
  final classMirror = reflector.reflectType(Model) as ClassMirror;
  return [
    classMirror.simpleName,
    classMirror,
    classMirror.staticMembers.values
        .where((value) {
          if (!value.isGetter) return false;
          var variableMirror =
              classMirror.declarations[value.simpleName] as VariableMirror;
          return !variableMirror.isConst && !variableMirror.isFinal;
        })
        .map((value) => value.simpleName)
        .toList(),
    classMirror.instanceMembers.values
        .where((value) {
          if (!value.isGetter ||
              value.simpleName == "hashCode" ||
              value.simpleName == "runtimeType") return false;
          var variableMirror =
              classMirror.declarations[value.simpleName] as VariableMirror;
          return !variableMirror.isConst && !variableMirror.isFinal;
        })
        .map((value) => value.simpleName)
        .toList(),
    (){
    return classMirror.newInstance(
        "", constructorPositionArgs, constructorNameArgs);
    },
    reflectableInvokeFunc,
    reflectableInvokeGetterFunc,
    reflectableInvokeSetterFunc,
    reflector.reflect,
    reflectableInstanceInvokeFunc,
    reflectableInstanceInvokeGetterFunc,
    reflectableInstanceInvokeSetterFunc,
  ];
}

forJsFunc(String code, List<dynamic> args, {String? sourceUrl}) async {
  var jsFunc = javaScriptRuntime.evaluate(code, sourceUrl: sourceUrl).rawResult
      as JSInvokable;
  try {
    var result = jsFunc.invoke(args);
    if(result is Future){
      await javaScriptRuntime.handlePromise(JsEvalResult(result.toString(), result));
    }
  } finally {
    JSRef.freeRecursive(jsFunc);
  }
}

toJsImmediateFunc(String funcBody) => "(async ()=>{\n$funcBody\n})()";

/*
flutter: ========================================
flutter: start use
flutter: set f1
flutter: get f1
flutter: "model.f1=sb"
flutter: get $hello
flutter: dart: invoke hello, args=[xxx]
flutter: "model.$hello: hello xxx[sb]"
flutter: get $sHello
flutter: "Model.$sHellosHello sb"
flutter: get $$newDartObject
flutter: set nested
flutter: get $$setProxy
flutter: get nested
flutter: get nested
flutter: set f1
flutter: get then
flutter: get f1
flutter: get nested
flutter: get f1
flutter: get nested
flutter: 1.  stringResult={f1: sb, nested: {f1: nestedSB, nested: null}}
flutter: 1.  rawResult=Instance of 'Future<dynamic>'
flutter: ========================================
flutter: get f1
flutter: model.f1=sbsbsb
flutter: set f1
flutter: get $hello
flutter: dart: invoke hello, args=[xxx]
flutter: model.$hello=hello xxx[sb2]
flutter: get $$get
flutter: 2.  Model{f1: sb2, nested: null}
flutter: 2.  Model{f1: sb2, nested: null}
 */
testProxy() async {
  print("=" * 40);
  //init
  const proxyJsKey = "assets/js/proxy.js";
  var proxyJSString = await rootBundle.loadString(proxyJsKey);
  await forJsFunc(proxyJSString, getProxyArgs(Model), sourceUrl: proxyJsKey);

  // print(javaScriptRuntime.evaluate("this.Model").stringResult);
  print("start use");


  //1. JS use Dart class
  var result = javaScriptRuntime.evaluate(toJsImmediateFunc("""
  model = Model();
  model.f1 = 'sb';
  console.log(JSON.stringify(`model.f1=\${model.f1}`));
  console.log(JSON.stringify(`model.\$hello: \${model.\$hello('xxx')}`));
  console.log(JSON.stringify(`Model.\$sHello\${Model.\$sHello('sb')}`));
  
  model2 = Model.\$\$newDartObject();
  model.nested = model2;
  model.\$\$setProxy('nested', Model(model.nested));
  model.nested.f1 = 'nestedSB';
  return model;
  """), sourceUrl: "use1.js");
  result = await javaScriptRuntime.handlePromise(result);
  print("1.  stringResult=${result.stringResult.toString()}");
  print("1.  rawResult=${result.rawResult}");

  //2. JS use Dart object reference(for Dart#Map-JS#Object)
  final model = Model("sbsbsb");
  await forJsFunc("(key, value) => {this[key]=Model(value);}", ["model", model], sourceUrl: "global.js");
  print("=="*20);
  result = javaScriptRuntime.evaluate("""
  console.log(`model.f1=\${model.f1}`);
  model.f1 = 'sb2';
  console.log(`model.\$hello=\${model.\$hello('xxx')}`);
  model.\$\$get();
  """);
  print("2.  ${result.rawResult}");
  print("2.  ${result.stringResult}");
}

void testRuntimeCache() {
  javaScriptRuntime.localContext['globalThis'] =
      javaScriptRuntime.evaluate("(key, value)=>this[key]=value");
  javaScriptRuntime.dartContext['dataInDart'] = 'xxxx';
}

/*
1.onMessage(ConsoleLog): console {log, warn, error}, args: [].join(' ')
2.onMessage(SetTimeout): setTimeout(handler, milis)
3.XMLHttpRequest and fetch
 */
void testExtraJSAPI() async {
  print("=" * 40);
  javaScriptRuntime.onMessage(
      "print", (str) => print("${str.runtimeType}, ${str.toString()}"));
  print("${"=" * 20} channel: ");
  javaScriptRuntime.evaluate("""
sendMessage('print', JSON.stringify('\t\tsend message to channel of print'));
console.log('\t\tconsole.log');
console.warn('\t\tconsole.warn');
console.error('\t\tconsole.error');

setTimeout(()=>{
  console.log('\t\tsetTimeout(handler, 2000)');
}, 2000);
""");
  await Future.delayed(const Duration(milliseconds: 2000));

  print("${"=" * 20} xhr: ");
  var xhrResult = javaScriptRuntime.evaluate("""
new Promise((resolve, reject)=>{
  xtr = new XMLHttpRequest();
  xtr.open('GET','https://bilibili.com/', true);
  xtr.onload = ()=>{
    resolve(xtr.status);
  };
  xtr.onerror = ()=>{
    reject(`xhr error, status=\${xtr.status}`);
  };
  xtr.send();
})
""");
  xhrResult = await javaScriptRuntime.handlePromise(xhrResult);
  print("xhrResult: ${xhrResult.stringResult}");

  print("${"=" * 20} fetch: ");
  var fetchResult = javaScriptRuntime.evaluate("""
fetch('https://bilibili.com/anime/', {method: 'GET'})
.then(response =>  response.status)
.catch(error => console.error('\t\t', 'fetch err=', error))
""");
  fetchResult = await javaScriptRuntime.handlePromise(fetchResult);
  print("fetchResult: ${fetchResult.stringResult}");
}

/*
当返回Promise时，rawResult必定是Future(即使engine.handlerPromise后)，而其stringResult才是结果
*/
void testPromise() async {
  print("=" * 40);
  print("${"=" * 20} testPromise ${"=" * 20}");
  //isPromise=false
  var promiseResult = javaScriptRuntime.evaluate("""
new Promise((resolve, reject)=>{
  setTimeout(()=>{
    resolve("promiseResult");
  }, 2000);
});
""");
  promiseResult = await javaScriptRuntime.handlePromise(promiseResult);
  printJsEvalResult(promiseResult,
      prefix: "testPromise: after await promiseResult");
}

void printJsEvalResult(JsEvalResult jsEvalResult, {String prefix = ""}) {
  print("${prefix} "
      ", stringResult=${jsEvalResult.stringResult}"
      ", rawResult=${jsEvalResult.rawResult}"
      ", isPromise=${jsEvalResult.isPromise}");
}

/*
1. 执行ES Module仅仅是加载模块，执行GLOBAL Script能返回结果
2. GLOBAL Script可以导入模块(但因为不是模块因此只能使用import函数而不是import语句)
 */
void testModule() async {
  final quickJsRuntime = javaScriptRuntime as QuickJsRuntime2;
  print("=" * 40);
  print("执行es module(作用域是模块, 无返回值)"
      "\n单纯的js脚本(默认，作用域是全局, 最后一句是返回值)");
  final utilModuleResult = quickJsRuntime.evaluate("""
export const a = 1; 
a;
  """, name: "util.js", evalFlags: JSEvalFlag.MODULE);
  final mainResult = quickJsRuntime.evaluate("""
import {a} from "util.js"; 
a+1;
""", name: "main.js", evalFlags: JSEvalFlag.MODULE);

  final scriptResult = quickJsRuntime.evaluate("1+1;",
      name: "script.js", evalFlags: JSEvalFlag.GLOBAL);
  var scriptUseModuleResult = quickJsRuntime.evaluate("""
import("util.js")
.then(utilM=>utilM.a+1); 
""", name: "scriptUseModule.js", evalFlags: JSEvalFlag.GLOBAL);
  scriptUseModuleResult =
      await quickJsRuntime.handlePromise(scriptUseModuleResult);

  print("""Look Result
MODULE: es module
  mainResult=${mainResult.stringResult},
  utilModuleResult=${utilModuleResult.stringResult}
GLOBAL: script
  scriptResult=${scriptResult.stringResult}
  scriptUseModuleResult=${scriptUseModuleResult.stringResult}
""");
}

/*
1.对于quickJs：可以执行
  es module(作用域是模块, 无返回值)
  单纯的js脚本(默认，作用域是全局, 最后一句是返回值)
2.quickJsRuntime就一个上下文对象，因此不推荐用const、let，但是函数定义是可以重复声明的（JS原本就可以这样，会覆盖之前的）
*/
void testQuickJS() async {
  print("=" * 40);
  print("${"=" * 20} testQuickJS ${"=" * 20}");
  final result = javaScriptRuntime.evaluate("""
      console.log('1.变量、对象字面量、对象解构、数组、数组解构。');
      var a = 1;
      console.log(a);
      
      var obj1 = {
        a1: 'a1'
      };
      console.log(JSON.stringify(obj1));
      var obj2 = {
        ...obj1
      };
      console.log(JSON.stringify(obj2));

      var arr1 = [1,2,3];
      console.log(JSON.stringify(arr1));
      var arr2 = [...arr1, 4];
      console.log(JSON.stringify(arr2));
      "Ok";
  """);
  print("""2.flutter_js 封装的JsEvalResult  
  isError=[${result.isError}],  
  isPromise=[${result.isPromise}], 
  rawResult=[${result.rawResult}], 
  stringResult=[${result.stringResult}]""");

  print("testQuickJS: 只有有一个上下文，因此不推荐用const、let");
  printJsEvalResult(
      javaScriptRuntime
          .evaluate("const aaa1 = 11; console.log(`aaa1=\${aaa1}`);"),
      prefix: "const");
  printJsEvalResult(
      javaScriptRuntime
          .evaluate("const aaa1 = 12; console.log(`aaa1=\${aaa1}`);"),
      prefix: "const");
  printJsEvalResult(
      javaScriptRuntime
          .evaluate("let aaa2 = 21; console.log(`aaa2=\${aaa2}`);"),
      prefix: "let");
  printJsEvalResult(
      javaScriptRuntime
          .evaluate("let aaa2 = 22; console.log(`aaa2=\${aaa2}`);"),
      prefix: "let");
  javaScriptRuntime.evaluate("var aaa3 = 31; console.log(`aaa3=\${aaa3}`);");
  javaScriptRuntime.evaluate("var aaa3 = 32; console.log(`aaa3=\${aaa3}`);");
  javaScriptRuntime.evaluate("aaa4 = 41; console.log(`aaa4=\${aaa4}`);");
  javaScriptRuntime.evaluate("aaa4 = 42; console.log(`aaa4=\${aaa4}`);");
}

JavascriptRuntime getJsRuntime({
  bool forceJavascriptCoreOnAndroid = false,
  bool xhr = true,
  Map<String, dynamic>? extraArgs = const {},
}) {
  moduleHandler(String module) {
    log("load module $module", name: "APP");
    return "export const a";
  }

  JavascriptRuntime runtime;
  if ((Platform.isAndroid && !forceJavascriptCoreOnAndroid)) {
    int stackSize = extraArgs?['stackSize'] ?? 1024 * 1024;
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
