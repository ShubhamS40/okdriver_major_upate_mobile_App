const crypto = require('crypto');
const dotenv = require('dotenv');
dotenv.config();

function generateTxnId() {
  return 'tx_' + Date.now() + '_' + Math.floor(Math.random() * 1e6);
}

function sha512(str) {
  return crypto.createHash('sha512').update(str).digest('hex');
}

function buildPayUParams({ amount, productinfo, firstname, email, phone, surl, furl, udf1, udf2 }) {
  const key = process.env.PAYU_KEY;
  const salt = process.env.PAYU_SALT;
  const txnid = generateTxnId();

  const amtStr = Number(amount).toFixed(2);
  const fields = {
    key,
    txnid,
    amount: amtStr,
    productinfo: productinfo || 'Driver Plan',
    firstname: firstname || 'Driver',
    email: email || 'driver@example.com',
    phone: phone || '9999999999',
    surl,
    furl,
    udf1: udf1 || '', // planId
    udf2: udf2 || '', // driverId
    udf3: '', udf4: '', udf5: '', udf6: '', udf7: '', udf8: '', udf9: '', udf10: ''
  };

  const hashString = `${fields.key}|${fields.txnid}|${fields.amount}|${fields.productinfo}|${fields.firstname}|${fields.email}|${fields.udf1}|${fields.udf2}|${fields.udf3}|${fields.udf4}|${fields.udf5}|${fields.udf6}|${fields.udf7}|${fields.udf8}|${fields.udf9}|${fields.udf10}|${salt}`;
  fields.hash = sha512(hashString);
  return fields;
}

const createPaymentOrder = async (req, res) => {
  try {
    const { amount, planId, callbackBaseUrl, driverId } = req.body || {};

    if (!process.env.PAYU_KEY || !process.env.PAYU_SALT) {
      return res.status(500).json({ success: false, message: 'PayU env vars missing' });
    }
    if (!amount || !planId) {
      return res.status(400).json({ success: false, message: 'amount and planId required' });
    }

    // Prefer callbackBaseUrl provided by client (device-specific), else env
    const base = (callbackBaseUrl && String(callbackBaseUrl)) || process.env.BACKEND_BASE_URL || '';
    const backendBase = base || '';
    const normalizedBase = backendBase.endsWith('/') ? backendBase.slice(0, -1) : backendBase;
    const surl = `${normalizedBase || 'https://example.com'}/api/driver/payment/payu-return`;
    const furl = `${normalizedBase || 'https://example.com'}/api/driver/payment/payu-return`;

    const authDriver = req.driver || {};
    const driverIdStr = String(driverId || authDriver.id || '');

    const params = buildPayUParams({
      amount,
      productinfo: 'OKDriver Driver Subscription',
      firstname: authDriver.firstName || 'Driver',
      email: authDriver.email || 'driver@example.com',
      phone: authDriver.phone || '9999999999',
      surl,
      furl,
      udf1: String(planId),
      udf2: driverIdStr
    });

    const action = (process.env.PAYU_BASE_URL || 'https://test.payu.in') + '/_payment';
    return res.status(200).json({ success: true, gateway: 'PAYU', action, params });
  } catch (error) {
    console.error('Driver PayU createPaymentOrder error:', error);
    res.status(500).json({ success: false, message: 'Payment init failed' });
  }
};

module.exports = { createPaymentOrder };


