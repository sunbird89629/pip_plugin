//
//  PipCounterView.swift
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
struct PipCounterView: View {
    @State private var count = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("👆 可交互计数器")
                    .foregroundColor(.white)
                    .font(.headline)

                Text("\(count)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.yellow)

                Button(action: {
                    count += 1
                }) {
                    Text("+1")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

//                Button(action: {
//                    if let pip = PipInteractiveManager.shared.pipController,
//                       pip.isPictureInPictureActive {
//                        pip.stopPictureInPicture()
//                    }
//                }) {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.title)
//                        .foregroundColor(.white.opacity(0.8))
//                }
//                .padding(.top, 20)
            }
            .padding()
        }
    }
}
