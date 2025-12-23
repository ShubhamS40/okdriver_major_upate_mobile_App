const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');
const prisma = new PrismaClient();

function generateTxnId() {
  return 'uw_' + Date.now() + '_' + Math.floor(Math.random() * 1e6);
}

function sha512(str) {
  return crypto.createHash('sha512').update(str).digest('hex');
}

function buildPayUParams({ amount, firstname, email, phone, surl, furl, udf1 }) {
  const key = process.env.PAYU_KEY;
  const salt = process.env.PAYU_SALT;
  const txnid = generateTxnId();
  const amtStr = Number(amount).toFixed(2);
  const fields = {
    key,
    txnid,
    amount: amtStr,
    productinfo: 'API Wallet Recharge',
    firstname: firstname || 'User',
    email: email || 'user@example.com',
    phone: phone || '9999999999',
    surl,
    furl,
    udf1: udf1 || '', // userId
    udf2: '', udf3: '', udf4: '', udf5: '', udf6: '', udf7: '', udf8: '', udf9: '', udf10: ''
  };
  const hashString = `${fields.key}|${fields.txnid}|${fields.amount}|${fields.productinfo}|${fields.firstname}|${fields.email}|${fields.udf1}|${fields.udf2}|${fields.udf3}|${fields.udf4}|${fields.udf5}|${fields.udf6}|${fields.udf7}|${fields.udf8}|${fields.udf9}|${fields.udf10}|${salt}`;
  fields.hash = sha512(hashString);
  return fields;
}

// GET wallet
const getWallet = async (req, res) => {
  try {
    const { userId } = req.params;
    const wallet = await prisma.apiWallet.upsert({
      where: { userId },
      update: {},
      create: { userId, balance: 0 }
    });
    const txns = await prisma.apiTransaction.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, take: 20 });
    res.json({ ok: true, data: { balance: wallet.balance, transactions: txns } });
  } catch (err) {
    console.error('getWallet error:', err);
    res.status(500).json({ ok: false, error: 'internal' });
  }
};

// POST recharge order (PayU)
const createRechargeOrder = async (req, res) => {
  try {
    const { userId } = req.params;
    const { amount } = req.body || {};
    if (!amount || Number(amount) <= 0) return res.status(400).json({ ok: false, error: 'invalid amount' });

    if (!process.env.PAYU_KEY || !process.env.PAYU_SALT) {
      return res.status(500).json({ ok: false, error: 'payu env missing' });
    }

    // ensure wallet
    await prisma.apiWallet.upsert({ where: { userId }, update: {}, create: { userId, balance: 0 } });

    const user = await prisma.user.findUnique({ where: { id: userId } });

    const websiteBase = process.env.WEBSITE_BASE_URL || 'http://localhost:3000';
    const backendBase = process.env.BACKEND_BASE_URL || 'http://localhost:5000';
    const surl = `${backendBase}/api/user/wallet/payu-return`;
    const furl = `${backendBase}/api/user/wallet/payu-return`;

    const params = buildPayUParams({
      amount,
      firstname: user?.name || 'User',
      email: user?.email || 'user@example.com',
      phone: '9999999999',
      surl,
      furl,
      udf1: String(userId)
    });

    // record pending txn
    await prisma.apiTransaction.create({
      data: {
        userId,
        amount,
        type: 'CREDIT',
        status: 'PENDING',
        reference: params.txnid,
        reason: 'WALLET_RECHARGE'
      }
    });

    const action = (process.env.PAYU_BASE_URL || 'https://test.payu.in') + '/_payment';
    res.json({ ok: true, gateway: 'PAYU', action, params });
  } catch (err) {
    console.error('createRechargeOrder error:', err);
    res.status(500).json({ ok: false, error: 'internal' });
  }
};

// PayU return/verify (simplified)
const payuReturn = async (req, res) => {
  try {
    const { mihpayid, status, txnid, amount, udf1 } = req.body || {};
    const userId = udf1;
    const success = String(status).toLowerCase() === 'success';

    // update txn
    await prisma.apiTransaction.updateMany({
      where: { reference: txnid },
      data: { status: success ? 'SUCCESS' : 'FAILED' }
    });

    if (success) {
      await prisma.apiWallet.upsert({
        where: { userId },
        update: { balance: { increment: Number(amount) } },
        create: { userId, balance: Number(amount) }
      });
    }

    res.json({ ok: true });
  } catch (err) {
    console.error('payuReturn error:', err);
    res.status(500).json({ ok: false });
  }
};

module.exports = { getWallet, createRechargeOrder, payuReturn };


