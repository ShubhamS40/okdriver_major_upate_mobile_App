const crypto = require('crypto');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const dotenv = require('dotenv');
dotenv.config();

// PayU return handler for vehicle limit top-up plans
const verifyVehicleLimitPayment = async (req, res) => {
  try {
    // PayU posts as application/x-www-form-urlencoded by default
    const body = req.body || {};
    const key = process.env.PAYU_KEY;
    const salt = process.env.PAYU_SALT;

    // PayU posts fields including status, txnid, amount, productinfo, email, etc., and hash
    const {
      status,
      txnid,
      amount,
      productinfo,
      firstname,
      email,
      mihpayid,
      hash,
      udf1, // planId
      udf2  // companyId
    } = body;

    // Verify hash for response: salt|status|||||||||udf10|udf9|...|udf1|email|firstname|productinfo|amount|txnid|key
    const udf = [body.udf1||'',body.udf2||'',body.udf3||'',body.udf4||'',body.udf5||'',body.udf6||'',body.udf7||'',body.udf8||'',body.udf9||'',body.udf10||''];
    const reverseUdf = udf.reverse().join('|');
    const responseStr = `${salt}|${status}|${reverseUdf}|${email||''}|${firstname||''}|${productinfo||''}|${Number(amount).toFixed(2)}|${txnid}|${key}`;
    const expectedHash = crypto.createHash('sha512').update(responseStr).digest('hex');

    const allowBypass = process.env.NODE_ENV !== 'production' && process.env.PAYU_SKIP_VERIFY === 'true';
    if (expectedHash !== hash && !allowBypass) {
      return res.status(400).json({ success: false, message: 'Invalid PayU hash' });
    }

    if (status !== 'success') {
      return res.status(400).json({ success: false, message: 'Payment failed', status });
    }

    const companyId = Number(udf2 || req.company?.id || 0);
    const numericPlanId = Number(udf1);

    // Get the vehicle limit plan
    const plan = await prisma.companyPlan.findUnique({ 
      where: { id: numericPlanId },
      select: {
        id: true,
        name: true,
        vehicleLimit: true,
        planType: true,
        price: true
      }
    });
    
    if (!plan) return res.status(404).json({ message: 'Plan not found' });
    
    // Verify this is a vehicle limit plan
    if (plan.planType !== 'VEHICLE_LIMIT' || !plan.vehicleLimit) {
      return res.status(400).json({ success: false, message: 'Invalid plan type for vehicle limit top-up' });
    }

    // Get company's current subscription expiry date
    const company = await prisma.company.findUnique({
      where: { id: companyId },
      select: {
        subscriptionExpiresAt: true,
        additionalVehicleLimit: true
      }
    });

    if (!company) return res.status(404).json({ message: 'Company not found' });
    
    // Use company's subscription expiry date for the top-up expiry
    const expiresAt = company.subscriptionExpiresAt || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // Default to 30 days if no subscription

    // Create a vehicle limit top-up record
    await prisma.vehicleLimitTopUp.create({
      data: {
        companyId,
        planId: numericPlanId,
        vehicleCount: plan.vehicleLimit,
        purchasedAt: new Date(),
        expiresAt,
        status: 'ACTIVE',
        paymentRef: mihpayid || txnid
      }
    });

    // Update company's additional vehicle limit
    await prisma.company.update({
      where: { id: companyId },
      data: { 
        additionalVehicleLimit: company.additionalVehicleLimit + plan.vehicleLimit 
      }
    });

    const website = process.env.WEBSITE_BASE_URL || 'http://localhost:3000';
    const successUrl = `${website}/company/vehicle-limit-success?txnid=${encodeURIComponent(txnid)}&mihpayid=${encodeURIComponent(mihpayid||'')}`;
    
    if (req.headers.accept && req.headers.accept.includes('text/html')) {
      return res.redirect(302, successUrl);
    }
    
    return res.json({ 
      success: true, 
      message: 'Payment successful & vehicle limit updated', 
      txnid, 
      mihpayid, 
      redirect: successUrl,
      vehicleLimit: plan.vehicleLimit,
      newTotalLimit: company.additionalVehicleLimit + plan.vehicleLimit
    });
  } catch (err) {
    console.error('PayU Vehicle Limit Verification Error:', err);
    res.status(500).json({ error: err.message });
  }
};

module.exports = { verifyVehicleLimitPayment };