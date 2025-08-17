// controller/payment/companyPurchasePayment.js
const Razorpay = require("razorpay");
const dotenv = require("dotenv");
dotenv.config();

const createPaymentOrder = async (req, res) => {
    try {
        const { amount, currency = "INR", receipt } = req.body;

        console.log("📥 Incoming Payment Request:", req.body);
        console.log("🔑 Razorpay Key ID:", process.env.RAZORPAY_KEY_ID);
        console.log("🔑 Razorpay Secret:", process.env.RAZORPAY_KEY_SECRET ? "Loaded ✅" : "Missing ❌");

        if (!amount) {
            console.warn("⚠️ Amount is missing in request body");
            return res.status(400).json({ success: false, message: "Amount is required" });
        }

        const razorpay = new Razorpay({
            key_id: process.env.RAZORPAY_KEY_ID,
            key_secret: process.env.RAZORPAY_KEY_SECRET
        });

        const options = {
            amount: amount * 100, // Amount in paise
            currency,
            receipt: receipt || `receipt_${Date.now()}`
        };

        console.log("📦 Razorpay Order Options:", options);

        const order = await razorpay.orders.create(options);

        console.log("✅ Razorpay Order Created:", order);

        return res.status(200).json({
            success: true,
            order
        });

    } catch (error) {
        console.error("❌ Error creating payment order:", error);
        res.status(500).json({ success: false, message: "Payment order creation failed", error });
    }
};

module.exports = { createPaymentOrder };
