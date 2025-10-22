/*
  Warnings:

  - You are about to drop the column `accessTokenEnc` on the `BankItem` table. All the data in the column will be lost.
  - You are about to drop the column `institutionName` on the `BankItem` table. All the data in the column will be lost.
  - You are about to drop the column `lastCursor` on the `BankItem` table. All the data in the column will be lost.
  - Added the required column `updatedAt` to the `BankItem` table without a default value. This is not possible if the table is not empty.

*/
-- DropIndex
DROP INDEX "public"."BankItem_userId_idx";

-- DropIndex
DROP INDEX "public"."BankTransaction_accountId_idx";

-- DropIndex
DROP INDEX "public"."BankTransaction_postedDate_idx";

-- AlterTable
ALTER TABLE "BankItem" DROP COLUMN "accessTokenEnc",
DROP COLUMN "institutionName",
DROP COLUMN "lastCursor",
ADD COLUMN     "cursor" TEXT,
ADD COLUMN     "institution" TEXT,
ADD COLUMN     "status" TEXT NOT NULL DEFAULT 'active',
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL;

-- AlterTable
ALTER TABLE "BankTransaction" ALTER COLUMN "pending" SET DEFAULT false,
ALTER COLUMN "categoryPath" SET DEFAULT ARRAY[]::TEXT[],
ALTER COLUMN "raw" DROP NOT NULL;

-- CreateTable
CREATE TABLE "PlaidSecret" (
    "id" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "accessToken" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PlaidSecret_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "PlaidSecret_itemId_key" ON "PlaidSecret"("itemId");

-- CreateIndex
CREATE INDEX "BankAccount_itemId_idx" ON "BankAccount"("itemId");

-- CreateIndex
CREATE INDEX "BankTransaction_accountId_postedDate_idx" ON "BankTransaction"("accountId", "postedDate");

-- AddForeignKey
ALTER TABLE "PlaidSecret" ADD CONSTRAINT "PlaidSecret_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "BankItem"("id") ON DELETE CASCADE ON UPDATE CASCADE;
