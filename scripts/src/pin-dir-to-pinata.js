#!/usr/bin/env node
'use strict'

const axios = require('axios');
const fs = require('fs');
const readdir = require('fs/promises').readdir;
const path = require('path');
const FormData = require('form-data');

async function main() {
  if (process.argv.length != 4) {
    console.error("usage: pin-directory-to-ipfs name directory")
    process.exit(1)
  }

  if (process.env.PINATA_API_KEY == null) {
    console.error("PINATA_API_KEY not set")
    process.exit(1)
  }

  if (process.env.PINATA_SECRET_API_KEY == null) {
    console.error("PINATA_SECRET_API_KEY not set")
    process.exit(1)
  }

  await pinDirectoryToIPFS(process.argv[2], process.argv[3], process.env.PINATA_API_KEY, process.env.PINATA_SECRET_API_KEY);
}

async function pinDirectoryToIPFS(name, src, pinataApiKey, pinataSecretApiKey) {
  const url = `https://api.pinata.cloud/pinning/pinFileToIPFS`;
  const files = await getFiles(src);
  const data = new FormData();

  const metadata = JSON.stringify({ name })
  data.append('pinataMetadata', metadata);

  files.forEach((file) => {
    const filepath = path.join(name, path.relative(src, file))
    //for each file stream, we need to include the correct relative file path
    data.append(`file`, fs.createReadStream(file), { filepath });
  });

  await axios.post(url, data, {
    maxBodyLength: 'Infinity', //this is needed to prevent axios from erroring out with large directories
    headers: {
      'Content-Type': `multipart/form-data; boundary=${data._boundary}`,
      pinata_api_key: pinataApiKey,
      pinata_secret_api_key: pinataSecretApiKey
    }
  });
};

async function getFiles(basePath) {
  const entries = await readdir(basePath, { withFileTypes: true });

  const files = entries
        .filter(file => !file.isDirectory())
        .map(file => path.join(basePath, file.name));

  const folders = entries.filter(folder => folder.isDirectory());

  for (const folder of folders)
    files.push(...await getFiles(path.join(basePath, folder.name)));

  return files;
}

main();
