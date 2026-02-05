// Azure Function - Delete Script API

const { CosmosClient } = require('@azure/cosmos');

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

function getUserId(req) {
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

  const scriptId = context.bindingData.id;

  if (!scriptId) {
    context.res = {
      status: 400,
      body: { error: 'Script ID required' }
    };
    return;
  }

  try {
    const db = await getContainer();

    // Verify ownership before deleting
    const { resource: existing } = await db.item(scriptId, userId).read();
    
    if (!existing || existing.userId !== userId) {
      context.res = {
        status: 404,
        body: { error: 'Script not found' }
      };
      return;
    }

    await db.item(scriptId, userId).delete();
    
    context.res = {
      status: 200,
      body: { success: true, message: 'Script deleted' }
    };

  } catch (error) {
    context.log.error('Delete Error:', error);
    context.res = {
      status: 500,
      body: { error: 'Internal server error' }
    };
  }
};
