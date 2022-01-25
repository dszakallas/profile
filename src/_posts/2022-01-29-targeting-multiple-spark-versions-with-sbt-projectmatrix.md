---
layout: article
title: Targeting multiple Spark versions with sbt-projectmatrix
key: 2022-01-29-targeting-multiple-spark-versions-with-sbt-projectmatrix
tags:
  - Scala
  - Apache Spark
  - sbt
---

# Introduction

I was recently involved in projects that had to target multiple Spark versions. One of them is LDBC SNB Datagen which targeted Spark 2 and Spark 3 for a while; the other one an internal ETL library that had to run on Spark 3.0 as well as Spark 2.4. As a major release, Spark 3 introduced breaking changes, especially for internal use interfaces, on which we depended in a few cases. Additionally, Scala 2.12 support has finally arrived, so cross-compilation became important. In this blogpost, I am going to show how [`sbt-projectmatrix`](https://github.com/sbt/sbt-projectmatrix) can be utilized for this purpose.

# Project skeleton
The goal is to have a separate assembly jar for the following Spark/Scala combinations:

- Spark 2.4 / Scala 2.11
- Spark 3.1 / Scala 2.12
- Spark 3.2 / Scala 2.12
- Spark 3.2 / Scala 2.13

Scala 2.13 is the first Scala version to add support for Java 11 target, which is also supperted by Spark 3.2, so we compile the last target to JVM 11. All others are compiled to Java 8.

I start by creating a project and adding `sbt-projectmatrix` as a plugin.  

`project/plugins.sbt`:
```scala
addSbtPlugin("com.eed3si9n" % "sbt-projectmatrix" % "0.9.0")
```

`sbt-projectmatrix` works by creating subprojects for each combination. Each subproject can have a different set of settings, source, dependencies, etc. I start by adding a subproject to contain
the main, platform independent code. Using the root at `file(".")` will not work, so I create subproject with the same name is the project itself. 

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

Notice the use of `projectMatrix` instead of `project` on the penultimate line. This way we configure a [ProjectMatrix](https://github.com/sbt/sbt-projectmatrix/blob/v0.9.0/src/main/scala/sbt/internal/ProjectMatrix.scala#L26) instead of a `Project`.

To target different Spark versions, we have to create a `VirtualAxis`. The targeted Spark versions become the axis values (rows). Let's put the source in `project/Build.scala`:

```scala
case class SparkVersionAxis(sparkVersion: String) extends sbt.VirtualAxis.WeakAxis {
  val sparkVersionCompat: String = sparkVersion.split("\\.", 3).take(2).mkString(".")
  override val directorySuffix = s"-spark${sparkVersionCompat}"
  override val idSuffix: String = directorySuffix.replaceAll("""\W+""", "_")
}
```

The plugin offers two flavors of `VirtualAxis`: `StrongAxis` and `WeakAxis`, the latter is basically nullable, i.e. allows us to depend on a subproject which does not specify a Spark version. This is handy if we want to depend on a common utility module with no Spark dependencies.
`directorySuffix` and `idSuffix` govern the name of the row-specific source directory name and module name respectively. We include only the first two components of the Spark version.

We can add the axis rows to the matrix with `ProjectMatrix.customRow`. Let's add a basic configuration only for Spark 2.4 to `build.sbt`.

```scala
lazy val `spark2.4` = SparkVersionAxis("2.4.7")

lazy val `spark-matrix-example` = (projectMatrix in file("spark-matrix-example"))
  .settings(commonSettings: _*)
  .customRow(
    scalaVersions = Seq("2.11.12"),
    axisValues = Seq(`spark2.4`, VirtualAxis.jvm),
    _.settings(
      moduleName := name.value + `spark2.4`.directorySuffix,
      libraryDependencies ++= Seq(
        "org.apache.spark" %% s"spark-core" % `spark2.4`.sparkVersion % Provided,
        "org.apache.spark" %% s"spark-sql" % `spark2.4`.sparkVersion % Provided,
        "org.apache.spark" %% s"spark-hive" % `spark2.4`.sparkVersion % Provided
      )
    )
  )
```

Sources under `src/main` and  `src/test` are shared, so they should compile for all Spark / Scala versions. Let's add a test to assert that it works.

`spark-matrix-example/src/test/scala/eu/szakallas/SparkExampleSpec.scala`
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

# Multiple rows

Time to add the other Spark versions. We can do that by chaining all of them with `customRow`. However let's refactoring by extracting some common configuration into an extension method.

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

  private def isJvm11Compat(axes: Seq[VirtualAxis]) = {
    axes.collectFirst{ case ScalaVersionAxis(_, scalaVersionCompat) => scalaVersionCompat }.map(_ == "2.13").getOrElse(true)
  }

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
              if (isJvm11Compat(virtualAxes.value)) "-target:jvm-11" else "-target:jvm-1.8"
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

and `sbt test` should run the test in all subprojects.

# Adding a shim
While Spark is quite conservative regarding public API changes, we can run into source compatibility issues if we depend on internal stuff. For example, `SerializableConfiguration` helper, used for passing a `HadoopConfiguration` to the executors, is private in Spark 2.4, causing this example to emit a compile-time error:

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

The implementation is only a few lines. We can add a shim which is only included for the Spark 2.4 target.

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
Notice that the file is placed in to `scala-spark2.4-jvm`, not `scala`. This way the file is only included for the Spark 2.4 target. While including for all versions wouldn't cause any issues in this case it is better to only have it where needed. 




# Packaging

I also add `sbt-assembly` as packaging an uberjar is the easiest way to submit an app to Spark.


addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "0.15.0")


  assembly / assemblyMergeStrategy := {
    case PathList("META-INF", "MANIFEST.MF") => MergeStrategy.discard
    case x =>
      val oldStrategy = (assembly / assemblyMergeStrategy).value
      oldStrategy(x)
  }
