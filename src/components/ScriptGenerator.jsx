import { useState } from 'react'
import './ScriptGenerator.css'

// Generates the batch script based on uploaded config
function generateScript(vendor, configContent, options = {}) {
  const { includeReboot = true, serverUrl = '' } = options
  
  const vendorScripts = {
    dell: `@echo off
:: QuickPXE Generated Script - Dell
:: Generated at quickpxe.com

wpeinit
echo =========================================
echo  QuickPXE - Dell BIOS Configuration
echo =========================================

set "CCTK=X:\\bios-tools\\dell\\cctk.exe"

:: Apply user configuration
%CCTK% --infile=X:\\bios-tools\\dell\\user-config.cctk

:: Force UEFI-only boot settings
%CCTK% bootorder --BootListType=uefi
%CCTK% --LegacyOrom=Disabled
%CCTK% --SecureBoot=Disabled
%CCTK% --UefiNwStack=Enabled
%CCTK% --WarningsAndErr=ContWarnErr
%CCTK% bootorder --EnableDevice=EmbNic1
%CCTK% bootorder --Sequence=EmbNic1

echo.
echo Configuration complete!
${includeReboot ? `timeout /t 5
wpeutil reboot` : 'pause'}`,

    hp: `@echo off
:: QuickPXE Generated Script - HP
:: Generated at quickpxe.com

wpeinit
echo =========================================
echo  QuickPXE - HP BIOS Configuration
echo =========================================

set "BCU=X:\\bios-tools\\hp\\BiosConfigUtility64.exe"

:: Apply user configuration
%BCU% /setconfig:X:\\bios-tools\\hp\\user-config.REPSET

:: Force UEFI-only boot settings
%BCU% /setvalue:"Boot Mode","UEFI Native (Without CSM)"
%BCU% /setvalue:"Legacy Support","Disable"
%BCU% /setvalue:"Secure Boot","Disable"
%BCU% /setvalue:"PXE Internal NIC boot","Enable"
%BCU% /setvalue:"UEFI Boot Order","HDD:USB:NETWORK"

echo.
echo Configuration complete!
${includeReboot ? `timeout /t 5
wpeutil reboot` : 'pause'}`,

    lenovo: `@echo off
:: QuickPXE Generated Script - Lenovo
:: Generated at quickpxe.com

wpeinit
echo =========================================
echo  QuickPXE - Lenovo BIOS Configuration  
echo =========================================

set "TBCT=X:\\bios-tools\\lenovo\\ThinkBiosConfig.hta"

:: Apply user configuration
mshta.exe "%TBCT%" "FILE=X:\\bios-tools\\lenovo\\user-config.ini"

:: Force UEFI-only boot settings (embedded in config)
:: BootMode,UEFI Only
:: CSM Support,Disable
:: Secure Boot,Disable
:: Ethernet PXE Option ROM,Enable
:: Network Boot,Enable

echo.
echo Configuration complete!
${includeReboot ? `timeout /t 5
wpeutil reboot` : 'pause'}`,

    auto: `@echo off
:: QuickPXE Generated Script - Auto-Detect
:: Generated at quickpxe.com

wpeinit
echo =========================================
echo  QuickPXE - Auto-Detect Manufacturer
echo =========================================

:: Detect manufacturer
for /f "tokens=2 delims==" %%a in ('wmic computersystem get manufacturer /value') do set "MFR=%%a"

echo Detected: %MFR%
echo.

:: Route to correct script
echo %MFR% | findstr /i "Dell" >nul && goto :DELL
echo %MFR% | findstr /i "HP Hewlett" >nul && goto :HP  
echo %MFR% | findstr /i "Lenovo" >nul && goto :LENOVO

echo ERROR: Unknown manufacturer: %MFR%
pause
exit /b 1

:DELL
call X:\\bios-tools\\dell\\apply-dell-bios.bat
goto :END

:HP
call X:\\bios-tools\\hp\\apply-hp-bios.bat
goto :END

:LENOVO
call X:\\bios-tools\\lenovo\\apply-lenovo-bios.bat
goto :END

:END
echo.
echo Configuration complete!
${includeReboot ? `timeout /t 5
wpeutil reboot` : 'pause'}`
  }

  return vendorScripts[vendor] || vendorScripts.auto
}

// Parse uploaded config to detect vendor
function detectVendor(filename, content) {
  const ext = filename.split('.').pop().toLowerCase()
  
  if (ext === 'cctk' || content.includes('Dell') || content.includes('CCTK')) {
    return 'dell'
  }
  if (ext === 'repset' || content.includes('BIOSConfig') || content.includes('HP ')) {
    return 'hp'
  }
  if (ext === 'ini' && (content.includes('ThinkCentre') || content.includes('Lenovo'))) {
    return 'lenovo'
  }
  return null
}

export function ScriptGenerator() {
  const [uploadedFile, setUploadedFile] = useState(null)
  const [uploadedContent, setUploadedContent] = useState('')
  const [detectedVendor, setDetectedVendor] = useState(null)
  const [manualVendor, setManualVendor] = useState('')
  const [generatedScript, setGeneratedScript] = useState('')
  const [includeReboot, setIncludeReboot] = useState(true)
  const [step, setStep] = useState(1) // 1=upload, 2=configure, 3=download

  const handleFileUpload = (e) => {
    const file = e.target.files[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (event) => {
      const content = event.target.result
      setUploadedFile(file)
      setUploadedContent(content)
      
      const vendor = detectVendor(file.name, content)
      setDetectedVendor(vendor)
      setManualVendor(vendor || '')
      setStep(2)
    }
    reader.readAsText(file)
  }

  const handleGenerate = () => {
    const vendor = manualVendor || 'auto'
    const script = generateScript(vendor, uploadedContent, { includeReboot })
    setGeneratedScript(script)
    setStep(3)
  }

  const handleDownloadScript = () => {
    const blob = new Blob([generatedScript], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'quickpxe-startup.bat'
    a.click()
    URL.revokeObjectURL(url)
  }

  const handleDownloadConfig = () => {
    const blob = new Blob([uploadedContent], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    const ext = manualVendor === 'dell' ? 'cctk' : manualVendor === 'hp' ? 'REPSET' : 'ini'
    a.download = `user-config.${ext}`
    a.click()
    URL.revokeObjectURL(url)
  }

  const handleDownloadZip = async () => {
    // Create a simple instruction file since we can't zip in browser easily
    const instructions = `QuickPXE USB Setup Instructions
================================

1. Copy these files to your WinPE USB:

   USB:\\bios-tools\\${manualVendor}\\user-config.${manualVendor === 'dell' ? 'cctk' : manualVendor === 'hp' ? 'REPSET' : 'ini'}
   USB:\\bios-tools\\startnet.cmd

2. Download the vendor BIOS tool and place it in:
   
   ${manualVendor === 'dell' ? 'USB:\\bios-tools\\dell\\cctk.exe' : ''}
   ${manualVendor === 'hp' ? 'USB:\\bios-tools\\hp\\BiosConfigUtility64.exe' : ''}
   ${manualVendor === 'lenovo' ? 'USB:\\bios-tools\\lenovo\\ThinkBiosConfig.hta' : ''}

3. Boot target PC from USB - script runs automatically!

Files included in this download:
- startnet.cmd (your generated script)
- user-config file (your uploaded config)
`
    const blob = new Blob([instructions], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'quickpxe-readme.txt'
    a.click()
    URL.revokeObjectURL(url)
    
    // Also download the actual files
    handleDownloadScript()
    setTimeout(() => handleDownloadConfig(), 500)
  }

  const handleReset = () => {
    setUploadedFile(null)
    setUploadedContent('')
    setDetectedVendor(null)
    setManualVendor('')
    setGeneratedScript('')
    setStep(1)
  }

  const copyToClipboard = () => {
    navigator.clipboard.writeText(generatedScript)
  }

  return (
    <div className="script-generator">
      <div className="generator-header">
        <h2>Generate Your Script</h2>
        <p>Upload a BIOS config file → Get a ready-to-use startup script</p>
      </div>

      {/* Progress Steps */}
      <div className="progress-steps">
        <div className={`progress-step ${step >= 1 ? 'active' : ''}`}>
          <span className="step-num">1</span>
          <span className="step-label">Upload</span>
        </div>
        <div className="step-line"></div>
        <div className={`progress-step ${step >= 2 ? 'active' : ''}`}>
          <span className="step-num">2</span>
          <span className="step-label">Configure</span>
        </div>
        <div className="step-line"></div>
        <div className={`progress-step ${step >= 3 ? 'active' : ''}`}>
          <span className="step-num">3</span>
          <span className="step-label">Download</span>
        </div>
      </div>

      {/* Step 1: Upload */}
      {step === 1 && (
        <div className="generator-step">
          <div className="upload-zone">
            <input 
              type="file" 
              id="config-upload" 
              accept=".cctk,.REPSET,.repset,.ini,.txt"
              onChange={handleFileUpload}
              hidden
            />
            <label htmlFor="config-upload" className="upload-label">
              <span className="upload-icon">📄</span>
              <span className="upload-text">
                <strong>Drop config file here</strong>
                <span>or click to browse</span>
              </span>
              <span className="upload-formats">.cctk (Dell) • .REPSET (HP) • .ini (Lenovo)</span>
            </label>
          </div>
          
          <div className="or-divider">
            <span>or generate without a config</span>
          </div>
          
          <div className="quick-options">
            <button className="vendor-btn dell" onClick={() => { setManualVendor('dell'); setStep(2); }}>
              Dell Script
            </button>
            <button className="vendor-btn hp" onClick={() => { setManualVendor('hp'); setStep(2); }}>
              HP Script
            </button>
            <button className="vendor-btn lenovo" onClick={() => { setManualVendor('lenovo'); setStep(2); }}>
              Lenovo Script
            </button>
            <button className="vendor-btn auto" onClick={() => { setManualVendor('auto'); setStep(2); }}>
              Auto-Detect
            </button>
          </div>
        </div>
      )}

      {/* Step 2: Configure */}
      {step === 2 && (
        <div className="generator-step">
          {uploadedFile && (
            <div className="file-info">
              <span className="file-icon">✓</span>
              <span className="file-name">{uploadedFile.name}</span>
              <span className="file-size">({Math.round(uploadedFile.size / 1024)}KB)</span>
            </div>
          )}
          
          <div className="config-options">
            <div className="option-group">
              <label>Vendor</label>
              <div className="vendor-select">
                {['dell', 'hp', 'lenovo', 'auto'].map(v => (
                  <button 
                    key={v}
                    className={`vendor-chip ${manualVendor === v ? 'active' : ''}`}
                    onClick={() => setManualVendor(v)}
                  >
                    {v === 'auto' ? 'Auto-Detect' : v.toUpperCase()}
                  </button>
                ))}
              </div>
            </div>
            
            <div className="option-group">
              <label className="checkbox-label">
                <input 
                  type="checkbox" 
                  checked={includeReboot}
                  onChange={(e) => setIncludeReboot(e.target.checked)}
                />
                <span>Auto-reboot after configuration</span>
              </label>
            </div>
          </div>

          <div className="step-actions">
            <button className="btn btn-secondary" onClick={handleReset}>
              ← Back
            </button>
            <button className="btn btn-primary" onClick={handleGenerate}>
              Generate Script →
            </button>
          </div>
        </div>
      )}

      {/* Step 3: Download */}
      {step === 3 && (
        <div className="generator-step">
          <div className="script-preview">
            <div className="preview-header">
              <span>startnet.cmd</span>
              <button className="copy-btn" onClick={copyToClipboard}>📋 Copy</button>
            </div>
            <pre className="preview-code">{generatedScript}</pre>
          </div>

          <div className="download-actions">
            <button className="btn btn-primary btn-lg" onClick={handleDownloadZip}>
              ⬇️ Download All Files
            </button>
            <button className="btn btn-secondary" onClick={handleDownloadScript}>
              Script Only
            </button>
            {uploadedFile && (
              <button className="btn btn-secondary" onClick={handleDownloadConfig}>
                Config Only
              </button>
            )}
          </div>

          <div className="next-steps">
            <h4>Next Steps:</h4>
            <ol>
              <li>Copy files to <code>USB:\bios-tools\{manualVendor}\</code></li>
              <li>Download the <a href="#downloads">{manualVendor.toUpperCase()} BIOS tool</a></li>
              <li>Boot target PC from USB</li>
            </ol>
          </div>

          <button className="btn btn-outline" onClick={handleReset}>
            ← Generate Another
          </button>
        </div>
      )}
    </div>
  )
}
