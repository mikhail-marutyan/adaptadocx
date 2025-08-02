# Security Policy

Adaptadocx applies layered auditing, dependency pinning, and incident-response practices to secure the entire build pipeline.

---

## Multi-layer security auditing

The **Security Audit** workflow runs on every *pull request* to `main` and on every `push` to a tag, with `continue-on-error` enabled so warnings surface without blocking builds.

### Security audit components

| Component              | Tool                | Purpose                                                                                               |
|------------------------|---------------------|-------------------------------------------------------------------------------------------------------|
| Vulnerability detection| **OSV-Scanner**     | Detects hijacked or malicious packages via the Google OSV database and project lockfiles              |
| Package analysis       | **Sandworm audit**  | Flags dependencies that ship risky `postinstall` scripts or protest-ware payloads                     |
| Pattern scanning       | **Banned-pattern detector** | Searches the repository and `node_modules` using project-defined PCRE signatures             |

---

## Dependency security management

### Pinned dependency: **es5-ext**

`es5-ext` is **locked to `0.10.53`** through *npm overrides* because newer versions execute political messaging during installation.

```json
{
  "overrides": {
    "es5-ext": "0.10.53"
  }
}
````

* **Security impact** — the protest script is never fetched or run.
* **Maintenance** — remove the override when a clean release appears or the package is dropped.

### Automated monitoring

Workflow file → `.github/workflows/security-audit.yml`

* Real-time CVE check (OSV-Scanner)
* Supply-chain risk scan (Sandworm)
* Custom banned-pattern scan
* Non-blocking execution

---

## Banned-pattern system

Config file → `security/banned-patterns.txt`

* One PCRE per line
* Lines starting with `#` are comments
* Applied to the repository and `node_modules`

#### Example patterns

```text
# Prohibited external resources
example\.malicious-site\.com
# Protest-ware detection
console\.log.*political.*message
# Possible API keys
[Aa]pi[_-]?[Kk]ey.*['\"][A-Za-z0-9]{20,}['\"]
```

---

## Workflow integration

**Trigger events**

* **pull_request** → `main`
* **push** → tags (`*`)

**Reporting**

* Logs visible in the Actions run view
* Summary table added to pull-request comments
* JSON artefacts uploaded for further analysis

### Response matrix

| Condition    | Action                          |
| ------------ | ------------------------------- |
| Zero hits    | Workflow passes (informational) |
| Pattern hit  | Investigate immediately         |
| CVE detected | Plan remediation                |

---

## Development best practices

| Area         | Guidelines                                                                          |
| ------------ | ----------------------------------------------------------------------------------- |
| Dependencies | Run `npm audit`, install with `npm ci --no-audit --no-fund`, pin known-bad versions |
| Code         | Validate inputs, avoid shell injection, keep banned-patterns updated                |
| Containers   | Scan images, use minimal base, update regularly, manage secrets securely            |

---

## Incident-response procedures

### Security vulnerability

1. **Assess** severity
2. **Plan** mitigation
3. **Patch / override** the issue
4. **Verify** via the security-audit workflow
5. **Document** the incident

### Banned-pattern hit

1. **Investigate** (false positive?)
2. **Locate** the source
3. **Remove or alter** offending code
4. **Refine** the pattern

---

## Maintenance schedule

| Frequency     | Tasks                                                      |
| ------------- | ---------------------------------------------------------- |
| **Weekly**    | Review audit summaries; fix new issues                     |
| **Monthly**   | Full dependency review; refine patterns; audit permissions |
| **Quarterly** | Threat-model update; tool evaluation; team training        |

---

## Contact & support

* **Report vulnerabilities** — use GitHub’s private vulnerability-reporting feature.
* **Policy questions** — open an issue in the repository for discussion.

---

This policy is reviewed regularly and updated as security requirements evolve.
