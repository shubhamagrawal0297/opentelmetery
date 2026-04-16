# OpenTelemetry Observability Stack on Linux ubuntu-22.04LTS Server

> Full observability setup using **OpenTelemetry Collector**, **Prometheus**, **Grafana**, and **Jaeger** — with PHP (CodeIgniter) instrumentation.

---

## 📐 Architecture Overview

PHP App (CodeIgniter)
        │
        ▼  HTTP (4318) / gRPC (4317)
┌─────────────────────────┐
│  OTel Collector Contrib  │
│  (Receives traces+metrics)│
└────────┬────────┬────────┘
         │        │
    Traces      Metrics
         │        │
         ▼        ▼
    Jaeger    Prometheus (scrapes :8889)
    (:16686)       │
                   ▼
                Grafana
                (:3000)
```

---

## 📦 Stack Components

| Component | Version | Port |
|-----------|---------|------|
| OTel Collector Contrib | v0.149.0 | 4317 (gRPC), 4318 (HTTP), 8888 (self-metrics), 8889 (exported metrics) |
| Prometheus | 2.51.1 | 9090 |
| Grafana | Latest Stable | 3000 |
| Jaeger | v2.17.0 | 16686 (UI), 4327 (gRPC), 4328 (HTTP) |

---

## 🖥️ Prerequisites

- Ubuntu 20.04+ (bare metal or VM rack server)
- `sudo` / root access
- Internet access for package downloads
- PHP app running (e.g., CodeIgniter at `/var/www/html/app`)
- `composer` installed for PHP instrumentation

---

## 🚀 Step-by-Step Setup

### Step 1 — System Update

```bash
sudo apt update && sudo apt upgrade -y
```

---

### Step 2 — Install OpenTelemetry Collector Contrib

```bash
# Download
wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.149.0/otelcol-contrib_0.149.0_linux_amd64.deb

# Install
sudo dpkg -i otelcol-contrib_0.149.0_linux_amd64.deb

# Verify
otelcol-contrib --version
```

#### Configure Collector

```bash
sudo mkdir -p /etc/otelcol-contrib
sudo vim /etc/otelcol-contrib/config.yaml
```

Paste the following config:

```yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
      grpc:
        endpoint: 0.0.0.0:4317

exporters:
  debug:
    verbosity: detailed

  prometheus:
    endpoint: "0.0.0.0:8889"

  otlp/jaeger:
    endpoint: "localhost:4327"
    tls:
      insecure: true

processors:
  batch:

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/jaeger, debug]

    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus, debug]
```

#### Create Systemd Service

```bash
sudo vim /lib/systemd/system/otelcol-contrib.service
```

```ini
[Unit]
Description=OpenTelemetry Collector Contrib
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/otelcol-contrib --config /etc/otelcol-contrib/config.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

#### Start & Enable

```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable otelcol-contrib
sudo systemctl start otelcol-contrib
systemctl status otelcol-contrib
```

#### Verify Ports

```bash
sudo ss -tulpn | grep 8889
curl -v localhost:8889/metrics
curl -v localhost:8888/metrics
```

---

### Step 3 — Install Prometheus

```bash
sudo apt update
sudo apt install prometheus -y
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus
```

#### Configure Prometheus to Scrape OTel Collector

```bash
sudo vim /etc/prometheus/prometheus.yml
```

Add these scrape jobs under `scrape_configs`:

```yaml
scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    scrape_timeout: 5s
    static_configs:
      - targets: ['localhost:9090']

  - job_name: node
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'otelcol-self'
    static_configs:
      - targets: ['localhost:8888']   # Collector self-metrics

  - job_name: 'otelcol-exported'
    static_configs:
      - targets: ['localhost:8889']   # App metrics exported by Collector
```

```bash
sudo systemctl restart prometheus
sudo systemctl status prometheus
```

#### Verify in Browser

```
http://<SERVER_IP>:9090/targets
```

Run these queries in Prometheus Graph:

```promql
up
otelcol_process_uptime
```

---

### Step 4 — Install Grafana

```bash
sudo apt-get install -y adduser libfontconfig1 musl
wget -q -O - https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install -y grafana
sudo systemctl enable --now grafana-server
sudo systemctl status grafana-server
```

#### Add Prometheus as Datasource

1. Open Grafana: `http://<SERVER_IP>:3000` (default login: `admin` / `admin`)
2. Go to **Connections → Data Sources → Add data source → Prometheus**
3. Set URL: `http://<SERVER_IP>:9090`
4. Click **Save & Test**

#### Useful Grafana Queries (Collector Dashboard)

```promql
otelcol_process_uptime
otelcol_process_cpu_seconds
otelcol_exporter_queue_size
```

---

### Step 5 — Install Jaeger v2

```bash
cd /tmp
wget https://github.com/jaegertracing/jaeger/releases/download/v2.17.0/jaeger-2.17.0-linux-amd64.tar.gz
tar -xzf jaeger-2.17.0-linux-amd64.tar.gz
sudo mv jaeger-2.17.0-linux-amd64/jaeger /usr/local/bin/jaeger
sudo chmod +x /usr/local/bin/jaeger
jaeger --help
```

#### Configure Jaeger

```bash
sudo mkdir -p /etc/jaeger
sudo vim /etc/jaeger/config.yaml
```

```yaml
extensions:
  jaeger_storage:
    backends:
      traces_storage:
        memory:
          max_traces: 100000

  jaeger_query:
    storage:
      traces: traces_storage
    base_path: /
    grpc:
      endpoint: 0.0.0.0:16685
    http:
      endpoint: 0.0.0.0:16686

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4327
      http:
        endpoint: 0.0.0.0:4328

processors:
  batch:

exporters:
  jaeger_storage_exporter:
    trace_storage: traces_storage

service:
  extensions: [jaeger_storage, jaeger_query]
  telemetry:
    metrics:
      readers:
        - pull:
            exporter:
              prometheus:
                host: 0.0.0.0
                port: 8890
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [jaeger_storage_exporter]
```

#### Create Jaeger Systemd Service

```bash
sudo tee /etc/systemd/system/jaeger.service > /dev/null <<'EOF'
[Unit]
Description=Jaeger v2
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/jaeger --config /etc/jaeger/config.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable jaeger
sudo systemctl start jaeger
sudo systemctl status jaeger
```

#### Verify

```bash
ss -tulnp | grep -E '16686|4327|4328'
```

Open Jaeger UI: `http://<SERVER_IP>:16686`

---

### Step 6 — PHP (CodeIgniter) Instrumentation

#### Install OTel PHP SDK via Composer

```bash
cd /var/www/html/app

# Install Composer if not present
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --2.2 --filename=composer2
php -r "unlink('composer-setup.php');"

# Install OTel packages
php composer2 require \
  open-telemetry/api \
  open-telemetry/sdk \
  open-telemetry/exporter-otlp \
  nyholm/psr7 \
  php-http/guzzle7-adapter
```

#### Create OTel Bootstrap File

```bash
vim /var/www/html/app/otel_bootstrap.php
```

```php
<?php

require __DIR__ . '/vendor/autoload.php';

use OpenTelemetry\API\Trace\StatusCode;
use OpenTelemetry\Contrib\Otlp\OtlpHttpTransportFactory;
use OpenTelemetry\Contrib\Otlp\SpanExporter;
use OpenTelemetry\SDK\Common\Attribute\Attributes;
use OpenTelemetry\SDK\Resource\ResourceInfo;
use OpenTelemetry\SDK\Trace\SpanProcessor\SimpleSpanProcessor;
use OpenTelemetry\SDK\Trace\TracerProvider;

$resource = ResourceInfo::create(Attributes::create([
    'service.name' => 'php-login-app',
    'service.version' => '1.0.0',
]));

$transport = (new OtlpHttpTransportFactory())->create(
    'http://127.0.0.1:4318/v1/traces',
    'application/x-protobuf'
);

$exporter = new SpanExporter($transport);

$tracerProvider = new TracerProvider(
    new SimpleSpanProcessor($exporter),
    null,
    $resource
);

$tracer = $tracerProvider->getTracer('php-login-tracer');

$spanName = ($_SERVER['REQUEST_METHOD'] ?? 'CLI') . ' ' . ($_SERVER['REQUEST_URI'] ?? '/');
$span = $tracer->spanBuilder($spanName)->startSpan();
$scope = $span->activate();

$span->setAttribute('http.method', $_SERVER['REQUEST_METHOD'] ?? '');
$span->setAttribute('http.target', $_SERVER['REQUEST_URI'] ?? '');
$span->setAttribute('http.host', $_SERVER['HTTP_HOST'] ?? '');
$span->setAttribute('http.scheme', !empty($_SERVER['HTTPS']) ? 'https' : 'http');

register_shutdown_function(function () use ($span, $scope, $tracerProvider) {
    $status = http_response_code();
    $span->setAttribute('http.status_code', $status);

    if ($status >= 500) {
        $span->setStatus(StatusCode::STATUS_ERROR, 'HTTP 5xx');
    }

    $scope->detach();
    $span->end();
    $tracerProvider->shutdown();
});
```

#### Hook into CodeIgniter index.php

Open `/var/www/html/app/index.php` and add at the very top (after `<?php` and `ob_start()`):

```php
<?php
ob_start();

require_once __DIR__ . '/otel_bootstrap.php';  // ← ADD THIS LINE

// ... rest of CI index.php
```

#### Restart Apache & Verify

```bash
php -l /var/www/html/app/otel_bootstrap.php
php -l /var/www/html/app/index.php
sudo systemctl restart apache2
sudo systemctl status apache2
tail -n 20 /var/log/apache2/error.log
```

---

### Step 7 — Test with Python Metric Generator (Optional)

```bash
apt install -y python3-pip
pip install opentelemetry-sdk opentelemetry-exporter-otlp --break-system-packages
```

```bash
vim test_metrics.py
```

```python
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
import time

exporter = OTLPMetricExporter(endpoint="http://localhost:4318/v1/metrics")
reader = PeriodicExportingMetricReader(exporter, export_interval_millis=5000)
provider = MeterProvider(metric_readers=[reader])

meter = provider.get_meter("test-meter")
counter = meter.create_counter("demo_counter")

while True:
    counter.add(1)
    print("metric sent")
    time.sleep(2)
```

```bash
python3 test_metrics.py
```

Then query in Prometheus:

```promql
demo_counter_total
```

---

## 🔍 Verification Checklist

| Check | Command |
|-------|---------|
| OTel Collector running | `systemctl status otelcol-contrib` |
| Collector self-metrics | `curl http://localhost:8888/metrics \| head -20` |
| Collector exported metrics | `curl http://localhost:8889/metrics \| head -20` |
| Prometheus targets | `http://<IP>:9090/targets` |
| Jaeger UI | `http://<IP>:16686` |
| Grafana UI | `http://<IP>:3000` |
| All ports open | `ss -tulnp \| grep -E '4317\|4318\|8888\|8889\|9090\|16686\|3000'` |

---

## 🔌 Port Reference

```
4317  → OTel Collector gRPC receiver (from app)
4318  → OTel Collector HTTP receiver (from app)
4327  → Jaeger gRPC receiver (from Collector)
4328  → Jaeger HTTP receiver
8888  → OTel Collector self-metrics (Prometheus scrapes this)
8889  → OTel Collector exported app metrics (Prometheus scrapes this)
8890  → Jaeger internal metrics
9090  → Prometheus UI & API
3000  → Grafana UI
16686 → Jaeger UI
16685 → Jaeger gRPC query API
```

---

## 🐛 Troubleshooting

### Collector not starting
```bash
journalctl -u otelcol-contrib -n 100 --no-pager
```

### Prometheus targets showing DOWN
```bash
# Verify collector is exporting metrics
curl http://localhost:8888/metrics
curl http://localhost:8889/metrics

# Restart both services
sudo systemctl restart otelcol-contrib
sudo systemctl restart prometheus
```

### Jaeger not receiving traces
```bash
# Check all ports are listening
ss -tulnp | grep -E '16685|16686|4327|4328'

# Check collector is forwarding to Jaeger
journalctl -u otelcol-contrib -n 50 --no-pager | grep -i jaeger
```

### PHP traces not appearing in Jaeger
```bash
# Check apache logs
tail -n 30 /var/log/apache2/error.log

# Test OTel endpoint manually
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" -d '{}'
```

---

## 📊 Grafana Dashboard Queries

### Collector Health
```promql
otelcol_process_uptime
otelcol_process_cpu_seconds
otelcol_exporter_queue_size
```

### PHP App Traces (via Jaeger datasource)
```
service.name: php-login-app
Span Name: GET /app/login
http.status_code: 200
```

---

## 📁 Project File Structure

```
/etc/otelcol-contrib/
└── config.yaml               # OTel Collector config

/etc/prometheus/
└── prometheus.yml            # Prometheus scrape config

/etc/jaeger/
└── config.yaml               # Jaeger v2 config

/lib/systemd/system/
├── otelcol-contrib.service   # Collector systemd unit
└── jaeger.service            # Jaeger systemd unit

/var/www/html/app/
├── otel_bootstrap.php        # PHP OTel instrumentation
├── index.php                 # CI entry point (modified)
└── vendor/                   # Composer OTel packages

/home/ (or /tmp/)
└── test_metrics.py           # Optional Python metric sender
```

---

## 📚 References

- [OpenTelemetry Collector Docs](https://opentelemetry.io/docs/collector/)
- [Jaeger v2 Docs](https://www.jaegertracing.io/docs/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)
- [OTel PHP SDK](https://opentelemetry.io/docs/languages/php/)
---

## 👤 Author

Setup documented from production deployment on Ubuntu Linux rack server.
