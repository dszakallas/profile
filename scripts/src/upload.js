#!/usr/bin/env node
'use strict'

const AWS = require('aws-sdk')
const p = require('util').promisify
const open = require('fs/promises').open
const readFile = require('fs/promises').readFile
const path = require('path')
const eachLimit = require('async/eachLimit')
const mime = require('mime/lite')

async function main() {
  if (process.argv.length != 5) {
    console.error("usage: upload file_list src bucket")
    process.exit(1)
  }
  const bucket = process.argv[4]
  const src = process.argv[3]
  const object_list = JSON.parse(await readFile(process.argv[2]))

  const s3 = new AWS.S3()
  const upload = p(s3.upload).bind(s3)

  await eachLimit(object_list, 4, async function(object) {
    const fd = await open(path.join(src, object));
    const stream = fd.createReadStream()
    await upload({ Bucket: bucket, Key: object, Body: stream, ContentType: mime.getType(object) })
    console.error(`synced ${object}`)
  })
}

main()
