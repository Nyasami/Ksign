import Foundation
import Combine

class UDIDProvider: ObservableObject {
    @Published var udids: [String] = []

    init() {
        loadUDIDs()
        NotificationCenter.default.addObserver(forName: Notification.Name("udidImported"), object: nil, queue: .main) { [weak self] _ in
            self?.loadUDIDsFromUserDefaults()
        }
    }

    func loadUDIDs() {
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            loadUDIDsFromUserDefaults()
            return
        }
        let url = URL(fileURLWithPath: path)
        let reader = CertificateReader(url)
        if let devices = reader.decoded?.ProvisionedDevices, devices.count == 1 {
            self.udids = devices
            // 将从描述文件中读取到的UDID保存到UserDefaults中
            UserDefaults.standard.set(devices[0], forKey: "deviceUDID")
        } else {
            loadUDIDsFromUserDefaults()
        }
    }

    private func loadUDIDsFromUserDefaults() {
        if let udid = UserDefaults.standard.string(forKey: "deviceUDID"), !udid.isEmpty {
            self.udids = [udid]
        } else {
            self.udids = []
        }
    }
} 