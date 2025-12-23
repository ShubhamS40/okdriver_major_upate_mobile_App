const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const crypto = require('crypto');

// PayU configuration - read from environment variables
const PAYU_MERCHANT_KEY = process.env.PAYU_KEY || 'gtKFFx';
const PAYU_SALT = process.env.PAYU_SALT || 'eCwWELxi';
const RAW_PAYU_BASE_URL = process.env.PAYU_BASE_URL || 'https://test.payu.in';
const PAYU_BASE_URL = RAW_PAYU_BASE_URL.endsWith('/_payment')
  ? RAW_PAYU_BASE_URL
  : `${RAW_PAYU_BASE_URL.replace(/\/$/, '')}/_payment`;

// Generate transaction ID
const generateTransactionId = () => {
  return `OKDRIVER-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
};

// Calculate PayU hash (include udf1..udf10 like driver flow)
const calculateHash = (data) => {
  const udf1 = data.udf1 || '';
  const udf2 = data.udf2 || '';
  const udf3 = data.udf3 || '';
  const udf4 = data.udf4 || '';
  const udf5 = data.udf5 || '';
  const udf6 = data.udf6 || '';
  const udf7 = data.udf7 || '';
  const udf8 = data.udf8 || '';
  const udf9 = data.udf9 || '';
  const udf10 = data.udf10 || '';
  const amount = (typeof data.amount === 'string' ? data.amount : Number(data.amount).toFixed(2));
  const hashString = `${PAYU_MERCHANT_KEY}|${data.txnid}|${amount}|${data.productinfo}|${data.firstname}|${data.email}|${udf1}|${udf2}|${udf3}|${udf4}|${udf5}|${udf6}|${udf7}|${udf8}|${udf9}|${udf10}|${PAYU_SALT}`;
  return crypto.createHash('sha512').update(hashString).digest('hex');
};

// Create a new payment order
exports.createPaymentOrder = async (req, res) => {
  try {
    const websiteBaseRaw = process.env.WEBSITE_BASE_URL || 'http://localhost:3000';
    const websiteBase = websiteBaseRaw.replace(/\/$/, '');
    const { userId, planId } = req.body;

    if (!userId || !planId) {
      return res.status(400).json({
        success: false,
        message: 'User ID and Plan ID are required'
      });
    }

    // Get user and plan details
    const user = await prisma.user.findUnique({
      where: { id: userId }
    });

    const plan = await prisma.apiPlan.findUnique({
      where: { id: planId }
    });

    if (!user || !plan) {
      return res.status(404).json({
        success: false,
        message: 'User or Plan not found'
      });
    }

    // Create transaction ID
    const txnid = generateTransactionId();

    // Determine mode based on base URL
    const isTestEnv = /test\.payu\.in/.test(PAYU_BASE_URL);
    // Optional sanity check: common mismatch between key/salt and environment
    if (process.env.NODE_ENV !== 'production') {
      if (isTestEnv && PAYU_MERCHANT_KEY !== 'gtKFFx') {
        console.warn('PayU: Using non-sandbox key with test endpoint. This will fail.');
      }
      if (!isTestEnv && PAYU_MERCHANT_KEY === 'gtKFFx') {
        console.warn('PayU: Using sandbox key with production endpoint. This will fail.');
      }
    }

    // Create payment data
    const safeFirstName = (user.name || 'User').toString().trim().split(' ')[0];
    const safeEmail = (user.email || '').toString().trim().toLowerCase();
    const safeProductInfo = `API Plan ${plan.name}`;
    const paymentData = {
      key: PAYU_MERCHANT_KEY,
      txnid: txnid,
      amount: Number(plan.price).toFixed(2),
      productinfo: safeProductInfo,
      firstname: safeFirstName,
      lastname: '',
      email: safeEmail,
      phone: user.phone || '',
      surl: `${req.protocol}://${req.get('host')}/api/user/payment/success`,
      furl: `${req.protocol}://${req.get('host')}/api/user/payment/failure`,
      udf1: String(userId),
      udf2: String(planId),
      udf3: '',
      udf4: '',
      udf5: '',
      udf6: '',
      udf7: '',
      udf8: '',
      udf9: '',
      udf10: '',
      service_provider: 'payu_paisa'
    };

    // Calculate hash
    const hash = calculateHash(paymentData);
    if (process.env.NODE_ENV !== 'production') {
      const dbg = `${PAYU_MERCHANT_KEY}|${paymentData.txnid}|${paymentData.amount}|${paymentData.productinfo}|${paymentData.firstname}|${paymentData.email}|${paymentData.udf1}|${paymentData.udf2}|${paymentData.udf3}|${paymentData.udf4}|${paymentData.udf5}|${paymentData.udf6}|${paymentData.udf7}|${paymentData.udf8}|${paymentData.udf9}|${paymentData.udf10}|${PAYU_SALT}`;
      console.log('PayU paymentData:', paymentData);
      console.log('PayU hashString:', dbg);
      console.log('PayU hash:', hash);
    }

    // Respond with the structure expected by the frontend
    return res.status(200).json({
      success: true,
      paymentUrl: PAYU_BASE_URL,
      formData: {
        ...paymentData,
        hash
      },
      debug: process.env.NODE_ENV !== 'production' ? { hash } : undefined
    });
  } catch (error) {
    console.error('Create Payment Order Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error during payment order creation'
    });
  }
};

// Handle payment success
exports.handlePaymentSuccess = async (req, res) => {
  try {
    const websiteBaseRaw = process.env.WEBSITE_BASE_URL || 'http://localhost:3000';
    const websiteBase = websiteBaseRaw.replace(/\/$/, '');
    const {
      txnid,
      status,
      mihpayid,
      amount,
      udf1: userId,
      udf2: planId
    } = req.body;

    // Verify payment status
    if (status !== 'success') {
      return res.redirect(`${websiteBase}/user/dashboard?payment=failure`);
    }

    // Get plan details
    const plan = await prisma.apiPlan.findUnique({
      where: { id: Number(planId) }
    });

    if (!plan) {
      return res.redirect(`${websiteBase}/user/dashboard?payment=failure`);
    }

    // Calculate expiry date
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + plan.daysValidity);

    // Create subscription and record payment metadata on subscription
    await prisma.userApiSubscription.create({
      data: {
        userId: userId,
        planId: Number(planId),
        status: 'ACTIVE',
        startAt: new Date(),
        endAt: expiresAt,
        paymentRef: mihpayid,
        paymentStatus: 'SUCCESS',
        payuMihpayid: mihpayid,
        paymentAmount: parseFloat(amount)
      }
    });

    return res.redirect(`${websiteBase}/user/dashboard?payment=success`);
  } catch (error) {
    console.error('Payment Success Handler Error:', error);
    const websiteBaseRaw = process.env.WEBSITE_BASE_URL || 'http://localhost:3000';
    const websiteBase = websiteBaseRaw.replace(/\/$/, '');
    return res.redirect(`${websiteBase}/user/dashboard?payment=failure`);
  }
};

// Handle payment failure
exports.handlePaymentFailure = async (req, res) => {
  try {
    const websiteBaseRaw = process.env.WEBSITE_BASE_URL || 'http://localhost:3000';
    const websiteBase = websiteBaseRaw.replace(/\/$/, '');
    const { txnid, status, error_Message } = req.body;

    return res.redirect(`${websiteBase}/user/dashboard?payment=failure`);
  } catch (error) {
    console.error('Payment Failure Handler Error:', error);
    const websiteBaseRaw = process.env.WEBSITE_BASE_URL || 'http://localhost:3000';
    const websiteBase = websiteBaseRaw.replace(/\/$/, '');
    return res.redirect(`${websiteBase}/user/dashboard?payment=failure`);
  }
};