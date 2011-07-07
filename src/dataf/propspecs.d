module dataf.propspecs;

import std.traits;

struct PropSpecs(T) {
  enum names = propNames!T();
}

private:

alias FunctionAttribute FA;

string[] propNames(T)() {
  string[] res;
  foreach(name; __traits(allMembers, T)) {
    static if (is(FunctionTypeOf!(__traits(getMember, T, name)) FT))
      static if (functionAttributes!(FT) & FA.PROPERTY)
        res ~= name;
  }
  return res;
}

unittest {
  struct A {
    @property float val() { return _val; }
    @property void val(float v) { _val = v; }

    @property auto ref A val2(float v) { _val = v; return this; }
    float _val;
  }

  enum specsA = PropSpecs!A();
  static assert(specsA.names.length == 2);
  static assert(specsA.names == ["val", "val2"]);

  class B {
    @property float val() { return _val; }
    @property void val(float v) { _val = v; }

    abstract @property B self() @safe pure nothrow;
    float _val;
  }

  enum specsB = PropSpecs!B();
  static assert(specsB.names.length == 2);
  static assert(specsB.names == ["val", "self"]);

  interface C {
    @property float val();
    @property void val(float v);
    final @property void setSome(double a) @trusted;
  }

  enum specsC = PropSpecs!C();
  static assert(specsC.names.length == 2);
  static assert(specsC.names == ["val", "setSome"]);
}
