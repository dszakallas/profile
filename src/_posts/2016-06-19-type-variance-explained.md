---
layout: article
title: 'Type variance explained'
key: 2016-06-19-type-variance-explained
tags:
  - Java
  - generic programming

---
Reasoning about subtype relations between parameterised types tend
to confuse developers. If you are a Java developer you\'ve probably seen
the syntax `? extends T` and `? super T`, or might even used it to
create flexible method signatures. I was very confused at first when I
tried to use them as their meaning wasn\'t clear to me. So, I just
placed `extends` everywhere, and changed it to `super` when the compiler
complained. Where is it even valid to place only super types of some
`T`? It made no sense to me at first. But as it turns out, it makes all
the sense. Let\'s start at the beginning. Say you have a `Cat` class
extending the `Animal` class. Here, `Cat` is the subtype of `Animal`, by
definition.

![animal\_cat](/static/2016-06-19-type-variance-explained/animal_cat.png)

Now, let\'s create four `XInYOut` classes, each of them having a single
method `apply`, and use these two classes with them. It doesn\'t matter
what this `apply` method does, we only care about its signature:
it takes one input parameter, and returns an output. Why do we create
four? To cover all combinations of the `Animal` and `Cat` classes, in
the input and output parameters. Without generic parameters yet, what
are possible subtyping relations between these classes? The most
straightforward is that `AnimalInCatOut` is a subtype of
`AnimalInAnimalOut`, because wherever you return an `Animal` you could
also return a `Cat` as it is its subtype. The same thing applies
to `CatInCatOut`  and `CatInAnimalOut`.
![aico](/static/2016-06-19-type-variance-explained/aico.png)

![subtype\_2](/static/2016-06-19-type-variance-explained/cico.png)

  Might be a bit trickier to see that `AnimalInAnimalOut` is a subtype
of `CatInAnimalOut`. The first one can replace the second one on
call-site without breaking type safety, because the caller expects
something the needs a `Cat` , and so they must provide an argument that
is subtype of `Cat`, and this always satisfy `Animal`. Of course the
same applies to `AnimalInCatOut` and `CatInCatOut`.
![suebtype\_1](/static/2016-06-19-type-variance-explained/ciao-1.png)

![subtype\_0](/static/2016-06-19-type-variance-explained/aico2.png)

`AnimalInCatOut` and `CatInAnimalOut` combine both treats of the upper
two cases; both the former\'s input a supertype, the output the subtype
of the latter. So `AnimalInCatOut` is a subtype of `CatInAnimalOut`.
Lastly, `CatInCatOut` cannot be a subtype of `AnimalInAnimalOut` as it
breaks the contract of its input parameter, vice versa it breaks the
output, so there is no relation between them. To sum things up:

![whole](/static/2016-06-19-type-variance-explained/whole.png)

Now, onto generics. Let\'s make one generic class by depending on two
types: `In` and `Out`.
![generic](/static/2016-06-19-type-variance-explained/generic.png)

The same rules applies here as well:

-   `Function<Animal, Cat>` is a subtype of
    `Function<Animal, Animal>` and `Function<Cat, Cat>` is a subtype of
    `Function<Cat, Animal>`. Here the subtype relation\'s direction of
    the dependent type `Function` is the same as the parameter `Out`,
    making `Out` a **covariant** type parameter.
-   `Function<Animal, Animal>` is a subtype of `Function<Cat, Animal>`,
    `Function<Animal, Cat>` is a subtype of `Function<Cat, Cat>`. Here
    the subtype relation\'s direction of the dependent type
    `Function` is opposite to the direction of the subtype relation
    between the parameter `In` making `In` a **contravariant** type
    parameter.
-   Making use of both parameters\' variance, `Function<Animal, Cat>` is
    a subtype of `Function<Cat, Animal>`.

In some languages, like Scala, variance is declared class level,
using `+` for covariant, `-` for contravariant parameters.

![anno2](/static/2016-06-19-type-variance-explained/anno2.png)

In Java however, the developer has a cumbersome job: the language does
not known class level variance. Instead one has to specify the type
variables\' variance every place they are used: `? extends T` for
covariant, `? super T` for contravariant positions. If you miss to
specify the variance at a place, you lose the information for consequent
uses.

Hope this clarified things a bit about type variance. Cheers!

 
