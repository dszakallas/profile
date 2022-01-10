#!/usr/bin/env node
'use strict'

const AWS = require('aws-sdk')
const p = require('util').promisify
const readFile = require('fs/promises').readFile

async function main() {
  if (process.env.DISTRIBUTION == null) {
    console.error("DISTRIBUTION not set")
    process.exit(1)
  }
  if (process.argv.length != 3) {
    console.error("usage: invalidate-cf file_list")
  }
  const distribution = process.env.DISTRIBUTION
  const cf = new AWS.CloudFront()

  const object_list = JSON.parse(await readFile(process.argv[2]))
  const createInvalidation = p(cf.createInvalidation).bind(cf)
  const invalidationBatch = new Date().toISOString()

  const params = {
    DistributionId: distribution,
    InvalidationBatch: {
      CallerReference: invalidationBatch,
      Paths: {
        Quantity: object_list.length,
        Items: object_list.map(p => `/${p}`)
      }
    }
  }

  await createInvalidation(params)
}

main()
