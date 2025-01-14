package thx.core;

#if macro
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Context;
import haxe.macro.TypedExprTools;
import thx.core.Arrays;
import thx.core.Ints;
#end

/**
`Nulls` provides extension methods that help to deal with nullable values.

Note that the parenthesis wrap the entire chain of identifiers. That means that a null check will be performed for each identifier in the chain.

Identifiers can also be getters and methods (both are invoked only once and only if the check reaches them). `Python` seems to struggle with some native methods like methods on strings.
**/
class Nulls {
/**
`isNull` checks if a chain of identifier is null at any point.
**/
  macro public static function isNull(value : Expr)
    return macro ($e{Nulls.opt(value)} == null);

/**
It traverses a chain of dot/array identifiers and it returns the last value in the chain or null if any of the identifiers is not set.

```haxe
var o : { a : { b : { c : String }}} = null;
trace((o.a.b.c).opt()); // prints null
var o = { a : { b : { c : 'A' }}};
trace((o.a.b.c).opt()); // prints 'A'
```
**/
  #if !macro macro #end public static function opt(value : Expr) {
    var ids  = [];
    function traverse(e : haxe.macro.Type.TypedExpr) switch e.expr {
      case TArray(a, e):
        traverse(a);
        var index = TypedExprTools.toString(e, true);
        ids.push('[$index]');
      case TConst(TThis):
        ids.push('this');
      case TConst(TInt(index)):
        ids.push('$index');
      case TLocal(o):
        ids.push(o.name);
      case TField(f, v):
        traverse(f);
        switch v {
          case FAnon(id):
            ids.push(id.toString());
          case FInstance(_, n):
            ids.push(n.toString());
          case _:
            throw 'invalid expression $e';
        }
      case TParenthesis(p):
        traverse(p);
      case TCall(e, el):
        traverse(e);
        var a = el.map(TypedExprTools.toString.bind(_, true)).join(", ");
        ids[ids.length - 1] += '($a)';
      case TBlock(_):
        if(Context.defined("python"))
          Context.error("Nulls.opt doesn't support some method calls on Python", value.pos);
        var s = TypedExprTools.toString(e, true);
        trace(s);
        ids.push(s);
      case _:
        throw 'invalid expression $e';
    }

    traverse(Context.typeExpr(value));
    var first = ids.shift(),
        temps = ['_0 = $first'].concat(Arrays.mapi(ids, function(_, i) return '_${i+1}')).join(', '),
        buf   = '{\n  var ${temps};\n  null == _0 ? null :',
        path;
    for(i in 0...ids.length) {
      var id = ids[i];
      if(id.substring(0, 1) == '[') {
        path = id;
      } else {
        path = '.$id';
      }
      buf += '\n    (null == (_${i+1} = _$i$path) ? null :';
    }
    buf += ' _${ids.length}' + Strings.repeat(')', ids.length) + ';\n}';
    return Context.parse(buf , value.pos);
  }

/**
Like `opt` but allows an `alt` value that replaces a `null` occurrance.

```haxe
var s : String = null;
trace(s.or('b')); // prints 'b'
s = 'a';
trace(s.or('b')); // prints 'a'

// or more complex
var o : { a : { b : { c : String }}} = null;
trace((o.a.b.c).or("B")); // prints 'B'
var o = { a : { b : { c : 'A' }}};
trace((o.a.b.c).or("B")); // prints 'A'
```

Notice that the subject `value` must be a constant identifier (eg: fields, local variables, ...).
**/
  macro public static function or<T>(value : ExprOf<Null<T>>, alt : ExprOf<T>)
    return macro { var t = $e{Nulls.opt(value)}; t != null ? t : $e{alt}; };

/**
`notNull` is the negation of `isNull`.
**/
  macro public static function notNull(value : Expr)
    return macro ($e{Nulls.opt(value)} != null);
}