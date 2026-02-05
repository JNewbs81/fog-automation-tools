// Azure Function - Scripts API
// Handles CRUD operations for user scripts using Azure Cosmos DB

const { CosmosClient } = require('@azure/cosmos');

// Initialize Cosmos client
const endpoint = process.env.COSMOS_ENDPOINT;
const key = process.env.COSMOS_KEY;
const databaseId = 'quickpxe';
const containerId = 'scripts';

let container = null;

async function getContainer() {
  if (!container) {
    if (!endpoint || !key) {
      throw new Error('Cosmos DB not configured');
    }
    const client = new CosmosClient({ endpoint, key });
    const database = client.database(databaseId);
    container = database.container(containerId);
  }
  return container;
}

// Get user ID from Azure AD B2C token
function getUserId(req) {
  // Azure Static Web Apps automatically validates the token
  // and provides user info in the x-ms-client-principal header
  const header = req.headers['x-ms-client-principal'];
  if (!header) return null;
  
  try {
    const encoded = Buffer.from(header, 'base64');
    const decoded = JSON.parse(encoded.toString('utf8'));
    return decoded.userId;
  } catch (e) {
    return null;
  }
}

module.exports = async function (context, req) {
  const userId = getUserId(req);
  
  if (!userId) {
    context.res = {
      status: 401,
      body: { error: 'Unauthorized' }
    };
    return;
  }

  try {
    const db = await getContainer();
    const method = req.method.toUpperCase();

    // GET - List all scripts for user
    if (method === 'GET') {
      const { resources } = await db.items
        .query({
          query: 'SELECT * FROM c WHERE c.userId = @userId ORDER BY c.updatedAt DESC',
          parameters: [{ name: '@userId', value: userId }]
        })
        .fetchAll();

      context.res = {
        status: 200,
        body: { scripts: resources }
      };
      return;
    }

    // POST - Create or update script
    if (method === 'POST') {
      const { id, name, content } = req.body;

      if (!name || !content) {
        context.res = {
          status: 400,
          body: { error: 'Name and content are required' }
        };
        return;
      }

      const now = new Date().toISOString();
      
      if (id) {
        // Update existing script
        const { resource: existing } = await db.item(id, userId).read();
        
        if (!existing || existing.userId !== userId) {
          context.res = {
            status: 404,
            body: { error: 'Script not found' }
          };
          return;
        }

        const updated = {
          ...existing,
          name,
          content,
          updatedAt: now
        };

        const { resource } = await db.item(id, userId).replace(updated);
        
        context.res = {
          status: 200,
          body: resource
        };
      } else {
        // Create new script
        const newScript = {
          id: `script-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
          userId,
          name,
          content,
          createdAt: now,
          updatedAt: now
        };

        const { resource } = await db.items.create(newScript);
        
        context.res = {
          status: 201,
          body: resource
        };
      }
      return;
    }

    // Method not allowed
    context.res = {
      status: 405,
      body: { error: 'Method not allowed' }
    };

  } catch (error) {
    context.log.error('API Error:', error);
    context.res = {
      status: 500,
      body: { error: 'Internal server error' }
    };
  }
};
