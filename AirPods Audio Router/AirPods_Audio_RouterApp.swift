//
//  AirPods_Audio_RouterApp.swift
//  AirPods Audio Router
//
//  Created by Shilp Patel on 9/25/26.
//

import SwiftUI

@main
struct AirPods_Audio_RouterApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                AudioSourcesView()
                    .tabItem { Label("Application Audio Sources", systemImage: "waveform") }
                ContentView()
                    .tabItem { Label("Audio Devices", systemImage: "speaker.wave.2") }
            }
        }
    }
}
