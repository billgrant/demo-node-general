ARG CHAINGUARD_ORG=your-org
FROM cgr.dev/${CHAINGUARD_ORG}/node:24-dev

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY app.js .

EXPOSE 3000
ENTRYPOINT ["node", "app.js"]
