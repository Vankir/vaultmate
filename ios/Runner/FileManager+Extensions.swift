import Foundation

class FileService {
    static let selectedFolderKey = "selectedFolderBookmark"
    
    static func saveSelectedFolder(_ url: URL) {
        print("Debug: Attempting to save folder bookmark for URL: \(url.path)")
        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: selectedFolderKey)
            print("Debug: Successfully saved bookmark data with key: \(selectedFolderKey)")
        } catch {
            print("Debug: Failed to save folder bookmark: \(error)")
        }
    }
    
    static func loadSelectedFolder() -> URL? {
        print("Debug: Attempting to load folder bookmark")
        guard let bookmarkData = UserDefaults.standard.data(forKey: selectedFolderKey) else {
            print("Debug: No bookmark data found for key: \(selectedFolderKey)")
            return nil
        }
        
        print("Debug: Found bookmark data, attempting to resolve")
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            print("Debug: Successfully resolved bookmark to URL: \(url.path)")
            print("Debug: Bookmark is stale: \(isStale)")
            
            if isStale {
                print("Debug: Attempting to save fresh bookmark for stale URL")
                saveSelectedFolder(url)
            }
            
            return url
        } catch {
            print("Debug: Failed to resolve bookmark: \(error)")
            UserDefaults.standard.removeObject(forKey: selectedFolderKey)
            return nil
        }
    }
    
    static func getFilesFromFolder(_ folderURL: URL) -> [URL]? {
        let success = folderURL.startAccessingSecurityScopedResource()
        defer {
            if success {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
            let enumerator = FileManager.default.enumerator(
                at: folderURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            
            var fileURLs: [URL] = []
            while let fileURL = enumerator?.nextObject() as? URL {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                if resourceValues.isDirectory != true {
                    fileURLs.append(fileURL)
                }
            }
            return fileURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            print("Error reading folder contents: \(error)")
            return nil
        }
    }
    
    static func readFileContent(_ fileURL: URL) -> String {
        let success = fileURL.startAccessingSecurityScopedResource()
        defer {
            if success {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            return content
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }
    
    static func writeFileContent(_ fileURL: URL, content: String) -> Error? {
        let success = fileURL.startAccessingSecurityScopedResource()
        defer {
            if success {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return nil
        } catch {
            return error
        }
    }
    
    static func fileExists(_ fileURL: URL) -> Bool {
        let success = fileURL.startAccessingSecurityScopedResource()
        defer {
            if success {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    static func createFile(_ fileURL: URL) -> Error? {
        let success = fileURL.startAccessingSecurityScopedResource()
        defer {
            if success {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: fileURL.path) {
            do {
                try "".write(to: fileURL, atomically: true, encoding: .utf8)
                return nil
            } catch {
                return error
            }
        }
        return nil // File already exists, consider it a success
    }
    
    static func deleteFile(_ fileURL: URL) -> Error? {
        let success = fileURL.startAccessingSecurityScopedResource()
        defer {
            if success {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil // Nothing to delete, consider it a success
        }
        do {
            try fileManager.removeItem(at: fileURL)
            return nil
        } catch {
            return error
        }
    }
} 
