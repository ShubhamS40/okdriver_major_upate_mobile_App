// controller/payment/companyPurchasePayment.js (PayU integration)
const crypto = require('crypto');
const dotenv = require('dotenv');
dotenv.config();

function generateTxnId() {
    return 'tx_' + Date.now() + '_' + Math.floor(Math.random() * 1e6);
}

function sha512(str) {
    return crypto.createHash('sha512').update(str).digest('hex');
}

// PayU parameters and hash generation per docs
function buildPayUParams({ amount, productinfo, firstname, email, phone, surl, furl, udf1, udf2 }) {
    const key = process.env.PAYU_KEY;
    const salt = process.env.PAYU_SALT;
    const txnid = generateTxnId();

    const amtStr = Number(amount).toFixed(2);
    const fields = {
        key,
        txnid,
        amount: amtStr,
        productinfo: productinfo || 'Company Plan',
        firstname: firstname || 'Company',
        email: email || 'company@example.com',
        phone: phone || '9999999999',
        surl,
        furl,
        udf1: udf1 || '', // planId
        udf2: udf2 || '', // companyId
        udf3: '', udf4: '', udf5: '', udf6: '', udf7: '', udf8: '', udf9: '', udf10: ''
    };

    // hashSequence: key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5|udf6|udf7|udf8|udf9|udf10|salt
    const hashString = `${fields.key}|${fields.txnid}|${fields.amount}|${fields.productinfo}|${fields.firstname}|${fields.email}|${fields.udf1}|${fields.udf2}|${fields.udf3}|${fields.udf4}|${fields.udf5}|${fields.udf6}|${fields.udf7}|${fields.udf8}|${fields.udf9}|${fields.udf10}|${salt}`;
    fields.hash = sha512(hashString);
    return fields;
}

const createPaymentOrder = async (req, res) => {
    try {
        const { amount, currency = 'INR', receipt, planId } = req.body || {};

        if (!process.env.PAYU_KEY || !process.env.PAYU_SALT) {
            return res.status(500).json({ success: false, message: 'PayU environment variables missing (PAYU_KEY/PAYU_SALT)' });
        }

        if (!amount) {
            return res.status(400).json({ success: false, message: 'Amount is required' });
        }

        // Prefer website return URL in development to avoid localhost backend callback issues
        const websiteBase = process.env.WEBSITE_BASE_URL || 'https://okdriver.in';
        const backendBase = 'https://backend.okdriver.in';
        const useWebsiteReturn = process.env.NODE_ENV !== 'production';
        const surl = useWebsiteReturn
            ? `${websiteBase}/api/payment/payu-return`
            : `${backendBase}/api/admin/companyplan/payment/payu-return`;
        const furl = useWebsiteReturn
            ? `${websiteBase}/api/payment/payu-return`
            : `${backendBase}/api/admin/companyplan/payment/payu-return`;

        const authCompany = req.company || {};

        const params = buildPayUParams({
            amount,
            productinfo: receipt || 'OKDriver Subscription',
            firstname: authCompany.name || 'Company',
            email: authCompany.email || 'company@example.com',
            phone: authCompany.phone || '9999999999',
            surl,
            furl,
            udf1: String(planId || ''),
            udf2: String(authCompany.id || '')
        });

        const action = (process.env.PAYU_BASE_URL || 'https://test.payu.in') + '/_payment';
        return res.status(200).json({ success: true, gateway: 'PAYU', action, params });
    } catch (error) {
        console.error('❌ PayU createPaymentOrder error:', error);
        res.status(500).json({ success: false, message: 'Payment init failed' });
    }
};

module.exports = { createPaymentOrder };
