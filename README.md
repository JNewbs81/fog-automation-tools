# QuickPXE

**Free BIOS configuration automation for PXE boot and Windows deployment**

Generate ready-to-use WinPE scripts from your BIOS config files. Perfect for PC resellers, IT departments, and refurbishers.

## Features

### 🆓 Free Script Generator (No Login)
- Upload your BIOS config file (.cctk, .REPSET, .ini)
- Get a ready-to-use startup script for WinPE
- Download and embed in your USB for offline PCs

### ☁️ Cloud Storage (Sign in with Google)
- Save unlimited scripts to the cloud
- Get server-hosted URLs for auto-updates
- Organize by model (OptiPlex 7080, EliteDesk 800, etc.)
- Download for offline/air-gapped PCs

### 🔧 Supported Vendors
- **Dell** - Command Configure (CCTK)
- **HP** - BIOS Configuration Utility (BCU)
- **Lenovo** - Think BIOS Config Tool (TBCT)

## Tech Stack

- **Frontend**: React + Vite
- **Auth**: Azure AD B2C (Google sign-in)
- **Database**: Azure Cosmos DB (free tier)
- **Hosting**: Azure Static Web Apps (free tier)

## Local Development

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build
```

## Azure Deployment

See [AZURE-SETUP.md](./AZURE-SETUP.md) for complete deployment instructions.

Quick steps:
1. Create Azure AD B2C tenant + Google OAuth
2. Create Cosmos DB (free tier)
3. Deploy to Azure Static Web Apps
4. Configure environment variables

## Cost

**$0/month** on Azure free tier:
- Static Web Apps: 100GB bandwidth/month
- Azure AD B2C: 50,000 users/month
- Cosmos DB: 1000 RU/s + 25GB storage

## License

MIT License - see [LICENSE](./LICENSE)

## Related

This is the web interface for [fog-automation-tools](https://github.com/JNewbs81/fog-automation-tools) - the underlying PowerShell scripts and BIOS configs.
