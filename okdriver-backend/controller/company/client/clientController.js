const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const jwt = require('jsonwebtoken');

/**
 * Client login with email (create account if doesn't exist)
 */
const clientLogin = async (req, res) => {
  try {
    const { email, companyId } = req.body;
    if (!email || !companyId) {
      return res.status(400).json({ message: "Email and companyId are required" });
    }

    let client = await prisma.client.findUnique({ where: { email } });

    // Create client if not exists (must belong to company)
    if (!client) {
      client = await prisma.client.create({
        data: { email, companyId }
      });
    }

    // Generate JWT for client
    const token = jwt.sign({ clientId: client.id, companyId }, process.env.JWT_SECRET, {
      expiresIn: '7d'
    });

    return res.status(200).json({ message: "Login successful", token, client });
  } catch (error) {
    console.error("Error in client login:", error);
    return res.status(500).json({ message: "Internal Server Error" });
  }
};

module.exports = { clientLogin };