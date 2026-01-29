# Secure Supply Chain MVP

**A DevSecOps demonstration for RASP Cyber Academy**

This project implements a "Shift Left" security pipeline tailored for a high-compliance banking environment. It guarantees that every artifact reaching production is free of secrets, critically vulnerability-free, and cryptographically signed.

---

## 🏦 Business Context: Banking Security

In a financial environment, a compromised container or leaked credential is catastrophic. This pipeline addresses three specific risks:

1.  **Data Leakage:** Preventing API keys, IBANs, or SWIFT codes from entering the git history.
2.  **Vulnerable Dependencies:** Blocking images with critical CVEs before they reach the registry.
3.  **Supply Chain Integrity:** Ensuring the code running in production is exactly what was built and approved (via Cosign signatures).

---

## 🛠️ Architecture & Security Gates

The pipeline enforces strict gates. If a check fails, the build stops immediately.

### Gate 1: Secret Detection (GitLeaks)
Before any build starts, we scan the codebase for hardcoded secrets.
* **Custom Config:** see `.gitleaks.toml`.
* **Bank-Specific Rules:** I've added custom regex rules to detect **IBANs** and **SWIFT/BIC** codes, in addition to standard API keys.

### Gate 2: Image Hardening (Docker)
We use a multi-stage `Dockerfile` to minimize attack surface:
* **Base Image:** `alpine:3.21` (pinned version for stability).
* **User:** Runs as non-root (`nginx` user).
* **Security Headers:** Nginx is pre-configured with `X-Frame-Options: DENY`, `CSP`, and `X-XSS-Protection`.

### Gate 3: Vulnerability Scanning (Trivy)
We scan the built image before pushing.
* **Policy:** Fails on `CRITICAL` or `HIGH` severities.
* **Noise Reduction:** Ignores `unfixed` vulnerabilities (if the vendor hasn't patched it, we don't block development, but we verify it's not exploitable).

### Gate 4: Signing (Cosign)
* **Trigger:** Only on push to `main`.
* **Action:** The image is signed with a private key.
* **Verification:** The signature allows the runtime environment (k8s) to verify authenticity.

---

## 🚀 Quick Start (Local Development)

I have included a `Makefile` to standardize the developer experience. No need to memorize complex Docker commands.

### Prerequisites
* Docker
* Make
* Cosign (optional, for signing)

### Commands

| Command | Description |
|---------|-------------|
| `make check` | **Recommended.** Runs Secrets check + Build + Trivy Scan (simulates CI). |
| `make run` | Builds and runs the container locally on `http://localhost:8080`. |
| `make scan` | Builds and scans for vulnerabilities using Trivy. |
| `make secrets` | Scans for secrets (uses local GitLeaks or falls back to Docker). |
| `make clean` | Removes local artifacts and cached images. |

---

## ⚙️ CI/CD Configuration

The pipeline is defined in `.github/workflows/secure-pipeline.yml`.

### Environment Variables
The pipeline requires the following **GitHub Secrets** for the signing stage:
* `COSIGN_PRIVATE_KEY`: Your generated private key.
* `COSIGN_PASSWORD`: The password for the key.

### Generating Keys
To generate a key pair for this project, run:
```bash
make keygen

```

Then upload the contents of `cosign.key` to GitHub Secrets.

---

## 📝 Policy Decisions & Trade-offs

* **Trivy Config:** I explicitly set `ignore-unfixed: true`. In a real-world scenario, blocking builds for unpatchable vulnerabilities creates friction without adding security value.
* **Key Management:** For this MVP, I'm using GitHub Secrets. **Production Recommendation:** Use OIDC (Keyless signing) with Sigstore/Fulcio or a Hardware Security Module (HSM) to manage keys securely.
* **Nginx:** configured to deny iframes to prevent clickjacking attacks (`X-Frame-Options: DENY`).

---

## Project Structure

```text
.
├── .github/workflows/   # CI/CD Pipeline definition
├── .gitleaks.toml       # Custom secret detection rules (IBAN, SWIFT)
├── Dockerfile           # Hardened multi-stage build
├── Makefile             # Local development task runner
└── README.md            # Documentation

```

---

## Author

r4nol - Created for **RASP Cyber Academy**.
