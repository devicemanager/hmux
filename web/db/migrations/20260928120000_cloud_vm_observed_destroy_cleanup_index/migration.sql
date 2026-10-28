CREATE INDEX CONCURRENTLY IF NOT EXISTS "cloud_vms_observed_destroy_cleanup_idx"
  ON "cloud_vms" ("updated_at", "id")
  WHERE "status" = 'destroyed'
    AND "provider_metadata" ? 'hmuxObservedDestroyCleanup'
    AND jsonb_typeof("provider_metadata"->'hmuxObservedDestroyCleanup') = 'object'
    AND (
      "provider_metadata"->'hmuxObservedDestroyCleanup' @> '{"modelPlane":true}'::jsonb
      OR (
        jsonb_typeof("provider_metadata"->'hmuxObservedDestroyCleanup'->'homeVolume') = 'string'
        AND length(btrim("provider_metadata"->'hmuxObservedDestroyCleanup'->>'homeVolume')) > 0
      )
    );
