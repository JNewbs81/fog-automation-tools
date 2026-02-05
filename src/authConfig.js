// Azure AD B2C Configuration
// You'll need to replace these values with your actual Azure AD B2C tenant info

export const msalConfig = {
  auth: {
    // Replace with your Azure AD B2C application (client) ID
    clientId: import.meta.env.VITE_AZURE_CLIENT_ID || "YOUR_CLIENT_ID",
    
    // Replace with your Azure AD B2C tenant authority
    // Format: https://{tenant-name}.b2clogin.com/{tenant-name}.onmicrosoft.com/{policy-name}
    authority: import.meta.env.VITE_AZURE_AUTHORITY || "https://quickpxe.b2clogin.com/quickpxe.onmicrosoft.com/B2C_1_signupsignin",
    
    // Known authorities for your tenant
    knownAuthorities: [import.meta.env.VITE_AZURE_KNOWN_AUTHORITY || "quickpxe.b2clogin.com"],
    
    // Redirect URI - your app URL
    redirectUri: import.meta.env.VITE_REDIRECT_URI || "http://localhost:5173",
    
    // Post logout redirect
    postLogoutRedirectUri: import.meta.env.VITE_REDIRECT_URI || "http://localhost:5173",
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  },
};

// Scopes for API access
export const loginRequest = {
  scopes: ["openid", "profile", "email"],
};

// API endpoint configuration
export const apiConfig = {
  // Azure Functions API endpoint
  endpoint: import.meta.env.VITE_API_ENDPOINT || "/api",
};
