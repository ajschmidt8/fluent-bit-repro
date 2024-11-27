# fluent-bit-repro

This issue serves as a reproducer for:

- https://github.com/fluent/fluent-bit/issues/9589
- https://github.com/fluent/fluent-bit/pull/9590

## Instructions

Run `docker-compose up` and witness that the `aggregator` does not output any records that match the `logs` key.
