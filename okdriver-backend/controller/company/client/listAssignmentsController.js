const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// For all company vehicles, return distinct client list names assigned to each vehicle
const getVehicleListAssignments = async (req, res) => {
  try {
    const companyId = req.company.id;
    console.log('🔍 Getting vehicle list assignments for company:', companyId);

    const vehicles = await prisma.vehicle.findMany({ where: { companyId } });
    const vehicleIds = vehicles.map(v => v.id);
    console.log('🚗 Found vehicles:', vehicles.length, 'Vehicle IDs:', vehicleIds);

    const accesses = await prisma.clientVehicleAccess.findMany({
      where: { companyId, vehicleId: { in: vehicleIds } },
      include: { client: { include: { accesses: false } } }
    });
    console.log('🔗 Found accesses:', accesses.length);

    // Build map vehicleId -> set of clientIds
    const mapVehicleToClientIds = new Map();
    for (const a of accesses) {
      const set = mapVehicleToClientIds.get(a.vehicleId) || new Set();
      set.add(a.clientId);
      mapVehicleToClientIds.set(a.vehicleId, set);
    }

    // Find lists for those clients
    const allClientIds = Array.from(new Set(accesses.map(a => a.clientId)));
    const listMembers = allClientIds.length ? await prisma.clientListMember.findMany({
      where: { clientId: { in: allClientIds } },
      include: { list: true }
    }) : [];

    // Build clientId -> list names
    const clientIdToListNames = new Map();
    for (const m of listMembers) {
      const arr = clientIdToListNames.get(m.clientId) || [];
      if (m.list) arr.push(m.list.name);
      clientIdToListNames.set(m.clientId, arr);
    }

    const result = vehicles.map(v => {
      const clientIds = Array.from(mapVehicleToClientIds.get(v.id) || []);
      const listNames = new Set();
      for (const cid of clientIds) {
        const names = clientIdToListNames.get(cid) || [];
        names.forEach(n => listNames.add(n));
      }
      return { vehicleId: v.id, vehicleNumber: v.vehicleNumber, listNames: Array.from(listNames) };
    });

    console.log('📋 Final result:', result);
    res.json(result);
  } catch (err) {
    console.error('getVehicleListAssignments error', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
};

// Vehicle details: latest location, list names, recent chats
const getVehicleDetails = async (req, res) => {
  try {
    const companyId = req.company.id;
    const vehicleId = Number(req.params.vehicleId);

    const vehicle = await prisma.vehicle.findFirst({
      where: { id: vehicleId, companyId },
      include: { locations: { take: 1, orderBy: { recordedAt: 'desc' } } }
    });
    if (!vehicle) return res.status(404).json({ message: 'Vehicle not found' });

    const accesses = await prisma.clientVehicleAccess.findMany({ where: { companyId, vehicleId } });
    const clientIds = accesses.map(a => a.clientId);
    const listMembers = clientIds.length ? await prisma.clientListMember.findMany({
      where: { clientId: { in: clientIds } }, include: { list: true }
    }) : [];
    const listNames = Array.from(new Set(listMembers.map(m => m.list?.name).filter(Boolean)));

    const chats = await prisma.chatMessage.findMany({
      where: { vehicleId },
      orderBy: { createdAt: 'desc' },
      take: 50
    });

    res.json({
      vehicle: { id: vehicle.id, vehicleNumber: vehicle.vehicleNumber, model: vehicle.model, type: vehicle.type },
      latestLocation: vehicle.locations[0] || null,
      listNames,
      chats: chats.reverse()
    });
  } catch (err) {
    console.error('getVehicleDetails error', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
};

module.exports = { getVehicleListAssignments, getVehicleDetails };



