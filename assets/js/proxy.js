/**
 * Proxy:
 * obj.$$xx: JSObject property, not proxy Funtion  like this.
 * obj.$: DartObject function
 * obj.xxx: DartObject property
 *
 * obj.$$get(): return DartObject
 * obj.$$setProxy(nestedPropertyName, await objClazzConstructorFunc(obj.nestedProperty));
 * objClazzConstructorFunc.newDartObject(): new a dartObject
 */
function getProxy(
  target,
  reflectTarget,
  dartObject,
  properties,
  reflectableInvokeFunc,
  reflectableInvokeGetterFunc,
  reflectableInvokeSetterFunc
) {
  properties.forEach((key) => (target[key] = null));

  const nestedProxy = {};
  const newPrototype = {
    get() {
      return dartObject;
    },
    setProxy(key, proxy) {
      nestedProxy[key] = proxy;
    },
  };
  Object.setPrototypeOf(newPrototype, Object.getPrototypeOf(target));
  Object.setPrototypeOf(target, newPrototype);

  return new Proxy(target, {
    set: (target, key, value) => {
      console.log(`set ${key}`);
      if (key.startsWith("$$")) {
        target[key.substring(2)] = value;
        return;
      }
      reflectableInvokeSetterFunc(reflectTarget, `${key}=`, value);
    },
    get: (target, key) => {
      console.log(`get ${key}`);

      if (key.startsWith("$$")) {
        return target[key.substring(2)];
      }
      if (key.startsWith("$")) {
        return new Proxy(() => {}, {
          apply: (func, thisArg, argumentsList) => {
            return reflectableInvokeFunc(
              reflectTarget,
              key.substring(1),
              argumentsList
            );
          },
        });
      }
      if (!(key in target)) return null;

      if (nestedProxy[key]) return nestedProxy[key];
      return reflectableInvokeGetterFunc(reflectTarget, key);
    },
  });
}
(
  className,
  clazz,
  staticProperties,
  properties,
  newInstanceFunc,
  reflectableInvokeFunc,
  reflectableInvokeGetterFunc,
  reflectableInvokeSetterFunc,

  reflectableReflectFunc,
  reflectableInstanceInvokeFunc,
  reflectableInstanceInvokeGetterFunc,
  reflectableInstanceInvokeSetterFunc
) => {
  this[className] = function (obj) {
    const dartObject = obj ? obj : newInstanceFunc();
    const reflectInstance = reflectableReflectFunc(
      obj ? obj : newInstanceFunc()
    );

    return getProxy(
      {},
      reflectInstance,
      dartObject,
      properties,
      reflectableInstanceInvokeFunc,
      reflectableInstanceInvokeGetterFunc,
      reflectableInstanceInvokeSetterFunc
    );
  };
  const newPrototype = { newDartObject: newInstanceFunc };
  Object.setPrototypeOf(newPrototype, Object.getPrototypeOf(this[className]));
  Object.setPrototypeOf(
    this[className],
    getProxy(
      newPrototype,
      clazz,
      `Class ${className}`,
      staticProperties,
      reflectableInvokeFunc,
      reflectableInvokeGetterFunc,
      reflectableInvokeSetterFunc
    )
  );
};
