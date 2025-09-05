const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Send message to a vehicle (from Client)
 */
const sendMessageToVehicle = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const { vehicleId, message } = req.body;

    if (!clientId || !vehicleId || !message) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    // Ensure client has access to this vehicle
    const access = await prisma.clientVehicleAccess.findFirst({
      where: { clientId, vehicleId }
    });

    if (!access) {
      return res.status(403).json({ message: "No access to this vehicle" });
    }

    const chat = await prisma.chatMessage.create({
      data: {
        vehicleId,
        senderType: "CLIENT",
        senderClientId: clientId,
        message
      }
    });

    return res.status(201).json({ message: "Message sent", chat });
  } catch (error) {
    console.error("Error sending chat:", error);
    return res.status(500).json({ message: "Internal Server Error" });
  }
};

/**
 * Fetch chat history of a vehicle
 */
const getVehicleChats = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const { vehicleId } = req.params;

    // Ensure client has access
    const access = await prisma.clientVehicleAccess.findFirst({
      where: { clientId, vehicleId: Number(vehicleId) }
    });

    if (!access) {
      return res.status(403).json({ message: "No access to this vehicle" });
    }

    const chats = await prisma.chatMessage.findMany({
      where: { vehicleId: Number(vehicleId) },
      orderBy: { createdAt: 'asc' }
    });

    return res.status(200).json(chats);
  } catch (error) {
    console.error("Error fetching chats:", error);
    return res.status(500).json({ message: "Internal Server Error" });
  }
};

module.exports = {
  sendMessageToVehicle,
  getVehicleChats,
};
