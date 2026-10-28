# Publication authorization traces

`requestTelemetry.ts` instruments `/api/freestyle/forward-auth`. Normal requests
follow the existing trace sampling ratio. Every request taking at least 750 ms,
or returning 5xx, also produces `hmux.publication_auth.outcome` through the
priority sampler. It includes operation offsets, durations, and failure flags,
even when the original request trace was not sampled. Its response carries the
retained trace id. Export is flushed in `after()`, outside response latency.

Use `hmux.publication_auth.duration_ms` for the full request duration. An outcome
span records a completed decision, so its own span duration is not request
latency. Parent and child operation timings overlap; do not sum them.

Operation names and decision categories are fixed by code. Request URLs, cookie
values, authorization codes, SQL parameters, and exception messages are not
recorded here. At most 32 operation events are retained per request. Check
`hmux.publication_auth.dropped_operations` before treating the list as complete.
Database operation time currently includes connection wait and query execution.

Find every retained slow or failed request:

```apl
['hmux-prod-otel-traces']
| where name == 'hmux.publication_auth.outcome'
| project _time, trace_id,
    duration_ms = ['attributes.custom']['hmux.publication_auth.duration_ms'],
    decision = ['attributes.custom']['hmux.publication_auth.decision'],
    events
```

Estimate normal request latency from the sampled request spans, not the
deliberately biased slow/failure stream. Do not combine the two streams: a
sampled slow request has both records.

```apl
['hmux-prod-otel-traces']
| where name == 'hmux.publication_auth.request'
| extend ms = todouble(['attributes.custom']['hmux.publication_auth.duration_ms'])
| summarize requests=count(), p50=percentile(ms, 50), p95=percentile(ms, 95), p99=percentile(ms, 99)
```

Preview export verification uses `hmux-preview-otel-traces` and service
`hmux-publication-auth-verification`. Synthetic checks are not production
performance measurements.
