import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentPickerDelegate {
    private var pendingResult: FlutterResult?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        setupMethodChannel()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Method Channel Setup
    
    private func setupMethodChannel() {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "icloud_files", binaryMessenger: controller.binaryMessenger)
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            switch call.method {
            case "selectFolder":
                self.handleSelectFolder(controller: controller, result: result)
            case "TaskFileCreate":
                self.handleFileCreate(arguments: call.arguments, result: result)
            case "getAllFiles":
                self.handleGetAllFiles(result: result)
            case "TaskFileExists":
                self.handleFileExists(arguments: call.arguments, result: result)
            case "TaskFileReadAsString":
                self.handleFileRead(arguments: call.arguments, result: result)
            case "TaskFileWriteAsString":
                self.handleFileWrite(arguments: call.arguments, result: result)
            case "TaskFileDelete":
                self.handleFileDelete(arguments: call.arguments, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Method Handlers
    
    private func handleSelectFolder(controller: FlutterViewController, result: @escaping FlutterResult) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        controller.present(documentPicker, animated: true)
        pendingResult = result
    }
    
    private func handleFileCreate(arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing file path", details: nil))
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        if let error = FileService.createFile(fileURL) {
            result(FlutterError(code: "CREATE_ERROR", message: "Failed to create file: \(error.localizedDescription)", details: nil))
        } else {
            result(nil)
        }
    }
    
    private func handleGetAllFiles(result: @escaping FlutterResult) {
        guard let folderURL = FileService.loadSelectedFolder() else {
            result(FlutterError(code: "NO_FOLDER", message: "No folder selected", details: nil))
            return
        }
        
        if let files = FileService.getFilesFromFolder(folderURL) {
            let filePaths = files.map { $0.path }
            print("Debug: Found files: \(filePaths)")
            result(filePaths)
        } else {
            result(FlutterError(code: "READ_ERROR", message: "Failed to read files", details: nil))
        }
    }
    
    private func handleFileExists(arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing file path", details: nil))
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        result(FileService.fileExists(fileURL))
    }
    
    private func handleFileRead(arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing file path", details: nil))
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        let content = FileService.readFileContent(fileURL)
        result(content)
    }
    
    private func handleFileWrite(arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let filePath = args["filePath"] as? String,
              let content = args["content"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing file path or content", details: nil))
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        if let error = FileService.writeFileContent(fileURL, content: content) {
            result(FlutterError(code: "WRITE_ERROR", message: "Failed to write file: \(error.localizedDescription)", details: nil))
        } else {
            result(nil)
        }
    }
    
    private func handleFileDelete(arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing file path", details: nil))
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        if let error = FileService.deleteFile(fileURL) {
            result(FlutterError(code: "DELETE_ERROR", message: "Failed to delete file: \(error.localizedDescription)", details: nil))
        } else {
            result(nil)
        }
    }
    
    // MARK: - UIDocumentPickerDelegate
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let selectedURL = urls.first {
            print("Debug: Selected folder URL: \(selectedURL.path)")
            
            let success = selectedURL.startAccessingSecurityScopedResource()
            print("Debug: Security access granted: \(success)")
            
            do {
                let fileManager = FileManager.default
                //let files = try fileManager.contentsOfDirectory(at: selectedURL, includingPropertiesForKeys: nil)
                //print("Debug: Immediate file check - Found \(files.count) files")
                
                FileService.saveSelectedFolder(selectedURL)
                pendingResult?(selectedURL.path)
            } catch {
                print("Debug: Error checking files: \(error)")
                selectedURL.stopAccessingSecurityScopedResource()
                pendingResult?(FlutterError(code: "ACCESS_ERROR", message: "Failed to access folder: \(error.localizedDescription)", details: nil))
            }
            
            pendingResult = nil
        }
    }
    
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pendingResult?(FlutterError(code: "CANCELLED", message: "User cancelled folder selection", details: nil))
        pendingResult = nil
    }
    
    // Add cleanup method
    override func applicationWillTerminate(_ application: UIApplication) {
        if let url = FileService.loadSelectedFolder() {
            url.stopAccessingSecurityScopedResource()
        }
        super.applicationWillTerminate(application)
    }
}
