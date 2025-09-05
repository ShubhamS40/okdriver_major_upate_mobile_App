-- AlterTable
ALTER TABLE "Vehicle" ADD COLUMN     "lastLat" DECIMAL(10,7),
ADD COLUMN     "lastLng" DECIMAL(10,7),
ADD COLUMN     "lastLocationAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "Vehicle_lastLocationAt_idx" ON "Vehicle"("lastLocationAt");
