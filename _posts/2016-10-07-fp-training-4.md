---
layout: post
title: 'FP Training @ RS: Recursion'
key: 2016-10-07-fp-training-4
tags:
  - functional programming
  - Haskell
  - tutorial
---
##  Agenda
 - Example 1: factorial
 - Example 2: map
 - Example 3: join


## 1. We implemented the factorial example in JavaScript imperatively:

```js
function factorial (n) {
  var prev = 1
  for (var i = 1; i <= n; ++i) {
    prev = prev * i
  }
  return prev
}
```

Here `prev` is mutated, so this is not allowed in pure functional languages. How can we solve the problem functionally?

> Recursion occurs when a thing is defined in terms of itself or of its type. Recursion is used in a variety of disciplines ranging from linguistics to logic. The most common application of recursion is in mathematics and computer science, where a function being defined is applied within its own definition. While this apparently defines an infinite number of instances (function values), it is often done in such a way that no loop or infinite chain of references can occur. (Wikipedia)

Recursive function: a function that calls itself.

Base case: The case when the recursion terminates.

```haskell
fac 0 = 1 -- base case
fac n = n * fac (n - 1) -- recursive case
```

```js
function fac (n) {
  if (n === 0) {
    return 1
  } else {
    return n * fac(n - 1)
  }
}
```

The problem with recursion is that it grows the stack, while a mutating loop does not.
This will overflow the stack on current v8:
```javascript
(function f(n){
  if (n <= 0) {
    return  "foo";
  }
  return f(n - 1);
}(1e6))
```

A specific kind of recursion, called *tail recursion*, can be optimized to use only constant stack if the
platform supports tail call optimization. A recursive call is said to be in tail position if it's the last operation
to be evaluated. In this case, we do not need its result or any variables on the stack after applying the recursive call (because it is the last thing to be carried out!), which means
that the outer stack frame can be replaced with the stack frame of the function we are about to call, rather than appending to it, thus leaving the stack at a constant size.
The above function is tail recursive because the recursive call is in tail position. Currently v8 detects and optimizes tail recursion only with the `--harmony_tailcalls` flag.
We can see that the factorial function we wrote is not tail recursive, as there is a multiplication after the recursive call.
However we can rewrite it be tail recursive:

```js
function fac_rec(p, n) {
  if (n === 0) {
    return 1
  } else {
    return fac (p * n, n - 1)
  }
}

function fac(n) {
  return fac_rec(1, n)
}
```

Note that stack traces are affected by tail call optimization, as we can only see the innermost frame of the
recursive function at all times.

## 2. Map

The map function is another rather simple recursive function:

```haskell
map f [] = []
map f (a:as) = (f a) : (map f as)
```

Q: Is this tail recursive?

## 3. Relations

Given `A` and `B` sets, let `R(A,B)` be a subset of `AxB`. (`x` here is the Cartesian product). `R` is called a *relation*.
Relation is the fundamental type of relational algebra, relational databases and SQL.

Example:

Given the following sets
```
Animal = { cat, cow, bear }
Food = { fish, grass, apple }
FoodType = { meat, plant }
```

let's create the following two relations:
```
Feed(Animal, Food) = { (cat, fish), (cow, grass), (bear, fish), (bear, apple) }
TypeOf(Food, FoodType) = { (fish, meat), (grass, plant), (apple, plant) }
```

We can join `Feed` and `TypeOf` relations to form a new relation
```
FeedType = Feed & TypeOf
```

`(animal, foodType)` in `FeedType` iff `(animal, food)` in `Feed` and `(food, foodType)` in `TypeOf`.

This means
```
FeedType = { (cat, meat), (cow, plant), (bear, meat), (bear, plant) }
```

In general:

`(a,c)` in `R & S` iff `(a, b)` in `R` and `(b, c)` in `S`.

Another example we talked about is `LikesArtist(Person, Artist)`, `HasGenre(Artist, Genre)` and
`LikesGenre = LikesArtist & HasGenre`.

Let's implement `join`:

```haskell

import Data.List (union)

data Rel a b = Rel [(a, b)] deriving Show

(\/) :: (Eq a, Eq b) => Rel a b -> Rel a b -> Rel a b
(\/) (Rel rs) (Rel qs) = Rel $ union rs qs

(&) :: (Eq a, Eq b, Eq c) => Rel a b -> Rel b c -> Rel a c
(&) (Rel rs) (Rel []) = Rel []
(&) (Rel []) (Rel qs) = Rel []
(&) (Rel ((r0, r1):rs)) (Rel ((q0, q1):qs)) =
  let
    match = if r1 == q0
      then Rel [(r0, q1)]
      else Rel []
    leftHead = Rel [(r0, r1)]
    leftTail = Rel rs
    right = Rel ((q0, q1):qs)
    rightTail = Rel qs
  in
    match \/ (leftHead & rightTail) \/ (leftTail & right)
```

We realize that this recursion spreads out into a binary tree, and in fact quadratic, and not
tail recursive.

Example for `LikesGenre = LikesArtist & HasGenre`:

```
λ> let likesArtist = Rel [("David", "Tool"), ("Gellert", "James Blake"), ("Gellert", "Kanye West")]
λ> let hasGenre = Rel [("Tool", "Prog Metal"), ("Kanye West", "Pop"), ("James Blake", "Pop")]
λ> likesArtist & hasGenre
Rel [("David","Prog Metal"),("Gellert","Pop")]
```
