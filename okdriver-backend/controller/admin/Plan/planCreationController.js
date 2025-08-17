const {PrismaClient} = require('@prisma/client');

const prisma = new PrismaClient()

// Create a new plan
const createPlan = async (req, res) => {
  try {
    const { name, description, price, durationDays } = req.body;

    if (!name || !price || !durationDays) {
      return res.status(400).json({ message: 'Name, price, and duration are required' });
    }

    const plan = await prisma.plan.create({
      data: { 
        name, 
        description, 
        price: parseFloat(price), 
        durationDays: parseInt(durationDays) 
      }
    });

    res.status(201).json({ message: 'Plan created successfully', plan });
  } catch (error) {
    console.error('Create Plan Error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};



module.exports = { createPlan };
