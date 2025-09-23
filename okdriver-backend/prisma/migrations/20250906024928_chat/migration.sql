-- CreateTable
CREATE TABLE "VehicleChat" (
    "id" SERIAL NOT NULL,
    "vehicleId" INTEGER NOT NULL,
    "companyId" INTEGER NOT NULL,
    "senderType" "SenderType" NOT NULL,
    "message" TEXT NOT NULL,
    "attachmentUrl" TEXT,
    "isRead" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VehicleChat_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "VehicleChat_vehicleId_createdAt_idx" ON "VehicleChat"("vehicleId", "createdAt");

-- CreateIndex
CREATE INDEX "VehicleChat_companyId_createdAt_idx" ON "VehicleChat"("companyId", "createdAt");

-- CreateIndex
CREATE INDEX "VehicleChat_isRead_idx" ON "VehicleChat"("isRead");

-- AddForeignKey
ALTER TABLE "VehicleChat" ADD CONSTRAINT "VehicleChat_vehicleId_fkey" FOREIGN KEY ("vehicleId") REFERENCES "Vehicle"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VehicleChat" ADD CONSTRAINT "VehicleChat_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE CASCADE ON UPDATE CASCADE;
