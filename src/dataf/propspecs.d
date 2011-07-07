module dataf.propspecs;

import std.algorithm, std.traits, std.typetuple;

struct PropSpecs(T) {
  enum names = propNames!T();
  alias propTypes!(T, names) Types;
  enum readMask = propReadable!(T, names, Types)();
  enum writeMask = propWriteable!(T, names, Types)();

  static sizediff_t indexOf(string name)() {
    return names.countUntil(name);
  }

  template typeOf(string name) {
    alias Types[indexOf!(name)()] typeOf;
  }

  static assert(names.length == Types.length);
  static assert(Types.length == readMask.length);
  static assert(readMask.length == writeMask.length);
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

bool[] propReadable(T, alias names, Types...)() {
  bool[] res;
  res.length = Types.length;
  foreach(i, PT; Types) {
    static if (is(typeof(__traits(getMember, T, names[i])) : PT))
      res[i] = true;
    else
      res[i] = false;
  }
  return res;
}

bool[] propWriteable(T, alias names, Types...)() {
  bool[] res;
  res.length = Types.length;
  foreach(i, PT; Types) {
    static if (is(typeof({__traits(getMember, T.init, names[i]) = PT.init;})))
      res[i] = true;
    else
      res[i] = false;
  }
  return res;
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

    @property auto ref float val2() { return _val; }
    float _val;
  }

  enum specsA = PropSpecs!A();
  static assert(specsA.names.length == 2);
  static assert(specsA.names == ["val", "val2"]);
  static assert(is(specsA.Types == TypeTuple!(double, float)));
  static assert(specsA.readMask == [true, true]);
  static assert(specsA.writeMask == [true, true]);

  class B {
    @property void val(float v) { _val = v; }

    abstract @property B self() @safe pure nothrow;
    float _val;
  }

  enum specsB = PropSpecs!B();
  static assert(specsB.names.length == 2);
  static assert(specsB.names == ["val", "self"]);
  static assert(is(specsB.Types == TypeTuple!(float, B)));
  static assert(specsB.readMask == [false, true]);
  static assert(specsB.writeMask == [true, false]);

  interface C {
    @property float val();
    @property void val(float v);
    final @property void setSome(double a) @trusted;
  }

  enum specsC = PropSpecs!C();
  static assert(specsC.names.length == 2);
  static assert(specsC.names == ["val", "setSome"]);
  static assert(is(specsC.Types == TypeTuple!(float, double)));
  static assert(specsC.readMask == [true, false]);
  static assert(specsC.writeMask == [true, true]);
}
