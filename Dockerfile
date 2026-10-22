FROM node:24

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY app.js .

EXPOSE 3000
ENTRYPOINT ["node", "app.js"]
