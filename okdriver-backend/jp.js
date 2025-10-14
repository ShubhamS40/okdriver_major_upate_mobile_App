const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function clearDriverSubscription() {
  await prisma.driverSubscription.deleteMany({});
  console.log("All records deleted from DriverSubscription table");
}

clearDriverSubscription()
  .catch(e => console.error(e))
  .finally(async () => await prisma.$disconnect());
