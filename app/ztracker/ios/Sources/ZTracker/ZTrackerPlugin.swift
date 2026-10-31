import Foundation
import Capacitor
import CoreLocation
import UIKit

// GPS natif : les positions sont enregistrées et envoyées au serveur par l'app elle-même,
// donc le suivi continue écran verrouillé (la page web, elle, est mise en veille par iOS).
@objc(ZTrackerPlugin)
public class ZTrackerPlugin: CAPPlugin, CAPBridgedPlugin, CLLocationManagerDelegate {
    public let identifier = "ZTrackerPlugin"
    public let jsName = "ZTracker"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "points", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "flush", returnType: CAPPluginReturnPromise)
    ]

    private var lm: CLLocationManager?
    private var url = ""
    private var key = ""
    private var seq = 0
    private var all: [[String: Any]] = []      // positions de la session (relues par la page au réveil)
    private var pending: [[String: Any]] = []  // positions pas encore envoyées
    private var sending = false
    private var lastKept: CLLocation?
    private var lastSend = Date()
    private let q = DispatchQueue(label: "ztracker")
    private let sendEvery: TimeInterval = 180

    private var pendFile: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("zt_pending.json")
    }

    override public func load() {
        try? FileManager.default.createDirectory(at: pendFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let d = try? Data(contentsOf: pendFile), let a = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] { pending = a }
    }

    @objc func start(_ call: CAPPluginCall) {
        url = call.getString("url") ?? url
        key = call.getString("key") ?? key
        DispatchQueue.main.async {
            if self.lm == nil {
                let m = CLLocationManager()
                m.delegate = self
                m.desiredAccuracy = kCLLocationAccuracyBest
                m.distanceFilter = 5
                m.activityType = .otherNavigation
                m.pausesLocationUpdatesAutomatically = false
                m.allowsBackgroundLocationUpdates = true
                m.showsBackgroundLocationIndicator = true
                self.lm = m
            }
            let st = self.lm!.authorizationStatus
            if st == .notDetermined { self.lm!.requestWhenInUseAuthorization() }
            if st == .denied || st == .restricted { call.reject("NOT_AUTHORIZED"); return }
            self.lm!.startUpdatingLocation()
            call.resolve()
        }
    }

    @objc func stop(_ call: CAPPluginCall) {
        DispatchQueue.main.async { self.lm?.stopUpdatingLocation() }
        send(force: true)
        call.resolve()
    }

    @objc func flush(_ call: CAPPluginCall) { send(force: true); call.resolve() }

    @objc func points(_ call: CAPPluginCall) {
        let after = call.getInt("after") ?? 0
        q.async {
            let list = self.all.filter { ($0["seq"] as? Int ?? 0) > after }
            call.resolve(["points": list, "seq": self.seq])
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let st = manager.authorizationStatus
        if st == .denied || st == .restricted { notifyListeners("error", data: ["code": "NOT_AUTHORIZED"]) }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for l in locations {
            if l.horizontalAccuracy < 0 || l.horizontalAccuracy > 150 { continue }
            let t = Int(l.timestamp.timeIntervalSince1970 * 1000)
            var p: [String: Any] = ["lat": l.coordinate.latitude, "lon": l.coordinate.longitude,
                                    "acc": Int(l.horizontalAccuracy.rounded()), "speed": max(0, l.speed), "t": t,
                                    "bearing": l.course >= 0 ? l.course : -1]
            // Comme la page : on garde un point s'il est précis et à plus de 10 m (ou 60 s) du précédent
            var keep = l.horizontalAccuracy <= 60
            if keep, let last = lastKept, l.distance(from: last) < 10, l.timestamp.timeIntervalSince(last.timestamp) < 60 { keep = false }
            p["keep"] = keep
            q.sync {
                seq += 1; p["seq"] = seq
                if keep {
                    lastKept = l
                    all.append(p); if all.count > 20000 { all.removeFirst(all.count - 20000) }
                    pending.append(["lat": (l.coordinate.latitude * 1e6).rounded() / 1e6, "lon": (l.coordinate.longitude * 1e6).rounded() / 1e6,
                                    "acc": Int(l.horizontalAccuracy.rounded()), "speed": max(0, l.speed), "t": t])
                    if pending.count > 5000 { pending.removeFirst(pending.count - 5000) }
                    savePending()
                }
            }
            notifyListeners("pos", data: p)
        }
        send(force: false)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        notifyListeners("error", data: ["code": "GPS"])
    }

    private func savePending() {
        if let d = try? JSONSerialization.data(withJSONObject: pending) { try? d.write(to: pendFile, options: .atomic) }
    }

    private func send(force: Bool) {
        q.async {
            if self.sending || self.pending.isEmpty || self.url.isEmpty || self.key.isEmpty { return }
            if !force && Date().timeIntervalSince(self.lastSend) < self.sendEvery && self.pending.count < 60 { return }
            let batch = Array(self.pending.prefix(200))
            guard let u = URL(string: self.url),
                  let body = try? JSONSerialization.data(withJSONObject: ["a": "pos", "k": self.key, "positions": batch]) else { return }
            self.sending = true
            var r = URLRequest(url: u); r.httpMethod = "POST"; r.timeoutInterval = 30
            r.setValue("text/plain", forHTTPHeaderField: "Content-Type"); r.httpBody = body
            var bg: UIBackgroundTaskIdentifier = .invalid
            bg = UIApplication.shared.beginBackgroundTask(withName: "zt-send") { if bg != .invalid { UIApplication.shared.endBackgroundTask(bg); bg = .invalid } }
            URLSession.shared.dataTask(with: r) { _, resp, err in
                self.q.async {
                    self.sending = false
                    if err == nil, let h = resp as? HTTPURLResponse, (200..<300).contains(h.statusCode) {
                        self.pending.removeFirst(min(batch.count, self.pending.count)); self.savePending()
                        self.lastSend = Date()
                        if !self.pending.isEmpty { self.send(force: true) }
                    }
                }
                DispatchQueue.main.async { if bg != .invalid { UIApplication.shared.endBackgroundTask(bg); bg = .invalid } }
            }.resume()
        }
    }
}
