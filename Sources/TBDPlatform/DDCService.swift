import Foundation
import TBDCore

/// DDC/CI 제어. IOAVService의 I2C 읽기와 쓰기 사용. 모든 요청은 직렬 큐에서 순서대로 수행. (SRS-DDC-001)
/// 시그니처 근거: spikes 문서 S5와 공개 소스(MonitorControl, m1ddc)의 같은 선언.
public enum DDCService {
    typealias I2CFn = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> Int32

    static let queue = DispatchQueue(label: "dev.thebestdisplay.ddc")
    static let chipAddress: UInt32 = 0x37
    static let dataAddress: UInt32 = 0x51
    public static let retries = 3
    /// 요청 1회가 이 시간을 넘겨 실패하면 싱크가 I2C에 응답하지 않는 상태로 봄.
    static let slowFailureThreshold: TimeInterval = 1.5
    /// 쓰기 뒤 디스플레이가 응답을 준비할 시간.
    static let replyDelay: useconds_t = 50_000
    static let retryDelay: useconds_t = 20_000

    static func functions(_ symbols: PrivateSymbols) -> (read: I2CFn, write: I2CFn)? {
        guard let read = symbols.function("IOAVServiceReadI2C", in: .ioKit, as: I2CFn.self),
              let write = symbols.function("IOAVServiceWriteI2C", in: .ioKit, as: I2CFn.self)
        else { return nil }
        return (read, write)
    }

    /// I2C로 EDID 직접 읽기 (칩 주소 0x50). 기본 블록과 선언된 확장 블록을 128바이트씩 읽음.
    /// 응답이 없으면 nil. (SRS-INF-004)
    public static func readEDID(service: AVService, symbols: PrivateSymbols = .shared) -> Data? {
        guard let io = functions(symbols) else { return nil }
        return queue.sync {
            func block(_ index: Int) -> [UInt8]? {
                for _ in 0..<retries {
                    var buffer = [UInt8](repeating: 0, count: 128)
                    if io.read(service.ref, 0x50, UInt32(index * 128), &buffer, 128) == 0, buffer.contains(where: { $0 != 0 }) { return buffer }
                    usleep(retryDelay)
                }
                return nil
            }
            guard let base = block(0), Array(base[0..<8]) == [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00] else { return nil }
            var bytes = base
            // 확장 블록: 체크섬이 맞는 블록까지만 이어 붙임. 256바이트 이후는 연결에 따라 읽히지 않을 수 있음.
            for index in 1...max(1, Int(base[126])) where base[126] > 0 {
                guard let next = block(index), next.reduce(0, { ($0 + Int($1)) & 0xFF }) == 0 else { break }
                bytes += next
            }
            return Data(bytes)
        }
    }

    /// VCP 값 읽기. 응답이 없거나 해석할 수 없으면 nil.
    public static func read(_ code: UInt8, service: AVService, symbols: PrivateSymbols = .shared, attempts: Int = retries) -> DDCPacket.Reply? {
        guard let io = functions(symbols) else { return nil }
        return queue.sync {
            var request = DDCPacket.getRequest(code)
            for _ in 0..<max(1, attempts) {
                guard io.write(service.ref, chipAddress, dataAddress, &request, UInt32(request.count)) == 0 else {
                    usleep(retryDelay)
                    continue
                }
                usleep(replyDelay)
                var reply = [UInt8](repeating: 0, count: 11)
                guard io.read(service.ref, chipAddress, dataAddress, &reply, UInt32(reply.count)) == 0 else {
                    usleep(retryDelay)
                    continue
                }
                switch DDCPacket.parseReply(reply, expecting: code) {
                case .success(let parsed): return parsed
                case .failure(.unsupportedCode): return nil
                case .failure: usleep(retryDelay)
                }
            }
            return nil
        }
    }

    /// VCP 값 쓰기. I2C 쓰기 성공 여부 반환 (디스플레이의 수용 여부는 다시 읽어 확인).
    @discardableResult
    public static func write(_ code: UInt8, value: UInt16, service: AVService, symbols: PrivateSymbols = .shared) -> Bool {
        guard let io = functions(symbols) else { return false }
        return queue.sync {
            var request = DDCPacket.setRequest(code, value: value)
            for _ in 0..<retries {
                if io.write(service.ref, chipAddress, dataAddress, &request, UInt32(request.count)) == 0 {
                    usleep(replyDelay)
                    return true
                }
                usleep(retryDelay)
            }
            return false
        }
    }

    /// capabilities 문자열 읽기: 오프셋을 올려 가며 조각을 모으고 빈 조각에서 종료. 응답이 없으면 nil. (SRS-DDC-002)
    public static func capabilities(service: AVService, symbols: PrivateSymbols = .shared) -> DDCCapabilities? {
        guard let io = functions(symbols) else { return nil }
        return queue.sync {
            var collected: [UInt8] = []
            var failures = 0
            let started = Date()
            while collected.count < 4096, failures < retries {
                var request = DDCCapabilities.request(offset: collected.count)
                guard io.write(service.ref, chipAddress, dataAddress, &request, UInt32(request.count)) == 0 else {
                    failures += 1
                    // 첫 조각부터 느리게 실패하면 응답하지 않는 싱크로 보고 중단.
                    if collected.isEmpty, Date().timeIntervalSince(started) > slowFailureThreshold { return nil }
                    usleep(retryDelay)
                    continue
                }
                usleep(replyDelay)
                var reply = [UInt8](repeating: 0, count: 40)
                guard io.read(service.ref, chipAddress, dataAddress, &reply, UInt32(reply.count)) == 0,
                      let fragment = DDCCapabilities.parseFragment(reply), fragment.offset == collected.count
                else {
                    failures += 1
                    // 첫 조각부터 느리게 실패하면 응답하지 않는 싱크로 보고 중단.
                    if collected.isEmpty, Date().timeIntervalSince(started) > slowFailureThreshold { return nil }
                    usleep(retryDelay)
                    continue
                }
                if fragment.data.isEmpty { break }
                collected += fragment.data
                failures = 0
            }
            guard !collected.isEmpty else { return nil }
            return DDCCapabilities.parse(String(decoding: collected, as: UTF8.self))
        }
    }

    /// DDC 지원 탐지: 밝기, 대비, 볼륨, 입력 소스를 읽어 응답한 코드 수집. (PRD-DDC-001)
    public static func probe(for display: DisplaySummary, symbols: PrivateSymbols = .shared) -> DDCProbe {
        guard !display.identity.isBuiltin else { return DDCProbe(status: .notApplicable) }
        guard functions(symbols) != nil, let service = SignalService.avService(for: display, symbols: symbols) else {
            return DDCProbe(status: .noChannel)
        }
        var values: [UInt8: [UInt16]] = [:]
        // 응답하지 않는 싱크는 I2C 호출 하나가 시스템 제한 시간까지 걸림 (LG TV 실측: 호출당 약 8초, 탐지 전체 50초).
        // 첫 요청이 오래 걸린 끝에 실패하면 재시도 없이 미응답으로 판정. (T55 실측)
        let started = Date()
        let first = read(VCPCode.brightness.rawValue, service: service, symbols: symbols, attempts: 1)
        if first == nil, Date().timeIntervalSince(started) > slowFailureThreshold {
            return DDCProbe(status: .noResponse)
        }
        if let first { values[VCPCode.brightness.rawValue] = [first.current, first.maximum] }
        for code in [VCPCode.brightness, .contrast, .volume, .inputSource] where values[code.rawValue] == nil {
            if let reply = read(code.rawValue, service: service, symbols: symbols) {
                values[code.rawValue] = [reply.current, reply.maximum]
            } else if values.isEmpty, code == .contrast {
                // 앞의 두 코드에 모두 응답이 없으면 미지원으로 판정하고 중단.
                break
            }
        }
        return DDCProbe(status: values.isEmpty ? .noResponse : .supported, values: values)
    }
}
