// controllers/companyController.js

const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const dotenv =require('dotenv')
const prisma = new PrismaClient();

dotenv.config();

// Company Registration
const registerCompany = async (req, res) => {
  try {
    const { name, email, password, type } = req.body;

    // Check required fields
    if (!name || !email || !password) {
      return res.status(400).json({ message: "Name, email, and password are required" });
    }

    // Check if email already exists
    const existing = await prisma.company.findUnique({ where: { email } });
    if (existing) {
      return res.status(400).json({ message: "Company already exists" });
    }

    // Hash the password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create the company
    const company = await prisma.company.create({
      data: {
        name,
        email,
        password: hashedPassword,
        type: type || "OTHER", // default enum value
        status: "ACTIVE"
      }
    });

    // Optional: generate a JWT token
    const token = jwt.sign(
      { id: company.id, email: company.email, role: "COMPANY" },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.status(201).json({
      message: "Company registered successfully",
      company: {
        id: company.id,
        name: company.name,
        email: company.email,
        type: company.type,
        status: company.status,
        createdAt: company.createdAt
      },
      token
    });
  } catch (err) {
    console.error("Register Company Error:", err);
    res.status(500).json({ error: "Internal Server Error" });
  }
};

module.exports = { registerCompany };
