# QuickPXE Azure Setup Guide

This guide walks you through setting up QuickPXE with Azure's **free tier** services:
- **Azure Static Web Apps** (Free) - Hosts the React frontend + API
- **Azure AD B2C** (Free tier - 50,000 MAU) - Google authentication
- **Azure Cosmos DB** (Free tier - 1000 RU/s) - Script storage database

## Prerequisites

- Azure account (free tier is fine)
- GitHub account
- Google Cloud Console account (for OAuth)

---

## Step 1: Create Azure AD B2C Tenant (Free)

### 1.1 Create B2C Tenant

1. Go to [Azure Portal](https://portal.azure.com)
2. Search for "Azure AD B2C" → **Create**
3. Select "Create a new Azure AD B2C Tenant"
4. Fill in:
   - **Organization name**: QuickPXE
   - **Initial domain name**: `quickpxe` (creates `quickpxe.onmicrosoft.com`)
   - **Country**: Your region
5. Click **Create**

### 1.2 Register Application

1. In your B2C tenant, go to **App registrations** → **New registration**
2. Fill in:
   - **Name**: QuickPXE Web App
   - **Supported account types**: Accounts in any identity provider
   - **Redirect URI**: 
     - Type: **Single-page application (SPA)**
     - URL: `http://localhost:5173` (add production URL later)
3. Click **Register**
4. Copy the **Application (client) ID** - you'll need this

### 1.3 Configure Google Identity Provider

1. In B2C tenant, go to **Identity providers** → **New OpenID Connect provider**
2. Select **Google**
3. You need Google OAuth credentials:

   **Create Google OAuth credentials:**
   1. Go to [Google Cloud Console](https://console.cloud.google.com)
   2. Create a new project or select existing
   3. Go to **APIs & Services** → **Credentials**
   4. Click **Create Credentials** → **OAuth 2.0 Client ID**
   5. Application type: **Web application**
   6. Authorized redirect URIs: `https://quickpxe.b2clogin.com/quickpxe.onmicrosoft.com/oauth2/authresp`
   7. Copy **Client ID** and **Client Secret**

4. Back in Azure B2C, enter the Google credentials
5. Click **Save**

### 1.4 Create User Flow

1. Go to **User flows** → **New user flow**
2. Select **Sign up and sign in** → **Recommended**
3. Fill in:
   - **Name**: `signupsignin` (creates `B2C_1_signupsignin`)
   - **Identity providers**: Check **Google**
   - **User attributes**: Select what to collect (Display Name, Email)
4. Click **Create**

---

## Step 2: Create Cosmos DB (Free Tier)

1. In Azure Portal, search **Azure Cosmos DB** → **Create**
2. Select **Azure Cosmos DB for NoSQL**
3. Fill in:
   - **Subscription**: Your subscription
   - **Resource Group**: Create new `quickpxe-rg`
   - **Account Name**: `quickpxe-db`
   - **Location**: Closest region
   - **Capacity mode**: **Serverless** (cheapest) or **Provisioned** with **Apply Free Tier Discount**
4. Click **Review + Create** → **Create**

### 2.1 Create Database and Container

1. Go to your Cosmos DB account
2. **Data Explorer** → **New Container**
3. Fill in:
   - **Database id**: `quickpxe` (Create new)
   - **Container id**: `scripts`
   - **Partition key**: `/userId`
4. Click **OK**

### 2.2 Get Connection Strings

1. Go to **Keys** in your Cosmos DB
2. Copy:
   - **URI** (endpoint)
   - **PRIMARY KEY**

---

## Step 3: Deploy to Azure Static Web Apps

### 3.1 Push to GitHub

```powershell
# If not already done:
git remote add origin https://github.com/YOUR_USERNAME/quickpxe.git
git branch -M main
git push -u origin main
```

### 3.2 Create Static Web App

1. In Azure Portal, search **Static Web Apps** → **Create**
2. Fill in:
   - **Subscription**: Your subscription
   - **Resource Group**: `quickpxe-rg`
   - **Name**: `quickpxe`
   - **Plan type**: **Free**
   - **Region**: Closest to you
3. **Deployment Details**:
   - **Source**: GitHub
   - Sign in and select your `quickpxe` repo
   - **Branch**: `main`
4. **Build Details**:
   - **Build Preset**: Custom
   - **App location**: `/`
   - **Api location**: `api`
   - **Output location**: `dist`
5. Click **Review + Create** → **Create**

### 3.3 Configure Environment Variables

1. Go to your Static Web App
2. **Configuration** → **Application settings**
3. Add these variables:

| Name | Value |
|------|-------|
| `COSMOS_ENDPOINT` | Your Cosmos DB URI |
| `COSMOS_KEY` | Your Cosmos DB PRIMARY KEY |
| `AZURE_CLIENT_ID` | Your B2C App registration Client ID |
| `AZURE_CLIENT_SECRET` | Your B2C App registration Client Secret |

4. Click **Save**

### 3.4 Update Frontend Config

Create a `.env.production` file in your project:

```env
VITE_AZURE_CLIENT_ID=your-client-id-here
VITE_AZURE_AUTHORITY=https://quickpxe.b2clogin.com/quickpxe.onmicrosoft.com/B2C_1_signupsignin
VITE_AZURE_KNOWN_AUTHORITY=quickpxe.b2clogin.com
VITE_REDIRECT_URI=https://your-app-name.azurestaticapps.net
VITE_API_ENDPOINT=/api
```

### 3.5 Add Production Redirect URI

1. Go back to your B2C tenant → **App registrations** → Your app
2. **Authentication** → Add another redirect URI:
   - `https://your-app-name.azurestaticapps.net`
3. Click **Save**

---

## Step 4: Add Custom Domain (Optional)

### 4.1 Purchase Domain through Azure

1. Search **App Service Domains** → **Buy domain**
2. Search for `quickpxe.com`
3. Complete purchase (~$12/year for .com)

### 4.2 Configure Custom Domain

1. Go to your Static Web App → **Custom domains**
2. Click **Add** → **Custom domain on Azure DNS**
3. Select your domain
4. Azure auto-configures DNS and SSL

### 4.3 Update Redirect URIs

Add `https://quickpxe.com` to:
1. Azure B2C app registration redirect URIs
2. Google OAuth authorized redirect URIs
3. Your `.env.production` file

---

## Cost Summary (Free Tier)

| Service | Free Tier Limit | Typical Usage |
|---------|-----------------|---------------|
| Static Web Apps | 100GB bandwidth, 2 custom domains | More than enough |
| Azure AD B2C | 50,000 monthly active users | Plenty for starting |
| Cosmos DB (Serverless) | 1000 RU/s, 25GB storage | Plenty for scripts |

**Total monthly cost: $0** (unless you exceed free tier limits)

---

## Environment Variables Reference

### Frontend (.env)

```env
VITE_AZURE_CLIENT_ID=         # B2C Application (client) ID
VITE_AZURE_AUTHORITY=         # https://{tenant}.b2clogin.com/{tenant}.onmicrosoft.com/{policy}
VITE_AZURE_KNOWN_AUTHORITY=   # {tenant}.b2clogin.com
VITE_REDIRECT_URI=            # Your app URL
VITE_API_ENDPOINT=            # /api (relative) or full URL
```

### Backend (Azure Portal Configuration)

```
COSMOS_ENDPOINT=              # Cosmos DB URI
COSMOS_KEY=                   # Cosmos DB Primary Key
AZURE_CLIENT_ID=              # Same as frontend
AZURE_CLIENT_SECRET=          # B2C App Client Secret (create in Certificates & secrets)
```

---

## Troubleshooting

### "AADSTS50011: Reply URL does not match"
- Add the exact URL to your B2C app registration's redirect URIs
- Make sure there's no trailing slash mismatch

### "Cosmos DB not configured" error
- Check that COSMOS_ENDPOINT and COSMOS_KEY are set in Azure Static Web App Configuration
- Restart the app after adding environment variables

### Google login not working
- Verify Google OAuth redirect URI matches exactly
- Check that Google identity provider is enabled in your B2C user flow

### Scripts not saving
- Check browser console for API errors
- Verify Cosmos DB container exists with correct partition key (`/userId`)

---

## Local Development

1. Copy `.env.example` to `.env`:

```env
VITE_AZURE_CLIENT_ID=your-client-id
VITE_AZURE_AUTHORITY=https://quickpxe.b2clogin.com/quickpxe.onmicrosoft.com/B2C_1_signupsignin
VITE_AZURE_KNOWN_AUTHORITY=quickpxe.b2clogin.com
VITE_REDIRECT_URI=http://localhost:5173
```

2. For API testing, install Azure Functions Core Tools:

```powershell
npm install -g azure-functions-core-tools@4
```

3. Update `api/local.settings.json` with your Cosmos credentials

4. Run both frontend and API:

```powershell
# Terminal 1 - Frontend
npm run dev

# Terminal 2 - API
cd api
func start
```
