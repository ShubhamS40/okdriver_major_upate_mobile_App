const crypto = require('crypto');
const { PrismaClient, Prisma } = require('@prisma/client');
const prisma = new PrismaClient();
const dotenv = require('dotenv');
dotenv.config();

const verifyPayment = async (req, res) => {
  try {
    const body = req.body || {};
    const key = process.env.PAYU_KEY;
    const salt = process.env.PAYU_SALT;

    const { status, txnid, amount, productinfo, firstname, email, mihpayid, hash } = body;

    const udf = [body.udf1||'',body.udf2||'',body.udf3||'',body.udf4||'',body.udf5||'',body.udf6||'',body.udf7||'',body.udf8||'',body.udf9||'',body.udf10||''];
    const reverseUdf = udf.reverse().join('|');
    const responseStr = `${salt}|${status}|${reverseUdf}|${email||''}|${firstname||''}|${productinfo||''}|${Number(amount).toFixed(2)}|${txnid}|${key}`;
    const expectedHash = crypto.createHash('sha512').update(responseStr).digest('hex');

    const allowBypass = process.env.NODE_ENV !== 'production' && process.env.PAYU_SKIP_VERIFY === 'true';
    if (expectedHash !== hash && !allowBypass) {
      return res.status(400).json({ success: false, message: 'Invalid PayU hash' });
    }
    if (status !== 'success') {
      await prisma.driverPayment.create({
        data: {
          driverId: String(body.udf2 || ''),
          planId: Number(body.udf1 || 0),
          amount: new Prisma.Decimal(Number(amount || 0)),
          status: 'FAILED',
          txnId: txnid,
          mihpayid: mihpayid || null,
        }
      });
      // Render a small HTML failure page for in-app WebView
      res.setHeader('Content-Type', 'text/html');
      return res.status(400).send(`<!doctype html><html><body style="font-family:sans-serif;padding:24px;">
<h2>Payment Failed</h2>
<p>Status: ${status}</p>
<button onclick="history.go(-1)">Back</button>
</body></html>`);
    }

    const driverId = String(body.udf2 || req.driver?.id || '');
    const planId = Number(body.udf1);

    // Validate driver exists before creating payment record
    if (!driverId || driverId === 'undefined' || driverId === 'null') {
      console.error('Invalid driverId in PayU callback:', driverId);
      return res.status(400).json({ success: false, message: 'Invalid driver ID in payment callback' });
    }

    const driver = await prisma.driver.findUnique({ where: { id: driverId } });
    if (!driver) {
      console.error('Driver not found for ID:', driverId);
      return res.status(404).json({ success: false, message: 'Driver not found' });
    }

    const plan = await prisma.driverPlan.findUnique({ where: { id: planId } });
    if (!plan) return res.status(404).json({ message: 'Plan not found' });

    const now = new Date();
    const endDate = new Date(now.getTime());
    endDate.setDate(endDate.getDate() + plan.durationDays);

    try {
      await prisma.driverPayment.create({
        data: {
          driverId,
          planId,
          amount: new Prisma.Decimal(Number(amount || 0)),
          status: 'SUCCESS',
          txnId: txnid,
          mihpayid: mihpayid || null,
        }
      });
    } catch (paymentError) {
      console.error('Error creating payment record:', paymentError);
      // Continue to create subscription even if payment record fails
    }

    try {
      await prisma.driverSubscription.create({
        data: {
          driverId,
          planId,
          startAt: now,
          endAt: endDate,
          status: 'ACTIVE',
          paymentRef: mihpayid || txnid
        }
      });
    } catch (subscriptionError) {
      console.error('Error creating subscription:', subscriptionError);
      return res.status(500).json({ success: false, message: 'Failed to create subscription', error: subscriptionError.message });
    }

    // Serve an in-app success page instead of redirecting to a website
    res.setHeader('Content-Type', 'text/html');
    return res.status(200).send(`<!doctype html><html><body style="font-family:sans-serif;padding:24px;">
<h2>Payment Successful</h2>
<p>Transaction: ${txnid}</p>
<button onclick="window.close();">Close</button>
<script>setTimeout(function(){ if (window.history.length > 1) { history.go(-2); } }, 500);</script>
</body></html>`);
  } catch (err) {
    console.error('Driver PayU verify error:', err);
    res.status(500).json({ error: err.message });
  }
};

module.exports = { verifyPayment };


