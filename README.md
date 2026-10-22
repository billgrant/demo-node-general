# demo-node-general

A hands-on Node.js demo of what changes when you move a JavaScript app onto Chainguard. You build the same small Express app three times, changing one thing each time, and scan each image with [grype](https://github.com/anchore/grype):

| Step | Base image | npm packages from | What it shows |
|---|---|---|---|
| 1 | `node:24` (Docker Hub) | public npm | The starting point: thousands of CVEs, runs as root |
| 2 | Chainguard `node:24-dev` | public npm | Swapping only the base image removes the OS-level CVEs |
| 3 | Chainguard `node:24-dev` | Chainguard Libraries for JavaScript | Malware is blocked at install time, packages are built from source, and remediated versions cut the remaining CVEs |

The whole run takes a few minutes. Each script stops before the scan so you can look at the build output first.

Adapted from the Python version of this demo, [andrewd-cg/demo-python-general](https://github.com/andrewd-cg/demo-python-general).

## What you need

**Tools**

- Docker with BuildKit (the default in current Docker Desktop, OrbStack, and Docker Engine)
- [grype](https://github.com/anchore/grype#installation)
- [chainctl](https://edu.chainguard.dev/chainguard/chainctl-usage/how-to-install-chainctl/) (steps 2 and 3)
- Node.js 24 and npm. Optional, only if you want to run the app outside a container

**Chainguard access (steps 2 and 3)**

Step 1 needs no Chainguard account. Steps 2 and 3 need a Chainguard organization that has:

- the `node` image, with the `24-dev` tag
- Chainguard Libraries for JavaScript, with upstream fallback. Step 3's lockfile includes a few packages served from Chainguard's `/javascript-upstream/` path

If you're not sure what your org has, ask your Chainguard admin or account team.

## Setup

### 1. Get the code

```bash
git clone <this-repo-url> demo-node-general
cd demo-node-general
```

### 2. Tell the scripts which Chainguard org to use

The Chainguard Dockerfiles pull from `cgr.dev/$CHAINGUARD_ORG/node:24-dev`, so no org name is hard-coded in the repo. Set it in your shell (and in `~/.zshrc` or `~/.bashrc` if you want it to stick):

```bash
export CHAINGUARD_ORG=your-org-name
```

The step 2 and 3 scripts stop with an error if it isn't set.

### 3. Log in to Chainguard

```bash
chainctl auth login
chainctl auth configure-docker                     # lets docker pull from cgr.dev
docker pull cgr.dev/$CHAINGUARD_ORG/node:24-dev    # confirms you have access
```

### 4. Create a Libraries pull token (step 3 only)

npm reads the token from `cg-libs/.npmrc`. That file is gitignored and dockerignored, so it never goes into git or an image layer.

`chainctl auth configure-npm` writes a project-level `.npmrc` in the directory you run it from, so run it from inside `cg-libs/`:

```bash
cd cg-libs
chainctl auth configure-npm --pull-token --parent="$CHAINGUARD_ORG" --ttl=720h
```

[`cg-libs/npmrc.example`](cg-libs/npmrc.example) shows what the file should look like, with `<pulltoken>` placeholders. It needs auth lines for both `/javascript/` and `/javascript-upstream/`.

Still inside `cg-libs/`, check that it works:

```bash
npm config get registry   # → https://libraries.cgr.dev/javascript/
npm ping
cd ..
```

## Run the demo

Each script builds an image, waits for **Enter**, then scans the image with grype. `run.sh` starts the image and calls the API, to prove the app still works after each change. Every script stops on the first error.

### Step 1: Docker Hub image

```bash
./build-and-scan-public.sh
./run.sh demo-node:public
```

Builds `demo-node:public` from [`Dockerfile`](Dockerfile) (`FROM node:24`). Look at the size of the grype report, and note that the container runs as root.

### Step 2: Chainguard image

```bash
./build-and-scan-cg.sh
./run.sh demo-node:cg
```

Builds `demo-node:cg` from [`cg.Dockerfile`](cg.Dockerfile). Diff it against `Dockerfile`: the base image is the only change. The OS-package CVEs go away, the image runs as a non-root user (65532), and what's left is in the npm packages, which still come from public npm.

### Step 3: Chainguard Libraries for JavaScript

```bash
./build-and-scan-cg-libs.sh
./run.sh demo-node:cg-libs
```

Now every npm package comes from `libraries.cgr.dev` instead of the public registry. The script runs in two parts.

**Part 1: malware is blocked.** The first build simulates a developer adding `tensorlake@0.5.144`, a package flagged as malware ([MAL-2026-17650](https://osv.dev/vulnerability/MAL-2026-17650): an obfuscated install script that went after credentials). **This build is supposed to fail.** You should see:

```
npm error 409 Conflict - GET https://libraries.cgr.dev/javascript/tensorlake - package withheld by the malware block-list
```

The package is never downloaded and nothing runs. As a safety net, this build uses its own tag (`demo-node:cg-libs-blocked`), and if it ever succeeds, the script deletes that image and exits. Don't run that image.

Press Enter to continue.

**Part 2: the clean build.** This builds with remediated versions of express and axios (`4.18.2-cgr.2` and `1.7.9-cgr.20`), then scans with grype.

To see where each package came from, run this from `cg-libs/` (it needs Node.js installed locally):

```bash
npm ci
chainctl libraries verify node_modules --detailed
```

### Full run, and starting over

```bash
./reset.sh
./build-and-scan-public.sh
./build-and-scan-cg.sh
./build-and-scan-cg-libs.sh
./run.sh demo-node:cg-libs
```

`reset.sh` removes the demo's built images but keeps the base images and build cache. `./reset.sh --full` also clears Docker's build cache for a true cold start, which means downloading everything again.

## Sample results

From a run on 2026-10-22. CVE counts change every day as new CVEs are published and fixes ship, so **your numbers will differ**. Look at the gap between the steps, not the exact counts.

| | Step 1: `node:24` | Step 2: Chainguard `node:24-dev` | Step 3: + Chainguard Libraries |
|---|---|---|---|
| Runs as | root | 65532 (non-root) | 65532 (non-root) |
| grype matches | 2,764 | 46 | **14** |
| Critical / High | 57 / 498 | 0 / 17 | **0 / 4** |
| OS-package matches | 2,705 | 0 | 0 |
| npm-package matches | 59 | 46 | 14 |
| Packages built from source by Chainguard | — | — | 74 of 77 |
| Malware (`tensorlake@0.5.144`) | — | — | **Blocked (409)** |

What's left after step 3:

- `path-to-regexp@0.1.7` (3 high). express 4 needs the 0.1.x line, and the remediated express still uses it.
- `body-parser`, `qs`, `cookie`, `send`, `serve-static` (1 high, the rest medium/low). They come in through express. The remediated express patches its own code but keeps the same dependency versions.
- 3 medium axios CVEs, fixed upstream in 1.20.0, which is newer than `1.7.9-cgr.20`.

## How it works

### The app

[`app.js`](app.js) is a small Express API that fetches 10 stock quotes from Yahoo Finance at once, using axios.

| Endpoint | Returns |
|---|---|
| `GET /quotes` | Plain-text table |
| `GET /quotes?format=json` | JSON |
| `GET /healthz` | `ok` |

To run it without Docker:

```bash
npm ci       # installs exactly what's in package-lock.json
npm start    # listens on :3000; set PORT to change it
curl localhost:3000/quotes
```

The dependencies are pinned to exact, older versions (`express@4.18.2`, `axios@1.7.9`, no `^`), so the demo always has known CVEs to show. Those two direct dependencies install 77 packages.

### Why step 3 has its own `cg-libs/` folder

Chainguard builds npm packages from source, so its tarballs aren't byte-for-byte the same as public npm's, and the integrity hashes in the lockfile differ. Steps 1–2 and step 3 can't share one `package-lock.json`, so `cg-libs/` has its own `package.json` and lockfile. The lockfile was converted with `chainctl libraries update-hashes`. To see the differences:

```bash
git diff --no-index package.json cg-libs/package.json            # two versions gain -cgr.N
git diff --no-index package-lock.json cg-libs/package-lock.json  # URLs and hashes
```

### Remediated `-cgr.N` versions

`express@4.18.2-cgr.2` and `axios@1.7.9-cgr.20` are the same upstream versions, with CVE fixes backported by Chainguard. npm treats `-cgr.N` as a semver prerelease, so it never picks one on its own. You have to pin them exactly (`npm install --save-exact`). To see what's available, run this from `cg-libs/`:

```bash
npm view express versions --json | grep cgr
```

JavaScript CVE remediation is in beta and has a small catalog, so some CVEs remain after step 3. They're mostly in express's transitive dependencies, such as `path-to-regexp@0.1.7`, which the remediated express still uses.

### The token never goes into an image

[`cg-libs.Dockerfile`](cg-libs.Dockerfile) gets `.npmrc` only through a BuildKit secret mount (`--mount=type=secret`), so the token is there during `npm ci` but never written to an image layer. `.dockerignore` also keeps any `.npmrc` out of the build context.

### `--allow-remote=all`

The Chainguard Node image ships npm 12, which by default refuses packages served from somewhere other than the configured registry (`allow-remote=none`, error `EALLOWREMOTE`). Chainguard serves its upstream fallback packages from `/javascript-upstream/`, so `cg-libs.Dockerfile` passes `--allow-remote=all`. That's safe here because every URL in the lockfile is on `libraries.cgr.dev`. To check:

```bash
grep '"resolved"' cg-libs/package-lock.json | grep -vc 'libraries.cgr.dev'   # → 0
```

### How the malware package stays out

`tensorlake` is never in `package.json` or a lockfile. It's added only in `cg-libs.Dockerfile`, behind a build arg (`ADD_BLOCKED_PKG`, off by default), with `npm install --no-save --ignore-scripts`. Steps 1 and 2 install from public npm and never reference it.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `CHAINGUARD_ORG: Set CHAINGUARD_ORG to your Chainguard org name` | `export CHAINGUARD_ORG=your-org-name` (setup step 2) |
| `Missing cg-libs/.npmrc` | Create the pull token (setup step 4) |
| `docker pull cgr.dev/...` fails | Run `chainctl auth login` and `chainctl auth configure-docker`, and check that your org has the `node` image with the `24-dev` tag |
| `npm error 401` or `403` from `libraries.cgr.dev` | The token is missing, expired, or in the wrong file. Recreate `cg-libs/.npmrc` and check it with `npm ping` from `cg-libs/` |
| `EALLOWREMOTE` | Use the repo's `cg-libs.Dockerfile`, which passes `--allow-remote=all` |
| `/quotes` shows `error:` lines | Yahoo Finance rate-limited or blocked the request. The app is fine; try again in a minute |
| Port 3000 already in use | Stop whatever is using it, or run `docker rm -f demo-node-general` if an earlier `run.sh` was interrupted |

## Files

| File | Purpose |
|---|---|
| `app.js` | Express server: `/quotes`, `/healthz` |
| `package.json`, `package-lock.json` | Steps 1–2: exact pins, public npm URLs and hashes |
| `cg-libs/package.json`, `cg-libs/package-lock.json` | Step 3: remediated versions, `libraries.cgr.dev` URLs and hashes |
| `cg-libs/npmrc.example` | What `cg-libs/.npmrc` should look like, with placeholders. Safe to show on screen |
| `cg-libs/.npmrc` | Your pull token. **Not in git**; you create it (setup step 4) |
| `Dockerfile` | Step 1: `FROM node:24` |
| `cg.Dockerfile` | Step 2: `FROM cgr.dev/${CHAINGUARD_ORG}/node:24-dev` |
| `cg-libs.Dockerfile` | Step 3: same base, installs from Chainguard Libraries with a secret-mounted `.npmrc`; `ADD_BLOCKED_PKG` build arg for the malware test |
| `build-and-scan-public.sh` | Step 1: build `demo-node:public`, pause, scan |
| `build-and-scan-cg.sh` | Step 2: build `demo-node:cg`, pause, scan |
| `build-and-scan-cg-libs.sh` | Step 3: malware build (expected to fail), pause, clean build, pause, scan |
| `run.sh` | Run an image on :3000 and call `/quotes`. Usage: `./run.sh demo-node:cg` |
| `reset.sh` | Remove the demo's built images; `--full` also clears the build cache |
| `.grype.yaml` | Ignores grype's binary-cataloger matches, which double-count CVEs in the `node` binary |
| `.dockerignore` | Keeps `.npmrc`, `node_modules/`, and `.git/` out of the Docker build context |
| `.gitignore` | Keeps `.npmrc` and `node_modules/` out of git |
