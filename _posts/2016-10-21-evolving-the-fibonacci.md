---
layout: article
title: 'Evolving the Fibonacci'
key: 2016-10-21-evolving-the-fibonacci
tags:
  - Scala
  - functional programming

---
We all know about the Fibonacci sequence. Some of us also know a song that
uses it to achieve a spiraling feeling (yes, Tool fans!).

In Haskell:

```haskell
fib 1 = 0
fib 2 = 1
fib x = fib (x - 1) (x - 2)
```

0 1 1 2 3 5 8 ...

That's it. Story ended. Well not quite. Let's see a language where we can
reason about the execution, because I can't in Haskell.

Scala has strict execution semantics. Let's go for that!

## The problems with the naive implementation

Writing a naive Fibonacci in Scala is as easy as in Haskell. For a new item in
the sequence we need to sum the last and the penultimate, except for the first
two, which are just 0 and 1 respectively.

```scala
def fib(n: Int): Int = {
  if (n <= 2) {
    n - 1
  } else {
    fib(n - 1, n - 2)
  }
}
```
There are multiple problems with this implementation though.
Let's see the evaluation tree for `n = 5`

![tree](/assets/2016-10-21-evolving-the-fibonacci/tree.png)

First it is apparent that values get evaluated multiple times. We evaluated
fib(3) and fib(1) twice, fib(2) thrice. One can see that for every node that has
a left grandchild, it's right child equals it's left grandchild. So for `fib(7)`
we need more than twice the evaluations than for `fib(5)`! Well that is far from
linear!

Besides being a CPU hog, there is another problem. It is not tail-recursive, so it
can overflow that stack for big values. E.g. `fib(100000)` will result in a
 `java.lang.StackOverflowError`. How can we improve this?

## Meet signal networks

If you attended Signals and Systems or similar course at university, there is
a great chance that the Fibonacci sequence came up as an example of a discrete
system. If you never had such course I am delighted to introduce to you this tiny
segment of it, or if it brings back bad memories, just try to pretend
they never happened (Sorry, could not come up with a better advice).

Let's see some basic signal network diagrams!

## The identity

The most simple network just outputs it's input.

![identity](/assets/2016-10-21-evolving-the-fibonacci/id.png)

With the example input sequence `0 1 2 1` the output will be `0 1 2 1`, as shown
on this table.

```
| x | y |
|---|---|
| 0 | 0 |
| 1 | 1 |
| 2 | 2 |
| 1 | 1 |
```

This is just a wire taking the input x into the output y. You can view this as
a `map` with the identity function.

```scala
def id[A](x: A) = x           // id: id[A](val x: A) => A
val x = List(0, 1, 2, 1)      // x: List[Int] = List(0, 1, 2, 1)
val y = x.map(id)             // y: List[Int] = List(0, 1, 2, 1)
```

In other notation, if think about the streams
as arrays (or more generally functions) of time `k`, then
the following equation holds:

```
y[k] = x[k]
```

## A function

You can also apply some more meaningful functions, like amplify by 2.

![function](/assets/2016-10-21-evolving-the-fibonacci/func.png)

```
| x | y |
|---|---|
| 0 | 0 |
| 1 | 2 |
| 2 | 4 |
| 1 | 2 |
```

```scala
val x = List(0, 1, 2, 1)      // x: List[Int] = List(0, 1, 2, 1)
val y = x.map(_ * 2)          // y: List[Int] = List(0, 2, 4, 2)
```

The equation for this is:

```
y[k] = 2 * x[k]
```

## A binary operation

You can join two wires with a binary operation:

![add](/assets/2016-10-21-evolving-the-fibonacci/add.png)

```
| x0 | x1  | y  |
|----|-----|----|
| 0  | 1   | 1  |
| 1  | -5  | -4 |
| 2  | -6  | -4 |
| 1  | 1   | 2  |
```

This is most easily achieved with `zip`:
```scala
val x0 = List(0, 1, 2, 1)
val x1 = List(1, -5, -6, 1)
val y = x0.zip(x1).map { case (a, b) => a + b }
```

And the corresponding equation is:

```
y[k] = x0[k] + x1[k]
```

Dead simple so far. The fun part comes with delays and feedbacks. Let's introduce
the delay first, it is needed for feedbacks anyway.

## Delays

A delay is an element that (guess what?) delays it's output by one cycle. This means
that the input will appear on it's output one iteration later. Formally

```
output[k] = input[k-1]
```
The question arises: if we start at `k = 0`, what will be the output at that point
of time? It is undefined. To overcome this, let's initialize the output for the
delay to 0.

The most simple network with a delay is this:

![delay](/assets/2016-10-21-evolving-the-fibonacci/delay.png)

It is very useful to introduce variables for the output of each of our delays.
We have only one here, let's name it `x0`.

```
| x | x0 | y |
|---|----|---|
| 0 | 0  | 0 |
| 1 | 0  | 0 |
| 2 | 1  | 1 |
| 1 | 2  | 2 |
```

How can we implement this in Scala? We can use a `scan` as seen here:

```scala
val x = List(0, 1, 2, 1)
val y = x.scan(0)((_, element) => element).take(4)
```

`scan` outputs the aggregate before consuming each item in the list, and after the
last item as well (so we cut that out with `take`). Here we only need to store
the current element in our aggregate (the delay buffer), to be output in the next
cycle. Easy!

## Closing the loop: feedback

Let's create a feedback. Feed the output of the delay (`x0`) back and add it to
the input of the delay. Let `y` be the result of this addition!

![feedback](/assets/2016-10-21-evolving-the-fibonacci/fb.png)

```
| x | x0 | y |
|---|----|---|
| 0 | 0  | 0 |
| 1 | 0  | 1 |
| 2 | 1  | 3 |
| 1 | 2  | 3 |
```

```scala
val x = List(0, 1, 2, 1)
val y = x.scanLeft((0, 0))({ case ((x0, y), x) => (x, x + x0) })
  .drop(1)
  .take(4)
  .map({ case (x0, y) => y })
```
Here, you can see that we have to maintain both our `x0` and `y` variables in
the aggregate to generate the next value. In the end however, we only need the
output so we project it with `map`. Another thing to notice is that we `drop`
the first value. The reason for that we don't need the aggregate before the
first input as there is a path without delay between the input `x` and output
`y` in our network.

Formally,

```
x0[k] = x[k-1]
y[k] = x[k] + x0[k]
```

Look how straightforwardly this equation maps to our code!

```
((x0, y), x) => (x, x + x0)
```

Here comes the clever idea. Let's feed the Fibonacci sequence to this system!
Of course it doesn't change our network (and code), only the input `x`
changes.

```scala
val x = List(0, 1, 1, 2, 3, 5, 8)
val y = x.scanLeft((0, 0))({ case ((x0, y), x) => (x, x + x0) }) // unchanged!
  .drop(1)
  .take(7)
  .map({ case (x0, y) => y })
```

```
| x | x0 | y  |
|---|----|--- |
| 0 | 0  | 0  |
| 1 | 0  | 1  |
| 1 | 1  | 2  |
| 2 | 1  | 3  |
| 3 | 2  | 5  |
| 5 | 3  | 8  |
| 8 | 5  | 13 |
```

Whoa! The output is almost a Fibonacci sequence, but not quite.
There should be a pair of `1`s, not only lonely one 🙂! Realize that we need
to shift the whole sequence to cram that extra `1` there. Let's do it by
introducing an initial `0` in the input.
```scala
val x = List(0, 0, 1, 1, 2, 3, 5, 8)
val y = x.scanLeft((0, 0))({ case ((x0, y), x) => (x, x + x0) }) // unchanged!
  .drop(1)
  .take(8)
  .map({ case (x0, y) => y })
```

```
| x | x0 | y  |
|---|----|--- |
| 0 | 0  | 0  |
| 0 | 0  | 0  |
| 1 | 0  | 1  |
| 1 | 1  | 2  |
| 2 | 1  | 3  |
| 3 | 2  | 5  |
| 5 | 3  | 8  |
| 8 | 5  | 13 |
```

Now we almost have the Fibonacci sequence at the output, the only problem is in
the second iteration, where the output should be 1 instead of 0. Let's patch it!
Before going on however, let's rename things a bit.

Rename `x0` to `x1`.

Rename `x` to `x0`.

This way we can introduce a brand new `x`. Make our tiny correction with this `x`!
Let it be a list of numbers that is always `0`, except for the second iteration,
when it is `1`, then add this to our `x0 + x1` to get the output!

The network is:

![partial fibonacci](/assets/2016-10-21-evolving-the-fibonacci/fib_a.png)

```scala
val x = List(0, 1, 0, 0, 0, 0, 0, 0)
val x0 = List(0, 0, 1, 1, 2, 3, 5, 8)
val y = x.zip(x0).scanLeft((0, 0))({ case ((x1, y), (x, x0)) => (x0, x + x0 + x1) })
  .drop(1)
  .take(8)
  .map({ case (x0, y) => y })
```

```
| x | x0 | x1 | y  |
|---|----|----|--- |
| 0 | 0  | 0  | 0  |
| 1 | 0  | 0  | 1  |
| 0 | 1  | 0  | 1  |
| 0 | 1  | 1  | 2  |
| 0 | 2  | 1  | 3  |
| 0 | 3  | 2  | 5  |
| 0 | 5  | 3  | 8  |
| 0 | 8  | 5  | 13 |
```

Formally:

```
x1[k] = x0[k-1]
y[k] = x[k] + x0[k] + x1[k]
```
Once again, take the time and look at the code and this equation!

Nice. The output is OK now. We can also discover another thing here. `x0` needn't be
an external input anymore, we can generate it. How? If you look at the table you can
realize that it's just `x + x0 + x1` from the previous iteration. This means that
we can generate the Fibonacci sequence from `x` only with the following network:

![fibonacci](/assets/2016-10-21-evolving-the-fibonacci/fib.png)

Formally:

```
x0[k] = x[k-1] + x0[k-1] + x1[k-1]
x1[k] = x0[k-1]
y[k] = x[k] + x0[k] + x1[k]
```

The output remains the same.
What to do with the code? Well, we need another buffer to maintain for sure.
Let's introduce that buffer and rewrite the scanner according to our definition above!

```scala
val x = List(0, 1, 0, 0, 0, 0, 0, 0, 0)
val y = x.scanLeft((0, 0, 0))({ case ((x0, x1, y), x) => (x + x0 + x1, x0, x + x0 + x1) })
  .drop(1)
  .take(8)
  .map({ case (x0, x1, y) => y })

// List(0, 1, 1, 2, 3, 5, 8, 13)
```

Wow, it works! It is also tail recursive, because `scanLeft` is tail recursive
(look it up if you don't believe it). The problem however is that we need to create input
lists to get an output. Lists are strict, operations on them will be evaluated in order,
and every intermediate computation will be stored in memory. Would we be better off with streams?

```scala
val x = 0 #:: (1 #:: Stream.continually(0))
val y = x.scanLeft((0, 0, 0))({ case ((x0, x1, y), x) => (x + x0 + x1, x0, x + x0 + x1) })
  .drop(1)
  .take(8)
  .map({ case (x0, x1, y) => y })
  .to[List]

// List(0, 1, 1, 2, 3, 5, 8, 13)
```

*NOTE*

An even more elegant way is doing the thing with a general stateful stream generator `unfold`.
A possible implementation of unfold (that only supports endless streams):

```scala
def unfold[A, S](z: S)(f: S => (A, S)): Stream[A] =
  f(z) match { case (a, s) => a #:: unfold(s)(f) }
```
So you can just:

```scala
val fibonacci = unfold((0, 0, 0))  {
  case (0, _, _) => (0, (1, 0, 0))
  case (1, _, _) => (1, (2, 1, 0))
  case (i, x, y) => (x + y, (x + 1, x + y, x))
}
fibonacci.take(8).to[List]
```
However now it contains inefficient pattern matches.

*END NOTE*

This looks nice, however we sacrificed tail-recursion. Can you spot where exactly?
The definition of `continually` is not tail-recursive:

```
def continually[A](elem: => A): Stream[A] = cons(elem, continually(elem))
```
This is a step backward, but we are still much better off than our very first
naive implementation, as at least we don't evaluate values multiple times here.

We are maximalists however, and we need a tail-recursive implementation!
Let's drop these fancy `List`s, `Stream`s, everything and start from scratch.

What do we have? We have a table, and we know how to move forward on it, we got
the equations for that! As a reminder:

```
x0[k] = x[k-1] + x0[k-1] + x1[k-1]
x1[k] = x0[k-1]
y[k] = x[k] + x0[k] + x1[k]
```

Let's create a function that starts from `k=0`, iterates according to the
equations and stops at `k=n`!

The following code does exactly this:

```scala
def fibonacci(n: Int): Int = {
  def loop(i: Int, max: Int, x: (Int, Int)): (Int, Int, (Int, Int)) = {

    val x_next = if (i <= 2) {
      (i - 1, 0)
    } else {
      (x._1 + x._2, x._1)
    }

    if (i == max) {
      (i, max, x_next)
    } else {
      loop(n + 1, max, x_next)
    }
  }
  loop(1, n, (0, 0))._3._1
}
```

There is an outer wrapper called `fibonacci` that provides a caller-friendly
interface. Then, inside it calls `loop`, setting the iteration variable to 1, the
stop criteria to `n` and initializing the inner buffers, formerly `x0` and `x1`
to zeros. In each iteration we calculate the next state of the buffers. If we
reached the max, we and the recursion, else we call the next iteration.

This is tail-recursive and efficient, however far from elegant.
Why do we even set the buffers if they get overwritten in the first place?
What if we mess up and start `i` from a greater value?

To find a better solution we have to realize that we can do the iteration in the
other direction, counting from `n` down to 1. Then, there is no way to put
the specialized `i <= 2` code into the loop body, but there is no need for that:

```scala
def fibonacci_elegant(n: Int): Int = {
  def loop(i: Int, x: (Int, Int)): (Int, (Int, Int)) = {
    if (i == 0) {
      (i, (x._1 + x._2, x._1))
    } else {
      loop(i - 1, (x._1 + x._2, x._1))
    }
  }

  if (n <= 2) {
    n - 1
  } else {
    loop(n - 3, (1, 0))._2._1
  }
}
```

It is sort of unrolls the starting special cases. It is still a bit cryptic,
as it is hard to find how our original system is encoded in this function, so
I still prefer the suboptimal `Stream` solution 😜.

That's all folks!
