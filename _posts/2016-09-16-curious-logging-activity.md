---
layout: article
title: 'Curious logging activity'
key: 2016-09-16-curious-logging-activity
tags:
  - data analysis
  - R
---
## The heartbeat of our logs


Logentries draws a neat linechart to visualize your logging activity. This chart is great for seeing if there are any errors appearing after a change, so you see at a glance if it's worth to check the logs. Looking at one of our services, this chart caught my eye:

![Entries](/static/2016-09-16-curious-logging-activity/screenshot.png)

At first sight this doesn't say very much apart from the fact that there are large bumps appearing at every 2 minutes (that's the frequency of the vertical lines). Regarding the other bumps there's not much we can say as they kind of blend in and it's hard to tell what's going on. Are they random or periodic too?

So i became curious and downloaded a 60 minute long log file to analyse.


```R
library(ggplot2)
library(data.table)

c <- read.csv("2016-04-04_181041_2016-04-04_191041.log", header=FALSE, sep = " ")
# We only need the timestamps of the logs
c <- c[,3]
c <- as.POSIXct(strptime(c, format="%Y-%m-%dT%H:%M:%OS", tz="GMT"))
# log span is ca. 60 minutes
span <- tail(c, n=1) - head(c, n=1)
```

I create a histogram with 10 second breaks (i.e 6 bin/minute)


```R
breaks <- floor(as.numeric(span, units="secs")/10)
x.time <- hist(c, plot = FALSE, breaks=breaks)
```

And apply Discrete Fourier Transform to the bins to get the frequency components:


```R
x.freq <- fft(x.time$counts)

spectrum <- function(X.k) {
  plot.data <- data.table(bin=0:(length(X.k)/2-1), amp=head(Mod(X.k), n=length(X.k)/2))
  plot.data[2:.N, amp:=2*amp]

  plot.data[bin>0] # Filter out the DC component
}

spectrum <- spectrum(x.freq)

ggplot(spectrum, aes(x=bin, y=amp)) + geom_bar(stat="identity")
```


    Error in file(con, "rb"): cannot open the connection




![png](/static/2016-09-16-curious-logging-activity/output_6_1.png)


Wow! The periodicity is so apparent it nearly gauges your eyes! But what are the exact frequencies?

Let's filter the peaks:


```R
spectrum[amp>1000]
```




<table>
<tbody>
  <tr><td>bin</td><td>amp</td></tr>
	<tr><td>30</td><td>1338.389</td></tr>
	<tr><td>60</td><td>3240.003</td></tr>
	<tr><td>90</td><td>1994.452</td></tr>
	<tr><td>120</td><td>1642.245</td></tr>
</tbody>
</table>




Multiples of 30 bins! That is...


```R
freq.minutes = 6
1/((30*freq.minutes)/length(x.freq))
```




2.00555555555556



That is very interesting. We found a base frequency of 2 minutes with a significant amplitude. That means the traffic to our service is indeed very periodic, not random.
