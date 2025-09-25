//
//  DTAudioRecorder.swift
//  Difft
//
//  Created by luke on 2025/8/14.
//  Copyright © 2025 Difft. All rights reserved.
//

import AVFoundation
import Accelerate

@objc
public enum DTAudioRecorderMode: Int {
    case avAudioRecorder
    case avAudioEngine
}

@objc
public class DTAudioRecorder: NSObject {

    // MARK: - Common
    public private(set) var url: URL
    public let mode: DTAudioRecorderMode

    public var isMeteringEnabled: Bool {
        get {
            switch mode {
            case .avAudioRecorder:
                return audioRecorder?.isMeteringEnabled ?? false
            case .avAudioEngine:
                return engineMeteringEnabled
            }
        }
        set {
            switch mode {
            case .avAudioRecorder:
                audioRecorder?.isMeteringEnabled = newValue
            case .avAudioEngine:
                engineMeteringEnabled = newValue
            }
        }
    }

    public var currentTime: TimeInterval {
        switch mode {
        case .avAudioRecorder:
            return audioRecorder?.currentTime ?? 0
        case .avAudioEngine:
            guard let sr = engineFileSampleRate else { return 0 }
            return TimeInterval(Double(engineFramesWritten) / sr)
        }
    }

    // MARK: - AVAudioRecorder backend
    private var audioRecorder: AVAudioRecorder?

    // MARK: - AVAudioEngine backend
    private var engine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var engineFile: AVAudioFile?
    private var engineConverter: AVAudioConverter?
    private var engineFramesWritten: AVAudioFramePosition = 0
    private var engineFileSampleRate: Double?
    private var engineMeteringEnabled: Bool = false
    private var engineLastAvgPower: Float = -160.0  // dBFS

    @objc public func averagePowerForChannel(_ channel: Int) -> Float {
        switch mode {
        case .avAudioRecorder:
            audioRecorder?.averagePower(forChannel: channel) ?? -160.0
        case .avAudioEngine:
            engineLastAvgPower
        }
    }

    // MARK: - Init
    public init(url: URL, settings: [String: Any], mode: DTAudioRecorderMode)
        throws
    {
        self.url = url
        self.mode = mode
        super.init()

        switch mode {
        case .avAudioRecorder:
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        case .avAudioEngine:
            try setupEngine(with: settings)
        }
    }

    deinit {
        // 清理
        audioRecorder = nil
        removeEngineTapAndStop()
    }

    // MARK: - Public controls

    @discardableResult
    public func prepareToRecord() -> Bool {
        switch mode {
        case .avAudioRecorder:
            return audioRecorder?.prepareToRecord() ?? false
        case .avAudioEngine:
            // Engine 需要提前启动 I/O，tap 会在 record() 时装载并开始写入
            // 这里仅检查节点和文件准备情况
            return engine != nil && inputNode != nil && engineFile != nil
        }
    }

    @discardableResult
    public func record() -> Bool {
        switch mode {
        case .avAudioRecorder:
            return audioRecorder?.record() ?? false
        case .avAudioEngine:
            guard let engine, let inputNode, let engineFile else {
                return false
            }
            // 如果未运行，先开引擎
            if !engine.isRunning {
                do {
                    try engine.start()
                } catch {
                    Logger.info("Engine start failed: \(error)")
                    return false
                }
            }
            // 安装 tap 写入
            installTapIfNeeded(on: inputNode, to: engineFile)
            return true
        }
    }

    public func stop() {
        switch mode {
        case .avAudioRecorder:
            audioRecorder?.stop()
        case .avAudioEngine:
            removeEngineTapAndStop()
        }
    }
}

// MARK: - AVAudioEngine internals
extension DTAudioRecorder {

    fileprivate func setupEngine(with settings: [String: Any]) throws {
        // 由外部配置 AVAudioSession；此处仅构建链路
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)  // 设备原生采样率/通道数（通常 44.1k/48k、单/双声道）

        // 目标文件：优先使用调用方传入 settings（支持 AAC/PCM 等）
        // 注意：写入时 buffer 的 format 必须与 file.processingFormat 一致；如不一致需 converter。
        let file = try AVAudioFile(forWriting: url, settings: settings)

        self.engine = engine
        self.inputNode = input
        self.engineFile = file
        self.engineFileSampleRate = file.processingFormat.sampleRate
        self.engineFramesWritten = 0

        // 如果输入与目标文件格式不同，则准备转换器
        if inputFormat != file.processingFormat {
            self.engineConverter = AVAudioConverter(
                from: inputFormat,
                to: file.processingFormat
            )
        } else {
            self.engineConverter = nil
        }
    }

    fileprivate func installTapIfNeeded(
        on node: AVAudioInputNode,
        to file: AVAudioFile
    ) {
        node.removeTap(onBus: 0)

        let inputFormat = node.outputFormat(forBus: 0)
        let processingFormat = file.processingFormat
        let useConverter = (engineConverter != nil)

        let bufferSize: AVAudioFrameCount = 1024

        node.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self = self else { return }

            // 计算电平（简单 RMS -> dB）
            if self.engineMeteringEnabled,
                let channelData = buffer.floatChannelData
            {
                let channelCount = Int(buffer.format.channelCount)
                var totalRMS: Float = 0
                let frameCount = Int(buffer.frameLength)
                for ch in 0..<channelCount {
                    let samples = channelData[ch]
                    var sum: Float = 0
                    vDSP_measqv(samples, 1, &sum, vDSP_Length(frameCount))
                    let rms = sqrt(sum)
                    totalRMS += rms
                }
                let avgRMS = totalRMS / Float(max(channelCount, 1))
                let db = 20 * log10(max(avgRMS, 1e-8))
                self.engineLastAvgPower = db
            }

            do {
                if useConverter, let converter = self.engineConverter {
                    guard
                        let outBuf = AVAudioPCMBuffer(
                            pcmFormat: processingFormat,
                            frameCapacity: buffer.frameCapacity
                        )
                    else {
                        return
                    }
                    var didConsumeInput = false
                    let status = converter.convert(to: outBuf, error: nil) {
                        _,
                        outStatus in
                        if didConsumeInput {
                            outStatus.pointee = .noDataNow
                            return nil
                        }
                        outStatus.pointee = .haveData
                        didConsumeInput = true
                        return buffer
                    }
                    if status == .haveData, outBuf.frameLength > 0 {
                        try file.write(from: outBuf)
                        self.engineFramesWritten += AVAudioFramePosition(
                            outBuf.frameLength
                        )
                    }
                } else {
                    try file.write(from: buffer)
                    self.engineFramesWritten += AVAudioFramePosition(
                        buffer.frameLength
                    )
                }
            } catch {
                Logger.info("File write failed: \(error)")
            }
        }
    }

    fileprivate func removeEngineTapAndStop() {
        if let node = inputNode {
            node.removeTap(onBus: 0)
        }
        engine?.stop()
        engine = nil
        inputNode = nil
        engineConverter = nil
        engineFile = nil
        engineFramesWritten = 0
        engineFileSampleRate = nil
    }
}
