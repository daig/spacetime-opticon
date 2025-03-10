//
//  LevelMeterView.swift
//  spacetime-mic
//
//  Created by David Girardo on 3/10/25.
//

import SwiftUI

// MARK: - Level Meter View
struct LevelMeterView: View {
    var level: Float
    var channelName: String
    
    var body: some View {
        VStack {
            Text(channelName)
                .font(.caption)
                .padding(.bottom, 2)
            
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background of the meter
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    
                    // Colored bar representing the level
                    Rectangle()
                        .fill(levelColor)
                        .frame(
                            width: geometry.size.width,
                            height: CGFloat(level) * geometry.size.height
                        )
                }
            }
            .cornerRadius(4)
            
            Text("\(Int(level * 100))%")
                .font(.caption)
                .padding(.top, 2)
        }
    }
    
    private var levelColor: Color {
        switch level {
        case 0..<0.5:
            return .green
        case 0.5..<0.8:
            return .yellow
        default:
            return .red
        }
    }
}
