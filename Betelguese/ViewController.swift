//
//  ViewController.swift
//  Odysseyra1n
//
//  Created by 23 Aaron on 11/06/2020.
//  Copyright © 2020 23 Aaron. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
  
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var goButton: NSButton!
    @IBOutlet weak var statusBox: NSBox!
    @IBOutlet var statusLabel: NSTextView!
    
    var goTouchBarButton: NSButton!
    var progressTouchBarLabel: NSTextField!
    
    var isBusy = false

    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.view.window?.styleMask.remove(NSWindow.StyleMask.resizable)
        
        if let windowController = view.window?.windowController as? WindowController {
            goTouchBarButton = windowController.goTouchBarButton
            progressTouchBarLabel = windowController.progressTouchBarLabel
        }
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        statusBox.cornerRadius = 4
        setStatus("Ready!")
        
        Timer.scheduledTimer(timeInterval: 1 / 60, target: self, selector: #selector(self.refreshStatus), userInfo: nil, repeats: true)
    }
    
    @objc func refreshStatus() {
        if isBusy {
            self.statusLabel.scrollToEndOfDocument(self)
        }
    }
    
    func setStatus(_ status: String, isLogOutput: Bool = false) {
        let font: NSFont
        if #available(macOS 10.15, *) {
            font = NSFont.monospacedSystemFont(ofSize: 0, weight: .regular)
        } else {
            font = NSFont.userFixedPitchFont(ofSize: 0)!
        }

        let attributedString = NSAttributedString(string: status, attributes: [
            .font: font,
            .foregroundColor: NSColor.white
        ])
        if isLogOutput {
            statusLabel.textStorage?.append(attributedString)
        } else {
            statusLabel.textStorage?.setAttributedString(attributedString)
        }
    }
    
    @IBAction func startButtonClick(_ sender: Any) {
        if UserDefaults.standard.bool(forKey: "oneClickMode") {
            doStuff()
            return
        }
        
        let confirmAlert = NSAlert()
        confirmAlert.messageText = "Important"
        confirmAlert.informativeText = """
        Before you begin: ENSURE YOU ARE JAILBROKEN WITH CHECKRA1N BEFORE USING!
        
        If you have already installed Cydia using Loader, please use the Restore System option, then re-jailbreak before continuing.
        
        DISCLAIMER: Use at your own risk. None of the people associated with this project are liable for any damage caused to your device.
        """
        confirmAlert.addButton(withTitle: "Continue")
        confirmAlert.addButton(withTitle: "Cancel")
        confirmAlert.beginSheetModal(for: view.window!) { (response) in
            if response == .alertFirstButtonReturn {
                self.doStuff()
            }
        }
        
    }
    
    func doStuff() {
        isBusy = true
        setStatus("Downloading…\n")
        goButton.isEnabled = false
        progressBar.startAnimation(nil)
        
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory() + "/odysseyra1n")
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        URLSession.shared.downloadTask(with: URL(string: "https://taurine.app/docs/betelguese.sh")!) { (url, response, error) in
            if error != nil {
                NSLog("response = %@", String(describing: response))
                NSLog("error = %@", error! as NSError)
                DispatchQueue.main.async {
                    NSAlert(error: error!).beginSheetModal(for: self.view.window!, completionHandler: nil)
                    self.stopDoingStuff()
                }
                return
            }
            
            let scriptData = try! Data(contentsOf: url!)

            let path = ProcessInfo.processInfo.environment["PATH"]! + ":" + Bundle.main.resourcePath!
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = [ "/dev/stdin", "-y" ]
            process.environment = [
                "PATH": path,
                "SSHPASS": "alpine"
            ]
            process.currentDirectoryPath = tempDir.path
            
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            inputPipe.fileHandleForWriting.write(scriptData)
            inputPipe.fileHandleForWriting.closeFile()
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let text = String(data: handle.availableData, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    self.setStatus(text, isLogOutput: true)
                }
            }
            
            process.launch()
            
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    let isError = process.terminationStatus != 0
                    self.stopDoingStuff(isError: isError)
                    
                    let alert = NSAlert()
                    if isError {
                        self.setStatus("\nError \(process.terminationStatus)", isLogOutput: true)
                        alert.messageText = "Error \(process.terminationStatus)"
                        
                        if process.terminationStatus == 1 {
                            alert.informativeText = "This can happen when your device isn’t detected. Try disconnecting and reconnecting your device, then try again."
                        }
                    } else {
                        alert.messageText = "Done!"
                    }
                    alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
                }
            }
        }.resume()
    }
    
    func stopDoingStuff(isError: Bool = false) {
        isBusy = false
        if !isError {
            setStatus("Ready!")
        }
        progressBar.stopAnimation(nil)
        goButton.isEnabled = true
    }

}

