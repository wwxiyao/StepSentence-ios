//
//  StepSentence_iosApp.swift
//  StepSentence-ios
//
//  Created by 阿哞 on 2025/9/2.
//

import SwiftUI
import SwiftData

@main
struct StepSentence_iosApp: App {
    var body: some Scene {
        WindowGroup {
            ProjectsView()
        }
        .modelContainer(for: [Project.self, Sentence.self])
    }
}
