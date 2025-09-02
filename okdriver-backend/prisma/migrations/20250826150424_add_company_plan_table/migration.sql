/*
  Warnings:

  - You are about to drop the `Plan` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `Subscription` table. If the table is not empty, all the data it contains will be lost.

*/
-- CreateEnum
CREATE TYPE "BillingCycle" AS ENUM ('DAILY', 'MONTHLY', 'THREE_MONTHS', 'YEARLY', 'CUSTOM');

-- DropForeignKey
ALTER TABLE "Company" DROP CONSTRAINT "Company_currentPlanId_fkey";

-- DropForeignKey
ALTER TABLE "Subscription" DROP CONSTRAINT "Subscription_companyId_fkey";

-- DropForeignKey
ALTER TABLE "Subscription" DROP CONSTRAINT "Subscription_planId_fkey";

-- AlterTable
ALTER TABLE "Vehicle" ADD COLUMN     "type" TEXT;

-- DropTable
DROP TABLE "Plan";

-- DropTable
DROP TABLE "Subscription";

-- CreateTable
CREATE TABLE "DriverPlan" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "price" DECIMAL(10,2) NOT NULL,
    "billingCycle" "BillingCycle" NOT NULL,
    "durationDays" INTEGER NOT NULL,
    "benefits" TEXT[],
    "features" TEXT[],
    "storageLimitGB" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DriverPlan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DriverService" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DriverService_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DriverSubscription" (
    "id" SERIAL NOT NULL,
    "driverId" TEXT NOT NULL,
    "planId" INTEGER NOT NULL,
    "startAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endAt" TIMESTAMP(3) NOT NULL,
    "status" "SubscriptionStatus" NOT NULL DEFAULT 'ACTIVE',
    "paymentRef" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DriverSubscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CompanyPlan" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "price" DECIMAL(10,2) NOT NULL,
    "durationDays" INTEGER NOT NULL,
    "billingCycle" TEXT NOT NULL,
    "keyAdvantages" TEXT[],
    "vehicleLimit" INTEGER NOT NULL,
    "storageLimitGB" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CompanyPlan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CompanyFeature" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CompanyFeature_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CompanyService" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "serviceType" TEXT,
    "color" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CompanyService_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CompanySubscription" (
    "id" SERIAL NOT NULL,
    "companyId" INTEGER NOT NULL,
    "planId" INTEGER NOT NULL,
    "startAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endAt" TIMESTAMP(3) NOT NULL,
    "status" "SubscriptionStatus" NOT NULL DEFAULT 'ACTIVE',
    "paymentRef" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CompanySubscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "_DriverPlanServices" (
    "A" INTEGER NOT NULL,
    "B" INTEGER NOT NULL,

    CONSTRAINT "_DriverPlanServices_AB_pkey" PRIMARY KEY ("A","B")
);

-- CreateTable
CREATE TABLE "_CompanyPlanServices" (
    "A" INTEGER NOT NULL,
    "B" INTEGER NOT NULL,

    CONSTRAINT "_CompanyPlanServices_AB_pkey" PRIMARY KEY ("A","B")
);

-- CreateTable
CREATE TABLE "_CompanyPlanFeatures" (
    "A" INTEGER NOT NULL,
    "B" INTEGER NOT NULL,

    CONSTRAINT "_CompanyPlanFeatures_AB_pkey" PRIMARY KEY ("A","B")
);

-- CreateIndex
CREATE UNIQUE INDEX "DriverService_name_key" ON "DriverService"("name");

-- CreateIndex
CREATE INDEX "DriverSubscription_driverId_status_idx" ON "DriverSubscription"("driverId", "status");

-- CreateIndex
CREATE INDEX "DriverSubscription_endAt_idx" ON "DriverSubscription"("endAt");

-- CreateIndex
CREATE UNIQUE INDEX "CompanyFeature_name_key" ON "CompanyFeature"("name");

-- CreateIndex
CREATE UNIQUE INDEX "CompanyService_name_key" ON "CompanyService"("name");

-- CreateIndex
CREATE INDEX "CompanySubscription_companyId_status_idx" ON "CompanySubscription"("companyId", "status");

-- CreateIndex
CREATE INDEX "CompanySubscription_endAt_idx" ON "CompanySubscription"("endAt");

-- CreateIndex
CREATE INDEX "_DriverPlanServices_B_index" ON "_DriverPlanServices"("B");

-- CreateIndex
CREATE INDEX "_CompanyPlanServices_B_index" ON "_CompanyPlanServices"("B");

-- CreateIndex
CREATE INDEX "_CompanyPlanFeatures_B_index" ON "_CompanyPlanFeatures"("B");

-- CreateIndex
CREATE INDEX "OTP_phone_code_idx" ON "OTP"("phone", "code");

-- CreateIndex
CREATE INDEX "OTP_expiresAt_idx" ON "OTP"("expiresAt");

-- AddForeignKey
ALTER TABLE "DriverSubscription" ADD CONSTRAINT "DriverSubscription_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "Driver"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DriverSubscription" ADD CONSTRAINT "DriverSubscription_planId_fkey" FOREIGN KEY ("planId") REFERENCES "DriverPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CompanySubscription" ADD CONSTRAINT "CompanySubscription_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CompanySubscription" ADD CONSTRAINT "CompanySubscription_planId_fkey" FOREIGN KEY ("planId") REFERENCES "CompanyPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Company" ADD CONSTRAINT "Company_currentPlanId_fkey" FOREIGN KEY ("currentPlanId") REFERENCES "CompanyPlan"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_DriverPlanServices" ADD CONSTRAINT "_DriverPlanServices_A_fkey" FOREIGN KEY ("A") REFERENCES "DriverPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_DriverPlanServices" ADD CONSTRAINT "_DriverPlanServices_B_fkey" FOREIGN KEY ("B") REFERENCES "DriverService"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_CompanyPlanServices" ADD CONSTRAINT "_CompanyPlanServices_A_fkey" FOREIGN KEY ("A") REFERENCES "CompanyPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_CompanyPlanServices" ADD CONSTRAINT "_CompanyPlanServices_B_fkey" FOREIGN KEY ("B") REFERENCES "CompanyService"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_CompanyPlanFeatures" ADD CONSTRAINT "_CompanyPlanFeatures_A_fkey" FOREIGN KEY ("A") REFERENCES "CompanyFeature"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_CompanyPlanFeatures" ADD CONSTRAINT "_CompanyPlanFeatures_B_fkey" FOREIGN KEY ("B") REFERENCES "CompanyPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;
