# 📘 Telemetry Harbor OSS

**Telemetry Harbor OSS** is the open-source ingestion and visualization stack behind [Telemetry Harbor](https://telemetryharbor.com).

It provides:

* **API ingestion layer** (Go Fiber) with Redis-backed queue
* **Worker** for insert into TimescaleDB
* **Grafana** with pre-configured dashboards and datasource
* **TimescaleDB** optimized for time-series telemetry
* **Redis** for queue management

With this stack, you can **self-host a full telemetry backend** and use the official [Telemetry Harbor SDKs](https://docs.telemetryharbor.com/docs/category/sdks). to push your data.

---

## 🚀 Quick Start

```bash
git clone https://github.com/TelemetryHarbor/telemetry-harbor-oss.git
cd telemetry-harbor-oss
docker compose up -d
```

Once started:

* API available at → `http://localhost:8000/api/v1`
* Grafana available at → `http://localhost:3000` (default: `admin / StrongAdminPassword!`)

---

## ⚠️ Security Notice

This repository ships with **default credentials** for ease of testing.
Before using in production, you **must change**:

* `POSTGRES_PASSWORD` in `docker-compose.yml`
* `REDIS_PASSWORD` in `docker-compose.yml`
* `API_KEY` in `docker-compose.yml`
* `GF_SECURITY_ADMIN_PASSWORD` in `docker-compose.yml`

Failure to do so will leave your system vulnerable.

---

## 📡 Ingestion API

Replace Telemetry Harbor Cloud URLs with your own domain omitting harbor id.

### Single Data Push

```http
POST https://yourdomain.com/api/v1/ingest/
```

### Batch Data Push

```http
POST https://yourdomain.com/api/v1/ingest/batch
```

Both require the **API key** set via environment variable (`API_KEY`).

---

## 📊 Visualization

Grafana comes pre-configured with:

* **Telemetry Harbor Datasource** (TimescaleDB)
* **Telemetry Harbor Dashboard**

You can log into Grafana (`http://localhost:3000`) and start exploring your telemetry data immediately.

---

## 🛠️ SDKs

Telemetry Harbor OSS is compatible with the **[Telemetry Harbor SDKs](https://docs.telemetryharbor.com/docs/category/sdks)**:

* Python
* C++
* JavaScript
* Arduino / Espressif

Just replace your ingest endpoint with your OSS URL.

---

## 📜 License

This project is licensed under the **Apache License 2.0**.

* ✅ Free to use (commercial + personal)
* ✅ Free to modify and redistribute
* ⚠️ Must **include attribution** (keep copyright + NOTICE file)

See [LICENSE](./LICENSE) for details.

If you use this project in your product, please credit **Telemetry Harbor** with a link to [https://telemetryharbor.com](https://telemetryharbor.com).

---

## 🤝 Contributing

We welcome issues, pull requests, and feature suggestions!

* Open a GitHub issue for bugs or feature requests
* Fork the repo and submit PRs

