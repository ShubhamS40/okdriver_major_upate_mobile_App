const { Novu } = require('@novu/node');
const dotenv = require('dotenv');
dotenv.config();

let novu = null;

function getNovu() {
  if (novu) return novu;
  
  const apiKey = process.env.NOVU_API_KEY;
  console.log('🔔 NOVU_API_KEY exists:', !!apiKey);
  
  if (!apiKey) {
    console.error('🔔 NOVU_API_KEY environment variable is not set!');
    return null;
  }
  
  try {
    novu = new Novu(apiKey);
    console.log('🔔 Novu client initialized successfully');
    return novu;
  } catch (error) {
    console.error('🔔 Failed to initialize Novu client:', error.message);
    return null;
  }
}

async function identifySubscriber(subscriberId, payload = {}) {
  const client = getNovu();
  if (!client || !subscriberId) return;
  try {
    console.log('🔔 Identifying subscriber:', subscriberId, payload);
    await client.subscribers.identify(subscriberId, payload);
    console.log('🔔 Subscriber identified successfully:', subscriberId);
  } catch (e) {
    console.error('🔔 Failed to identify subscriber:', subscriberId, e.message);
  }
}

async function notifyAdminNewTicket(ticket, company) {
  try {
    const client = getNovu();
    if (!client) {
      console.log('🔔 Novu client not available (check NOVU_API_KEY)');
      return;
    }
    
    console.log('🔔 Sending admin notification for new ticket:', ticket.id);
    
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
    const admins = await prisma.admin.findMany({ select: { id: true, email: true } });
    
    if (!admins.length) {
      console.warn('🔔 No admins found in database');
      return;
    }
    
    const payload = {
      ticketId: String(ticket.id || ''),
      subject: String(ticket.subject || 'No Subject'),
      priority: String(ticket.priority || 'MEDIUM'),
      companyId: String(company?.id || ''),
      companyName: String(company?.name || 'Unknown Company'),
      company: String(company?.name || 'Unknown Company'),
      company_name: String(company?.name || 'Unknown Company'),
      createdAt: new Date().toISOString(),
      description: String(ticket.description || ''),
      status: String(ticket.status || 'OPEN'),
      action: 'CREATED'
    };
    
    for (const admin of admins) {
      const subscriberId = `admin-${admin.id}`;
      
      await identifySubscriber(subscriberId, {
        firstName: admin.email?.split('@')[0] || 'Admin',
        email: admin.email || `admin${admin.id}@example.com`,
        adminId: admin.id,
        type: 'admin'
      });
      
      try {
        await client.trigger('company-ticket-created', {
          to: { subscriberId },
          payload: {
            ...payload,
            adminName: admin.email?.split('@')[0] || 'Admin',
            adminEmail: admin.email
          }
        });
        console.log('🔔 ✅ Admin notification sent to:', subscriberId);
      } catch (error) {
        console.error('🔔 ❌ Failed to send notification to admin:', subscriberId, error.message);
      }
    }
    
  } catch (e) {
    console.error('🔔 notifyAdminNewTicket error:', e.message);
  }
}

async function notifyCompanyTicketStatusChange(ticket, company, action, adminName = 'Admin', adminResponse = '') {
  try {
    const client = getNovu();
    if (!client) {
      console.log('🔔 Novu client not available (check NOVU_API_KEY)');
      return;
    }
    
    const subscriberId = `company-${company.id}`;
    console.log('🔔 Sending company notification for ticket status change:', {
      ticketId: ticket.id,
      action,
      status: ticket.status,
      subscriberId
    });
    
    // Identify company subscriber
    await identifySubscriber(subscriberId, { 
      firstName: company.name || 'Company',
      email: company.email || `company${company.id}@example.com`,
      companyId: company.id,
      companyName: company.name,
      type: 'company'
    });
    
    // Choose the right workflow based on action/status
    let workflowId = 'company-ticket-updated';
    if (action === 'CLOSED' || action === 'RESOLVED' || ticket.status === 'CLOSED' || ticket.status === 'RESOLVED') {
      workflowId = 'company-ticket-closed';
    } else if (action === 'IN_PROGRESS' || ticket.status === 'IN_PROGRESS') {
      workflowId = 'company-ticket-in-progress';
    }
    
    // Base payload
    const basePayload = {
      ticketId: String(ticket.id || ''),
      subject: String(ticket.subject || 'No Subject'),
      status: String(ticket.status || action),
      action: String(action),
      adminName: String(adminName),
      adminResponse: String(adminResponse || ticket.adminResponse || 'Status updated by admin'),
      priority: String(ticket.priority || 'MEDIUM'),
      companyName: String(company?.name || 'Company'),
      companyId: String(company.id),
      updatedAt: new Date().toISOString(),
      description: String(ticket.description || ''),
      previousStatus: String(ticket.previousStatus || 'UNKNOWN')
    };

    // Add specific fields based on workflow
    let payload = { ...basePayload };
    if (workflowId === 'company-ticket-closed') {
      payload.closedAt = new Date().toISOString();
      payload.resolvedAt = new Date().toISOString();
    } else if (workflowId === 'company-ticket-in-progress') {
      payload.startedAt = new Date().toISOString();
    }
    
    console.log('🔔 Sending notification:', {
      workflowId,
      subscriberId,
      payload: JSON.stringify(payload, null, 2)
    });
    
    const response = await client.trigger(workflowId, {
      to: { subscriberId },
      payload
    });
    
    console.log('🔔 ✅ Company notification sent successfully:', {
      workflowId,
      subscriberId,
      transactionId: response.transactionId
    });
    
    return response;
    
  } catch (e) {
    console.error('🔔 ❌ notifyCompanyTicketStatusChange error:', e.message);
    if (e.response) {
      console.error('🔔 Response status:', e.response.status);
      console.error('🔔 Response data:', JSON.stringify(e.response.data, null, 2));
    }
    throw e;
  }
}

// Enhanced function to handle all ticket status changes properly
async function handleTicketStatusChange(ticketId, newStatus, adminId, adminResponse = '') {
  try {
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
    
    // Get ticket with company info
    const ticket = await prisma.ticket.findUnique({
      where: { id: parseInt(ticketId) },
      include: { 
        company: true 
      }
    });
    
    if (!ticket) {
      console.error('🔔 Ticket not found:', ticketId);
      return;
    }
    
    const admin = await prisma.admin.findUnique({
      where: { id: parseInt(adminId) },
      select: { email: true, name: true }
    });
    
    // Store previous status
    const previousStatus = ticket.status;
    
    // Update ticket status
    const updatedTicket = await prisma.ticket.update({
      where: { id: parseInt(ticketId) },
      data: { 
        status: newStatus,
        adminResponse: adminResponse || ticket.adminResponse,
        updatedAt: new Date()
      }
    });
    
    // Send notification with proper context
    await notifyCompanyTicketStatusChange(
      { ...updatedTicket, previousStatus }, 
      ticket.company, 
      newStatus, 
      admin?.name || admin?.email?.split('@')[0] || 'Admin',
      adminResponse
    );
    
    console.log('🔔 ✅ Ticket status updated and notification sent');
    return updatedTicket;
    
  } catch (error) {
    console.error('🔔 ❌ Error in handleTicketStatusChange:', error.message);
    throw error;
  }
}

// Legacy function for backward compatibility
async function notifyCompanyResolved(ticket, company, adminName = 'Admin') {
  return await notifyCompanyTicketStatusChange(ticket, company, 'RESOLVED', adminName);
}

// Legacy function for backward compatibility  
async function notifyCompanyTicketAction(ticket, company, action, adminName = 'Admin') {
  return await notifyCompanyTicketStatusChange(ticket, company, action, adminName);
}

// New function for ticket updates with more context
async function notifyTicketUpdate(ticket, company, admin, previousStatus, adminResponse = '') {
  try {
    const adminName = admin?.email?.split('@')[0] || admin?.name || 'Admin';
    
    // Update ticket object with previous status for better context
    const ticketWithContext = {
      ...ticket,
      previousStatus
    };
    
    // Notify company about the status change
    await notifyCompanyTicketStatusChange(
      ticketWithContext, 
      company, 
      ticket.status, 
      adminName, 
      adminResponse
    );
    
    console.log('🔔 ✅ Ticket update notification sent successfully');
  } catch (error) {
    console.error('🔔 ❌ Error in notifyTicketUpdate:', error.message);
    throw error;
  }
}

// Function to test notifications
async function testNotifications(testCompanyId = '1', testAdminId = '1') {
  try {
    const client = getNovu();
    if (!client) {
      console.log('🔔 Novu client not available');
      return;
    }

    console.log('🔔 Testing notifications...');
    
    const testTicket = {
      id: 'TEST-' + Date.now(),
      subject: 'Test Notification',
      description: 'Testing notification delivery',
      priority: 'HIGH',
      status: 'IN_PROGRESS'
    };
    
    const testCompany = {
      id: testCompanyId,
      name: 'Test Company',
      email: 'test@company.com'
    };

    // Test company closed notification with all required fields
    await client.trigger('company-ticket-closed', {
      to: { subscriberId: `company-${testCompanyId}` },
      payload: {
        ticketId: testTicket.id,
        subject: testTicket.subject,
        status: 'CLOSED',
        priority: testTicket.priority,
        adminName: 'Test Admin',
        adminResponse: 'Test ticket has been resolved',
        companyId: testCompany.id,
        companyName: testCompany.name,
        closedAt: new Date().toISOString(),
        resolvedAt: new Date().toISOString(),
        action: 'TEST_CLOSED'
      }
    });
    
    // Test company in-progress notification
    await client.trigger('company-ticket-in-progress', {
      to: { subscriberId: `company-${testCompanyId}` },
      payload: {
        ticketId: testTicket.id,
        subject: testTicket.subject,
        status: 'IN_PROGRESS',
        priority: testTicket.priority,
        adminName: 'Test Admin',
        adminResponse: 'Working on your ticket',
        companyId: testCompany.id,
        companyName: testCompany.name,
        startedAt: new Date().toISOString(),
        action: 'TEST_IN_PROGRESS'
      }
    });
    
    console.log('🔔 ✅ Test notifications sent successfully');
    
  } catch (error) {
    console.error('🔔 ❌ Test notifications failed:', error.message);
    if (error.response) {
      console.error('🔔 Error details:', JSON.stringify(error.response.data, null, 2));
    }
  }
}

// Validate API key function
async function validateNovuConfig() {
  try {
    const client = getNovu();
    if (!client) return false;
    
    const response = await client.subscribers.list({ page: 0, limit: 1 });
    console.log('🔔 ✅ Novu API key is valid');
    return true;
  } catch (error) {
    console.error('🔔 ❌ Novu API validation failed:', error.message);
    return false;
  }
}

module.exports = { 
  // Main notification functions
  notifyAdminNewTicket,
  notifyCompanyTicketStatusChange,
  notifyTicketUpdate,
  handleTicketStatusChange,
  
  // Legacy functions for backward compatibility
  notifyCompanyResolved, 
  notifyCompanyTicketAction,
  
  // Utility functions
  identifySubscriber,
  validateNovuConfig,
  testNotifications
};