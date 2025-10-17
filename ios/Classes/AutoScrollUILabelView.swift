//
//  AutoScrollUILabelView.swift
//  
//
//  Created by 王豪 on 2025/10/17.
//


import AVKit
import Combine
import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
struct AutoScrollUILabelView: UIViewRepresentable {
    let text: String
    var font: UIFont
    var textColor: UIColor
    @Binding var isScrolling: Bool
    @Binding var scrollSpeed: Double

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isScrollEnabled = false // we drive programmatically
        let label = UILabel()
        label.numberOfLines = 0
        label.font = font
        label.textColor = textColor
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            label.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -16)
        ])

        context.coordinator.setup(scrollView: scrollView, label: label)
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.update(text: text, font: font, color: textColor)
        context.coordinator.updateScrolling(isScrolling: isScrolling, speed: scrollSpeed)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        private weak var scrollView: UIScrollView?
        private weak var label: UILabel?
        private var displayLink: CADisplayLink?
        private var lastTime: CFTimeInterval = 0
        private var speedPerSec: Double = 30 // default

        func setup(scrollView: UIScrollView, label: UILabel) {
            self.scrollView = scrollView
            self.label = label
        }

        func update(text: String, font: UIFont, color: UIColor) {
            label?.text = text
            label?.font = font
            label?.textColor = color
            // Ensure layout then update contentSize
            label?.setNeedsLayout()
            label?.layoutIfNeeded()
        }

        func updateScrolling(isScrolling: Bool, speed: Double) {
            speedPerSec = speed
            if isScrolling { start() } else { stop() }
        }

        private func start() {
            stop()
            lastTime = CACurrentMediaTime()
            displayLink = CADisplayLink(target: self, selector: #selector(tick))
            displayLink?.add(to: .main, forMode: .common)
        }

        private func stop() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func tick() {
            guard let sv = scrollView else { return }
            guard let label = label else { return }
            let now = CACurrentMediaTime()
            let dt = now - lastTime
            lastTime = now
            let delta = CGFloat(speedPerSec * dt)
            var newOffset = sv.contentOffset.y + delta
            let maxOffset = max(0, sv.contentSize.height - sv.bounds.height)
            if newOffset > maxOffset {
                newOffset = 0
            }
            sv.setContentOffset(CGPoint(x: 0, y: newOffset), animated: false)
        }
    }
}