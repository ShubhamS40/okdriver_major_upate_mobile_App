const crypto = require("crypto");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

const verifyPayment = async (req, res) => {
  try {
    const {
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      planId
    } = req.body;

    const companyId = req.company.id; // Middleware me set kiya hua

    // 1️⃣ Signature verify
    const sign = razorpay_order_id + "|" + razorpay_payment_id;
    const expectedSign = crypto
      .createHmac("sha256", process.env.RAZORPAY_SECRET_KEY)
      .update(sign.toString())
      .digest("hex");

    if (expectedSign !== razorpay_signature) {
      return res.status(400).json({ message: "Invalid payment signature" });
    }

    console.log("✅ Payment verified");

    // 2️⃣ Plan find
    const plan = await prisma.plan.findUnique({ where: { id: planId } });
    if (!plan) {
      return res.status(404).json({ message: "Plan not found" });
    }

    // 3️⃣ End date calculate
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + plan.durationDays);

    // 4️⃣ Subscription create
    await prisma.subscription.create({
      data: {
        companyId,
        planId,
        endAt: endDate,
        status: "ACTIVE",
      },
    });

    // 5️⃣ Company update
    await prisma.company.update({
      where: { id: companyId },
      data: {
        currentPlanId: planId,
        subscriptionExpiresAt: endDate,
      },
    });

    res.json({ message: "Payment & Plan activated successfully" });

  } catch (err) {
    console.error("Payment Verification Error:", err);
    res.status(500).json({ error: err.message });
  }
};

module.exports = { verifyPayment };
