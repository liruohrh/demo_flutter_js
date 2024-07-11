import 'package:reflectable/reflectable.dart';

class Reflector extends Reflectable {
  const Reflector()
      : super(
            invokingCapability, newInstanceCapability, declarationsCapability);
}

const reflector = Reflector();

@reflector
class Model {
  String? f1;
  Model? nested;

  Model([this.f1]);

  String hello(String name) => "hello $name[$f1]";

  @override
  String toString() {
    return 'Model{f1: $f1, nested: $nested}';
  }

  static String sHello(String name)=> "sHello $name";
}
main(){
}