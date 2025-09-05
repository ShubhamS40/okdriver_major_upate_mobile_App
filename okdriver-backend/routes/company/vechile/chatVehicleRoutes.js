// routes/company/vehicle/chatVehicleRoutes.js

const express = require("express");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
const vehicleChatController = require("../../../controller/company/vechile/vehicleChatController");
const { authenticateCompany } = require("../../../middleware/companyAuth");

const router = express.Router();

// Get vehicle chat history (protected route)
router.get("/:vehicleId/chat-history", authenticateCompany, vehicleChatController.getVehicleChatHistory);

// Chat history निकालना (legacy route)
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
