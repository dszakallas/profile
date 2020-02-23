---

title: 'Java, the bad parts: Recursive lambdas'
key: 2016-05-07-java-the-bad-parts-recursive-lambdas
tags:
  - Java
  - functional programming
  - rant

---
Have you ever tried to create a recursive lambda in Java?

You might ask why on earth would somebody do that. For you I have a
confession to begin with: I\'ve been spoiled. I\'ve been spoiled with
the overwhelming expressiveness of functional programming. I\'ve been
using Scala and JavaScript for more almost 2 years now, and that leaves
a trace. I think about problems differently than an average Java
developer does. Both Scala and JavaScript gives you the ability to
express your problems more or less functionally. Neither of them are
purely functional languages, but occupy a sweet spot to be fairly
convenient to use. But why do then I mess around in Java? Not for fun,
sure. I had a homework assignment for a university course which involved
writing a breadth first traversal component for a graph. During
traversal, you may inspect your current paths, and run some solver on it
that classifies it as good or bad, and if it\'s bad you have to bail out
with the level on which the bad path appeared and the path itself. It\'s
pretty straightforward right? I have a stream of trees, which starts
with an initial tree consisting only the root node, then I recursively
`flatMap` the tree\'s outward edges to get a tree of longer paths, at
every step I check if the new paths are bad\... \... so I need lists,
streams \... \... let\'s take a look at the standard Java collections.  

![OH GOD NO MEME](https://media.riffsy.com/images/d0a4caede6c27bb39ea426d82bbb2112/raw)

**No. Just simply no.**

So I started implementing my old own naive functional list. Guava
provides a friendlier interface for Java collections, but I didn\'t want
to involve additional dependencies, and also it would have solved my
need for functional lazy streams. (This is only a guess, I haven\'t
looked at Guava since 3 years.) Finally I\'m at the point: creating my
tree stream involved recursive lambdas. Let\'s take a look at a dummy
example with natural numbers. In Scala it\'s as simple as a cake:

```scala
def naturals: Stream[Int] = 0 #:: naturals.map(_ + 1)

naturals.take(5).foreach(println)
// 0
// 1
// 2
// 3
// 4
```

In Java I tried this:

```java
Function<Void, Stream<Integer>> n = (Void) -> Stream.cons(
   (Void _1) -> 0,
   (Void _1) -> n.andThen(x -> x.map(y -> y + 1)).apply(null));

Stream<Integer> naturals = n.apply(null);

naturals.take(5).foreach(x -> System.out.println(x));
```

This looks awful already, but even worse, it doesn\'t compile. Let\'s
see why it looks awful:

-   because it\'s Java?
-   Java doesn\'t let you have a variable in the same name in an inner
    scope as in an outer one, while in Scala and JavaScript this works
    and called shadowing. That is why I had to find another name than
    `x` in my `map` function.
-   I couldn\'t find a function type with no input arguments, I had to
    use `Function<Void, T>` instead. The `Void` class is a dummy class,
    that cannot be instantiated (`null` is the only valid value), so it
    acts like a `void` more or less.  That\'s why you will never need
    the value for a `Void`. So you can omit it right? Hold on. The same
    no redeclaration rule that we faced above holds for unnamed
    parameters. You cannot omit the name when an omitted name shadows
    another one omitted name. What the actual f\*ck??? How can a
    non-existent name even shadow another? Someone really screwed
    something up with this language.

![CLIENT EASTWOOD DISGUSTED
MEME](https://media.riffsy.com/images/0dcd3033a8ecaa55e41c93f9843ea2f3/raw)

And then, it doesn\'t compile.
It doesn\'t, because `n` may have been uninitialized at the time of use
in the lambda. The compiler is thinking it\'s smarter than me. I
understand it\'s a dangerous situation because if that lambda runs
before defining the outer function, I get a `NullPointerException`. But
I\'m clever enough not to do this. Why doesn\'t it allow me? So I don\'t
have to use this hack, which circumvents this foul attempt to stop me:

```java
@SuppressWarnings("rawtypes")
final Function[] _n = { null };
@SuppressWarnings("unchecked")
Function<Void, Stream<Integer>> __n = _n[0];
__n = (Void) -> Stream.cons(
   (Void _0) -> 0,
   (Void _0) -> {
     @SuppressWarnings("unchecked")
     Stream<Integer> f = ((Function<Void, Stream<Integer>>)_n[0])
        .andThen(x -> x.map(y -> y + 1)).apply(null);
     return f;
   }
 );
_n[0] = __n;

Stream<Integer> naturals = __n.apply(null);

naturals.take(5).foreach(x -> System.out.println(x));
// 0
// 1
// 2
// 3
// 4
```

Beautiful. Luckily you can hide this ugliness if you abstract it:

```java
static <U> Stream<U> recursively(Function<Void, U> base, Function<U, U> next) {
 @SuppressWarnings("rawtypes")
 final Function[] _n = { null };
 @SuppressWarnings("unchecked")
   Function<Void, Stream<U>> __n = _n[0];
   __n = (Void) -> Stream.cons(
     base,
     (Void _0) -> {
       @SuppressWarnings("unchecked")
       Stream<U> f = ((Function<Void, Stream<U>>)_n[0]).andThen(x -> x.map(y -> next.apply(y))).apply(null);
         return f;
       }
     );
   _n[0] = __n;
   return __n.apply(null);
```

The lesson was learned and it is: Java makes you life harder than it
should be when you write functional code. Hard enough to don\'t even
bother. [Source for the List and Stream classes is
here](https://github.com/dszakallas/util)    
