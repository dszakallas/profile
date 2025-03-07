---
layout: article
title: Targeting multiple Spark versions with sbt-projectmatrix
key: 2022-01-29-targeting-multiple-spark-versions-with-sbt-projectmatrix
tags:
  - Scala
  - Apache Spark
  - sbt
  - developer tools
---

## Introduction

I was recently involved in projects that had to work on multiple Spark versions. One of them is an open-source project that targeted Spark 2 and Spark 3 for a while; the other one a collection of internal ETL applications that the team migrated to Spark 3 but also had to support Spark 2 for a longer period of time due to external constraints. Spark 3.0.0 finally ditched the archaic Scala 2.11, making it necessary to cross-compile the library for multiple Scala versions. While almost perfectly source-compatible, it also broke the code a few places where we directly depended on Spark internals. Moreover, some libraries don't have an overlapping version range with both Scala 2.11 and Scala 2.12 support, requiring us to use separate versions of these libraries. In this blogpost, I am going to show how [`sbt-projectmatrix`](https://github.com/sbt/sbt-projectmatrix) can be utilized for cross-compilation with possibly different set of dependencies and platform dependent shims where necessary.

Disclaimer: `sbt-projectmatrix` is experimental at the time of writing this article.

## Project skeleton
In this article, I am going to walk through a project that targets the following combos:

- Spark 2.4 / Scala 2.11
- Spark 3.1 / Scala 2.12
- Spark 3.2 / Scala 2.12
- Spark 3.2 / Scala 2.13

Note that Spark 3.2 is still very fresh at the time of writing this article, and not many third-party Spark libraries have Scala 2.13 jars published to Maven Central. If you have such dependencies you won't be able to build this target yet. 
Scala 2.13 is the first version to support compiling to Java 11, which is also supported by Spark 3.2. I'll explore this in the article.

We start by creating a project and adding `sbt-projectmatrix` as a plugin.

`project/plugins.sbt`:
```scala
addSbtPlugin("com.eed3si9n" % "sbt-projectmatrix" % "0.9.0")
```

`sbt-projectmatrix` works by creating subprojects for each combination. Each subproject may have different settings, sources, dependencies, etc. Let's create the subproject matrix with the same name as the project itself. 

`build.sbt`:
```scala
import sbt._

ThisBuild / scalaVersion := "2.13.6"

val commonSettings = Seq(
  version := "0.0.1-SNAPSHOT",
  libraryDependencies ++= Seq(
    "org.scalatest" %% "scalatest" % "3.1.0" % Test,
  ),
)

lazy val `spark-matrix-example` = (projectMatrix in file("spark-matrix-example"))
  .settings(commonSettings: _*)
```

Notice the use of `projectMatrix` instead of `project` in the last statement. Also, using `file(".")` wouldn't work because the matrix contained multiple subprojects after adding rows to it.

To target different Spark versions, we have to create a `VirtualAxis` for it. The targeted Spark versions will be the axis values (rows). Let's put the source in `project/Build.scala`:

```scala
case class SparkVersionAxis(sparkVersion: String) extends sbt.VirtualAxis.WeakAxis {
  val sparkVersionCompat: String = sparkVersion.split("\\.", 3).take(2).mkString(".")
  override val directorySuffix = s"-spark${sparkVersionCompat}"
  override val idSuffix: String = directorySuffix.replaceAll("""\W+""", "_")
}
```

The plugin offers two flavors of `VirtualAxis`: `StrongAxis` and `WeakAxis`. the latter essentially marks it nullable, i.e. allows us to depend on a subproject which does not specify a Spark version. This is handy if we have subprojects without Spark dependencies (e.g common utils, business logic). `directorySuffix` and `idSuffix` govern the name of the row-specific source directory name and the module name respectively. We include only the first two components of the Spark version, that should be enough to determine compatibility.

We can add the axis rows to the matrix with `ProjectMatrix.customRow`. Here's a basic configuration for Spark 2.4 added to `build.sbt`:

```scala
lazy val spark24 = SparkVersionAxis("2.4.7")

lazy val `spark-matrix-example` = (projectMatrix in file("spark-matrix-example"))
  .settings(commonSettings: _*)
  .customRow(
    scalaVersions = Seq("2.11.12"),
    axisValues = Seq(spark24, VirtualAxis.jvm),
    _.settings(
      moduleName := name.value + spark24.directorySuffix,
      libraryDependencies ++= Seq(
        "org.apache.spark" %% s"spark-core" % spark24.sparkVersion % Provided,
        "org.apache.spark" %% s"spark-sql" % spark24.sparkVersion % Provided,
        "org.apache.spark" %% s"spark-hive" % spark24.sparkVersion % Provided
      )
    )
  )
```

Sources under `src/main` and  `src/test` are shared across rows, i.e. they get included for all Spark / Scala versions. This is where the majority of the code should ideally live. Let's add a test to assert that the configuration works so far.

`spark-matrix-example/src/test/scala/eu/szakallas/SparkExampleSpec.scala`:
```scala
package eu.szakallas

import org.scalatest._
import flatspec._
import matchers._
import org.apache.spark.sql.SparkSession

class SparkExampleSpec extends AnyFlatSpec with should.Matchers {
  lazy val spark = SparkSession.builder
    .appName("SparkMatrixExample")
    .master("local[*]")
    .getOrCreate()

  "Spark" should "work" in {
    println(s"Running Spark ${spark.version} on Scala ${util.Properties.versionNumberString}")
  }
}
```

Running `sbt test` should print:

```
[info] SparkExampleSpec:
[info] SparkExample
[info] - should work on Spark 2.4.7 / Scala 2.11.12
```

## Multiple rows

Time to add the other Spark versions. We can do that by chaining all of them with `customRow`. However, let's remove some of the duplication by extracting the common configuration to an extension method.

`project/Build.scala`
```scala
import sbt._
import sbt.Keys._
import sbt.VirtualAxis._
import sbt.internal.ProjectMatrix
import sbtprojectmatrix.ProjectMatrixKeys._

case class SparkVersionAxis(sparkVersion: String) extends sbt.VirtualAxis.WeakAxis {
  val sparkVersionCompat: String = sparkVersion.split("\\.", 3).take(2).mkString(".")
  override val directorySuffix = s"-spark${sparkVersionCompat}"
  override val idSuffix: String = directorySuffix.replaceAll("""\W+""", "_")
}

object SparkVersionAxis {
  private def sparkDeps(version: String, modules: Seq[String]) = for {module <- modules} yield {
    "org.apache.spark" %% s"spark-${module}" % version % Provided
  }

  def isScala2_13(axes: Seq[VirtualAxis]) = {
    axes.collectFirst{ case ScalaVersionAxis(_, scalaVersionCompat) => scalaVersionCompat }.map(_ == "2.13").getOrElse(true)
  }

  def isSpark2_4(axes: Seq[VirtualAxis]) = {
    axes.collectFirst{ case v@SparkVersionAxis(_) => v.sparkVersionCompat }.map(_ == "2.4").getOrElse(false)
  }

  private val classVersion = System.getProperty("java.class.version").toFloat

  implicit class ProjectExtension(val p: ProjectMatrix) extends AnyVal {
    def sparkRow(sparkAxis: SparkVersionAxis, scalaVersions: Seq[String], settings: Def.SettingsDefinition*): ProjectMatrix =
      p.customRow(
        scalaVersions = scalaVersions,
        axisValues = Seq(sparkAxis, VirtualAxis.jvm),
        _
          .settings(
            moduleName := name.value + sparkAxis.directorySuffix,
            libraryDependencies ++= sparkDeps(sparkAxis.sparkVersion, Seq("core", "sql", "hive")),

            scalacOptions += {
              if (isScala2_13(virtualAxes.value)) {
                "-target:jvm-11"
              } else {
                "-target:jvm-1.8"
              }
            },
            Test / test := {
              if (!(isScala2_13(virtualAxes.value) && classVersion < 55) && !(isSpark2_4(virtualAxes.value) && classVersion > 52))
                (Test / test).value
            }
          )
          .settings(settings: _*)
      )
  }
}
```

Besides setting `moduleName` and `libraryDependencies` I also configured the Scala compiler to use the Java 11 target when using Scala 2.13. `build.sbt` becomes a lot shorter: 

```scala
lazy val `spark-matrix-example` = (projectMatrix in file("spark-matrix-example"))
  .settings(commonSettings: _*)
  .sparkRow(SparkVersionAxis("2.4.7"), scalaVersions = Seq("2.11.12"))
  .sparkRow(SparkVersionAxis("3.1.2"), scalaVersions = Seq("2.12.12"))
  .sparkRow(SparkVersionAxis("3.2.0"), scalaVersions = Seq("2.12.12", "2.13.6"))
```

`sbt projects` should list four subprojects now
```
[info] 	  spark-matrix-example_spark2_42_11
[info] 	  spark-matrix-example_spark3_12_12
[info] 	  spark-matrix-example_spark3_2
[info] 	  spark-matrix-example_spark3_22_12
```

To be able to execute all tests, we should be on Java 11 or later, as the last combo targets that version (bytecode version 55) and will fail on Java 8 as it is unable to recognize the bytecode. However, the bytecode toolkit that Spark 2.4 uses when serializing executor procedures is not compatible with Java 11. As a workaround, I ignored the tests on incompatible platforms by overriding the `Test / test` task of the subprojects. Automating the tests to run on different JVMs are left to the interested reader.

## Adding a shim
While Spark is quite conservative regarding public API changes, we can run into source compatibility issues if we depend on internals. For example, the `SerializableConfiguration` helper, used for passing a `HadoopConfiguration` to the executors, is private in Spark 2.4, causing this example to emit a compile-time error:

```scala
package eu.szakallas

import org.scalatest._
import flatspec._
import matchers._
import org.apache.spark.sql.SparkSession
import org.apache.spark.util.SerializableConfiguration
import Inspectors._

class SparkExampleSpec extends AnyFlatSpec with should.Matchers {
  lazy val spark = SparkSession.builder
    .appName("SparkMatrixExample")
    .master("local[*]")
    .getOrCreate()

  "SparkExample" should s"work on Spark ${spark.version} / Scala ${util.Properties.versionNumberString}" in {
    val hadoopConf = spark.sparkContext.hadoopConfiguration
    hadoopConf.set("mykey", "myvalue")
    val serializableConf = new SerializableConfiguration(hadoopConf)
    val results: Array[Boolean] = spark.sparkContext
      .parallelize(1 until 10)
      .map { _ => serializableConf.value.get("mykey") == "myvalue" }
      .collect()
    forAll (results) { _ shouldBe true }
  }
}
```

The implementation is only a few lines. We can add a shim only to be included in the Spark 2.4 target.

`spark-matrix-example/src/main/scala-spark2.4-jvm/org/apache/spark/util/SerializableConfiguration`:
```scala
package org.apache.spark.util

import java.io.{ObjectInputStream, ObjectOutputStream}
import org.apache.hadoop.conf.Configuration

class SerializableConfiguration(@transient var value: Configuration) extends Serializable {
  private def writeObject(out: ObjectOutputStream): Unit = Utils.tryOrIOException {
    out.defaultWriteObject()
    value.write(out)
  }
  private def readObject(in: ObjectInputStream): Unit = Utils.tryOrIOException {
    value = new Configuration(false)
    value.readFields(in)
  }
}
```
Notice that the file is placed in to `scala-spark2.4-jvm`, not `scala`. This way the file is only included for the Spark 2.4 target. Including in all versions wouldn't cause any issues in this particular case, however there are instances where this is unavoidable. Using this method, we can segregate any platform-dependent source code we encounter. 

## Different dependencies

We can add different dependencies to the subprojects, as demonstrated here with `com.audienceproject:spark-dynamodb`. Note that the library does not support Scala 2.13 at the time of writing this article, so I excluded it from one of the subprojects in this hypothetical scenario. Of course, in a real project we either have to wait for the authors to publish it, or contribute ourselves.

```scala

val Spark2DynamoDB = "com.audienceproject" %% "spark-dynamodb" % "1.0.4"

val Spark3DynamoDB = "com.audienceproject" %% "spark-dynamodb" % "1.1.2" excludeAll (
  ExclusionRule("com.fasterxml.jackson.core")
)

val `spark-matrix-example` = (projectMatrix in file("spark-matrix-example"))
  .settings(commonSettings: _*)
  .sparkRow(SparkVersionAxis("2.4.7"),
            scalaVersions = Seq("2.11.12"),
            settings = Seq(
              libraryDependencies ++= Seq(Spark2DynamoDB)
            )
  )
  .sparkRow(SparkVersionAxis("3.1.2"),
            scalaVersions = Seq("2.12.12"),
            settings = Seq(
              libraryDependencies ++= Seq(Spark3DynamoDB)
            )
  )
  .sparkRow(SparkVersionAxis("3.2.0"),
            scalaVersions = Seq("2.12.12", "2.13.6"),
            settings = Seq(
              libraryDependencies ++= { if (!isScala2_13(virtualAxes.value)) Seq(Spark3DynamoDB) else Seq() }
            )
  )
```

## Packaging

Using an uberjar is the easiest way to submit an app to Spark. The `sbt-assembly` plugin adds this functionality and works more or less out of the box. Add to `project/plugins.sbt`:

```
addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "0.15.0")
```

By running `sbt assembly`, all subprojects' artifacts are created. One thing I didn't quite like is their names, i.e 

```
spark-matrix-example/target/spark2.4-jvm-2.11/spark-matrix-example-assembly-0.0.1-SNAPSHOT.jar
spark-matrix-example/target/spark3.1-jvm-2.12/spark-matrix-example-assembly-0.0.1-SNAPSHOT.jar
spark-matrix-example/target/spark3.2-jvm-2.12/spark-matrix-example-assembly-0.0.1-SNAPSHOT.jar
spark-matrix-example/target/spark3.2-jvm-2.13/spark-matrix-example-assembly-0.0.1-SNAPSHOT.jar
```

It would be better if the names contained the axis coordinates. We can add those by customizing `assemblyJarName` in `build.sbt`:

```scala
val commonSettings = Seq(
  version := "0.0.1-SNAPSHOT",
  libraryDependencies ++= Seq(
    "org.scalatest" %% "scalatest" % "3.1.0" % Test,
  ),
  assembly / assemblyJarName := {
    { moduleName.value + "_" + scalaBinaryVersion.value + "-" + version.value + ".assembly.jar" }
  }
)
```
This produces the following results:

```
spark-matrix-example/target/spark2.4-jvm-2.11/spark-matrix-example-spark2.4_2.11-0.0.1-SNAPSHOT.assembly.jar
spark-matrix-example/target/spark3.1-jvm-2.12/spark-matrix-example-spark3.1_2.12-0.0.1-SNAPSHOT.assembly.jar
spark-matrix-example/target/spark3.2-jvm-2.12/spark-matrix-example-spark3.2_2.12-0.0.1-SNAPSHOT.assembly.jar
spark-matrix-example/target/spark3.2-jvm-2.13/spark-matrix-example-spark3.2_2.13-0.0.1-SNAPSHOT.assembly.jar
```

Now we can upload the assembly JARs to a blob storage, etc. without name clashes.

In case of libraries, `sbt package` will create a package that contains the axis suffix by default, so no additional configuration is needed.

## Final words

`sbt-projectmatrix` is an experimental sbt plugin, but can prove very useful when targeting multiple Spark versions, as it comes with challenges more lightweight approaches cannot handle. The project files accompanying this blogpost can be found at [https://github.com/dszakallas/spark-matrix-example](https://github.com/dszakallas/spark-matrix-example) to make it easier to try out.
