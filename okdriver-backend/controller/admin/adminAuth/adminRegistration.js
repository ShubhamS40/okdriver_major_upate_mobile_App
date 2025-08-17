const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const {PrismaClient} = require('@prisma/client'); // adjust path to your prisma client
const prisma = new PrismaClient();

// Register Admin
exports.registerAdmin = async (req, res) => {
    try {
        const { name, email, password } = req.body;

        // check if already exists
        const existing = await prisma.admin.findUnique({ where: { email } });
        if (existing) {
            return res.status(400).json({ message: "Admin already exists" });
        }

        const hashedPassword = await bcrypt.hash(password, 10);

        const admin = await prisma.admin.create({
            data: { name, email, password: hashedPassword }
        });

        res.status(201).json({ message: "Admin registered successfully", admin });
    } catch (err) {
        console.error("Register Admin Error:", err);
        res.status(500).json({ message: "Internal server error" });
    }
};


