import { useState, useEffect } from 'react'
import { AuthProvider } from './components/AuthProvider'
import { LoginButton } from './components/LoginButton'
import { ScriptGenerator } from './components/ScriptGenerator'
import { MyScripts } from './components/MyScripts'
import './App.css'

function AppContent() {
  const [currentSlide, setCurrentSlide] = useState(0)
  
  const slides = [
    {
      title: "Configure BIOS in Seconds",
      subtitle: "Upload your config, get a ready-to-use script",
      accent: "No login required"
    },
    {
      title: "Dell • HP • Lenovo",
      subtitle: "Auto-detects manufacturer and applies settings",
      accent: "UEFI, PXE, disable CSM"
    },
    {
      title: "100% Free & Open Source",
      subtitle: "Perfect for PC resellers and IT departments",
      accent: "MIT License"
    }
  ]

  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentSlide((prev) => (prev + 1) % slides.length)
    }, 4000)
    return () => clearInterval(timer)
  }, [])

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
            <a href="#generator">Generate Script</a>
            <a href="#my-scripts">My Scripts</a>
            <a href="#downloads">Downloads</a>
            <LoginButton />
          </div>
        </div>
      </nav>

      {/* Hero Slideshow */}
      <section className="hero">
        <div className="hero-bg">
          <div className="grid-overlay"></div>
          <div className="glow glow-1"></div>
          <div className="glow glow-2"></div>
        </div>
        <div className="container hero-content">
          <div className="slideshow">
            {slides.map((slide, index) => (
              <div 
                key={index} 
                className={`slide ${index === currentSlide ? 'active' : ''}`}
              >
                <div className="hero-badge">
                  <span className="pulse"></span>
                  {slide.accent}
                </div>
                <h1 className="hero-title">{slide.title}</h1>
                <p className="hero-subtitle">{slide.subtitle}</p>
              </div>
            ))}
          </div>
          <div className="slide-dots">
            {slides.map((_, index) => (
              <button 
                key={index}
                className={`dot ${index === currentSlide ? 'active' : ''}`}
                onClick={() => setCurrentSlide(index)}
              />
            ))}
          </div>
          <div className="hero-cta">
            <a href="#generator" className="btn btn-primary btn-lg">
              Generate Script Now
            </a>
          </div>
        </div>
      </section>

      {/* Script Generator - Main Feature */}
      <section className="generator-section" id="generator">
        <div className="container">
          <ScriptGenerator />
        </div>
      </section>

      {/* My Scripts - For logged in users */}
      <section className="my-scripts-section" id="my-scripts">
        <div className="container">
          <MyScripts />
        </div>
      </section>

      {/* Downloads - Compact */}
      <section className="downloads" id="downloads">
        <div className="container">
          <h2 className="section-title">Required Tools</h2>
          <div className="download-grid">
            <a href="https://www.dell.com/support/kbdoc/en-us/000178000/dell-command-configure" target="_blank" rel="noopener noreferrer" className="download-card">
              <span className="vendor-tag dell">DELL</span>
              <span>Command Configure</span>
            </a>
            <a href="https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html" target="_blank" rel="noopener noreferrer" className="download-card">
              <span className="vendor-tag hp">HP</span>
              <span>BIOS Config Utility</span>
            </a>
            <a href="https://support.lenovo.com/us/en/solutions/ht100612" target="_blank" rel="noopener noreferrer" className="download-card">
              <span className="vendor-tag lenovo">LENOVO</span>
              <span>Think BIOS Config</span>
            </a>
            <a href="https://go.microsoft.com/fwlink/?linkid=2271337" target="_blank" rel="noopener noreferrer" className="download-card">
              <span className="vendor-tag winpe">WINPE</span>
              <span>Windows ADK</span>
            </a>
          </div>
        </div>
      </section>

      {/* Footer - Minimal */}
      <footer className="footer">
        <div className="container footer-content">
          <div className="footer-brand">
            <span className="logo-quick">Quick</span>
            <span className="logo-pxe">PXE</span>
            <span className="footer-tagline">Free BIOS automation for PXE boot</span>
          </div>
          <div className="footer-links">
            <a href="https://github.com/JNewbs81/fog-automation-tools" target="_blank" rel="noopener noreferrer">GitHub</a>
            <span>•</span>
            <span>© 2026 MIT License</span>
          </div>
        </div>
      </footer>
    </div>
  )
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  )
}

export default App
