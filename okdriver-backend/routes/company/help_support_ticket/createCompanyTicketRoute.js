const express = require('express');
const router = express.Router();
const { verifyCompanyAuth } = require('../../../middleware/companyAuth');
const { createCompanyTicket, listCompanyTickets, getCompanyTicket } = require('../../../controller/company/help_support_ticket/createCompanyTicketController');

// Create a new help & support ticket
router.post('/tickets', verifyCompanyAuth, createCompanyTicket);
router.get('/tickets', verifyCompanyAuth, listCompanyTickets);
router.get('/tickets/:id', verifyCompanyAuth, getCompanyTicket);

module.exports = router;


