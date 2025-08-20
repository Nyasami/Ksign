import UIKit
import Foundation

// MARK: - UDIDProvider
// class UDIDProvider: NSObject {
//     @objc dynamic var udids: [String] = []
//
//     override init() {
//         super.init()
//         loadUDIDs()
//         NotificationCenter.default.addObserver(forName: Notification.Name("udidImported"), object: nil, queue: .main) { [weak self] _ in
//             self?.loadUDIDsFromUserDefaults()
//         }
//     }
//
//     func loadUDIDs() {
//         guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
//             loadUDIDsFromUserDefaults()
//             return
//         }
//         let url = URL(fileURLWithPath: path)
//         let reader = CertificateReader(url)
//         if let devices = reader.decoded?.ProvisionedDevices, devices.count == 1 {
//             self.udids = devices
//         } else {
//             loadUDIDsFromUserDefaults()
//         }
//     }
//
//     private func loadUDIDsFromUserDefaults() {
//         if let udid = UserDefaults.standard.string(forKey: "deviceUDID"), !udid.isEmpty {
//             self.udids = [udid]
//         } else {
//             self.udids = []
//         }
//     }
// }

// MARK: - GetUDIDViewController
class GetUDIDViewController: UIViewController {
    private let udidProvider = UDIDProvider()
    private var udidLabel: UILabel!
    private var copyButton: UIButton!
    private var fetchButton: UIButton!
    private var stackView: UIStackView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "获取 UDID"
        setupUI()
        updateUDIDDisplay()
    }

    private func setupUI() {
        udidLabel = UILabel()
        udidLabel.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        udidLabel.textColor = .label
        udidLabel.numberOfLines = 0
        udidLabel.textAlignment = .center

        copyButton = UIButton(type: .system)
        copyButton.setTitle("复制 UDID", for: .normal)
        copyButton.addTarget(self, action: #selector(copyUDID), for: .touchUpInside)

        fetchButton = UIButton(type: .system)
        fetchButton.setTitle("重新获取 UDID", for: .normal)
        fetchButton.addTarget(self, action: #selector(fetchUDID), for: .touchUpInside)

        stackView = UIStackView(arrangedSubviews: [udidLabel, copyButton, fetchButton])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func updateUDIDDisplay() {
        if let udid = udidProvider.udids.first {
            udidLabel.text = udid
            copyButton.isEnabled = true
        } else {
            udidLabel.text = "未检测到 UDID，请手动获取。"
            copyButton.isEnabled = false
        }
    }

    @objc private func copyUDID() {
        if let udid = udidProvider.udids.first {
            UIPasteboard.general.string = udid
            let alert = UIAlertController(title: "已复制", message: "UDID 已复制到剪贴板", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func fetchUDID() {
        if let url = URL(string: "https://app.yhios.cn/udid") {
            UIApplication.shared.open(url)
        }
    }
} 