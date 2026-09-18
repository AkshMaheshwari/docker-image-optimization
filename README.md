# Docker Image Optimization using Jenkins CI/CD

A college DevOps project demonstrating a complete CI/CD pipeline: a Node.js/Express
application is built, tested, containerized, optimized, pushed to Docker Hub by
Jenkins, and deployed to Render.

Live demo: **https://docker-image-optimization.onrender.com**
Docker Hub image: **[akshm23/docker-image-optimization](https://hub.docker.com/r/akshm23/docker-image-optimization)**

---

## 1. Project Overview

This project demonstrates the full software delivery lifecycle for a small web
service, with a specific focus on **Docker image optimization**: we build the
same application two different ways (a naive "baseline" image and an
"optimized" image) and measure the real difference in size and build time.

The end-to-end pipeline is:

```
GitHub → Jenkins → Application Build → Automated Tests → Docker Build
       → Optimized Docker Image → Docker Hub → Render → Running Container
       → Public URL
```

The project is intentionally kept simple (no Kubernetes, no microservices, no
monitoring stack) so it can be fully understood, built, and demonstrated live
by three students within a single session.

## 2. Architecture

```
Developer
   ↓
GitHub  (source control, triggers Jenkins via SCM)
   ↓
Jenkins  (running locally on Windows, port 8080)
   ↓
Build            (npm ci, node --check)
   ↓
Test             (Jest + Supertest)
   ↓
Docker Build     (Dockerfile.optimized)
   ↓
Optimized Docker Image
   ↓
Docker Hub       (image registry)
   ↓
Render           (pulls the image, runs the container)
   ↓
Docker Container
   ↓
Public Application  (https://docker-image-optimization.onrender.com)
```

## 3. Technologies Used

| Category | Technology |
|---|---|
| Runtime | Node.js |
| Web framework | Express |
| Testing | Jest, Supertest |
| Containerization | Docker |
| Image registry | Docker Hub |
| CI/CD | Jenkins (declarative pipeline) |
| Deployment | Render (Web Service from a Docker image) |
| Version control | Git / GitHub |

## 4. Prerequisites

To build and run this project locally you need:

- [Node.js](https://nodejs.org/) (v18+; developed and tested on v24)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Git](https://git-scm.com/)
- A [Docker Hub](https://hub.docker.com/) account (for pushing images)
- A [Render](https://render.com/) account (for deployment)
- [Jenkins](https://www.jenkins.io/) (for the CI/CD pipeline — can run locally)

## 5. Local Application Setup

```bash
git clone https://github.com/AkshMaheshwari/docker-image-optimization.git
cd docker-image-optimization
npm install
npm start
```

The server starts on `http://localhost:3000` (or the port set in the `PORT`
environment variable). Verify it manually:

```bash
curl http://localhost:3000/
curl http://localhost:3000/health
```

Expected: an HTML page saying "Docker Image Optimization Demo", and
`{"status":"healthy"}` from `/health`.

## 6. Running Tests

```bash
npm test
```

This runs the Jest + Supertest suite in [tests/server.test.js](tests/server.test.js),
covering:

1. `GET /` returns HTTP 200
2. `GET /health` returns HTTP 200
3. `GET /health` returns `{"status":"healthy"}`

## 7. Building the Baseline Docker Image

[Dockerfile.baseline](Dockerfile.baseline) intentionally uses less efficient
practices for comparison purposes: a full `node:latest` base image, no
`.dockerignore` awareness, and `npm install` (including dev dependencies).

```bash
docker build -f Dockerfile.baseline -t docker-image-optimization:baseline .
```

## 8. Running the Baseline Image

```bash
docker run -d -p 3001:3000 --name baseline-test docker-image-optimization:baseline
curl http://localhost:3001/
curl http://localhost:3001/health
docker rm -f baseline-test
```

## 9. Building the Optimized Docker Image

[Dockerfile.optimized](Dockerfile.optimized) applies techniques that make
sense for this specific application:

- **Smaller base image** — `node:20-alpine` instead of `node:latest`
- **Efficient layer ordering** — dependency manifests are copied and installed
  *before* application source, so code changes don't invalidate the
  dependency-install cache layer
- **`.dockerignore`** — excludes `node_modules`, `.git`, `tests`, `coverage`,
  env files, etc. from the build context (see [.dockerignore](.dockerignore))
- **`npm ci`** instead of `npm install` — faster, reproducible installs from
  `package-lock.json`
- **Production dependencies only** — `npm ci --omit=dev` skips Jest/Supertest,
  which aren't needed at runtime
- **No multi-stage build** — deliberately omitted. This app has no
  compile/transpile step, so a build stage wouldn't strip anything that
  `--omit=dev` and `.dockerignore` don't already exclude. Adding one would be
  complexity without benefit.

```bash
docker build -f Dockerfile.optimized -t docker-image-optimization:optimized .
```

## 10. Running the Optimized Image

```bash
docker run -d -p 3002:3000 --name optimized-test docker-image-optimization:optimized
curl http://localhost:3002/
curl http://localhost:3002/health
docker rm -f optimized-test
```

The optimized image behaves **identically** to the baseline — same routes,
same responses, same port — only the image itself is smaller and faster to
build.

## 11. Comparing the Images

Run the provided benchmarking script from the project root:

```bash
bash scripts/benchmark.sh
```

This rebuilds both images with `--no-cache` and reports build time, image
size, and layer count for each ([scripts/benchmark.sh](scripts/benchmark.sh)).
You can also inspect them manually:

```bash
docker images docker-image-optimization
docker history docker-image-optimization:baseline
docker history docker-image-optimization:optimized
```

### Actual measured results (this machine, both base images already cached locally)

| Metric | Baseline | Optimized |
|---|---|---|
| Image size | 1.85 GB | **202 MB** (~9x smaller) |
| Build time (`--no-cache`) | 9s | 4s |
| Total layers | 15 | 16 |

**Note on layer count:** total layer count includes the base image's own
layers, and Alpine happens to slice its base into slightly more layers than
Debian does — so layer count isn't the meaningful metric for this comparison.
**Image size is the headline result**: switching from `node:latest` to
`node:20-alpine` plus `npm ci --omit=dev` and a `.dockerignore` cuts the image
down by roughly 9x. If you re-run the benchmark on a different machine or after
`docker system prune`, your build-time numbers will differ since they'll
include the base image pull — that's expected; only report what you actually
measure.

## 12. Docker Hub Setup

1. Create a free account at [hub.docker.com](https://hub.docker.com)
2. Create a repository (e.g. `docker-image-optimization`), public or private
3. Generate an **access token**: Account Settings → Security → Personal
   access tokens → Generate new token, with **Read & Write** permission.
   Copy it immediately — it's only shown once.
4. Do **not** commit this token anywhere. It is only ever pasted into Jenkins'
   credential store (see below).

## 13. Jenkins Setup

This project assumes a Jenkins instance is reachable (locally at
`http://localhost:8080` during development, or wherever your team hosts it).

**Windows-specific gotcha:** if Jenkins runs as a native Windows service
(check with `Get-Service Jenkins` / Task Manager → Services), it runs under
the `LocalSystem` account, which only reads the **machine-level** `PATH` —
not any individual user's PATH. If `docker` isn't on the machine PATH, `docker
build`/`docker push` steps will fail with "docker is not recognized" even
though `docker` works fine in your own terminal. Fix:

```powershell
# Run as Administrator
$dockerBin = "C:\Users\<you>\AppData\Local\Programs\DockerDesktop\resources\bin"
$current = [Environment]::GetEnvironmentVariable('Path','Machine')
[Environment]::SetEnvironmentVariable('Path', "$current;$dockerBin", 'Machine')
Restart-Service -Name Jenkins -Force
```

Because pipeline stages use `bat` (Windows batch), not `sh`, this Jenkinsfile
only works on a Windows Jenkins agent. If your team's Jenkins runs on Linux or
WSL instead, the `bat` steps would need to be changed to `sh`.

## 14. Jenkins Credentials

The Jenkinsfile never hardcodes secrets — it reads them from Jenkins'
credential store at runtime via `withCredentials`. You must create these two
**Secret text** credentials under **Manage Jenkins → Credentials → System →
Global credentials → Add Credentials**:

| Credential ID | Kind | Value |
|---|---|---|
| `dockerhub-credentials` | Secret text | Your Docker Hub access token (from step 12) |
| `render-deploy-hook-url` | Secret text | Your Render service's Deploy Hook URL (from step 16) |

The IDs must match exactly — the Jenkinsfile looks them up by these names.

## 15. Jenkins Pipeline Configuration

1. Create a new **Pipeline** job in Jenkins
2. Under **Pipeline**, set **Definition** to **"Pipeline script from SCM"**
   (not "Pipeline script" — the Jenkinsfile uses `checkout scm`, which only
   resolves to a real repository when the job itself is SCM-configured)
3. **SCM**: Git
4. **Repository URL**: `https://github.com/AkshMaheshwari/docker-image-optimization.git`
5. **Branch Specifier**: `*/master`
6. **Script Path**: `Jenkinsfile`
7. Save

The pipeline exposes two build parameters (`DOCKERHUB_USERNAME`,
`DOCKERHUB_REPOSITORY`) — fill these in with your own Docker Hub username and
repository name when running **Build with Parameters**.

### Pipeline stages

1. **Checkout** — pulls the repo from GitHub
2. **Install Dependencies** — `npm ci`
3. **Run Tests** — `npm test` (Jest + Supertest)
4. **Application Build** — `node --check src/server.js` (there's no
   compiler for plain Express, so this validates the entry point parses
   cleanly before it goes into an image)
5. **Build Docker Image** — builds `Dockerfile.optimized`, tagged with the
   Jenkins build number and `latest`
6. **Validate Docker Container** — runs the freshly built image, curls
   `/health`, then tears the container down
7. **Push Docker Image to Docker Hub** — logs in using the
   `dockerhub-credentials` token and pushes both tags
8. **Deployment Trigger** — POSTs to the Render deploy hook
   (`render-deploy-hook-url`), which tells Render to pull the new `latest`
   image and redeploy

## 16. Render Deployment

1. Log into [dashboard.render.com](https://dashboard.render.com)
2. **New → Web Service → "Deploy an existing image from a registry"**
3. **Image URL**: `docker.io/<your-dockerhub-username>/<your-repo>:latest`
4. Instance type: Free (or any tier your team prefers)
5. Create the service — Render pulls and runs the image, exposing it on a
   public `https://<service-name>.onrender.com` URL
6. The app listens on `process.env.PORT`, which Render sets automatically —
   no extra configuration needed
7. In the service's **Settings → Deploy Hook**, copy the deploy hook URL and
   store it in Jenkins as the `render-deploy-hook-url` credential (step 14)

The deployed service exposes the same two routes as local development:
`/` and `/health`.

## 17. Complete CI/CD Flow

Once everything above is configured, a single Jenkins build performs the
entire flow with no manual steps:

```
Jenkins pulls latest code from GitHub
  → installs dependencies
  → runs the test suite
  → validates the app entry point
  → builds the optimized Docker image
  → runs the image locally and health-checks it
  → pushes the image to Docker Hub
  → tells Render to redeploy the new image
  → Render pulls the image and serves it publicly
```

This was verified working end-to-end on 2026-09-18: Jenkins build succeeded
(`Finished: SUCCESS`), the image was pushed to
`akshm23/docker-image-optimization`, Render's deploy hook responded with a
deploy ID, and the public URL served both `/` and `/health` correctly after
the redeploy completed.

## 18. Team Responsibilities

_Fill in your team's actual names and division of work below — this is a
group project of 3 students._

| Area | Responsible |
|---|---|
| Application development (Express app, routes) | _TODO_ |
| Automated testing (Jest/Supertest) | _TODO_ |
| Dockerization (baseline + optimized images, benchmarking) | _TODO_ |
| Jenkins pipeline & CI/CD configuration | _TODO_ |
| Docker Hub & Render deployment configuration | _TODO_ |
| Documentation & demo preparation | _TODO_ |

## 19. Expected Demonstration Flow

A suggested order for a live demo:

1. Show the repo structure and explain the architecture diagram (Section 2)
2. Run `npm test` locally to show the automated test suite passing
3. Build both Dockerfiles live (or show pre-built results) and run
   `scripts/benchmark.sh` to show the real size/build-time difference
4. Open Jenkins, trigger a build with parameters, and narrate each stage as
   it goes green in the console output
5. Show the resulting image on Docker Hub
6. Show the Render dashboard confirming a new deploy was triggered
7. Open the public URL and hit `/` and `/health` in the browser to prove the
   full pipeline shipped a real, running container
