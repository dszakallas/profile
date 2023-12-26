VERSION 0.7

deps:
    FROM DOCKERFILE .

site:
    FROM +deps
    COPY src /site
    ARG JEKYLL_BUILD_ARGS
    ARG JEKYLL_ENV
    ENV JEKYLL_ENV=$JEKYLL_ENV
    RUN jekyll build ${JEKYLL_BUILD_ARGS}
    SAVE ARTIFACT ./_site AS LOCAL src/_site

scripts:
    FROM node:18-alpine
    WORKDIR workspace
    COPY scripts/package.json scripts/package-lock.json .
    RUN npm install
    COPY scripts/src src

updates:
    ARG --required BUCKET_NAME
    FROM +scripts
    ARG JEKYLL_BUILD_ARGS
    ARG JEKYLL_ENV
    COPY (+site/_site --JEKYLL_BUILD_ARGS=$JEKYLL_BUILD_ARGS --JEKYLL_ENV=$JEKYLL_ENV) _site
    RUN --secret AWS_ACCESS_KEY_ID \
        --secret AWS_SECRET_ACCESS_KEY \
        npm run --silent updates -- _site ${BUCKET_NAME} > updates.json
    SAVE ARTIFACT ./updates.json AS LOCAL build/updates.json

upload-to-s3:
    ARG --required BUCKET_NAME
    FROM +scripts
    ARG JEKYLL_BUILD_ARGS
    ARG JEKYLL_ENV
    COPY (+site/_site --JEKYLL_BUILD_ARGS=$JEKYLL_BUILD_ARGS --JEKYLL_ENV=$JEKYLL_ENV) _site
    COPY (+updates/updates.json --BUCKET_NAME=$BUCKET_NAME) updates.json
    RUN --secret AWS_ACCESS_KEY_ID \
        --secret AWS_SECRET_ACCESS_KEY \
        npm run --silent upload -- updates.json _site ${BUCKET_NAME}

invalidate-cf:
    ARG --required BUCKET_NAME
    FROM +scripts
    ARG JEKYLL_BUILD_ARGS
    ARG JEKYLL_ENV
    COPY (+updates/updates.json --JEKYLL_BUILD_ARGS=$JEKYLL_BUILD_ARGS --JEKYLL_ENV=$JEKYLL_ENV --BUCKET_NAME=$BUCKET_NAME) updates.json
    RUN --secret AWS_ACCESS_KEY_ID \
        --secret AWS_SECRET_ACCESS_KEY \
        --secret DISTRIBUTION \
        npm run --silent invalidate-cf -- updates.json
