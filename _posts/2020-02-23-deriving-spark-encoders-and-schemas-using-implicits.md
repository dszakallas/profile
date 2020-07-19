---
layout: article
title: Deriving Spark Encoders and Schemas Using Implicits
key: 2020-02-23-deriving-spark-encoders-and-schemas-using-implicits
tags:
  - Apache Spark
  - Scala
  - generic programming
---

# Abstract
Since Apache Spark 2.0 the Dataset API is the preferred way of programming over low level RDDs. However when migrating complex business entities from RDDs to Datasets, a handful of problems arise. One is the lack of support for user defined types, confining the developer to a predefined set of types and severely hindering the usefulness of Datasets. The other one is the inferior type safety of DataFrame operations compared to RDDs.

In this blogpost I describe how our team at Ekata resolved these problems while migrating our ETL pipeline from RDDs to DataFrames. We did this without changing our object-oriented domain entities, writing schema description, breaking binary compatibility with our existing serialized format, or needlessly degrading the optimizations coming with DataFrames. With the help of the code generation capabilities of the Scala compiler and a set open source type level libraries, we derived schema for our business entities, generated Dataset encoders and had fun along the way.

# [Full Article 🔗](https://www.dataversity.net/case-study-deriving-spark-encoders-and-schemas-using-implicits/#)
The article is published on the DATAVERSITY blog. Click on the link above to read it.
