-- CreateTable
CREATE TABLE "ClientList" (
    "id" SERIAL NOT NULL,
    "companyId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ClientList_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ClientListMember" (
    "id" SERIAL NOT NULL,
    "clientListId" INTEGER NOT NULL,
    "clientId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ClientListMember_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ClientList_companyId_idx" ON "ClientList"("companyId");

-- CreateIndex
CREATE UNIQUE INDEX "ClientList_companyId_name_key" ON "ClientList"("companyId", "name");

-- CreateIndex
CREATE INDEX "ClientListMember_clientId_idx" ON "ClientListMember"("clientId");

-- CreateIndex
CREATE UNIQUE INDEX "ClientListMember_clientListId_clientId_key" ON "ClientListMember"("clientListId", "clientId");

-- AddForeignKey
ALTER TABLE "ClientList" ADD CONSTRAINT "ClientList_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ClientListMember" ADD CONSTRAINT "ClientListMember_clientListId_fkey" FOREIGN KEY ("clientListId") REFERENCES "ClientList"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ClientListMember" ADD CONSTRAINT "ClientListMember_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "Client"("id") ON DELETE CASCADE ON UPDATE CASCADE;
