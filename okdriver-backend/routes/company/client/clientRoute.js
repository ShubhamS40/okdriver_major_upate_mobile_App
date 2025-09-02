const express = require('express');
const {
  getAssignedVehicles,
} = require('./../../../controller/company/client/getAssignedVechileDetails'); // SAME folder ka route.js import karo
const {
  clientLogin
} = require('./../../../controller/company/client/clientController'); // SAME folder ka route.js import karo
const {
  getVehicleChats,sendMessageToVehicle
} = require('./../../../controller/company/client/chatVechileController'); // SAME folder ka route.js import karo

const verifyClientAuth = require('../../../middleware/verifyClientAuth');
const { verifyCompanyAuth } = require('../../../middleware/companyAuth');

// List controllers
const {
  createClientList,
  getClientLists,
  deleteClientList,
  addMemberToList,
  removeMemberFromList,
  assignListToVehicle,
  revokeListFromVehicle,
  getVehicleClients
} = require('../../../controller/company/client/listController');
const { getVehicleListAssignments, getVehicleDetails } = require('../../../controller/company/client/listAssignmentsController');

const router = express.Router();

// Debug route to test if router is working
router.get('/test', (req, res) => {
  console.log('✅ Client route test endpoint hit');
  res.json({ message: 'Client route is working' });
});

// Debug route to test assignment endpoint
router.get('/test-assignment/:listId/:vehicleId', verifyCompanyAuth, (req, res) => {
  console.log('🔍 Testing assignment endpoint with:', req.params);
  res.json({ 
    message: 'Assignment test endpoint hit',
    params: req.params,
    companyId: req.company.id
  });
});

// Login/Register Client
router.post('/login', clientLogin);

// Get all assigned vehicles (with last location)
router.get('/vehicles', verifyClientAuth, getAssignedVehicles);

// Send message to a vehicle
router.post('/chat', verifyClientAuth, sendMessageToVehicle);

// Get chat history for a vehicle
router.get('/chat/:vehicleId', verifyClientAuth, getVehicleChats);

// Client Lists (company-authenticated)
router.post('/lists', verifyCompanyAuth, createClientList);
router.get('/lists', verifyCompanyAuth, getClientLists);
router.delete('/lists/:listId', verifyCompanyAuth, deleteClientList);

// Members
router.post('/lists/:listId/members', verifyCompanyAuth, addMemberToList);
router.delete('/lists/:listId/members/:clientId', verifyCompanyAuth, removeMemberFromList);

// Assignments to vehicles
router.post('/lists/:listId/assign/:vehicleId', verifyCompanyAuth, assignListToVehicle);
router.delete('/lists/:listId/assign/:vehicleId', verifyCompanyAuth, revokeListFromVehicle);

// View who can access a vehicle
router.get('/vehicles/:vehicleId/clients', verifyCompanyAuth, getVehicleClients);

// Vehicle -> list names assignments (for dashboard table)
router.get('/vehicles-list-assignments', verifyCompanyAuth, getVehicleListAssignments);

// Vehicle details (location, lists, chats)
router.get('/vehicle/:vehicleId/details', verifyCompanyAuth, getVehicleDetails);

console.log('✅ Client routes loaded with assignListToVehicle route');

module.exports = router;
