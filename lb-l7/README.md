# Load Balancer L7

Single region, Cloud Armor for DDoS protection, HTTP to HTTPS redirection.

- When you access `http://<your-domain.com>`, you will be redirected to `https://<your-domain.com>`.
- When you access `https://<your-domain.com>`, traffic is distributed evenly (50/50) between Run Service A and Run Service B.
- When you access `https://<your-domain.com>/c`, the request is rewritten to the root path of Run Service C.
