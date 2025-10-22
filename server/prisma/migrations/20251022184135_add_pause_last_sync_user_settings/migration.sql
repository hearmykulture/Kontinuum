-- AlterTable
ALTER TABLE "BankItem" ADD COLUMN     "lastSyncAt" TIMESTAMP(3),
ADD COLUMN     "paused" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "UserSettings" (
    "userId" TEXT NOT NULL,
    "bankSyncEnabled" BOOLEAN NOT NULL DEFAULT true,
    "consentVersion" TEXT,
    "consentAcceptedAt" TIMESTAMP(3),

    CONSTRAINT "UserSettings_pkey" PRIMARY KEY ("userId")
);

-- CreateIndex
CREATE INDEX "BankItem_userId_idx" ON "BankItem"("userId");
