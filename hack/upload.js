#!/usr/bin/env node
'use strict'

import AWS from 'aws-sdk'
import s3diff from 's3-diff'
import { eachLimit } from 'async'
import mime from 'mime'
import { promisify as p } from 'util'
import pino from 'pino'
import { parseArgs } from 'node:util'

const log = pino({level: process.env.LOG_LEVEL || 'info'})

const updates = async (local, bucket) => {
  return await new Promise((resolve, reject) => {
    s3diff({ local, remote: { bucket }, recursive: true }, (err, data) => {
      if (err) {
        reject(err)
      } else {
        resolve(data.changed.concat(data.extra))
      }
    })
  })
}

const upload = async (local, bucket, filenames, {dryrun} = {dryrun: false}) => {
  const s3 = new AWS.S3()
  const upload = p(s3.upload).bind(s3)
  await eachLimit(filenames, 8, async function(filename) {
    if (dryrun) {
      log.info(`would sync ${filename}`)
      return
    }
    const fd = await open(path.join(local, filename));
    const stream = fd.createReadStream()
    await upload({ Bucket: bucket, Key: filename, Body: stream, ContentType: mime.getType(filename) })
    log.info(`synced ${filename}`)
  })
}

const invalidateCloudfront = async (distribution, filenames, {dryrun} = {dryrun: false}) => {
  const cloudfront = new AWS.CloudFront()
  const createInvalidation = p(cloudfront.createInvalidation).bind(cloudfront)
  const invalidationBatch = new Date().toISOString()
  const paths = {
    Quantity: filenames.length,
    Items: filenames.map(p => `/${p}`)
  }

  if (dryrun) {
    log.info(`would invalidate ${distribution} ${invalidationBatch} ${JSON.stringify(paths)}`)
    return
  }

  await createInvalidation({
    DistributionId: distribution,
    InvalidationBatch: {
      CallerReference: invalidationBatch,
      Paths: paths
    }
  })
  log.info(`invalidated ${distribution} ${invalidation.Invalidation.Id}`)
}

const options = {
  distribution: {
    type: 'string',
    alias: 'd',
    describe: 'Cloudfront distribution ID'
  },
  dryrun: {
    type: 'boolean',
    alias: 'n',
    describe: 'Don\'t actually upload anything'
  }
}

const { values, positionals } = parseArgs({ args: process.argv.slice(2), options, allowPositionals: true })

if (positionals.length != 2) {
  console.error("usage: upload [--distribution|-d distribution] [--dryrun|-n] local bucket")
  process.exit(1)
}

const [local, bucket] = positionals
const { dryrun } = values
const filenames = await updates(local, bucket)
if (filenames.length == 0) {
  log.info("no changes")
  process.exit(0)
}
await upload(local, bucket, filenames, {dryrun})

if (values.distribution) {
  await invalidateCloudfront(values.distribution, filenames, {dryrun})
}
