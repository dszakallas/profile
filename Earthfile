VERSION 0.6

deps:
    FROM DOCKERFILE .

site:
    FROM +deps
    COPY src /srv/jekyll
    RUN jekyll build
    SAVE ARTIFACT ./_site AS LOCAL src/_site

future-site:
    FROM +deps
    COPY src /srv/jekyll
    RUN jekyll build --future
    SAVE ARTIFACT ./_site AS LOCAL src/_site

scripts:
    FROM node:16-alpine
    WORKDIR workspace
    COPY scripts/package.json scripts/package-lock.json .
    RUN npm install
    COPY scripts/src src

updates:
    ARG --required BUCKET_NAME
    FROM +scripts
    COPY +site/_site _site
    RUN --secret AWS_ACCESS_KEY_ID \
        --secret AWS_SECRET_ACCESS_KEY \
        npm run --silent updates -- _site ${BUCKET_NAME} > updates.json
    SAVE ARTIFACT ./updates.json

upload-to-s3:
    ARG --required BUCKET_NAME
    FROM +scripts
    COPY +site/_site _site
    COPY (+updates/updates.json --BUCKET_NAME=$BUCKET_NAME) updates.json
    RUN --secret AWS_ACCESS_KEY_ID \
        --secret AWS_SECRET_ACCESS_KEY \
        npm run --silent upload -- updates.json _site ${BUCKET_NAME}

invalidate-cf:
    ARG --required BUCKET_NAME
    FROM +scripts
    COPY (+updates/updates.json --BUCKET_NAME=$BUCKET_NAME) updates.json
    RUN --secret AWS_ACCESS_KEY_ID \
        --secret AWS_SECRET_ACCESS_KEY \
        --secret DISTRIBUTION \
        npm run --silent invalidate-cf -- updates.json
