import SwiftUI

struct ContentView: View {
    @StateObject private var photoFetcher = PhotoFetcher()
    @State private var responseText: String = ""
    @State private var selectedPhoto: UIImage? = nil
    @State private var responseViewHeight: CGFloat = 200
    @State private var maxResponseViewHeight: CGFloat = 0
    @State private var questions: [String] = []
    @State private var selectedQuestion: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 0)]) {
                    ForEach(photoFetcher.photos, id: \.self) { photo in
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()
                            .onTapGesture {
                                selectedPhoto = photo
                                if let selectedPhoto = selectedPhoto {
                                    uploadPhoto(photo: selectedPhoto)
                                }
                            }
                            .border(selectedPhoto == photo ? Color.blue : Color.clear, width: 2)
                    }
                }
                .padding(.horizontal, 0)
            }
            .frame(maxHeight: .infinity)

            if !responseText.isEmpty || !questions.isEmpty {
                ResizableTextView(text: $responseText, questions: $questions, selectedQuestion: $selectedQuestion, height: $responseViewHeight, maxHeight: $maxResponseViewHeight) { question in
                    if let selectedPhoto = selectedPhoto {
                        askQuestion(question: question, photo: selectedPhoto)
                    }
                }
                .padding(.horizontal, 0)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            if let window = UIApplication.shared.windows.first {
                maxResponseViewHeight = window.frame.height
            }
            photoFetcher.fetchCount = 200
            photoFetcher.fetchPhotos()
        }
    }

    func uploadPhoto(photo: UIImage) {
        let apiKey = ""
        let url = URL(string: "")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        guard let base64String = photoFetcher.base64Encode(image: photo) else {
            print("Failed to encode image to base64")
            return
        }

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "What’s in this image? Explain this image in details. Search and analyze on every detail from the image. If there is any key information or question, explain briefly on that as well, if not, do not need to say. If this is an iPhone screenshot, do not need to give those unnecessary header information, just get the main picture. Be accurate, precise and concise, and avoid unnecessary words. And in the end, give three questions to further analyze regarding this image, directly give the questions starting only with <Q1>, <Q2> and <Q3>."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64String)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1024
        ]

        let jsonData = try! JSONSerialization.data(withJSONObject: payload, options: [])

        URLSession.shared.uploadTask(with: request, from: jsonData) { data, response, error in
            guard let data = data, error == nil else {
                print("Upload error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let gptResponse = try? JSONDecoder().decode(GPTResponse.self, from: data) {
                DispatchQueue.main.async {
                    parseResponse(gptResponse.choices.first?.message.content ?? "No response")
                }
            } else {
                print("Failed to decode GPT response")
            }
        }.resume()
    }

    func askQuestion(question: String, photo: UIImage) {
        let apiKey = "sk-CQy7FFKPFCOwwhY3A4E84b48E9F24aA18bA86eCf8cDaE55c"
        let url = URL(string: "https://api.cpdd666.cn/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        guard let base64String = photoFetcher.base64Encode(image: photo) else {
            print("Failed to encode image to base64")
            return
        }

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Answer the following question based on the image. I want true information, so do not try pretending to get information from the image if the image does not provide details regarding this question. If there is not much information from the image, you do not need to say, just give me useful answer to the question. Then you can just search or use your knowledge to answer this question in details from technical researches or general knowledge. Be accurate, precise and concise and avoid unnecessary outputs. The question is: \(question)"
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64String)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1024
        ]

        let jsonData = try! JSONSerialization.data(withJSONObject: payload, options: [])

        URLSession.shared.uploadTask(with: request, from: jsonData) { data, response, error in
            guard let data = data, error == nil else {
                print("Upload error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let gptResponse = try? JSONDecoder().decode(GPTResponse.self, from: data) {
                DispatchQueue.main.async {
                    parseResponse(gptResponse.choices.first?.message.content ?? "No response")
                }
            } else {
                print("Failed to decode GPT response")
            }
        }.resume()
    }

    func parseResponse(_ response: String) {
        let lines = response.split(separator: "\n")
        var filteredResponse = ""
        var newQuestions: [String] = []

        for line in lines {
            if line.starts(with: "<Q1>") {
                newQuestions.append(String(line))
            } else if line.starts(with: "<Q2>") {
                newQuestions.append(String(line))
            } else if line.starts(with: "<Q3>") {
                newQuestions.append(String(line))
            } else {
                filteredResponse += line + "\n"
            }
        }

        self.responseText = filteredResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        self.questions = newQuestions
        self.updateResponseViewHeight()
    }

    private func updateResponseViewHeight() {
        let textHeight = responseText.height(withConstrainedWidth: UIScreen.main.bounds.width, font: .systemFont(ofSize: 14))
        let questionHeight = questions.joined(separator: "\n").height(withConstrainedWidth: UIScreen.main.bounds.width, font: .systemFont(ofSize: 14))
        responseViewHeight = min(textHeight + questionHeight, maxResponseViewHeight)
    }
}

struct GPTResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

struct ResizableTextView: View {
    @Binding var text: String
    @Binding var questions: [String]
    @Binding var selectedQuestion: String?
    @Binding var height: CGFloat
    @Binding var maxHeight: CGFloat
    var onSelectQuestion: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(text)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = text
                        }) {
                            Text("Copy")
                        }
                    }

                ForEach(questions, id: \.self) { question in
                    Text(question)
                        .foregroundColor(selectedQuestion == question ? .gray : .blue)
                        .onTapGesture {
                            withAnimation {
                                selectedQuestion = question
                                onSelectQuestion(question)
                            }
                        }
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = question
                            }) {
                                Text("Copy")
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation {
                            height = value.translation.height < 0 ? min(maxHeight, height + abs(value.translation.height)) : max(200, height - value.translation.height)
                        }
                    }
            )
        }
        .frame(height: height)
        .onAppear {
            adjustHeight()
        }
        .onChange(of: text) { _ in
            adjustHeight()
        }
        .onChange(of: questions) { _ in
            adjustHeight()
        }
        .scrollContentBackground(.hidden)
    }

    private func adjustHeight() {
        let textHeight = text.height(withConstrainedWidth: UIScreen.main.bounds.width, font: .systemFont(ofSize: 14))
        let questionHeight = questions.joined(separator: "\n").height(withConstrainedWidth: UIScreen.main.bounds.width, font: .systemFont(ofSize: 14))
        height = min(textHeight + questionHeight, maxHeight)
    }
}

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        return ceil(boundingBox.height)
    }
}

