# Security Policy

## Supported Versions
This project is in **PoC stage**.  
No stable versions yet. All contributions and fixes should target the `main` branch.

---

## Reporting Vulnerabilities
If you discover a security issue, please **do not open a public GitHub issue**.  
Instead:

1. Contact the maintainer directly via email: `tuzelbaeff@gmail.com`
2. Provide:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested remediation (if any)

We aim to respond **within 7 days**.

---

## Guidelines for Using This Project
- **Do not** use this PoC in production environments without additional hardening.  
- **Never commit secrets**:
  - `OPENAI_API_KEY`
  - kubeconfigs
  - private keys  
- Store secrets in Kubernetes Secrets or CI/CD secret managers.  
- Consider using Vault / Sealed Secrets / SOPS for secure key management.  
- Regularly scan images and dependencies using:
  - [`trivy`](https://github.com/aquasecurity/trivy)  
  - [`pip-audit`](https://github.com/pypa/pip-audit)  

---

## Out of Scope
- Vulnerabilities in **third-party dependencies** (Falco, n8n, OpenAI API, Prometheus, etc.) are out of scope and should be reported upstream.  