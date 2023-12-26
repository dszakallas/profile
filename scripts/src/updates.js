#!/usr/bin/env node
'use strict'

import s3diff from 's3-diff'

if (process.argv.length != 4) {
    console.error("usage: diff local bucket")
    process.exit(1)
}

s3diff({
    local: process.argv[2],
    remote: { bucket: process.argv[3] },
    recursive: true
}, (err, data) => {
  console.log(JSON.stringify(data.changed.concat(data.extra)))
});
