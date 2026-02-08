#!/usr/bin/env node
import { S3Client, ListObjectsV2Command, DeleteObjectsCommand } from '@aws-sdk/client-s3'
import { Upload } from '@aws-sdk/lib-storage'
import { CloudFrontClient, CreateInvalidationCommand } from '@aws-sdk/client-cloudfront'
import { eachLimit } from 'async'
import mime from 'mime'
import { open, readdir, stat } from 'fs/promises'
import pino from 'pino'
import path from 'path'
import { parseArgs } from 'node:util'

const log = pino({level: process.env.LOG_LEVEL || 'info'})

const walkDir = async (dir, baseDir = dir) => {
  const files = []
  const entries = await readdir(dir, { withFileTypes: true })
  
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      files.push(...await walkDir(fullPath, baseDir))
    } else {
      const relativePath = path.relative(baseDir, fullPath)
      files.push(relativePath)
    }
  }
  return files
}

const getLocalFiles = async (localDir) => {
  const filenames = await walkDir(localDir)
  const fileMap = new Map()
  
  for (const filename of filenames) {
    const fullPath = path.join(localDir, filename)
    const stats = await stat(fullPath)
    fileMap.set(filename, {
      size: stats.size,
      mtime: stats.mtime
    })
  }
  return fileMap
}

const getS3Files = async (bucket) => {
  const s3Client = new S3Client({})
  const fileMap = new Map()
  let continuationToken
  
  do {
    const command = new ListObjectsV2Command({
      Bucket: bucket,
      ContinuationToken: continuationToken
    })
    const response = await s3Client.send(command)
    
    if (response.Contents) {
      for (const obj of response.Contents) {
        fileMap.set(obj.Key, {
          size: obj.Size,
          etag: obj.ETag
        })
      }
    }
    continuationToken = response.NextContinuationToken
  } while (continuationToken)
  
  return fileMap
}

const updates = async (local, bucket) => {
  const localFiles = await getLocalFiles(local)
  const s3Files = await getS3Files(bucket)
  const toAdd = []
  const toModify = []
  const toDelete = []
  
  for (const [filename, localInfo] of localFiles) {
    const s3Info = s3Files.get(filename)
    
    if (!s3Info) {
      // File doesn't exist in S3 - it's new
      toAdd.push(filename)
    } else if (s3Info.size !== localInfo.size) {
      // File exists but has different size - it's modified
      toModify.push(filename)
    }
  }
  
  // Find files in S3 that don't exist locally
  for (const filename of s3Files.keys()) {
    if (!localFiles.has(filename)) {
      toDelete.push(filename)
    }
  }
  
  return { toAdd, toModify, toDelete }
}

const upload = async (local, bucket, filenames, operation, {dryrun} = {dryrun: false}) => {
  const s3Client = new S3Client({})
  await eachLimit(filenames, 8, async function(filename) {
    if (dryrun) {
      log.info(`would ${operation} ${filename}`)
      return
    }
    const fd = await open(path.join(local, filename));
    const stream = fd.createReadStream()
    const uploader = new Upload({
      client: s3Client,
      params: { Bucket: bucket, Key: filename, Body: stream, ContentType: mime.getType(filename) }
    })
    await uploader.done()
    log.info(`${operation} ${filename}`)
  })
}

const deleteFromS3 = async (bucket, filenames, {dryrun} = {dryrun: false}) => {
  if (filenames.length === 0) {
    return
  }
  
  const s3Client = new S3Client({})
  
  // Delete in batches of 1000 (S3 limit)
  for (let i = 0; i < filenames.length; i += 1000) {
    const batch = filenames.slice(i, i + 1000)
    
    if (dryrun) {
      batch.forEach(filename => log.info(`would delete ${filename}`))
      continue
    }
    
    const command = new DeleteObjectsCommand({
      Bucket: bucket,
      Delete: {
        Objects: batch.map(Key => ({ Key })),
        Quiet: false
      }
    })
    
    const response = await s3Client.send(command)
    if (response.Deleted) {
      response.Deleted.forEach(obj => log.info(`deleted ${obj.Key}`))
    }
    if (response.Errors) {
      response.Errors.forEach(err => log.error(`failed to delete ${err.Key}: ${err.Message}`))
    }
  }
}

const invalidateCloudfront = async (distribution, filenames, {dryrun} = {dryrun: false}) => {
  const cloudfrontClient = new CloudFrontClient({})
  const invalidationBatch = new Date().toISOString()
  const paths = {
    Quantity: filenames.length,
    Items: filenames.map(p => `/${p}`)
  }

  if (dryrun) {
    log.info(`would invalidate ${distribution} ${invalidationBatch} ${JSON.stringify(paths)}`)
    return
  }

  const command = new CreateInvalidationCommand({
    DistributionId: distribution,
    InvalidationBatch: {
      CallerReference: invalidationBatch,
      Paths: paths
    }
  })
  await cloudfrontClient.send(command)
  log.info(`invalidated ${distribution} ${invalidationBatch} ${JSON.stringify(paths)}`)
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
const { toAdd, toModify, toDelete } = await updates(local, bucket)

if (toAdd.length === 0 && toModify.length === 0 && toDelete.length === 0) {
  log.info("no changes")
  process.exit(0)
}

await deleteFromS3(bucket, toDelete, {dryrun})
await upload(local, bucket, toModify, 'modified', {dryrun})
await upload(local, bucket, toAdd, 'added', {dryrun})

const allChangedFiles = [...toAdd, ...toModify, ...toDelete]
if (values.distribution && allChangedFiles.length > 0) {
  await invalidateCloudfront(values.distribution, allChangedFiles, {dryrun})
}
