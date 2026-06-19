import Foundation

enum HardwareType: String, CaseIterable, Codable {
    case mini  = "OpenScan Mini"
    case midi  = "OpenScan Midi"
    case classic = "OpenScan Classic"
}

enum ControllerType: String, CaseIterable, Codable {
    case auto    = "Auto-detect"
    case zero2   = "Raspberry Pi Zero 2"
    case pi3     = "Raspberry Pi 3"
    case pi4     = "Raspberry Pi 4"
    case pi5     = "Raspberry Pi 5"
}

enum ShieldType: String, CaseIterable, Codable {
    case green = "GreenShield"
    case black = "BlackShield"
    case red   = "RedShield"
}

enum CameraType: String, CaseIterable, Codable {
    case imx519  = "Arducam IMX519"
    case hawkeye = "Arducam Hawkeye"
    case piCam3  = "Raspberry Pi Camera 3"
}

@Observable
final class HardwareConfig: Codable {
    var hardwareType: HardwareType   = .mini
    var controllerType: ControllerType = .auto
    var shieldType: ShieldType       = .green
    var cameraType: CameraType       = .imx519
    var hostname: String             = "openscan.local"
    var port: UInt16                 = 2050

    // MARK: - Codable support (needed because @Observable is not auto-Codable)

    enum CodingKeys: String, CodingKey {
        case hardwareType, controllerType, shieldType, cameraType, hostname, port
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hardwareType   = try c.decode(HardwareType.self,    forKey: .hardwareType)
        controllerType = try c.decode(ControllerType.self,  forKey: .controllerType)
        shieldType     = try c.decode(ShieldType.self,      forKey: .shieldType)
        cameraType     = try c.decode(CameraType.self,      forKey: .cameraType)
        hostname       = try c.decode(String.self,          forKey: .hostname)
        port           = try c.decode(UInt16.self,          forKey: .port)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hardwareType,   forKey: .hardwareType)
        try c.encode(controllerType, forKey: .controllerType)
        try c.encode(shieldType,     forKey: .shieldType)
        try c.encode(cameraType,     forKey: .cameraType)
        try c.encode(hostname,       forKey: .hostname)
        try c.encode(port,           forKey: .port)
    }

    // MARK: - Persistence

    static var saveURL: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("Moga", isDirectory: true)
            .appendingPathComponent("hardware_config.json")
    }

    func save() {
        do {
            let dir = HardwareConfig.saveURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(self)
            try data.write(to: HardwareConfig.saveURL, options: .atomic)
        } catch {
            print("HardwareConfig: save failed — \(error)")
        }
    }

    static func load() -> HardwareConfig {
        guard let data = try? Data(contentsOf: saveURL),
              let config = try? JSONDecoder().decode(HardwareConfig.self, from: data)
        else { return HardwareConfig() }
        return config
    }
}
