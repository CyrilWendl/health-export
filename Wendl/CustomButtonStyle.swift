//
//  CustomButtonStyle.swift
//  Wendl
//
//  Created by Cyril Wendl on 06.06.2025.
//


import SwiftUI

struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(configuration.isPressed ? Color.blue.opacity(0.7) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .font(.headline)
            .shadow(radius: configuration.isPressed ? 1 : 4)
    }
}
