ARG CHAINGUARD_ORG=your-org
FROM cgr.dev/${CHAINGUARD_ORG}/node:24-dev

WORKDIR /app

COPY cg-libs/package.json cg-libs/package-lock.json ./
# npm 12 refuses Chainguard's /javascript-upstream/ tarballs by default.
# Safe here: every resolved URL in the lockfile is libraries.cgr.dev.
RUN --mount=type=secret,id=npmrc,target=/app/.npmrc,uid=65532 \
    npm ci --omit=dev --allow-remote=all

# Demo beat: a developer adds a package Chainguard has flagged as malware
# (tensorlake 0.5.144, MAL-2026-17650). Off by default; the step 3 script
# turns it on for a first build that should fail at the Chainguard endpoint.
ARG ADD_BLOCKED_PKG=false
RUN --mount=type=secret,id=npmrc,target=/app/.npmrc,uid=65532 \
    if [ "$ADD_BLOCKED_PKG" = "true" ]; then \
      npm install --no-save --ignore-scripts --allow-remote=all \
        tensorlake@0.5.144 ; \
    fi

COPY app.js .

EXPOSE 3000
ENTRYPOINT ["node", "app.js"]
