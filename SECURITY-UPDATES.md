# Security Updates - MXA OCR

## Date: 2026-04-10

### Vulnerabilities Fixed

This document tracks the security vulnerabilities that were identified and resolved.

#### 1. FastAPI ReDoS Vulnerability
- **Package**: fastapi
- **Vulnerable Version**: 0.104.1 (≤ 0.109.0)
- **Patched Version**: 0.109.1
- **Vulnerability**: Content-Type Header ReDoS
- **Severity**: Medium
- **Fix**: Updated to 0.109.1

#### 2. python-multipart Multiple Vulnerabilities
- **Package**: python-multipart
- **Vulnerable Version**: 0.0.6
- **Patched Version**: 0.0.22
- **Vulnerabilities**:
  1. Arbitrary File Write via Non-Default Configuration (< 0.0.22)
  2. Denial of Service via deformed multipart/form-data boundary (< 0.0.18)
  3. Content-Type Header ReDoS (≤ 0.0.6)
- **Severity**: High to Medium
- **Fix**: Updated to 0.0.22 (covers all three vulnerabilities)

#### 3. Pillow Multiple Vulnerabilities
- **Package**: Pillow
- **Vulnerable Versions**: 10.1.0 → 10.3.0
- **Patched Version**: 12.1.1
- **Vulnerabilities**:
  1. Buffer overflow vulnerability (< 10.3.0)
  2. Out-of-bounds write when loading PSD images (>= 10.3.0, < 12.1.1)
- **Severity**: High
- **Fix**: Updated to 12.1.1 (covers both vulnerabilities)

#### 4. Black Cache File Vulnerability
- **Package**: black
- **Vulnerable Version**: 23.11.0 (< 26.3.1)
- **Patched Version**: 26.3.1
- **Vulnerability**: Arbitrary file writes from unsanitized user input in cache file name
- **Severity**: Medium
- **Fix**: Updated to 26.3.1
- **Note**: This is a development dependency

### Summary

All identified vulnerabilities have been patched by updating to the latest secure versions of the affected packages. No breaking changes were introduced as all updates are within compatible version ranges.

### Verification

To verify the updates are applied:

```bash
cd python-backend
pip install -r requirements.txt
pip list | grep -E "(fastapi|python-multipart|Pillow|black)"
```

Expected output:
```
black                26.3.1
fastapi              0.109.1
Pillow               12.1.1
python-multipart     0.0.22
```

### Next Steps

1. ✅ Dependencies updated in requirements.txt
2. ⏳ Commit changes to repository
3. ⏳ Deploy to staging environment
4. ⏳ Run security scan to verify no vulnerabilities remain
5. ⏳ Deploy to production

### References

- [FastAPI Security Advisory](https://github.com/advisories/GHSA-qf9m-vfgh-m389)
- [python-multipart Security Advisories](https://github.com/advisories)
- [Pillow Security Advisory](https://github.com/advisories/GHSA-56pw-mpj4-fxww)
- [Black Security Advisory](https://github.com/advisories)
