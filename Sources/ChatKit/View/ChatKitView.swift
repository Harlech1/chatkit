import SwiftUI
import PhotosUI

public struct ChatKitView: View {
    @State private var store = ChatStore()
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool

    @State private var isScrolledUp = false
    @State private var scrollProxy: ScrollViewProxy?

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false

    private let title: String
    private let accentColor: Color

    public init(title: String = "Chat", accentColor: Color = .blue) {
        self.title = title
        self.accentColor = accentColor
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(store.messages.enumerated()), id: \.element.id) { index, message in
                            ChatBubble(message: message, accentColor: accentColor)
                                .padding(.top, spacing(for: index))
                                .id(message.id)
                        }

                        if store.isProcessing {
                            TypingIndicator()
                                .padding(.top, 8)
                        }

                        Color.clear
                            .frame(height: 80)
                            .id("bottom")
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(
                                            key: ScrollOffsetPreferenceKey.self,
                                            value: geo.frame(in: .global).minY
                                        )
                                }
                            )
                    }
                    .padding()
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    let screenHeight = UIScreen.main.bounds.height
                    let atBottom = value < screenHeight + 50
                    if atBottom != !isScrolledUp {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isScrolledUp = !atBottom
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture { hideKeyboard() }
                .onAppear {
                    scrollProxy = proxy
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: isTextFieldFocused) { _, focused in
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: store.messages.count) { _, _ in
                    if let last = store.messages.last, last.isFromUser {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    } else {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }

            VStack(spacing: 8) {
                if isScrolledUp {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isScrolledUp = false
                        }
                        DispatchQueue.main.async {
                            withAnimation {
                                scrollProxy?.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .modifier(GlassButtonModifier(isActive: false, interactive: false))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
                }

                inputBar
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(Color.clear)
        .scrollContentBackground(.hidden)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                selectedPhotoItem = nil
            }
        }
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageToSend = selectedImage

        guard !trimmed.isEmpty || imageToSend != nil else { return }

        messageText = ""
        selectedImage = nil

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        store.send(text: trimmed, image: imageToSend)
    }

    private func spacing(for index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        let current = store.messages[index]
        let previous = store.messages[index - 1]
        return current.isFromUser == previous.isFromUser ? 2 : 8
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let image = selectedImage {
                HStack(alignment: .top, spacing: 8) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            selectedImage = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(8)
                .modifier(GlassModifier(cornerRadius: 16))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                    }
                    .buttonStyle(.plain)
                    .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)

                    TextField("Message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .focused($isTextFieldFocused)
                        .submitLabel(.return)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .modifier(GlassModifier(cornerRadius: 20))

                if canSend {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .modifier(GlassButtonModifier(
                            color: accentColor,
                            isActive: true,
                            interactive: false
                        ))
                        .contentShape(Circle())
                        .onTapGesture {
                            sendMessage()
                        }
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.3), value: selectedImage != nil)
        .animation(.interactiveSpring(duration: 0.3), value: canSend)
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedImage != nil
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    var accentColor: Color = .blue
    @State private var appeared = false
    @State private var showEnlargedImage = false

    private var markdownText: AttributedString {
        (try? AttributedString(
            markdown: message.text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(message.text)
    }

    var body: some View {
        HStack(alignment: .top) {
            if message.isFromUser {
                Spacer(minLength: UIScreen.main.bounds.width * 0.165)
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 6) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onTapGesture {
                            showEnlargedImage = true
                        }
                }

                if !message.text.isEmpty {
                    Text(markdownText)
                        .padding(10)
                        .background(message.isFromUser ? accentColor : Color(.systemGray5))
                        .foregroundStyle(message.isFromUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .contextMenu {
                if !message.text.isEmpty {
                    Button(action: {
                        UIPasteboard.general.string = message.text
                    }) {
                        Label("Copy Text", systemImage: "doc.on.doc")
                    }
                }
                if message.image != nil {
                    Button(action: {
                        if let image = message.image {
                            UIPasteboard.general.image = image
                        }
                    }) {
                        Label("Copy Image", systemImage: "photo.on.rectangle")
                    }
                }
            }

            if !message.isFromUser {
                Spacer(minLength: UIScreen.main.bounds.width * 0.165)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
        }
        .fullScreenCover(isPresented: $showEnlargedImage) {
            if let image = message.image {
                EnlargedImageView(image: image)
            }
        }
    }
}

// MARK: - Enlarged Image View

struct EnlargedImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                let delta = value.magnification / lastScale
                                lastScale = value.magnification
                                scale = min(max(scale * delta, 1), 4)
                            }
                            .onEnded { _ in
                                lastScale = 1
                                if scale <= 1 {
                                    withAnimation(.spring(duration: 0.3)) {
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                } else if value.translation.height > 0 {
                                    offset = CGSize(width: 0, height: value.translation.height)
                                }
                            }
                            .onEnded { value in
                                if scale > 1 {
                                    lastOffset = offset
                                } else if value.translation.height > 100 {
                                    dismiss()
                                } else {
                                    withAnimation(.spring(duration: 0.3)) {
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.3)) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2
                            }
                        }
                    }
                    .onTapGesture {
                        dismiss()
                    }
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animationOffsets: [CGFloat] = [0, 0, 0]

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 6, height: 6)
                        .offset(y: animationOffsets[index])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        for index in 0..<3 {
            withAnimation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever()
                    .delay(Double(index) * 0.2)
            ) {
                animationOffsets[index] = -5
            }
        }
    }
}

// MARK: - Glass Modifiers

struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

struct GlassButtonModifier: ViewModifier {
    var color: Color = .blue
    var isActive: Bool = false
    var interactive: Bool = true

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if isActive {
                if interactive {
                    content.glassEffect(.regular.tint(color).interactive(), in: .circle)
                } else {
                    content.glassEffect(.regular.tint(color), in: .circle)
                }
            } else {
                if interactive {
                    content.glassEffect(.regular.interactive(), in: .circle)
                } else {
                    content.glassEffect(.regular, in: .circle)
                }
            }
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationStack {
        ChatKitView()
    }
}
