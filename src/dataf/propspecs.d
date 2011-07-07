module dataf.propspecs;

import std.traits, std.typetuple;

struct PropSpecs(T) {
  enum names = propNames!T();
  alias propTypes!(T, names) Types;
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

template propTypes(T, alias names) {
  static if (names.length == 0)
    alias TypeTuple!() propTypes;
  else
    alias TypeTuple!(propType!(T, names[0]), propTypes!(T, names[1..$])) propTypes;
}

template propType(T, string name) {
  alias fromOverloads!(__traits(getOverloads, T, name)) propType;
}

template fromOverloads(Funcs...) if (Funcs.length == 0) {
  static assert(0, "can't determine property type");
}

template fromOverloads(Funcs...) if (Funcs.length == 1) {
  static if (is(ParameterTypeTuple!(Funcs[0]) PT)) {
    static if (PT.length == 0)
      alias ReturnType!(Funcs[0]) fromOverloads;
    else
      alias PT[0] fromOverloads;
  } else {
    static assert(0, "can't determine property type");
  }
}

template fromOverloads(Funcs...) if (Funcs.length > 1) {
  static if (is(CommonType!(fromOverloads!(Funcs[0]), fromOverloads!(Funcs[1 .. $])) CT)) {
    static if (is(CT == void))
      static assert(0, "can't determine property type");
    else
      alias CT fromOverloads;
  } else {
    static assert(0, "can't determine property type");
  }
}

unittest {
  struct A {
    @property float val() { return _val; }
    @property void val(float v) { _val = v; }
    @property void val(double v) { _val = v; }

    @property auto ref A val2(float v) { _val = v; return this; }
    float _val;
  }

  enum specsA = PropSpecs!A();
  static assert(specsA.names.length == 2);
  static assert(specsA.names == ["val", "val2"]);
  static assert(is(specsA.Types == TypeTuple!(double, float)));

  class B {
    @property float val() { return _val; }
    @property void val(float v) { _val = v; }

    abstract @property B self() @safe pure nothrow;
    float _val;
  }

  enum specsB = PropSpecs!B();
  static assert(specsB.names.length == 2);
  static assert(specsB.names == ["val", "self"]);
  static assert(is(specsB.Types == TypeTuple!(float, B)));

  interface C {
    @property float val();
    @property void val(float v);
    final @property void setSome(double a) @trusted;
  }

  enum specsC = PropSpecs!C();
  static assert(specsC.names.length == 2);
  static assert(specsC.names == ["val", "setSome"]);
  static assert(is(specsC.Types == TypeTuple!(float, double)));
}
