-- CreateTable
CREATE TABLE "BankItem" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "institutionName" TEXT,
    "plaidItemId" TEXT NOT NULL,
    "accessTokenEnc" TEXT NOT NULL,
    "lastCursor" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BankItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BankAccount" (
    "id" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "plaidAccountId" TEXT NOT NULL,
    "name" TEXT,
    "mask" TEXT,
    "subtype" TEXT,
    "officialName" TEXT,
    "currency" TEXT,

    CONSTRAINT "BankAccount_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BankTransaction" (
    "id" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "isoCurrency" TEXT,
    "amount" DECIMAL(65,30) NOT NULL,
    "authorizedDate" TIMESTAMP(3),
    "postedDate" TIMESTAMP(3),
    "pending" BOOLEAN NOT NULL,
    "name" TEXT,
    "merchantName" TEXT,
    "categoryPath" TEXT[],
    "pendingTransactionId" TEXT,
    "raw" JSONB NOT NULL,
    "removed" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "BankTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "BankItem_plaidItemId_key" ON "BankItem"("plaidItemId");

-- CreateIndex
CREATE INDEX "BankItem_userId_idx" ON "BankItem"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "BankAccount_plaidAccountId_key" ON "BankAccount"("plaidAccountId");

-- CreateIndex
CREATE INDEX "BankTransaction_accountId_idx" ON "BankTransaction"("accountId");

-- CreateIndex
CREATE INDEX "BankTransaction_postedDate_idx" ON "BankTransaction"("postedDate");

-- AddForeignKey
ALTER TABLE "BankAccount" ADD CONSTRAINT "BankAccount_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "BankItem"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BankTransaction" ADD CONSTRAINT "BankTransaction_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "BankAccount"("id") ON DELETE CASCADE ON UPDATE CASCADE;
