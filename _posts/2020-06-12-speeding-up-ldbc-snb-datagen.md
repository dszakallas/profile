---
layout: post
title: Migrating LDBC SNB Datagen to Spark
key: 2020-06-12-speeding-up-ldbc-snb-datagen
tags:
  - Apache Spark
  - Scala
  - Java
  - Hadoop
  - MapReduce
  - AWS EMR
  - LDBC
---

# Abstract

LDBC’s Social Network Benchmark (LDBC SNB) is an industrial and academic initiative, formed by principal actors in the field of graph-like data management. Its goal is to define a framework where different graph-based technologies can be fairly tested and compared, that can drive the identification of systems’ bottlenecks and required functionalities, and can help researchers open new frontiers in high-performance graph data management.

LDBC SNB provides Datagen (Data Generator), which produces synthetic datasets, mimicing a social network’s activity during a period of time. Datagen is defined by the charasteristics of realism, scalability, determinism and usability. To address scalability in particular, Datagen has been implemented on the MapReduce computation model to enable scaling out across a distributed cluster. However, since its inception in the early 2010s there has been a tremendous amount of development in the big data landscape, both in the sophistication of distributed processing platforms, as well as public cloud IaaS offerings. In the light of this, we should reevaluate this implementation, and in particular, investigate if Apache Spark would be a more cost-effective solution for generating datasets on the scale of tens of terabytes, on public clouds such as Amazon Web Services (AWS).


# [Full article on ldbcouncil.org 🔗](http://ldbcouncil.org/blog/speeding-ldbc-snb-datagen)
The article is published on ldbcouncil.org. Click on the link above to navigate to the blogpost.

