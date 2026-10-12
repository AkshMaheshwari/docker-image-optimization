# Live Demo Script — Docker Image Optimization using Jenkins CI/CD

This is a step-by-step script for presenting this project live. All commands
are PowerShell (this project is built and demoed on Windows). All URLs,
image names, and numbers below are the real, actual values for this project
— not placeholders.

## Reference values (fill in / confirm before presenting)

| Item | Value |
|---|---|
| GitHub repo | https://github.com/AkshMaheshwari/docker-image-optimization |
| Docker Hub image | `akshm23/docker-image-optimization` |
| Docker Hub page | https://hub.docker.com/r/akshm23/docker-image-optimization |
| Jenkins URL | http://localhost:8080 |
| Jenkins job name | `docker-image-optimization` |
| Render public URL | https://docker-image-optimization.onrender.com |
| Baseline image size | 1.85 GB |
| Optimized image size | 202 MB (~9x smaller) |

---

## Pre-demo checklist (do this 5–10 minutes before presenting)

- [ ] **Warm up the Render URL.** The free tier spins down when idle and takes
      30–60s to cold-start on the first request. Open
      https://docker-image-optimization.onrender.com in a browser now so it's
      already warm when you demo it live.
- [ ] **Confirm Docker Desktop is running** (check for the whale icon in the
      system tray).
- [ ] **Confirm Jenkins is running.** Open http://localhost:8080 — if it
      doesn't load, Jenkins (a Windows service) may need starting:
      ```powershell
      Get-Service Jenkins
      # If not Running, as Administrator:
      Start-Service Jenkins
      ```
- [ ] **Log into Jenkins** in a browser tab and leave it on the
      `docker-image-optimization` job page.
- [ ] **Have Docker Hub and Render dashboards open** in separate tabs, logged
      in, so you're not fumbling with logins mid-demo.
- [ ] **Close unrelated terminal windows** running `npm start` or leftover
      `docker run` containers from earlier testing, so ports 3000–3010 are
      free:
      ```powershell
      docker ps
      # stop anything left over from testing:
      docker rm -f baseline-test optimized-test docker-opt-ci-test 2>$null
      ```

---

## Step-by-step walkthrough (~8–10 minutes)

### 1. Introduce the architecture (30s)

Open [README.md](README.md), show the architecture diagram in Section 2.

> "This project builds an Express app, tests it, containerizes it two
> different ways to demonstrate Docker image optimization, and ships the
> optimized version through Jenkins to Docker Hub and then Render, ending in
> a public URL."

### 2. Run the app locally (1 min)

```powershell
npm install
npm start
```

In a second PowerShell window:

```powershell
Invoke-WebRequest -Uri "http://localhost:3000/" -UseBasicParsing
Invoke-RestMethod -Uri "http://localhost:3000/health"
```

Expected: HTML page "Docker Image Optimization Demo", and
`{"status":"healthy"}`. Stop the server with `Ctrl+C`.

### 3. Run the automated tests (30s)

```powershell
npm test
```

Expected: `Tests: 3 passed, 3 total`.

> "These three tests are what Jenkins runs automatically on every build —
> if any of them fail, the pipeline stops before a Docker image is even
> built."

### 4. Show the optimization comparison — the technical centerpiece (2 min)

```powershell
.\scripts\benchmark.ps1
```

While it runs, explain the differences between
[Dockerfile.baseline](Dockerfile.baseline) and
[Dockerfile.optimized](Dockerfile.optimized):

- `node:latest` (full Debian) → `node:20-alpine` (much smaller base)
- `npm install` (installs dev deps too) → `npm ci --omit=dev` (production
  only, reproducible)
- No `.dockerignore` → `.dockerignore` excludes `node_modules`, `.git`,
  `tests`, `coverage`, env files from the build context
- Dependency-first layer ordering, so code changes don't invalidate the
  install cache layer

When it finishes, point at the headline number:

> **"1.85 GB down to 202 MB — roughly a 9x reduction, from the exact same
> application, with identical behavior."**

### 5. Trigger the Jenkins pipeline (3 min)

1. In the Jenkins tab, click **Build with Parameters**
2. Confirm `DOCKERHUB_USERNAME` = `akshm23` and `DOCKERHUB_REPOSITORY` =
   `docker-image-optimization`, then click **Build**
3. Click into the running build → **Console Output**
4. Narrate each stage as it appears in the log:

   | Stage | What it's doing |
   |---|---|
   | Checkout | Pulls the latest code from GitHub |
   | Install Dependencies | `npm ci` |
   | Run Tests | `npm test` — same 3 tests from step 3 |
   | Application Build | `node --check src/server.js` — validates the entry point |
   | Build Docker Image | Builds `Dockerfile.optimized`, tags it with the build number and `latest` |
   | Validate Docker Container | Runs the new image, hits `/health`, tears it down |
   | Push Docker Image to Docker Hub | Logs in with a stored token, pushes both tags |
   | Deployment Trigger | POSTs to Render's deploy hook |

> "Notice nothing here is manual — one click ran the entire build-test-ship
> pipeline."

### 6. Show the image on Docker Hub (30s)

Switch to the Docker Hub tab, refresh the repository page, point out the new
tag matching the Jenkins build number that just ran.

### 7. Show the Render deploy (30s)

Switch to the Render dashboard, open the **Events** tab for the service, show
the deploy that was just triggered (its ID matches what the Jenkins console
printed at the Deployment Trigger stage).

### 8. Hit the live public URL — the payoff (30s)

```powershell
Invoke-WebRequest -Uri "https://docker-image-optimization.onrender.com/" -UseBasicParsing
Invoke-RestMethod -Uri "https://docker-image-optimization.onrender.com/health"
```

Or just open both URLs in a browser.

> "This running container was built, tested, optimized, pushed, and deployed
> entirely by the pipeline we just watched — nothing here was touched by
> hand."

---

## Troubleshooting notes (things we actually hit while building this)

These are real issues encountered during development — worth knowing in case
something looks broken during rehearsal or on a different machine:

- **`bash scripts/benchmark.sh` fails with "docker could not be found in this
  WSL 2 distro"** — this happens if you type that command in PowerShell,
  since PowerShell's `bash` launches your default WSL distro, which doesn't
  have Docker Desktop's WSL integration enabled. Fix: use
  `.\scripts\benchmark.ps1` instead, or run the `.sh` version from an actual
  Git Bash terminal.
- **Jenkins `checkout scm` fails with "'checkout scm' is only available when
  using 'Multibranch Pipeline' or 'Pipeline script from SCM'"** — happens if
  the Jenkins job's Pipeline definition is set to "Pipeline script" (a pasted
  script) instead of "Pipeline script from SCM." Fix: reconfigure the job to
  pull from the GitHub repo (see README Section 15).
- **Jenkins `docker build` fails with "docker is not recognized"** — happens
  when Jenkins runs as a Windows service (`LocalSystem` account), which only
  sees the machine-level `PATH`, not your user PATH where Docker Desktop's
  CLI usually lives. Fix: add Docker's bin folder to the **System** PATH and
  restart the Jenkins service (see README Section 13).
- **Render's first request after idle is slow** — expected free-tier
  behavior, not a bug. Warm it up before presenting (see checklist above).
- **PowerShell's `curl` isn't real curl** — it's aliased to
  `Invoke-WebRequest`, which doesn't accept curl's flags (like `-f` or `-s`).
  Use `Invoke-WebRequest` / `Invoke-RestMethod`, or call `curl.exe`
  explicitly if you want real curl syntax.
