import Foundation
import Observation
@preconcurrency import Network

/// Bonjour discovers an endpoint, never authenticates it. The backend validates its
/// short-lived, event-bound reception token. No account tokens, names or contacts on Bonjour.
@MainActor @Observable
final class NearbyCheckinService {
    private(set) var status = "尚未開始"
    private(set) var isRunning = false
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [NWConnection] = []
    private var tried: Set<NWEndpoint> = []
    private var ticket: ReceptionTicket?
    private var runID = UUID()
    private var timer: Task<Void, Never>?
    static let serviceType = "_snoots-checkin._tcp"

    func host(_ ticket: ReceptionTicket) throws {
        if isRunning, listener != nil { self.ticket = ticket; return }
        stop()
        self.ticket = ticket
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let listener = try NWListener(using: parameters)
        listener.service = NWListener.Service(name: String(UUID().uuidString.prefix(12)), type: Self.serviceType)
        self.listener = listener; isRunning = true; status = "正在啟用接待…"
        let run = runID
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, self.runID == run else { return }
                switch state {
                case .ready: self.status = "接待中｜請保持此畫面與 App 在前景"
                case .failed: self.stop(); self.status = "無法啟用接待，請確認本機網路權限；仍可使用手動簽到。"
                case .waiting: self.status = "等待網路／授權，可在系統設定檢查本機網路權限。"
                default: break
                }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                guard let self, self.runID == run, self.isRunning, self.connections.count < 30, let ticket = self.ticket,
                      let data = try? JSONEncoder().encode(ticket) else { connection.cancel(); return }
                self.connections.append(connection)
                connection.start(queue: .main)
                connection.send(content: data, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
                    connection.cancel()
                    Task { @MainActor in self.connections.removeAll { $0 === connection } }
                })
            }
        }
        listener.start(queue: .main)
    }

    func search(eventID: UUID, onTicket: @escaping @MainActor (ReceptionTicket) async -> Bool) {
        stop(); isRunning = true; status = "正在尋找本場發起人…"
        let parameters = NWParameters.tcp; parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: parameters)
        self.browser = browser; let run = runID
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, self.runID == run else { return }
                switch state {
                case .failed: self.stop(); self.status = "搜尋失敗，請檢查本機網路權限或請發起人手動簽到。"
                case .waiting: self.status = "等待網路／授權；找不到裝置時可請發起人手動簽到。"
                default: break
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                guard let self, self.runID == run, self.isRunning else { return }
                for result in results.prefix(20) where !self.tried.contains(result.endpoint) {
                    self.tried.insert(result.endpoint)
                    let connection = NWConnection(to: result.endpoint, using: parameters)
                    self.connections.append(connection); connection.start(queue: .main)
                    self.receive(connection, buffer: Data(), eventID: eventID, run: run, onTicket: onTicket)
                }
            }
        }
        browser.start(queue: .main)
        timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, self.runID == run else { return }
            self.stop(); self.status = "尚未找到可完成簽到的接待端。請重新搜尋，或請發起人手動簽到。"
        }
    }
    private func receive(_ connection: NWConnection, buffer: Data, eventID: UUID, run: UUID,
                         onTicket: @escaping @MainActor (ReceptionTicket) async -> Bool) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { [weak self] bytes, _, complete, error in
            Task { @MainActor [weak self] in
                guard let self, self.runID == run, self.isRunning else { connection.cancel(); return }
                var all = buffer; all.append(bytes ?? Data())
                guard all.count <= 1024, error == nil else { connection.cancel(); return }
                if complete {
                    connection.cancel()
                    guard let value = try? JSONDecoder().decode(ReceptionTicket.self, from: all), value.eventID == eventID else { return }
                    self.status = "找到接待端，正在由伺服器驗證並儲存…"
                    if await onTicket(value), self.runID == run {
                        self.stop(); self.status = "簽到成功｜已由伺服器儲存"
                    } else if self.runID == run { self.status = "尚未完成簽到，請查看原因並重試。" }
                } else { self.receive(connection, buffer: all, eventID: eventID, run: run, onTicket: onTicket) }
            }
        }
    }
    func stop() {
        runID = UUID(); isRunning = false; timer?.cancel(); timer = nil
        listener?.cancel(); listener = nil; browser?.cancel(); browser = nil
        connections.forEach { $0.cancel() }; connections = []; tried = []; ticket = nil
    }
}
