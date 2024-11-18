# fluent-bit-repro

## Introduction

This repository serves as a minimal reproducer for an mTLS issue with Fluent Bit.

The main issue is that the `opentelemetry` output plugin doesn't appear to work with mTLS. The plugin shows the following error when trying to flush data to the `opentelemetry` backend with mTLS enabled:

```
[error] [output:opentelemetry:opentelemetry.1] <HOST>:4318, HTTP status=0
```

To reproduce the issue, this repository contains a `docker-compose.yaml` file with the following configuration:

- A Grafana Tempo container _without_ mTLS enabled
- A Grafana Tempo container _with_ mTLS enabled
- A Fluent Bit container with two `opentelemetry` output plugins that are configured to talk to each of the Grafana Tempo backends above
- A shell script to generate mTLS certificates

## Steps to Reproduce

> **NOTE**: You will need `openssl`, `protocurl`, `docker`, and `docker-compose` installed for the steps below.

Generate mTLS certificates:

```sh
./certs/generate.sh
```

Start the containers:

```sh
docker-compose up
```

From your local system, send an example trace to the Fluent Bit container:

```sh
protocurl \
 -i opentelemetry.proto.collector.trace.v1.ExportTraceServiceRequest \
 -o opentelemetry.proto.collector.trace.v1.ExportTraceServiceResponse \
 -u localhost:4318/v1/traces \
 -d @trace.json -I op -D
```

The error behavior that we see triggering here is that the `opentelemetry` output plugin that connects to the mTLS backend throws the following error:

```
[error] [output:opentelemetry:opentelemetry.1] tempo-mtls:4318, HTTP status=0
```

Sending the example trace data directly to the Tempo backend with the same mTLS certificates works without any issues:

```sh
# sudo is used since the generated certs are owned by the root user
sudo protocurl \
  -i opentelemetry.proto.collector.trace.v1.ExportTraceServiceRequest \
  -o opentelemetry.proto.collector.trace.v1.ExportTraceServiceResponse \
  -u https://localhost:4320/v1/traces \
  -C '--cert ./certs/generated/fb/cert.pem --key ./certs/generated/fb/key.pem --cacert ./certs/generated/fb/ca.pem' \
  -d @trace.json -I op -D
```

The `opentelemetry` output plugin that targets the non-mTLS Grafana Tempo backend works without issue.
