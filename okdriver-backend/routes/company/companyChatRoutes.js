const express = require('express');
const { verifyCompanyAuth } = require('../../middleware/companyAuth');
const {
  sendMessageToVehicleByCompany,
  sendMessageToClientByCompany,
  getVehicleChatsForCompany,
} = require('../../controller/company/companyChatController');

const router = express.Router();

// Send message to a vehicle room
router.post('/chat', verifyCompanyAuth, sendMessageToVehicleByCompany);

// Send message targeting a client in the vehicle context (optional)
router.post('/chat/client', verifyCompanyAuth, sendMessageToClientByCompany);

// Fetch chat history for a vehicle (monitor)
router.get('/chat/:vehicleId', verifyCompanyAuth, getVehicleChatsForCompany);

module.exports = router;


