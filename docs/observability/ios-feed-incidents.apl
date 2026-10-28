['hmux-prod-otel-traces']
| where _time > ago(24h) and name == 'hmux.mobile.feed.scroll_anomaly'
| extend p = ['attributes.custom']
| project _time, observed_at = tostring(p['hmux.mobile.occurred_at']), window_id = tostring(p['hmux.mobile.feed.window_id']), sentry_event_id = tostring(p['hmux.mobile.feed.sentry_event_id']), build = tostring(p['hmux.mobile.feed.build_number']), sha = tostring(p['hmux.mobile.feed.build_sha']), simulator = tostring(p['hmux.mobile.feed.is_simulator']), worst_ms = tolong(p['hmux.mobile.feed.callback_gap_max_ms']), callbacks = tolong(p['hmux.mobile.feed.callback_count']), items = tolong(p['hmux.mobile.feed.item_count'])
| order by _time desc
| take 100
