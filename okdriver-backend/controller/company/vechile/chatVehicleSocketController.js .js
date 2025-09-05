// controller/company/vehicle/chatVehicleSocketController.js

const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

module.exports = {
  handleConnection: async (socket, io) => {
    console.log("🔗 New client connected:", socket.id);

    // जब कोई client किसी vehicle की chat join करे
    socket.on("joinVehicleRoom", (vehicleNumber) => {
      socket.join(vehicleNumber);
      console.log(`🚚 Client ${socket.id} joined vehicle room: ${vehicleNumber}`);
    });

    // जब कोई message भेजे
    socket.on("sendMessage", async (data) => {
      try {
        const { vehicleNumber, senderRole, message } = data;

        if (!vehicleNumber || !message) return;

        // DB में save करना
        const chat = await prisma.vehicleChat.create({
          data: {
            vehicleNumber,
            senderRole, // e.g. "driver" / "company" / "client"
            message,
          },
        });

        // Room में सबको भेजना
        io.to(vehicleNumber).emit("receiveMessage", chat);
        console.log(`💬 Message sent to room ${vehicleNumber}: ${message}`);
      } catch (error) {
        console.error("❌ Error saving message:", error);
      }
    });

    // disconnect
    socket.on("disconnect", () => {
      console.log("❌ Client disconnected:", socket.id);
    });
  },
};
