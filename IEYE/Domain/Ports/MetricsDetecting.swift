//
//  MetricsDetecting.swift
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//

import Foundation

public protocol MetricsDetecting: AnyObject {
    var onMetrics: ((FaceMetrics) -> Void)? { get set }
    var onFaceLost: ((TimeInterval) -> Void)? { get set } // timestamp
    func start()
    func stop()
}
