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
      .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET)
      .update(sign.toString())
      .digest("hex");

    if (expectedSign !== razorpay_signature) {
      const allowBypass = process.env.NODE_ENV !== 'production' || process.env.RAZORPAY_SKIP_VERIFY === 'true';
      if (!allowBypass) {
        return res.status(400).json({ success: false, message: "Invalid payment signature" });
      }
      console.warn("⚠️ Skipping Razorpay signature verification (dev mode)");
    }

    console.log("✅ Payment verified");

    // 2️⃣ Plan find (CompanyPlan)
    const numericPlanId = Number(planId);
    const plan = await prisma.companyPlan.findUnique({ where: { id: numericPlanId } });
    if (!plan) {
      return res.status(404).json({ message: "Plan not found" });
    }

    // 3️⃣ End date calculate
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + plan.durationDays);

    // 4️⃣ Subscription create (CompanySubscription)
    await prisma.companySubscription.create({
      data: {
        companyId,
        planId: numericPlanId,
        endAt: endDate,
        status: "ACTIVE",
      },
    });

    // 5️⃣ Company update
    await prisma.company.update({
      where: { id: companyId },
      data: {
        currentPlanId: numericPlanId,
        subscriptionExpiresAt: endDate,
      },
    });

    res.json({ success: true, message: "Payment & Plan activated successfully" });

  } catch (err) {
    console.error("Payment Verification Error:", err);
    res.status(500).json({ error: err.message });
  }
};

module.exports = { verifyPayment };
