VERSION 0.6

deps:
    FROM DOCKERFILE .

site:
    FROM +deps
    COPY src /srv/jekyll
    ARG JEKYLL_BUILD_ARGS
    RUN jekyll build ${JEKYLL_BUILD_ARGS}
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
    ARG JEKYLL_BUILD_ARGS
    COPY (+site/_site --JEKYLL_BUILD_ARGS=${JEKYLL_BUILD_ARGS}) _site
    RUN --secret AWS_ACCESS_KEY_ID \
        --secret AWS_SECRET_ACCESS_KEY \
        npm run --silent updates -- _site ${BUCKET_NAME} > updates.json
    SAVE ARTIFACT ./updates.json

upload-to-s3:
    ARG --required BUCKET_NAME
    FROM +scripts
    ARG JEKYLL_BUILD_ARGS
    COPY (+site/_site --JEKYLL_BUILD_ARGS=${JEKYLL_BUILD_ARGS}) _site
    COPY (+updates/updates.json --BUCKET_NAME=$BUCKET_NAME) updates.json
    RUN --secret AWS_ACCESS_KEY_ID \
        --secret AWS_SECRET_ACCESS_KEY \
        npm run --silent upload -- updates.json _site ${BUCKET_NAME}

invalidate-cf:
    ARG --required BUCKET_NAME
    FROM +scripts
    ARG JEKYLL_BUILD_ARGS
    COPY (+updates/updates.json --JEKYLL_BUILD_ARGS=${JEKYLL_BUILD_ARGS} --BUCKET_NAME=$BUCKET_NAME) updates.json
    RUN --secret AWS_ACCESS_KEY_ID \
        --secret AWS_SECRET_ACCESS_KEY \
        --secret DISTRIBUTION \
        npm run --silent invalidate-cf -- updates.json
