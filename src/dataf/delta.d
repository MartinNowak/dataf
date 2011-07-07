module dataf.delta;

import dataf.propspecs;
import std.bitmanip;

struct Delta(T) {
  void add(string name, T2)(T2 t) if(is(T2 : PropSpecs!(T).typeOf!(name))) {
    enum idx = PropSpecs!(T).indexOf!(name)();
    assert(data.length == 0, "multiple changes currently unsupported");
    PropSpecs!(T).Types[idx] converted = t;
    data.length = converted.alignof;
    data[0 .. converted.sizeof] = (cast(void*)&converted)[0 .. converted.sizeof];
    if (mask.length <= idx)
      mask.length = idx + 1;
    mask[idx] = true;
  }

  void apply(ref T elem) {
    foreach(idx, TF; PropSpecs!(T).Types) {
      if (mask[idx]) {
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
  struct A {
    @property float val() { return _val; }
    @property void val(float v) { _val = v; }
    @property void val(double v) { _val = v; }

    @property auto ref float val2() { return _val2; }
    float _val, _val2 = 0.f;
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
}
