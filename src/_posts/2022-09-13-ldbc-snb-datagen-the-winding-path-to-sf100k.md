---
layout: article
title: LDBC SNB Datagen - The winding path to SF100K
key: 2022-09-13-ldbc-snb-datagen-the-winding-path-to-sf100k
tags:
  - Apache Spark
  - Scala
  - Java
  - Hadoop
  - MapReduce
  - AWS EMR
  - LDBC
---

More than two years have elapsed since my [last technical update](https://ldbcouncil.org/post/speeding-up-ldbc-snb-datagen/) on LDBC SNB Datagen, in which I discussed
the reasons for moving the code to Apache Spark from the MapReduce-based Apache Hadoop implementation and the challenges I faced during the migration. Since then, we reached several goals such as
 we refactored the serializers to use Spark's high-level writers to support the popular Parquet data format and to enable running on spot nodes; brought back factor generation; implemented support for the novel BI benchmark; and optimized the runtime to generate SF30K on 20 i3.4xlarge machines on AWS.

[Continue reading on ldbcouncil.org >>](https://ldbcouncil.org/post/ldbc-snb-datagen-the-winding-path-to-sf100k/)

