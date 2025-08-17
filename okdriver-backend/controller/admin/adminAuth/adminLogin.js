
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const {PrismaClient} = require('@prisma/client'); // adjust path to your prisma client
const prisma = new PrismaClient();


// Login Admin
exports.loginAdmin = async (req, res) => {
    try {
        const { email, password } = req.body;

        const admin = await prisma.admin.findUnique({ where: { email } });
        if (!admin) {
            return res.status(400).json({ message: "Invalid email or password" });
        }

        const isMatch = await bcrypt.compare(password, admin.password);
        if (!isMatch) {
            return res.status(400).json({ message: "Invalid email or password" });
        }

        const token = jwt.sign(
            { id: admin.id, email: admin.email, role: 'admin' },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );

        res.json({ message: "Login successful", token });
    } catch (err) {
        console.error("Login Admin Error:", err);
        res.status(500).json({ message: "Internal server error" });
    }
};