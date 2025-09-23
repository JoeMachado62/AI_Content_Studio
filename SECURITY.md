# Security Policy

## Introduction

The AI Content Studio (based on Postiz) is committed to ensuring the security and integrity of our users' data. This security policy outlines our procedures for handling security vulnerabilities, our disclosure policy, and implemented security measures.

## Reporting Security Vulnerabilities

If you discover a security vulnerability in the Postiz app, please report it to us privately via email to one of the maintainers:

- @nevo-david
- @ennogelhaus ([email](mailto:gelhausenno@outlook.de))

When reporting a security vulnerability, please provide as much detail as possible, including:

- A clear description of the vulnerability
- Steps to reproduce the vulnerability
- Any relevant code or configuration files

## Supported Versions

This project currently only supports the latest release. We recommend that users always use the latest version of the Postiz app to ensure they have the latest security patches.

## Disclosure Guidelines

We follow a private disclosure policy. If you discover a security vulnerability, please report it to us privately via email to one of the maintainers listed above. We will respond promptly to reports of vulnerabilities and work to resolve them as quickly as possible.

We will not publicly disclose security vulnerabilities until a patch or fix is available to prevent malicious actors from exploiting the vulnerability before a fix is released.

## Security Vulnerability Response Process

We take security vulnerabilities seriously and will respond promptly to reports of vulnerabilities. Our response process includes:

- Investigating the report and verifying the vulnerability.
- Developing a patch or fix for the vulnerability.
- Releasing the patch or fix as soon as possible.
- Notifying users of the vulnerability and the patch or fix.

## Template Attribution

## Implemented Security Measures

### Server Security
- **Fail2ban**: Installed and configured to protect against SSH brute force attacks
  - 3 failed attempts within 10 minutes results in 1-hour IP ban
  - Monitoring SSH access logs at `/var/log/auth.log`
- **SSH Hardening**:
  - ClientAliveInterval: 60 seconds
  - ClientAliveCountMax: 3
  - TCPKeepAlive enabled
- **Firewall**: System firewall configured to allow only necessary ports

### Application Security
- **Environment Variables**: All sensitive data stored in environment variables
- **JWT Authentication**: Secure token-based authentication system
- **Input Validation**: Comprehensive input validation using Zod schemas
- **Rate Limiting**: API rate limiting configured (30 requests/hour by default)
- **HTTPS**: SSL/TLS encryption for all communications
- **Database Security**: PostgreSQL with secure connection strings

### Development Security
- **No Hardcoded Secrets**: All API keys and secrets loaded from environment
- **Secure Headers**: Security headers implemented for web responses
- **CORS Configuration**: Proper Cross-Origin Resource Sharing settings
- **Error Handling**: Structured error logging without exposing sensitive data

### Data Protection
- **Local Storage Option**: Files can be stored locally instead of cloud services
- **Cloudflare R2**: When using cloud storage, secure bucket configurations
- **Database Encryption**: Sensitive data encrypted at rest
- **Audit Logging**: Comprehensive logging for security events

### Monitoring & Alerting
- **Sentry Integration**: Error tracking and monitoring
- **Access Logs**: Comprehensive logging of system access
- **Failed Login Tracking**: Monitoring and alerting on authentication failures

## Security Configuration Checklist

### Required Actions for Production:
- [ ] Change default JWT_SECRET to a strong, unique value
- [ ] Configure strong database passwords
- [ ] Set up SSL certificates for HTTPS
- [ ] Configure firewall rules (allow only ports 22, 80, 443)
- [ ] Set up backup systems with encryption
- [ ] Configure monitoring and alerting
- [ ] Review and rotate API keys regularly
- [ ] Set up automated security updates
- [ ] Configure log retention policies
- [ ] Implement backup verification procedures

### Environment Variables Security:
- Ensure `.env` file is never committed to version control
- Use strong, unique secrets for all API keys
- Regularly rotate authentication credentials
- Use separate environments for development/staging/production
- Implement secrets management for production deployments

## Template Attribution

This SECURITY.md file is based on the [GitHub Security Policy Template](https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository).

Thank you for helping to keep the AI Content Studio secure!
