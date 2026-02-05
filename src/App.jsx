import { useState } from 'react'
import { AuthProvider } from './components/AuthProvider'
import { LoginButton } from './components/LoginButton'
import { ScriptEditor } from './components/ScriptEditor'
import './App.css'

function AppContent() {
  const [copied, setCopied] = useState(false)

  const copyCode = () => {
    const code = `# Clone QuickPXE from GitHub
git clone https://github.com/JNewbs81/fog-automation-tools.git C:\\QuickPXE
cd C:\\QuickPXE

# Create WinPE environment (run in "Deployment and Imaging Tools Environment" as Admin)
copype amd64 C:\\WinPE_QuickPXE

# Create bootable USB (change D to your USB drive letter)
.\\create-winpe-usb.ps1 -USBDriveLetter D

# If step 5 fails, run this instead:
.\\create-usb-simple.ps1 -DiskNumber 1 -DriveLetter D`
    
    navigator.clipboard.writeText(code)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <div className="app">
      {/* Navigation */}
      <nav className="navbar">
        <div className="container nav-container">
          <a href="#" className="logo">
            <span className="logo-quick">Quick</span>
            <span className="logo-pxe">PXE</span>
          </a>
          <div className="nav-links">
            <a href="#features">Features</a>
            <a href="#editor">Script Editor</a>
            <a href="#downloads">Downloads</a>
            <a href="#quickstart">Quick Start</a>
            <LoginButton />
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="hero">
        <div className="hero-bg">
          <div className="grid-overlay"></div>
          <div className="glow glow-1"></div>
          <div className="glow glow-2"></div>
        </div>
        <div className="container hero-content">
          <div className="hero-badge">
            <span className="pulse"></span>
            Open Source • Free Forever
          </div>
          <h1 className="hero-title">
            Configure BIOS for<br />
            <span className="gradient-text">PXE Boot</span> in Seconds
          </h1>
          <p className="hero-subtitle">
            Automated BIOS configuration for Dell, HP, and Lenovo systems. 
            Perfect for PC resellers, IT departments, and refurbishers deploying Windows at scale.
          </p>
          <div className="hero-buttons">
            <a href="#quickstart" className="btn btn-primary">
              <span>🚀</span> Get Started
            </a>
            <a href="#downloads" className="btn btn-secondary">
              <span>⬇️</span> Download Tools
            </a>
          </div>
          
          {/* Terminal Preview */}
          <div className="terminal-wrapper">
            <div className="terminal">
              <div className="terminal-header">
                <div className="terminal-dots">
                  <span className="dot red"></span>
                  <span className="dot yellow"></span>
                  <span className="dot green"></span>
                </div>
                <span className="terminal-title">quickpxe.exe</span>
              </div>
              <div className="terminal-body">
                <p className="line"><span className="prompt">$</span> Detecting hardware...</p>
                <p className="line output">✓ Detected: Dell OptiPlex 7080</p>
                <p className="line output">✓ Secure Boot: <span className="success">Disabled</span></p>
                <p className="line output">✓ Boot Mode: <span className="success">UEFI Only</span></p>
                <p className="line output">✓ Legacy/CSM: <span className="success">Disabled</span></p>
                <p className="line output">✓ PXE Boot: <span className="success">Enabled</span></p>
                <p className="line output">✓ UEFI Network Stack: <span className="success">Enabled</span></p>
                <p className="line output">✓ SATA Mode: <span className="success">AHCI</span></p>
                <p className="line"><span className="prompt">$</span> <span className="command">Rebooting to PXE in 5s...</span></p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="stats">
        <div className="container stats-grid">
          <div className="stat-card">
            <div className="stat-number">3</div>
            <div className="stat-label">Vendors Supported</div>
            <div className="stat-sub">Dell • HP • Lenovo</div>
          </div>
          <div className="stat-card">
            <div className="stat-number">100%</div>
            <div className="stat-label">Free & Open Source</div>
            <div className="stat-sub">MIT License</div>
          </div>
          <div className="stat-card">
            <div className="stat-number">&lt;60s</div>
            <div className="stat-label">Per Machine</div>
            <div className="stat-sub">Boot, configure, done</div>
          </div>
          <div className="stat-card">
            <div className="stat-number">0</div>
            <div className="stat-label">Manual BIOS Entry</div>
            <div className="stat-sub">Fully automated</div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="features" id="features">
        <div className="container">
          <div className="section-header">
            <h2 className="section-title">Why QuickPXE?</h2>
            <p className="section-subtitle">Stop manually entering BIOS on every PC. Our tools automate the tedious work.</p>
          </div>
          <div className="features-grid">
            <div className="feature-card">
              <div className="feature-icon">⚡</div>
              <h3>Lightning Fast</h3>
              <p>Configure 100+ PCs per day. Boot from USB, walk away, done.</p>
            </div>
            <div className="feature-card">
              <div className="feature-icon">🔧</div>
              <h3>Multi-Vendor</h3>
              <p>Auto-detects Dell, HP, or Lenovo and applies correct settings.</p>
            </div>
            <div className="feature-card">
              <div className="feature-icon">🎯</div>
              <h3>UEFI Ready</h3>
              <p>Sets UEFI-only mode, disables CSM, enables network stack.</p>
            </div>
            <div className="feature-card">
              <div className="feature-icon">🔄</div>
              <h3>Auto-Update</h3>
              <p>USB sticks download latest configs from your server automatically.</p>
            </div>
            <div className="feature-card">
              <div className="feature-icon">🆓</div>
              <h3>100% Free</h3>
              <p>Open source. No subscriptions, no limits, use commercially.</p>
            </div>
            <div className="feature-card">
              <div className="feature-icon">🛡️</div>
              <h3>Battle Tested</h3>
              <p>Used on thousands of PCs. Handles edge cases gracefully.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Script Editor Section */}
      <section className="editor-section" id="editor">
        <div className="container">
          <div className="section-header">
            <h2 className="section-title">Script Editor</h2>
            <p className="section-subtitle">Customize your QuickPXE startup scripts. Sign in to save and manage your own scripts.</p>
          </div>
          <ScriptEditor />
        </div>
      </section>

      {/* Downloads Section */}
      <section className="downloads" id="downloads">
        <div className="container">
          <div className="section-header">
            <h2 className="section-title">Download BIOS Tools</h2>
            <p className="section-subtitle">Official vendor tools required for BIOS configuration. All free.</p>
          </div>
          <div className="vendor-grid">
            <div className="vendor-card dell">
              <div className="vendor-logo">DELL</div>
              <h3>Dell Command Configure</h3>
              <p>For OptiPlex, Precision, Latitude, XPS systems</p>
              <a href="https://www.dell.com/support/kbdoc/en-us/000178000/dell-command-configure" target="_blank" rel="noopener noreferrer" className="vendor-btn">
                Download from Dell →
              </a>
            </div>
            <div className="vendor-card hp">
              <div className="vendor-logo">HP</div>
              <h3>HP BIOS Configuration Utility</h3>
              <p>For EliteDesk, ProDesk, EliteBook, ProBook systems</p>
              <a href="https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html" target="_blank" rel="noopener noreferrer" className="vendor-btn">
                Download from HP →
              </a>
            </div>
            <div className="vendor-card lenovo">
              <div className="vendor-logo">LENOVO</div>
              <h3>Think BIOS Config Tool</h3>
              <p>For ThinkCentre, ThinkPad, ThinkStation systems</p>
              <a href="https://support.lenovo.com/us/en/solutions/ht100612" target="_blank" rel="noopener noreferrer" className="vendor-btn">
                Download from Lenovo →
              </a>
            </div>
          </div>
          
          {/* WinPE Downloads */}
          <div className="winpe-section">
            <h3>Windows PE Required</h3>
            <p>QuickPXE runs from a bootable WinPE USB drive</p>
            <div className="winpe-links">
              <a href="https://go.microsoft.com/fwlink/?linkid=2271337" target="_blank" rel="noopener noreferrer" className="winpe-link">
                <span className="winpe-icon">📦</span>
                <div>
                  <strong>Windows ADK</strong>
                  <span>Main installer - select "Deployment Tools"</span>
                </div>
              </a>
              <a href="https://go.microsoft.com/fwlink/?linkid=2271338" target="_blank" rel="noopener noreferrer" className="winpe-link">
                <span className="winpe-icon">💿</span>
                <div>
                  <strong>Windows PE Add-on</strong>
                  <span>Required for WinPE support</span>
                </div>
              </a>
              <a href="https://github.com/JNewbs81/fog-automation-tools" target="_blank" rel="noopener noreferrer" className="winpe-link">
                <span className="winpe-icon">📁</span>
                <div>
                  <strong>QuickPXE Scripts</strong>
                  <span>GitHub repository</span>
                </div>
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* Quick Start Section */}
      <section className="quickstart" id="quickstart">
        <div className="container">
          <div className="section-header light">
            <h2 className="section-title">Quick Start</h2>
            <p className="section-subtitle">Up and running in under 10 minutes</p>
          </div>
          
          <div className="steps">
            <div className="step">
              <div className="step-number">1</div>
              <h4>Install ADK</h4>
              <p>Download Windows ADK + WinPE Add-on from Microsoft</p>
            </div>
            <div className="step-arrow">→</div>
            <div className="step">
              <div className="step-number">2</div>
              <h4>Clone Scripts</h4>
              <p>Get QuickPXE from GitHub</p>
            </div>
            <div className="step-arrow">→</div>
            <div className="step">
              <div className="step-number">3</div>
              <h4>Create USB</h4>
              <p>Run the USB creator script</p>
            </div>
            <div className="step-arrow">→</div>
            <div className="step">
              <div className="step-number">4</div>
              <h4>Boot & Go</h4>
              <p>Insert USB, boot, BIOS auto-configures</p>
            </div>
          </div>

          <div className="code-block">
            <div className="code-header">
              <span>Run in Admin PowerShell</span>
              <button className="copy-btn" onClick={copyCode}>
                {copied ? '✓ Copied!' : '📋 Copy'}
              </button>
            </div>
            <pre className="code-content">
{`# Clone QuickPXE from GitHub
git clone https://github.com/JNewbs81/fog-automation-tools.git C:\\QuickPXE
cd C:\\QuickPXE

# Create WinPE environment (run in "Deployment and Imaging Tools Environment" as Admin)
copype amd64 C:\\WinPE_QuickPXE

# Create bootable USB (change D to your USB drive letter)
.\\create-winpe-usb.ps1 -USBDriveLetter D

# If step 5 fails, run this instead:
.\\create-usb-simple.ps1 -DiskNumber 1 -DriveLetter D`}
            </pre>
          </div>
        </div>
      </section>

      {/* Use Cases */}
      <section className="usecases">
        <div className="container">
          <div className="section-header">
            <h2 className="section-title">Who Uses QuickPXE?</h2>
            <p className="section-subtitle">Built for anyone deploying Windows at scale</p>
          </div>
          <div className="usecase-grid">
            <div className="usecase-card">
              <span className="usecase-icon">💼</span>
              <h3>PC Resellers</h3>
              <p>Refurbish and deploy hundreds of PCs daily without manual BIOS entry.</p>
            </div>
            <div className="usecase-card">
              <span className="usecase-icon">🏢</span>
              <h3>IT Departments</h3>
              <p>Mass deploy Windows across mixed Dell/HP/Lenovo fleets.</p>
            </div>
            <div className="usecase-card">
              <span className="usecase-icon">♻️</span>
              <h3>Refurbishers</h3>
              <p>Process donated or lease-return PCs quickly and efficiently.</p>
            </div>
            <div className="usecase-card">
              <span className="usecase-icon">🏫</span>
              <h3>Schools & Labs</h3>
              <p>Re-image computer labs without a team of technicians.</p>
            </div>
            <div className="usecase-card">
              <span className="usecase-icon">🔧</span>
              <h3>MSPs</h3>
              <p>Standardize client deployments across diverse hardware.</p>
            </div>
            <div className="usecase-card">
              <span className="usecase-icon">🖥️</span>
              <h3>FOG Users</h3>
              <p>Perfect companion for FOG Project imaging servers.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="footer">
        <div className="container">
          <div className="footer-content">
            <div className="footer-brand">
              <div className="logo">
                <span className="logo-quick">Quick</span>
                <span className="logo-pxe">PXE</span>
              </div>
              <p>Free, open-source BIOS configuration automation for PXE boot and Windows deployment.</p>
              <a href="https://github.com/JNewbs81/fog-automation-tools" target="_blank" rel="noopener noreferrer" className="btn btn-outline">
                ⭐ Star on GitHub
              </a>
            </div>
            <div className="footer-links">
              <h4>Downloads</h4>
              <a href="https://www.dell.com/support/kbdoc/en-us/000178000/dell-command-configure" target="_blank" rel="noopener noreferrer">Dell Command Configure</a>
              <a href="https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html" target="_blank" rel="noopener noreferrer">HP BCU</a>
              <a href="https://support.lenovo.com/us/en/solutions/ht100612" target="_blank" rel="noopener noreferrer">Lenovo TBCT</a>
              <a href="https://go.microsoft.com/fwlink/?linkid=2271337" target="_blank" rel="noopener noreferrer">Windows ADK</a>
            </div>
            <div className="footer-links">
              <h4>Resources</h4>
              <a href="https://github.com/JNewbs81/fog-automation-tools" target="_blank" rel="noopener noreferrer">GitHub Repository</a>
              <a href="https://github.com/JNewbs81/fog-automation-tools/issues" target="_blank" rel="noopener noreferrer">Report Issues</a>
              <a href="https://fogproject.org" target="_blank" rel="noopener noreferrer">FOG Project</a>
            </div>
          </div>
          <div className="footer-bottom">
            <p>© 2026 QuickPXE. Open source under MIT License.</p>
            <p>Not affiliated with Dell, HP, Lenovo, or Microsoft.</p>
          </div>
        </div>
      </footer>
    </div>
  )
}

// Wrap with AuthProvider
function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  )
}

export default App
