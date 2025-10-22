-- Optional: if you want gen_random_uuid() later
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ===== Ensure UserSettings table exists (shadow-safe) =====
DO $$
BEGIN
  IF to_regclass('public."UserSettings"') IS NULL THEN
    CREATE TABLE "UserSettings" (
      "userId"   TEXT      NOT NULL,
      "features" JSONB     NOT NULL DEFAULT '{}'::jsonb,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT now()
    );
    -- 1:1 settings per user
    CREATE UNIQUE INDEX IF NOT EXISTS "UserSettings_userId_key" ON "UserSettings" ("userId");
  END IF;
END$$;

-- ===== Backfill-safe column additions =====
ALTER TABLE "UserSettings" ADD COLUMN IF NOT EXISTS "id" TEXT;
ALTER TABLE "UserSettings" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT now();

-- Backfill id for existing rows
UPDATE "UserSettings"
SET "id" = COALESCE("id", CONCAT('us_', "userId"));

-- Switch PK to id (drop any existing PK first)
DO $$
DECLARE
  pk_name text;
BEGIN
  SELECT conname INTO pk_name
  FROM pg_constraint
  WHERE conrelid = 'UserSettings'::regclass
    AND contype = 'p';

  IF pk_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE "UserSettings" DROP CONSTRAINT %I', pk_name);
  END IF;

  ALTER TABLE "UserSettings" ALTER COLUMN "id" SET NOT NULL;
  ALTER TABLE "UserSettings" ADD CONSTRAINT "UserSettings_pkey" PRIMARY KEY ("id");
END$$;

-- Ensure unique on userId (keeps the 1:1 invariant)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'UserSettings'
      AND indexname = 'UserSettings_userId_key'
  ) THEN
    CREATE UNIQUE INDEX "UserSettings_userId_key" ON "UserSettings" ("userId");
  END IF;
END$$;

-- ===== BankItem additions used by Phase 13 =====
ALTER TABLE IF EXISTS "BankItem"
  ADD COLUMN IF NOT EXISTS "paused" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "lastSyncAt" TIMESTAMP(3);
