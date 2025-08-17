const jwt = require('jsonwebtoken');

module.exports = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    if (!authHeader) {
        return res.status(401).json({ message: "Not authorized, token missing" });
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
        return res.status(401).json({ message: "Not authorized, token missing" });
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        if (decoded.role !== 'admin') {
            return res.status(403).json({ message: "Access denied, not an admin" });
        }
        req.admin = decoded;
        next();
    } catch (err) {
        return res.status(401).json({ message: "Invalid token" });
    }
};
