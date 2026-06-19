import Foundation

// Uploads a zipped project to OpenScan Cloud using the user's API key.
// Results are emailed to the account associated with the API key.

@Observable
final class CloudUploader {
    enum State { case idle, uploading(Double), done, failed(String) }
    private(set) var state: State = .idle

    private let uploadURL = URL(string: "https://www.openscan.eu/cloud/upload")!

    func upload(zipURL: URL, apiKey: String) async {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            state = .failed("No API key set. Add it in Settings.")
            return
        }

        state = .uploading(0)

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        guard let zipData = try? Data(contentsOf: zipURL) else {
            state = .failed("Could not read zip file.")
            return
        }

        var body = Data()
        // API key field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"api_key\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(apiKey)\r\n".data(using: .utf8)!)
        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(zipURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/zip\r\n\r\n".data(using: .utf8)!)
        body.append(zipData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                state = .done
            } else {
                state = .failed("Upload failed. Check your API key and try again.")
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
