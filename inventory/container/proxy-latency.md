# Proxy latency — sanitised benchmark

Captured 2026-11-12 from inside `c4-desktop`. Session IDs and exit addresses are
redacted. The benchmark is indicative for one provider and one client, not a market
comparison.

## Method

- Ten 24-hour sticky sessions were generated from the residential provider.
- Each session was tested from the container with:

  ```bash
  curl -s -o /dev/null --max-time 15 \
    -x "http://<user>:<pass>@<gateway>:32345" \
    -w "%{time_total}" \
    http://cp.cloudflare.com/generate_204
  ```

- Three runs per session; the range is reported.
- The fastest stable session was selected for the browser bridge and the two public
  nodes.

## Results

| Rank | `time_total` (3 runs) | Exit country | Note |
|---:|---|---|---|
| 1 | 1.27 – 1.40 s | TR | selected |
| 2 | 1.38 – 1.42 s | TR | stable |
| 3 | 1.46 – 1.50 s | TR | stable |
| 4 | 1.58 – 1.65 s | TR | — |
| 5 | 1.58 – 1.72 s | TR | — |
| 6 | 1.73 – 2.01 s | TR | — |
| 7 | 1.75 – 2.13 s | TR | — |
| 8 | 2.05 – 2.42 s | TR | — |
| 9 | 3.21 – 4.21 s | TR | slow |
| 10 | timeout | — | discarded |

The previous rotating account measured 1.35 / 1.45 / 1.88 s, with more variance. The
selected sticky session is more stable, not dramatically faster.

## End-to-end client test

From a separate client machine, through the public nodes:

| Node | HTTP total (3 runs) |
|---|---|
| VLESS `10041/TCP` | 1.89 / 1.89 / 1.91 s |
| Hysteria2 `10042/UDP` | 1.62 / 1.64 / 1.89 s |

Both exits were the same Turkish residential address (redacted), `loc=TR`, `colo=SOF`.

## Interpreting 700 ms

A 700 ms measurement is usually a TCP handshake to the VPS, not a page load. The
residential last mile adds roughly 1.3 s to a full HTTP request from the container.
Changing the residential session does not change the client-to-VPS TCP RTT.

Measure separately:

1. TCP RTT to the VPS (tcping).
2. Proxy connect time via the residential gateway (`time_connect`).
3. End-to-end request time (`time_total`).
4. Page load time in the browser (performance API).

Do not compare a TCP handshake with a page load.

## Cost note

Residential bandwidth is metered. Do not place these nodes in a Clash `url-test` or
`fallback` group that probes continuously; it burns quota and adds noise. Use manual
selection or a health check with a long interval and a tiny response.
