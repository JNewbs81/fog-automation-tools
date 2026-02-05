import { useState, useEffect } from 'react'
import { useUser } from './AuthProvider'
import './MyScripts.css'

// API calls
const api = {
  async getScripts(token) {
    const res = await fetch('/api/scripts', {
      headers: { 'Authorization': `Bearer ${token}` }
    })
    if (!res.ok) throw new Error('Failed to fetch')
    return res.json()
  },
  
  async saveScript(token, script) {
    const res = await fetch('/api/scripts', {
      method: 'POST',
      headers: { 
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(script)
    })
    if (!res.ok) throw new Error('Failed to save')
    return res.json()
  },
  
  async deleteScript(token, id) {
    const res = await fetch(`/api/scripts/${id}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${token}` }
    })
    if (!res.ok) throw new Error('Failed to delete')
    return res.json()
  }
}

export function MyScripts() {
  const { user, isAuthenticated, login, getAccessToken } = useUser()
  const [scripts, setScripts] = useState([])
  const [loading, setLoading] = useState(false)
  const [selectedScript, setSelectedScript] = useState(null)
  const [editMode, setEditMode] = useState(false)
  const [editName, setEditName] = useState('')
  const [editContent, setEditContent] = useState('')
  const [editVendor, setEditVendor] = useState('auto')
  const [editModels, setEditModels] = useState('')
  const [saved, setSaved] = useState(false)

  useEffect(() => {
    if (isAuthenticated) loadScripts()
  }, [isAuthenticated])

  const loadScripts = async () => {
    try {
      setLoading(true)
      const token = await getAccessToken()
      if (token) {
        const data = await api.getScripts(token)
        setScripts(data.scripts || [])
      }
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const handleSave = async () => {
    try {
      setLoading(true)
      const token = await getAccessToken()
      const scriptData = {
        id: selectedScript?.id,
        name: editName,
        content: editContent,
        vendor: editVendor,
        models: editModels.split(',').map(m => m.trim()).filter(Boolean)
      }
      const result = await api.saveScript(token, scriptData)
      
      if (selectedScript) {
        setScripts(scripts.map(s => s.id === result.id ? result : s))
      } else {
        setScripts([result, ...scripts])
      }
      
      setSelectedScript(result)
      setSaved(true)
      setTimeout(() => setSaved(false), 2000)
      setEditMode(false)
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async (id) => {
    if (!confirm('Delete this script?')) return
    try {
      const token = await getAccessToken()
      await api.deleteScript(token, id)
      setScripts(scripts.filter(s => s.id !== id))
      if (selectedScript?.id === id) {
        setSelectedScript(null)
        setEditMode(false)
      }
    } catch (err) {
      console.error(err)
    }
  }

  const handleNew = () => {
    setSelectedScript(null)
    setEditName('New Script')
    setEditContent(`@echo off
:: QuickPXE Custom Script
wpeinit
echo Your custom BIOS configuration here...
pause`)
    setEditVendor('auto')
    setEditModels('')
    setEditMode(true)
  }

  const handleEdit = (script) => {
    setSelectedScript(script)
    setEditName(script.name)
    setEditContent(script.content)
    setEditVendor(script.vendor || 'auto')
    setEditModels(script.models?.join(', ') || '')
    setEditMode(true)
  }

  const handleDownload = (script) => {
    const blob = new Blob([script.content], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `${script.name.replace(/[^a-z0-9]/gi, '-').toLowerCase()}.bat`
    a.click()
    URL.revokeObjectURL(url)
  }

  const getServerUrl = (script) => {
    return `https://quickpxe.azurewebsites.net/api/scripts/${script.id}/download`
  }

  // Not logged in - show prompt
  if (!isAuthenticated) {
    return (
      <div className="my-scripts guest">
        <div className="guest-prompt">
          <h3>Save & Host Your Scripts</h3>
          <p>Sign in to save scripts, add model-specific configs, and get server-hosted URLs for auto-updates.</p>
          <ul className="benefits">
            <li>Save unlimited scripts to the cloud</li>
            <li>Server-hosted URLs for network-connected PCs</li>
            <li>Downloadable scripts for offline/air-gapped PCs</li>
            <li>Organize by model (OptiPlex 7080, EliteDesk 800, etc.)</li>
          </ul>
          <button className="btn btn-primary" onClick={login}>
            Sign in with Google
          </button>
        </div>
      </div>
    )
  }

  // Logged in - show scripts
  return (
    <div className="my-scripts">
      <div className="my-scripts-header">
        <div>
          <h2>My Scripts</h2>
          <p>Your saved configurations - download for USB or use server URL</p>
        </div>
        <button className="btn btn-primary" onClick={handleNew}>+ New Script</button>
      </div>

      <div className="scripts-layout">
        {/* Script List */}
        <div className="script-list">
          {loading && scripts.length === 0 && (
            <div className="loading-state">Loading...</div>
          )}
          
          {!loading && scripts.length === 0 && !editMode && (
            <div className="empty-state">
              <p>No scripts yet</p>
              <button className="btn btn-secondary" onClick={handleNew}>Create your first script</button>
            </div>
          )}

          {scripts.map(script => (
            <div 
              key={script.id} 
              className={`script-card ${selectedScript?.id === script.id ? 'active' : ''}`}
              onClick={() => handleEdit(script)}
            >
              <div className="script-card-header">
                <span className="script-name">{script.name}</span>
                <span className={`vendor-badge ${script.vendor || 'auto'}`}>
                  {(script.vendor || 'auto').toUpperCase()}
                </span>
              </div>
              {script.models?.length > 0 && (
                <div className="script-models">
                  {script.models.slice(0, 3).join(', ')}
                  {script.models.length > 3 && ` +${script.models.length - 3}`}
                </div>
              )}
              <div className="script-card-actions">
                <button onClick={(e) => { e.stopPropagation(); handleDownload(script); }}>
                  ⬇️ Download
                </button>
                <button onClick={(e) => { e.stopPropagation(); navigator.clipboard.writeText(getServerUrl(script)); }}>
                  🔗 Copy URL
                </button>
                <button className="delete" onClick={(e) => { e.stopPropagation(); handleDelete(script.id); }}>
                  🗑️
                </button>
              </div>
            </div>
          ))}
        </div>

        {/* Editor Panel */}
        {editMode && (
          <div className="script-editor-panel">
            <div className="editor-toolbar">
              <input
                type="text"
                value={editName}
                onChange={(e) => setEditName(e.target.value)}
                placeholder="Script name"
                className="name-input"
              />
              <div className="toolbar-actions">
                {saved && <span className="saved-badge">✓ Saved</span>}
                <button className="btn btn-secondary" onClick={() => setEditMode(false)}>Cancel</button>
                <button className="btn btn-primary" onClick={handleSave} disabled={loading}>
                  {loading ? 'Saving...' : 'Save'}
                </button>
              </div>
            </div>

            <div className="editor-options">
              <div className="option">
                <label>Vendor</label>
                <select value={editVendor} onChange={(e) => setEditVendor(e.target.value)}>
                  <option value="auto">Auto-Detect</option>
                  <option value="dell">Dell</option>
                  <option value="hp">HP</option>
                  <option value="lenovo">Lenovo</option>
                </select>
              </div>
              <div className="option">
                <label>Models (comma-separated)</label>
                <input
                  type="text"
                  value={editModels}
                  onChange={(e) => setEditModels(e.target.value)}
                  placeholder="OptiPlex 7080, OptiPlex 5090..."
                />
              </div>
            </div>

            <textarea
              className="script-textarea"
              value={editContent}
              onChange={(e) => setEditContent(e.target.value)}
              spellCheck={false}
            />

            {selectedScript && (
              <div className="server-url-info">
                <label>Server URL (for network-connected PCs)</label>
                <div className="url-box">
                  <code>{getServerUrl(selectedScript)}</code>
                  <button onClick={() => navigator.clipboard.writeText(getServerUrl(selectedScript))}>Copy</button>
                </div>
                <p className="url-hint">Use this URL in your startup script to always get the latest version</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
