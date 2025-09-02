import SwiftUI

struct SimplePracticeView: View {
    let sentence: Sentence
    let project: Project
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(sentence.text)
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
            
            Text("这是简化版的练习视图")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .navigationTitle("单句练习")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("[SimplePracticeView] Appear for sentence: \(sentence.text)")
        }
    }
}

#Preview {
    let project = Project(title: "测试项目", fullText: "这是一个测试句子。")
    let sentence = Sentence(order: 0, text: "这是一个测试句子。", project: project)
    project.sentences = [sentence]
    
    return NavigationStack {
        SimplePracticeView(sentence: sentence, project: project)
    }
}
