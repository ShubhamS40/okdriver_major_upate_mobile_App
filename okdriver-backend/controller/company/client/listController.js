const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Create a new client list
const createClientList = async (req, res) => {
  try {
    const companyId = req.company.id;
    const { name } = req.body;
    if (!name) return res.status(400).json({ message: 'List name is required' });

    const list = await prisma.clientList.create({
      data: { name, companyId }
    });
    res.status(201).json(list);
  } catch (err) {
    console.error('createClientList error', err);
    if (err.code === 'P2002') {
      return res.status(409).json({ message: 'List name already exists' });
    }
    res.status(500).json({ message: 'Internal Server Error' });
  }
};

// Get all lists for a company with members
const getClientLists = async (req, res) => {
  try {
    const companyId = req.company.id;
    const lists = await prisma.clientList.findMany({
      where: { companyId },
      include: { members: { include: { client: true } } }
    });
    res.json(lists);
  } catch (err) {
    console.error('getClientLists error', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
};

// Delete a list
const deleteClientList = async (req, res) => {
  try {
    const companyId = req.company.id;
    const listId = Number(req.params.listId);
    const list = await prisma.clientList.findFirst({ where: { id: listId, companyId } });
    if (!list) return res.status(404).json({ message: 'List not found' });
    await prisma.clientList.delete({ where: { id: listId } });
    res.json({ message: 'Deleted' });
  } catch (err) {
    console.error('deleteClientList error', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
};

// Add an email to list; creates Client if missing
const addMemberToList = async (req, res) => {
  try {
    const companyId = req.company.id;
    const listId = Number(req.params.listId);
    const { email, name } = req.body;
    if (!email) return res.status(400).json({ message: 'Email is required' });

    const list = await prisma.clientList.findFirst({ where: { id: listId, companyId } });
    if (!list) return res.status(404).json({ message: 'List not found' });

    let client = await prisma.client.findUnique({ where: { email } });
    if (!client) {
      client = await prisma.client.create({ data: { email, name: name || null, companyId } });
    } else if (client.companyId !== companyId) {
      return res.status(400).json({ message: 'Client belongs to another company' });
    }

    const member = await prisma.clientListMember.create({
      data: { clientListId: listId, clientId: client.id }
    });
    res.status(201).json(member);
  } catch (err) {
    console.error('addMemberToList error', err);
    if (err.code === 'P2002') {
      return res.status(409).json({ message: 'Client already in list' });
    }
    res.status(500).json({ message: 'Internal Server Error' });
  }
};

// Remove a member from list
const removeMemberFromList = async (req, res) => {
  try {
    const companyId = req.company.id;
    const listId = Number(req.params.listId);
    const clientId = Number(req.params.clientId);
    const list = await prisma.clientList.findFirst({ where: { id: listId, companyId } });
    if (!list) return res.status(404).json({ message: 'List not found' });

    const member = await prisma.clientListMember.findFirst({ where: { clientListId: listId, clientId } });
    if (!member) return res.status(404).json({ message: 'Member not in list' });

    await prisma.clientListMember.delete({ where: { id: member.id } });
    res.json({ message: 'Removed' });
  } catch (err) {
    console.error('removeMemberFromList error', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
};

// Assign a list to a vehicle: create accesses for each member
const assignListToVehicle = async (req, res) => {
  console.log('🚀 assignListToVehicle called with:', {
    listId: req.params.listId,
    vehicleId: req.params.vehicleId,
    companyId: req.company?.id
  });
  
  try {
    const companyId = req.company.id;
    const listId = Number(req.params.listId);
    const vehicleId = Number(req.params.vehicleId);

    console.log('🔍 Looking for list:', listId, 'and vehicle:', vehicleId, 'for company:', companyId);

    // Validate parameters
    if (!listId || isNaN(listId)) {
      return res.status(400).json({ message: 'Invalid list ID' });
    }
    if (!vehicleId || isNaN(vehicleId)) {
      return res.status(400).json({ message: 'Invalid vehicle ID' });
    }

    const list = await prisma.clientList.findFirst({ 
      where: { id: listId, companyId }, 
      include: { 
        members: {
          include: {
            client: true
          }
        } 
      } 
    });
    
    if (!list) {
      console.log('❌ List not found');
      return res.status(404).json({ message: 'List not found' });
    }

    const vehicle = await prisma.vehicle.findFirst({ where: { id: vehicleId, companyId } });
    if (!vehicle) {
      console.log('❌ Vehicle not found');
      return res.status(404).json({ message: 'Vehicle not found for this company' });
    }

    console.log('✅ Found list and vehicle, members count:', list.members.length);

    if (list.members.length === 0) {
      return res.status(400).json({ message: 'List has no members to assign' });
    }

    // Upsert accesses for each member
    const operations = list.members.map(member => {
      console.log(`🔗 Creating access for client ${member.clientId} to vehicle ${vehicleId}`);
      return prisma.clientVehicleAccess.upsert({
        where: { 
          clientId_vehicleId: { 
            clientId: member.clientId, 
            vehicleId: vehicleId 
          } 
        },
        update: {}, // No update needed if exists
        create: { 
          companyId, 
          clientId: member.clientId, 
          vehicleId: vehicleId 
        }
      });
    });

    await prisma.$transaction(operations);
    
    console.log('✅ Successfully assigned list to vehicle');
    res.json({ 
      message: 'Assigned list to vehicle',
      assignedCount: list.members.length,
      listName: list.name,
      vehicleNumber: vehicle.vehicleNumber
    });
  } catch (err) {
    console.error('❌ assignListToVehicle error', err);
    
    // Handle specific Prisma errors
    if (err.code === 'P2002') {
      return res.status(409).json({ message: 'Some clients already have access to this vehicle' });
    }
    
    res.status(500).json({ message: 'Internal Server Error', error: err.message });
  }
};

// Revoke list from a vehicle: delete accesses for those members
const revokeListFromVehicle = async (req, res) => {
  try {
    const companyId = req.company.id;
    const listId = Number(req.params.listId);
    const vehicleId = Number(req.params.vehicleId);

    const list = await prisma.clientList.findFirst({ where: { id: listId, companyId }, include: { members: true } });
    if (!list) return res.status(404).json({ message: 'List not found' });

    await prisma.clientVehicleAccess.deleteMany({
      where: { companyId, vehicleId, clientId: { in: list.members.map(m => m.clientId) } }
    });
    res.json({ message: 'Revoked list from vehicle' });
  } catch (err) {
    console.error('revokeListFromVehicle error', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
};

// For a vehicle, list allowed clients
const getVehicleClients = async (req, res) => {
  try {
    const companyId = req.company.id;
    const vehicleId = Number(req.params.vehicleId);
    const vehicle = await prisma.vehicle.findFirst({ where: { id: vehicleId, companyId } });
    if (!vehicle) return res.status(404).json({ message: 'Vehicle not found for this company' });

    const accesses = await prisma.clientVehicleAccess.findMany({
      where: { vehicleId, companyId },
      include: { client: true }
    });
    res.json(accesses.map(a => a.client));
  } catch (err) {
    console.error('getVehicleClients error', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
};

module.exports = {
  createClientList,
  getClientLists,
  deleteClientList,
  addMemberToList,
  removeMemberFromList,
  assignListToVehicle,
  revokeListFromVehicle,
  getVehicleClients
};


