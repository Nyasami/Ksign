import Foundation

enum CertificateRestoreError: Error {
    case message(String)
}

class CertificateRestoreHelper {
    static func restoreCertificate(for udid: String, completion: @escaping (Result<Void, CertificateRestoreError>) -> Void) {
        guard let url = URL(string: "https://cert.yhios.cn/api/app.php?udid=\(udid)") else {
            completion(.failure(.message("无效的URL")))
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    completion(.failure(.message("请求失败，请检查网络连接")))
                }
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else {
                DispatchQueue.main.async {
                    completion(.failure(.message("数据格式错误")))
                }
                return
            }
            if status == "error" {
                DispatchQueue.main.async {
                    completion(.failure(.message((json["message"] as? String) ?? "未知错误")))
                }
                return
            }
            guard let encryptedDataBase64 = json["data"] as? String else {
                DispatchQueue.main.async {
                    completion(.failure(.message("数据解析失败")))
                }
                return
            }
            let key = "sZq1K4Y!2mB5xP7dT9gLfRqVhJcXeZm@"
            let iv = "Wp7dK1zQc3Vb0tX9"
            if let encryptedData = Data(base64Encoded: encryptedDataBase64),
               let decryptedData = CertificateEncryption.decryptAESCBC(base64Cipher: encryptedDataBase64, key: key, iv: iv),
               let jsonObject = try? JSONSerialization.jsonObject(with: decryptedData, options: []) as? [String: Any],
               let provisionObj = jsonObject["provision"] as? [String: Any],
               let certsObj = jsonObject["certs"] as? [String: Any],
               let password = jsonObject["pass"] as? String,
               let provisionBase64 = provisionObj["content"] as? String,
               let certsBase64 = certsObj["content"] as? String,
               let provision = Data(base64Encoded: provisionBase64),
               let p12 = Data(base64Encoded: certsBase64) {
                DispatchQueue.main.async {
                    FR.handleCertificateData(
                        p12Data: p12,
                        provisionData: provision,
                        p12Password: password,
                        certificateName: ""
                    ) { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                completion(.success(()))
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(.message("加密数据解析失败")))
                }
            }
        }
        task.resume()
    }
} 