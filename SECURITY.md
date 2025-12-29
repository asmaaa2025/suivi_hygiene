# Security Policy

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability, please follow these steps:

1. **Do NOT** open a public GitHub issue
2. Email security details to: adlaniasma@gmail.com
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Report

Please report:
- Authentication or authorization flaws
- Data exposure vulnerabilities
- SQL injection or other injection attacks
- Cross-site scripting (XSS) vulnerabilities
- Remote code execution
- Sensitive data exposure (API keys, tokens, etc.)
- Any other security-related issues

### What NOT to Report

Please do NOT report:
- Issues that require physical access to the device
- Issues that require social engineering
- Denial of service attacks
- Spam or content issues
- Issues in third-party dependencies (report to them directly)

## Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity (typically 30-90 days)

## Security Best Practices

When using this application:

1. **Never commit secrets** to version control
   - Use `.env` files for local development
   - Use environment variables in production
   - Never commit `.env` files

2. **Keep dependencies updated**
   ```bash
   flutter pub upgrade
   ```

3. **Use strong Supabase RLS policies**
   - Review and test RLS policies regularly
   - Ensure proper user isolation

4. **Secure API keys**
   - Rotate keys if exposed
   - Use service role keys only server-side
   - Never expose service role keys in client code

5. **Regular security audits**
   - Review dependencies for vulnerabilities
   - Keep Flutter and Dart SDK updated
   - Monitor Supabase security advisories

## Disclosure Policy

- We will acknowledge receipt of your report within 48 hours
- We will provide regular updates on the status of the vulnerability
- We will notify you when the vulnerability is fixed
- We will credit you in the security advisory (if you wish)

## Security Updates

Security updates will be:
- Released as patch versions (e.g., 1.0.1, 1.0.2)
- Documented in CHANGELOG.md
- Tagged with security labels in GitHub

Thank you for helping keep BekkApp secure!

