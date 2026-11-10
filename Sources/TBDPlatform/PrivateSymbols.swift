import Foundation
import TBDCore

/// 비공개 프레임워크 심볼의 실행 시 조회. 정적 링크 없음. (SRS-ARC-002, ADR-0002)
public final class PrivateSymbols: @unchecked Sendable {
    public static let shared = PrivateSymbols()

    private let lock = NSLock()
    private var handles: [PrivateFramework: UnsafeMutableRawPointer?] = [:]
    private var cache: [String: UnsafeMutableRawPointer?] = [:]

    public init() {}

    private func handle(_ framework: PrivateFramework) -> UnsafeMutableRawPointer? {
        if let known = handles[framework] { return known }
        let opened = dlopen(framework.path, RTLD_NOW)
        handles[framework] = opened
        return opened
    }

    /// 심볼 주소. 프레임워크 또는 심볼이 없으면 nil.
    public func address(_ name: String, in framework: PrivateFramework) -> UnsafeMutableRawPointer? {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(framework.rawValue):\(name)"
        if let known = cache[key] { return known }
        let found = handle(framework).flatMap { dlsym($0, name) }
        cache[key] = found
        return found
    }

    /// C 함수 포인터로 변환한 심볼. `T`는 `@convention(c)` 함수 타입이어야 함.
    /// 선언의 정확성은 컴파일러가 검증하지 않으므로 호출부에 시그니처 근거를 기록.
    public func function<T>(_ name: String, in framework: PrivateFramework, as type: T.Type) -> T? {
        guard let pointer = address(name, in: framework) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    /// Objective-C 클래스. 프레임워크를 먼저 적재한 뒤 조회.
    public func objcClass(_ name: String, in framework: PrivateFramework) -> AnyClass? {
        lock.lock()
        _ = handle(framework)
        lock.unlock()
        return NSClassFromString(name)
    }

    public func isPresent(_ requirement: SymbolRequirement) -> Bool {
        switch requirement {
        case .function(let framework, let name): address(name, in: framework) != nil
        case .objcClass(let framework, let name): objcClass(name, in: framework) != nil
        }
    }

    public func status(of capability: Capability) -> CapabilityStatus {
        capability.status(isPresent: isPresent)
    }

    public func allStatuses() -> [CapabilityStatus] {
        Capability.allCases.map(status(of:))
    }
}
