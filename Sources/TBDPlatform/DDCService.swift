import Foundation
import TBDCore

/// DDC/CI 제어. IOAVService의 I2C 읽기와 쓰기 사용. 모든 요청은 직렬 큐에서 순서대로 수행. (SRS-DDC-001)
/// 시그니처 근거: spikes 문서 S5와 공개 소스(MonitorControl, m1ddc)의 같은 선언.
public enum DDCService {
    typealias I2CFn = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> Int32

    static let queue = DispatchQueue(label: "dev.thebestdisplay.ddc")
    static let chipAddress: UInt32 = 0x37
    static let dataAddress: UInt32 = 0x51
    static let retries = 3
    /// 쓰기 뒤 디스플레이가 응답을 준비할 시간.
    static let replyDelay: useconds_t = 50_000
    static let retryDelay: useconds_t = 20_000

    static func functions(_ symbols: PrivateSymbols) -> (read: I2CFn, write: I2CFn)? {
        guard let read = symbols.function("IOAVServiceReadI2C", in: .ioKit, as: I2CFn.self),
              let write = symbols.function("IOAVServiceWriteI2C", in: .ioKit, as: I2CFn.self)
        else { return nil }
        return (read, write)
    }

    /// VCP 값 읽기. 응답이 없거나 해석할 수 없으면 nil.
    public static func read(_ code: UInt8, service: AVService, symbols: PrivateSymbols = .shared) -> DDCPacket.Reply? {
        guard let io = functions(symbols) else { return nil }
        return queue.sync {
            var request = DDCPacket.getRequest(code)
            for _ in 0..<retries {
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

    /// DDC 지원 탐지: 밝기, 대비, 볼륨, 입력 소스를 읽어 응답한 코드 수집. (PRD-DDC-001)
    public static func probe(for display: DisplaySummary, symbols: PrivateSymbols = .shared) -> DDCProbe {
        guard !display.identity.isBuiltin else { return DDCProbe(status: .notApplicable) }
        guard functions(symbols) != nil, let service = SignalService.avService(for: display, symbols: symbols) else {
            return DDCProbe(status: .noChannel)
        }
        var values: [UInt8: [UInt16]] = [:]
        for code in [VCPCode.brightness, .contrast, .volume, .inputSource] {
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
