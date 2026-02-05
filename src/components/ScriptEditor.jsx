import { useState, useEffect } from 'react';
import { useUser } from './AuthProvider';
import './ScriptEditor.css';

// Default script that downloads from Azure server
const DEFAULT_SCRIPT = `@echo off
:: QuickPXE Default Script - Downloads latest configs from server
:: This script runs automatically when booting from QuickPXE USB

wpeinit

echo ==========================================
echo  QuickPXE - Automated BIOS Configuration
echo ==========================================
echo.

:: Create temp directory for tools
if not exist X:\\bios-tools mkdir X:\\bios-tools

:: Server URL for updated scripts (change to your Azure server)
set "TOOLS_URL=https://quickpxe.azurewebsites.net/api/scripts"

echo Downloading latest BIOS tools from server...
echo.

:: Download auto-detect script
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/auto-detect-apply.bat' -OutFile 'X:\\bios-tools\\auto-detect-apply.bat' -UseBasicParsing" 2>nul
if %errorlevel% neq 0 (
    echo WARNING: Could not download from server, using embedded scripts...
    goto :use_embedded
)

:: Download manufacturer-specific scripts
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/dell/apply-dell-bios.bat' -OutFile 'X:\\bios-tools\\dell\\apply-dell-bios.bat' -UseBasicParsing" 2>nul
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/hp/apply-hp-bios.bat' -OutFile 'X:\\bios-tools\\hp\\apply-hp-bios.bat' -UseBasicParsing" 2>nul
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/lenovo/apply-lenovo-bios.bat' -OutFile 'X:\\bios-tools\\lenovo\\apply-lenovo-bios.bat' -UseBasicParsing" 2>nul

echo Download complete!
echo.

:run_script
:: Run the auto-detect script
call X:\\bios-tools\\auto-detect-apply.bat
goto :end

:use_embedded
:: Fallback to embedded scripts if download fails
if exist X:\\bios-tools-embedded\\auto-detect-apply.bat (
    call X:\\bios-tools-embedded\\auto-detect-apply.bat
) else (
    echo ERROR: No scripts available!
    pause
)

:end
echo.
echo Configuration complete. Rebooting in 10 seconds...
echo Press any key to reboot immediately, or Ctrl+C to cancel.
timeout /t 10
wpeutil reboot
`;

// API calls for scripts
const api = {
  async getScripts(token) {
    const response = await fetch('/api/scripts', {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });
    if (!response.ok) throw new Error('Failed to fetch scripts');
    return response.json();
  },

  async saveScript(token, script) {
    const response = await fetch('/api/scripts', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(script),
    });
    if (!response.ok) throw new Error('Failed to save script');
    return response.json();
  },

  async deleteScript(token, scriptId) {
    const response = await fetch(`/api/scripts/${scriptId}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });
    if (!response.ok) throw new Error('Failed to delete script');
    return response.json();
  },
};

export function ScriptEditor() {
  const { user, isAuthenticated, getAccessToken } = useUser();
  const [scripts, setScripts] = useState([]);
  const [selectedScript, setSelectedScript] = useState(null);
  const [editingScript, setEditingScript] = useState('');
  const [scriptName, setScriptName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [saved, setSaved] = useState(false);
  const [showDefault, setShowDefault] = useState(true);

  // Load user's scripts
  useEffect(() => {
    if (isAuthenticated) {
      loadScripts();
    }
  }, [isAuthenticated]);

  const loadScripts = async () => {
    try {
      setLoading(true);
      const token = await getAccessToken();
      if (token) {
        const data = await api.getScripts(token);
        setScripts(data.scripts || []);
      }
    } catch (err) {
      console.error('Failed to load scripts:', err);
      // Don't show error - user might not have any scripts yet
    } finally {
      setLoading(false);
    }
  };

  const handleNewScript = () => {
    setSelectedScript(null);
    setScriptName('My Custom Script');
    setEditingScript(DEFAULT_SCRIPT);
    setShowDefault(false);
    setSaved(false);
  };

  const handleSelectScript = (script) => {
    setSelectedScript(script);
    setScriptName(script.name);
    setEditingScript(script.content);
    setShowDefault(false);
    setSaved(false);
  };

  const handleSave = async () => {
    if (!scriptName.trim()) {
      setError('Please enter a script name');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const token = await getAccessToken();
      
      const scriptData = {
        id: selectedScript?.id,
        name: scriptName.trim(),
        content: editingScript,
      };

      const saved = await api.saveScript(token, scriptData);
      
      // Update local state
      if (selectedScript) {
        setScripts(scripts.map(s => s.id === saved.id ? saved : s));
      } else {
        setScripts([...scripts, saved]);
      }
      
      setSelectedScript(saved);
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (err) {
      setError('Failed to save script. Please try again.');
      console.error('Save error:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!selectedScript) return;
    
    if (!confirm(`Delete "${selectedScript.name}"? This cannot be undone.`)) {
      return;
    }

    try {
      setLoading(true);
      const token = await getAccessToken();
      await api.deleteScript(token, selectedScript.id);
      
      setScripts(scripts.filter(s => s.id !== selectedScript.id));
      setSelectedScript(null);
      setScriptName('');
      setEditingScript('');
      setShowDefault(true);
    } catch (err) {
      setError('Failed to delete script.');
      console.error('Delete error:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleDownload = () => {
    const content = showDefault ? DEFAULT_SCRIPT : editingScript;
    const name = showDefault ? 'quickpxe-default.bat' : `${scriptName.replace(/[^a-z0-9]/gi, '-').toLowerCase()}.bat`;
    
    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = name;
    a.click();
    URL.revokeObjectURL(url);
  };

  const copyToClipboard = () => {
    const content = showDefault ? DEFAULT_SCRIPT : editingScript;
    navigator.clipboard.writeText(content);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  if (!isAuthenticated) {
    return (
      <div className="script-editor guest-mode">
        <div className="editor-header">
          <h2>Script Editor</h2>
          <p>View the default QuickPXE startup script below. Sign in to create and save your own custom scripts.</p>
        </div>
        
        <div className="editor-toolbar">
          <span className="script-label">Default QuickPXE Script (Read Only)</span>
          <div className="toolbar-actions">
            <button className="btn btn-secondary" onClick={copyToClipboard}>
              {saved ? '✓ Copied!' : '📋 Copy'}
            </button>
            <button className="btn btn-secondary" onClick={handleDownload}>
              ⬇️ Download
            </button>
          </div>
        </div>
        
        <div className="code-editor readonly">
          <pre>{DEFAULT_SCRIPT}</pre>
        </div>
        
        <div className="editor-info">
          <h4>What this script does:</h4>
          <ul>
            <li>Initializes WinPE environment</li>
            <li>Downloads latest BIOS configuration tools from your server</li>
            <li>Auto-detects manufacturer (Dell, HP, Lenovo)</li>
            <li>Applies UEFI-only settings, disables CSM/Legacy</li>
            <li>Enables PXE boot and UEFI Network Stack</li>
            <li>Falls back to embedded scripts if server unavailable</li>
          </ul>
        </div>
      </div>
    );
  }

  return (
    <div className="script-editor">
      <div className="editor-header">
        <h2>Script Editor</h2>
        <p>Create and manage your custom QuickPXE startup scripts.</p>
      </div>

      <div className="editor-layout">
        {/* Sidebar - Script List */}
        <div className="script-sidebar">
          <div className="sidebar-header">
            <h3>My Scripts</h3>
            <button className="btn btn-primary btn-sm" onClick={handleNewScript}>
              + New
            </button>
          </div>
          
          <div className="script-list">
            <div 
              className={`script-item default ${showDefault ? 'active' : ''}`}
              onClick={() => {
                setShowDefault(true);
                setSelectedScript(null);
                setEditingScript('');
              }}
            >
              <span className="script-icon">📄</span>
              <span className="script-name">Default Script</span>
              <span className="script-badge">Built-in</span>
            </div>
            
            {loading && scripts.length === 0 && (
              <div className="script-item loading">Loading...</div>
            )}
            
            {scripts.map(script => (
              <div 
                key={script.id}
                className={`script-item ${selectedScript?.id === script.id && !showDefault ? 'active' : ''}`}
                onClick={() => handleSelectScript(script)}
              >
                <span className="script-icon">📝</span>
                <span className="script-name">{script.name}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Main Editor */}
        <div className="editor-main">
          {showDefault ? (
            <>
              <div className="editor-toolbar">
                <span className="script-label">Default QuickPXE Script (Read Only)</span>
                <div className="toolbar-actions">
                  <button className="btn btn-secondary" onClick={copyToClipboard}>
                    {saved ? '✓ Copied!' : '📋 Copy'}
                  </button>
                  <button className="btn btn-secondary" onClick={handleDownload}>
                    ⬇️ Download
                  </button>
                </div>
              </div>
              <div className="code-editor readonly">
                <pre>{DEFAULT_SCRIPT}</pre>
              </div>
            </>
          ) : (
            <>
              <div className="editor-toolbar">
                <input
                  type="text"
                  className="script-name-input"
                  value={scriptName}
                  onChange={(e) => setScriptName(e.target.value)}
                  placeholder="Script name..."
                />
                <div className="toolbar-actions">
                  {error && <span className="error-msg">{error}</span>}
                  {saved && <span className="success-msg">✓ Saved!</span>}
                  <button 
                    className="btn btn-secondary" 
                    onClick={copyToClipboard}
                  >
                    📋 Copy
                  </button>
                  <button 
                    className="btn btn-secondary" 
                    onClick={handleDownload}
                  >
                    ⬇️ Download
                  </button>
                  {selectedScript && (
                    <button 
                      className="btn btn-danger" 
                      onClick={handleDelete}
                      disabled={loading}
                    >
                      🗑️ Delete
                    </button>
                  )}
                  <button 
                    className="btn btn-primary" 
                    onClick={handleSave}
                    disabled={loading}
                  >
                    {loading ? 'Saving...' : '💾 Save'}
                  </button>
                </div>
              </div>
              <textarea
                className="code-editor editable"
                value={editingScript}
                onChange={(e) => setEditingScript(e.target.value)}
                placeholder="Enter your batch script here..."
                spellCheck={false}
              />
            </>
          )}
        </div>
      </div>
    </div>
  );
}
