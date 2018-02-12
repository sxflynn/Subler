//
//  Document.swift
//  Subler
//
//  Created by Damiano Galassi on 10/02/2018.
//

import Cocoa
import IOKit.pwr_mgt

@objc(SBDocument) class Document: NSDocument {

    var mp4: MP42File

    override init() {
        self.options = [:]
        self.optimize = false
        self.mp4 = MP42File()
    }

    @objc init(mp4: MP42File) throws {
        self.options = [:]
        self.optimize = false
        self.mp4 = mp4
        super.init()

        if let url = mp4.url {
            fileURL = url
        } else {
            updateChangeCount(.changeDone)
        }
    }

    override func makeWindowControllers() {
        let documentWindowController = DocumentWindowController()
        addWindowController(documentWindowController)
        documentWindowController.showWindow(self)
    }

    // MARK: Read

    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { return true }

    override open var isEntireFileLoaded: Bool { get { return false } }

    override func read(from url: URL, ofType typeName: String) throws {
        mp4 = try MP42File(url: url)
    }

    override func revert(toContentsOf url: URL, ofType typeName: String) throws {
        mp4 = try MP42File(url: url)

        if let docController = windowControllers.first as? DocumentWindowController {
            docController.reloadData()
        }

        updateChangeCount(.changeCleared)
    }

    // MARK: Save

    private var optimize: Bool
    private var options: [String : Any]

    private func defaultSaveOptions() -> [String : Any] {
        var options = [String : Any]()

        if UserDefaults.standard.bool(forKey: "chaptersPreviewTrack") {
            options[MP42GenerateChaptersPreviewTrack] = true
            options[MP42ChaptersPreviewPosition] = UserDefaults.standard.float(forKey: "SBChaptersPreviewPosition")

        }

        if let accessoryViewController = accessoryViewController {
            options[MP4264BitData] = accessoryViewController._64bit_data.state == .on ? true : false
            options[MP4264BitTime] = accessoryViewController._64bit_time.state == .on ? true : false
        }
        return options
    }

    @IBAction func saveAndOptimize(_ sender: Any) {
        optimize = true
        save(self)
    }

    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool { return true }

    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {
        let docController = windowControllers.first as? DocumentWindowController

        let modifiedCompletionhandler = { (error: Error?) -> Void in
            if let error = error {
                completionHandler(error);
            } else {
                do {
                    let reloadedFile = try MP42File(url: url)
                    self.mp4 = reloadedFile
                    docController?.reloadData()
                    completionHandler(error)
                }
                catch {
                    completionHandler(error)
                }
            }

            docController?.endProgressReporting()
        }

        options = defaultSaveOptions()
        accessoryViewController = nil

        docController?.startProgressReporting()
        super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: modifiedCompletionhandler)
    }

    private var sleepAssertion: IOPMAssertionID = IOPMAssertionID(0)
    private var sleepAssertionSuccess: IOReturn = kIOReturnInvalid

    private func preventSleep() {
        sleepAssertionSuccess = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString,
                                                  IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                  "Subler Save Operation" as CFString,
                                                  &sleepAssertion)
    }

    private func allowSleep() {
        if sleepAssertionSuccess == kIOReturnSuccess {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertionSuccess = kIOReturnInvalid
            sleepAssertion = IOPMAssertionID(0)
        }
    }

    override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) throws {
        unblockUserInteraction()
        preventSleep()

        if UserDefaults.standard.bool(forKey: "SBOrganizeAlternateGroups") {
            mp4.organizeAlternateGroups()
            if UserDefaults.standard.bool(forKey: "SBInferMediaCharacteristics") {
                mp4.inferMediaCharacteristics()
            }
        }

        defer {
            allowSleep()
            mp4.progressHandler = nil
            optimize = false
            options = [:]
        }

        switch saveOperation {
        case .saveOperation:
            try mp4.update(options: options)
        case .saveAsOperation:
            try mp4.write(to: url, options: options)
        default:
            fatalError("Unsupported save operation")
        }

        if optimize {
            DispatchQueue.main.async {
                let docController = self.windowControllers.first as? DocumentWindowController
                docController?.setProgress(title: NSLocalizedString("Optimizing…", comment: "Document Optimize sheet."))
            }
            mp4.optimize()
        }
    }

    // MARK: Save panel

    private var accessoryViewController: SaveOptions?

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        self.accessoryViewController = SaveOptions(doc: self, savePanel: savePanel)

        savePanel.isExtensionHidden = false
        savePanel.accessoryView = accessoryViewController?.view

        return true
    }

    // MARK: User interface validation

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(revertToSaved(_:)) where isDocumentEdited == true:
            return true
        case #selector(save(_:)) where isDocumentEdited == true:
            return true
        case #selector(saveAs(_:)):
            return true
        case #selector(saveAndOptimize(_:)) where isDocumentEdited == false && mp4.hasFileRepresentation == true:
            return true
        default:
            return false
        }
    }

}