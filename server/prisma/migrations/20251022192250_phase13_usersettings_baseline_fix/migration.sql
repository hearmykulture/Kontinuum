-- Optional: if you want gen_random_uuid() later
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- Ensure the quoted "UserSettings" table exists (shadow-safe)
-- ============================================================
DO $$
BEGIN
  IF to_regclass('public."UserSettings"') IS NULL THEN
    CREATE TABLE "UserSettings" (
      "id"                TEXT,
      "userId"            TEXT         NOT NULL,
      "features"          JSONB        NOT NULL DEFAULT '{}'::jsonb,
      "bankSyncEnabled"   BOOLEAN,
      "consentVersion"    TEXT,
      "consentAcceptedAt" TIMESTAMP(3),
      "createdAt"         TIMESTAMP(3) NOT NULL DEFAULT now(),
      "updatedAt"         TIMESTAMP(3) NOT NULL DEFAULT now()
    );
  END IF;
END$$;

-- Add/align columns for legacy installs (no-ops if already present)
ALTER TABLE "UserSettings" ADD COLUMN IF NOT EXISTS "id"                TEXT;
ALTER TABLE "UserSettings" ADD COLUMN IF NOT EXISTS "features"          JSONB        NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE "UserSettings" ADD COLUMN IF NOT EXISTS "bankSyncEnabled"   BOOLEAN;
ALTER TABLE "UserSettings" ADD COLUMN IF NOT EXISTS "consentVersion"    TEXT;
ALTER TABLE "UserSettings" ADD COLUMN IF NOT EXISTS "consentAcceptedAt" TIMESTAMP(3);
ALTER TABLE "UserSettings" ADD COLUMN IF NOT EXISTS "createdAt"         TIMESTAMP(3) NOT NULL DEFAULT now();
ALTER TABLE "UserSettings" ADD COLUMN IF NOT EXISTS "updatedAt"         TIMESTAMP(3) NOT NULL DEFAULT now();

-- Backfill id deterministically from userId (only where missing)
UPDATE "UserSettings"
SET "id" = COALESCE("id", CONCAT('us_', "userId"));

-- Ensure PK on id (id must be NOT NULL first)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'UserSettings_pkey'
  ) THEN
    ALTER TABLE "UserSettings" ALTER COLUMN "id" SET NOT NULL;
    ALTER TABLE "UserSettings" ADD CONSTRAINT "UserSettings_pkey" PRIMARY KEY ("id");
  END IF;
END$$;

-- Ensure unique 1:1 on userId
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename  = 'UserSettings'
      AND indexname  = 'UserSettings_userId_key'
  ) THEN
    CREATE UNIQUE INDEX "UserSettings_userId_key" ON "UserSettings" ("userId");
  END IF;
END$$;

-- ============================================================
-- Phase 13 additions on BankItem
-- ============================================================
ALTER TABLE "BankItem"
  ADD COLUMN IF NOT EXISTS "paused"     BOOLEAN      NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "lastSyncAt" TIMESTAMP(3);
