# Security Best Practices for Headless DOM

This document outlines security best practices for running the Headless DOM Content Extractor container.

## Current Security Measures

1. **Docker Network Security**: Container should only be exposed on localhost by using `-p 127.0.0.1:5000:5000`
2. **Non-Root User**: The secure Dockerfile (`Dockerfile-secure`) runs the application as a non-root user
3. **Inside/Outside Security Separation**: 
   - Inside the container: App binds to all interfaces (0.0.0.0) for proper Docker networking
   - Outside the container: Docker only exposes on localhost for security

## Recommended Docker Run Commands

### For Local Development/Usage (Most Secure)

```bash
# Build with the secure Dockerfile
docker build -t headless-dom-secure -f Dockerfile-secure .

# Run binding only to localhost
docker run -p 127.0.0.1:5000:5000 headless-dom-secure
```

This ensures:
- The API is only accessible from the host machine
- The container runs as a non-root user

### For Production Usage

If you need to expose the service to other machines, use a reverse proxy like Nginx in front of this container:

```bash
# Run the container with no public ports
docker run --name headless-dom-backend -p 127.0.0.1:5000:5000 headless-dom-secure
```

Then configure Nginx to forward traffic to this container with appropriate security headers.

## Additional Security Recommendations

1. **Resource Limits**: Set Docker resource limits to prevent DoS attacks:
   ```bash
   docker run --memory=1g --cpus=1 -p 127.0.0.1:5000:5000 headless-dom-secure
   ```

2. **Read-Only Filesystem**: Mount the container filesystem as read-only:
   ```bash
   docker run --read-only -p 127.0.0.1:5000:5000 headless-dom-secure
   ```

3. **No New Privileges**: Prevent privilege escalation:
   ```bash
   docker run --security-opt=no-new-privileges -p 127.0.0.1:5000:5000 headless-dom-secure
   ```

4. **Set up API Rate Limiting**: For production usage, implement rate limiting to prevent abuse

5. **Regular Updates**: Keep the container and all dependencies up to date

6. **Consider Network Isolation**: Use Docker networks to isolate this container from others:
   ```bash
   docker network create scraper-net
   docker run --network scraper-net -p 127.0.0.1:5000:5000 headless-dom-secure
   ```

## Security Risks to Be Aware Of

1. **Information Leak**: This service can be used to extract data from websites, potentially exposing sensitive information
2. **Proxy Abuse**: Could be used as a proxy for malicious purposes - implement access controls
3. **Resource Consumption**: Web scraping is resource-intensive - monitor and limit usage
4. **Legal Issues**: Some websites prohibit scraping - ensure compliance with terms of service

## Never Expose Directly to the Internet

This service should never be directly exposed to the internet. Always use:
1. A reverse proxy with proper security headers and rate limiting
2. Authentication mechanisms to prevent unauthorized access
3. HTTPS for all connections

Always validate that the URL being accessed is permitted under your use case and legal jurisdiction. 