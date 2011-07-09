module dataf.delta;

import dataf.propspecs;
import std.bitmanip;

template needsDelta(T) {
  enum needsDelta = is(T == struct) || is(T == class) || is(T == interface);
}

template maybeDelta(T) {
  static if(needsDelta!T)
    alias Delta!T maybeDelta;
  else
    alias T maybeDelta;
}

struct Delta(T) {
  void add(string name, T2)(T2 t)
    if (PropSpecs!(T).writeMask[PropSpecs!(T).indexOf!(name)()]
        && is(T2 : maybeDelta!(PropSpecs!(T).typeOf!(name)))) {
    enum idx = PropSpecs!(T).indexOf!(name)();
    assert(data.length == 0, "multiple changes currently unsupported");

    maybeDelta!(PropSpecs!(T).Types[idx]) converted = t;
    data.length = ((converted.sizeof + converted.alignof - 1) % converted.alignof) * converted.alignof;
    data[0 .. converted.sizeof] = (cast(void*)&converted)[0 .. converted.sizeof];
    if (mask.length <= idx)
      mask.length = idx + 1;
    mask[idx] = true;
  }

  void apply(ref T elem) {
    foreach(idx, TF; PropSpecs!(T).Types)
      static if (PropSpecs!(T).writeMask[idx])
        if (mask[idx]) {
          static if (needsDelta!TF) {
            (cast(Delta!TF*)data.ptr).apply(__traits(getMember, elem, PropSpecs!(T).names[idx]));
            data = data[0 .. (Delta!TF).alignof];
          } else {
            __traits(getMember, elem, PropSpecs!(T).names[idx]) = *cast(TF*)data.ptr;
            data = data[0 .. TF.alignof];
          }
        }
  }

private:
  BitArray mask;
  void[] data;
}

unittest {
  struct B {
    @property auto ref float val() { return _val; }
    float _val = 12.0f;
  }

  struct A {
    @property float val() { return _val; }
    @property void val(float v) { _val = v; }
    @property void val(double v) { _val = v; }

    @property auto ref float val2() { return _val2; }
    @property auto ref B valB() { return _b; }
    float _val, _val2 = 0.f;
    B _b;
  }

  A a;
  a.val = 0.f;
  assert(a.val == 0.f);
  auto delta = Delta!A();

  delta.add!("val")(2.0f);
  delta.apply(a);
  assert(a.val == 2.f);
  assert(a.val2 == 0.f);

  Delta!A delta2;

  delta2.add!("val2")(2.0f);
  delta2.apply(a);
  assert(a.val == 2.f);
  assert(a.val2 == 2.f);

  a.val = 0.0f; a.val2 = 0.0f;
  assert(a.val == 0.f);
  assert(a.val2 == 0.f);

  delta2 = delta;
  delta2.apply(a);
  assert(a.val == 2.f);
  assert(a.val2 == 0.f);

  Delta!B deltaB;
  deltaB.add!("val")(13.f);
  Delta!A deltaInB;
  deltaInB.add!("valB")(deltaB);
  assert(a.valB.val == 12.f);
  deltaInB.apply(a);
  assert(a.valB.val == 13.f);
}
