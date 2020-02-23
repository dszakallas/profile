---

title: Implementing Kleene logic two different ways in Scala
key: 2017-06-24-implementing-kleene-logic-two-different-ways-in-scala
tags:
  - generic programming
  - Scala
  - functional programming
---

Recently I've been writing a graph query engine at Fault Tolerant System
Research Group at uni. The frontend is Cypher, a language popularized
by Neo Technology shipped OOTB with their graph database Neo4j.

Recently Cypher is getting standardized in an open source and open government
initiative under the name openCypher; and other DB vendors, such as the RDBMS giant Oracle
are starting to support it.

The language itself is similar to SQL augmented with syntax for graph
pattern matching. One of the similarities is the handling of NULL values.

## NULLs

Let's get back to mother of all query languages, the almighty SQL and start with a test.
Can you answer by heart what these SQL queries evaluate to?

```sql
SELECT NULL IS NULL;
SELECT NULL = NULL;
SELECT NULL <> NULL;
SELECT TRUE OR NULL;
SELECT TRUE AND NULL;
SELECT FALSE AND NULL;
SELECT FALSE OR NULL;
```
<sub>Results: TRUE, NULL, NULL, TRUE, NULL, FALSE, NULL</sub>

The results might surprise you, however there's nothing
unconventional here. The rules are according to [Kleene logic](https://en.wikipedia.org/wiki/Three-valued_logic#Kleene_logic), where
NULL encodes an uncertain value. So in layman's terms

- Is an uncertain value uncertain? Of course! (TRUE)
- Does an uncertain value (equal to / differ from)
another uncertain value? Not sure. (NULL)
- If something is true OR something else is unknown, is the whole thing true? Of course as
TRUE OR TRUE and TRUE or FALSE or both TRUE
- ... and so on.

Actually, if you think about it, `TRUE OR NULL == TRUE` and `FALSE AND NULL == FALSE`
equivalences are the ones making short circuiting feasible in programming languages.

All in all you get this truth table:

<table class="tg">
  <tr>
    <th class="tg-3we0"></th>
    <th class="tg-3we0">NOT</th>
    <th class="tg-3we0">OR TRUE</th>
    <th class="tg-3we0">OR NULL</th>
    <th class="tg-3we0">OR FALSE</th>
    <th class="tg-3we0">AND TRUE</th>
    <th class="tg-3we0">AND NULL</th>
    <th class="tg-3we0">AND FALSE</th>
  </tr>
  <tr>
    <td class="tg-71z8">TRUE</td>
    <td class="tg-heq4">FALSE</td>
    <td class="tg-71z8">TRUE</td>
    <td class="tg-71z8">TRUE</td>
    <td class="tg-71z8">TRUE</td>
    <td class="tg-71z8">TRUE</td>
    <td class="tg-3we0">NULL</td>
    <td class="tg-heq4">FALSE</td>
  </tr>
  <tr>
    <td class="tg-3we0">NULL</td>
    <td class="tg-3we0">NULL</td>
    <td class="tg-71z8">TRUE</td>
    <td class="tg-3we0">NULL</td>
    <td class="tg-3we0">NULL</td>
    <td class="tg-3we0">NULL</td>
    <td class="tg-3we0">NULL</td>
    <td class="tg-heq4">FALSE</td>
  </tr>
  <tr>
    <td class="tg-heq4">FALSE</td>
    <td class="tg-71z8">TRUE</td>
    <td class="tg-71z8">TRUE</td>
    <td class="tg-3we0">NULL</td>
    <td class="tg-heq4">FALSE</td>
    <td class="tg-heq4">FALSE</td>
    <td class="tg-heq4">FALSE</td>
    <td class="tg-heq4">FALSE</td>
  </tr>
</table>

Let's implement this in Scala!

## Using `Option[Boolean]`

It is pretty straightforward to do with `Option`s,
because of the mapping

- TRUE <-> Some(true)
- NULL <-> None
- FALSE <-> Some(false)

I am pretty fond of Haskell's model for polymorphism, and I use the [simulacrum](https://github.com/mpilquist/simulacrum/)
library to implement this functionality for `Option[Boolean]`s concisely

First define the type class:

```scala
@typeclass trait KleeneLike[-A] {
  @op("&&") def and(x: A, y: A): Option[Boolean]
  @op("||") def or(x: A, y: A): Option[Boolean]
  @op("unary_!") def not(x: A): Option[Boolean]
}
```

Then implement it for `Option[Boolean]`:

```scala
object KleeneLike {
  trait KleeneLikeForOptionBoolean {
    override def and(x: Option[Boolean], y: Option[Boolean]): Option[Boolean] = (x, y) match {
      case (Some(true), Some(true)) => Some(true)
      case (Some(false), _) => Some(false)
      case (_, Some(false)) => Some(false)
      case _ => None
    }
    override def or(x: Option[Boolean], y: Option[Boolean]): Option[Boolean] = (x, y) match {
      case (Some(false), Some(false)) => Some(false)
      case (Some(true), _) => Some(true)
      case (_, Some(true)) => Some(true)
      case _ => None
    }
    override def not(x: Option[Boolean]): Option[Boolean] =
      for { _x <- x } yield !_x
  }

  implicit def optionBooleanKleeneLike
    [Opt <: Option[Boolean]]: KleeneLike[Opt]
    = new KleeneLikeForOptionBoolean {}
}
```

This looks simple however you should look out for not to do e.g. this:

```scala
override def or(x: Option[Boolean], y: Option[Boolean]): Option[Boolean] = (x, y) match {
  for { _x <- x; _y <- y } yield _x || _y
}
```

because it yields `None` for `Some(true) || None` which is not what we want!

[Here's a more general solution](https://gist.github.com/szdavid92/c595fe23b5a1a960f997024cb63a3fff#file-kleenewithtypeclasses-scala) with additional `==` and `!=` ops for arbitrary types.

## Using `Integer`

`Option[Boolean]` is fine but let's do something more efficient.
Scala has a feature called value classes for sparing a runtime
representation for wrappers, compiling their operations
into function calls on a single underlying type. Let's create a value class wrapper around `Integer`
and do the heavy-lifting with bitwise operations!

```scala
class Kleene(val value: Int) extends AnyVal {
  def &&(rhs: Kleene): Kleene = ???
  def ||(rhs: Kleene): Kleene = ???
  def unary_! : Kleene = ???
  def ==(rhs: Kleene): Kleene = ???
  def !=(rhs: Kleene): Kleene = ???
}
```

How to represent stuff?
We have 3 values so we need at least two bits.
It seems that the most straightforward representation is this:

```
00: false
{01, 10}: null
11: true
```

Because then wonderfully:

```scala
def &&(rhs: Kleene): Kleene = new Kleene(value & rhs.value)
def ||(rhs: Kleene): Kleene = new Kleene(value | rhs.value)
def unary_! : Kleene = new Kleene(value ^ 0x3)
```

<sub>`&` is bitwise AND, `|` is bitwise OR, `^` is XOR.</sub>

Now `==` and `!=` are more complex. The key is to parity here.


Operating on the two bits separately:
`(a1 ^ b1) & (a1 ^ b2)`
- returns `0` for an odd `b`,
- returns `0` for the same, `1` for different `a1` `b1`, if `b` is even

`(a2 ^ b2) | (a2 ^ b1)`:
- returns 1 for an odd `b`
- returns 0 for the same, `1` for different `a2` `b2`,  if b is even

if `a` is odd and `b` is even then exactly one of them is false.

So this should do the trick for `!=`.

```scala
private def flipped: Int = (value & 0x1) << 1 | (value & 0x2) >> 1
```

```scala
def !=(rhs: Kleene): Kleene = {
  val first = value ^ rhs.value
  val second = value ^ rhs.flipped
  // MSbs are ANDed, LSbs are ORed
  new Kleene((first & second & 0x2) | ((first | second) & 0x1))
}
```
You can negate this to get `==`.
[Here's the whole file](https://gist.github.com/dszakallas/c595fe23b5a1a960f997024cb63a3fff#file-kleene-scala)

## Conclusion

🍕
