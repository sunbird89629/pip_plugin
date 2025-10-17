//
//  AutoScrollTextView.swift
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
struct AutoScrollTextView: View {
    let content: String
    @Binding var isScrolling: Bool
    @Binding var scrollSpeed: Double
    @Binding var fontSize: Double
    @Binding var textColor: Color

    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(content)
                .font(.system(size: fontSize))
                .foregroundColor(textColor)
                .padding()
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ContentHeightPreferenceKey.self,
                            value: geometry.size.height
                        )
                    }
                )
                .offset(y: scrollOffset)
        }
        .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
            self.contentHeight = height
        }
        .onReceive(timer) { _ in
            guard isScrolling else { return }

            let increment = scrollSpeed / 60.0
            var newOffset = scrollOffset - increment

            if abs(newOffset) > contentHeight {
                newOffset = 0
            }
            scrollOffset = newOffset
        }
        .onChange(of: isScrolling) { isScrolling in
            if !isScrolling {
                // scrollOffset = 0
            }
        }
    }
}
