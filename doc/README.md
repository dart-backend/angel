# Performance Testing

## WRT

    ```bash
    wrk -t12 -c400 -d30s http://localhost:8080/query?queries=20
    ```
This runs a benchmark for 30 seconds, using 12 threads, and keeping 400 HTTP connections open.
