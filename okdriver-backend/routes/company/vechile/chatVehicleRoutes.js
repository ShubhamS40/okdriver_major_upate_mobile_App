// routes/company/vehicle/chatVehicleRoutes.js

const express = require("express");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

const router = express.Router();

// Chat history निकालना
router.get("/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;

    const chats = await prisma.vehicleChat.findMany({
      where: { vehicleNumber },
      orderBy: { createdAt: "asc" },
    });

    res.json({ success: true, chats });
  } catch (error) {
    console.error("❌ Error fetching chats:", error);
    res.status(500).json({ success: false, error: "Server error" });
  }
});

module.exports = router;
